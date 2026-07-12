function fNIR = shortChannelRegression(fNIR, varargin)
% SHORTCHANNELREGRESSION Remove superficial physiology using short-separation channels
%
% Regresses out scalp hemodynamic signals from long-separation channels
% using short-separation channel data as a proxy for superficial physiology.
% Three methods are available: nearest short channel per long channel,
% PCA of all short channels, or all short channels simultaneously.
%
% Reference:
%   Saager, R. B. & Berger, A. J. (2005). Direct characterization and
%   removal of interfering absorption trends in two-layer turbid media.
%   J. Opt. Soc. Am. A, 22(9), 1874-1882.
%
%   Brigadoi, S. & Cooper, R. J. (2015). How short is short? Optimum
%   source-detector distance for short-separation channels in functional
%   NIRS. Neurophotonics, 2(2), 025005.
%
% Syntax:
%   fNIR = pf2_base.fnirs.shortChannelRegression(fNIR)
%   fNIR = pf2_base.fnirs.shortChannelRegression(fNIR, 'Name', Value)
%
% Inputs:
%   fNIR - Processed fNIRS data structure with hemoglobin fields (.HbO,
%          .HbR, etc.) and .probeinfo containing probe geometry with
%          IsShortSeparation flags.
%
% Name-Value Parameters:
%   'Method'     - Regression method (default: 'nearest')
%                  'nearest' - Use closest short channel for each long channel
%                  'pca'     - Use first N principal components of short channels
%                  'all'     - Use all short channels as simultaneous regressors
%   'Biomarkers' - Cell array of fields to correct (default: {'HbO','HbR'})
%   'NumPCs'     - Number of PCs for 'pca' method (default: 1)
%   'ShortSepMax'- Optional source-detector distance threshold for detecting
%                  short channels from geometry (same units as the device's
%                  sdDistances) when no flags are available (default: []).
%   'CenterRegressors' - Mean-center each short-channel regressor before
%                  removing it (default: false). When true the correction is
%                  exactly mean-preserving (no DC shift); when false the
%                  long-channel mean shifts by mean(regressor)*beta, matching
%                  the historical behavior.
%
% Outputs:
%   fNIR - Corrected fNIRS structure with superficial signal removed from
%          specified biomarker fields. Original short-channel data is
%          preserved. A .ssrInfo field is added with regression details.
%
% Algorithm:
%   1. Identify short-separation channels. Detection prefers
%      probeinfo.Probe{1}.IsShortSeparation, then falls back to the attached
%      device (fNIR.device.isShortSep), then to a source-detector distance
%      threshold (ShortSepMax) on the device geometry. This lets SSR run on
%      device-config imports (e.g. COBI .nir) that carry short channels in
%      the device but populate no probeinfo.
%   2. Extract short-channel biomarker data
%   3. For each long channel and biomarker:
%      a. 'nearest': find closest short channel by 3D position, regress out
%      b. 'pca': compute PCA of all short channels, regress out first NumPCs
%      c. 'all': regress out all short channels simultaneously
%   4. Corrected = original - shortRegressors * beta
%
% Example:
%   data = pf2.import.importSNIRF('subject01.snirf', false);
%   processed = processFNIRS2(data);
%   corrected = pf2_base.fnirs.shortChannelRegression(processed);
%
% Notes:
%   - Requires processed data (hemoglobin fields must exist)
%   - Short channels are identified by the precedence in the Algorithm
%     section (probeinfo flags -> device flags -> SD-distance threshold)
%   - Short-channel data in the output is not modified
%   - Samples where the target or a short-channel regressor is NaN are left
%     at their original value (the correction is skipped there) rather than
%     being set to NaN, so NaN gaps in short channels do not erase otherwise
%     valid long-channel samples. A short level discontinuity can appear at
%     gap boundaries (corrected vs uncorrected samples meet); this is
%     preferred over fabricating correction values on untrusted samples
%   - SSR is typically applied after Beer-Lambert conversion
%
% See also: pf2_base.fnirs.buildDesignMatrix, pf2_base.fnirs.fitGLM,
%           pf2.import.importSNIRF

% --- Parse inputs ---
p = inputParser;
p.addRequired('fNIR', @isstruct);
p.addParameter('Method', 'nearest', @(x) ismember(x, {'nearest', 'pca', 'all'}));
p.addParameter('Biomarkers', {'HbO', 'HbR'}, @iscell);
p.addParameter('NumPCs', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('ShortSepMax', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('CenterRegressors', false, @(x) isscalar(x) && (islogical(x) || ismember(x, [0 1])));
p.parse(fNIR, varargin{:});

method = p.Results.Method;
biomarkers = p.Results.Biomarkers;
numPCs = round(p.Results.NumPCs);   % PC count must be integer-valued
shortSepMax = p.Results.ShortSepMax;
centerReg = logical(p.Results.CenterRegressors);

% --- Identify short channels (probeinfo -> device -> SD threshold) ---
[isShort, optPos3D] = resolveShortChannels(fNIR, shortSepMax);
if isempty(isShort)
    warning('pf2:ssr:noProbe', ...
        'No probeinfo or device geometry found. Cannot identify short channels.');
    return;
end

isShort = logical(isShort(:)');
nOpt = numel(isShort);
shortIdx = find(isShort);
longIdx = find(~isShort);

if isempty(shortIdx)
    warning('pf2:ssr:noShortChannels', 'No short-separation channels found.');
    return;
end

if isempty(longIdx)
    warning('pf2:ssr:noLongChannels', 'No long-separation channels found.');
    return;
end

% --- Positions for nearest-channel matching ---
if strcmp(method, 'nearest') && (isempty(optPos3D) || size(optPos3D, 1) < nOpt)
    warning('pf2:ssr:noPositions', ...
        'No 3D positions available for nearest matching; using ''all'' method.');
    method = 'all';
end

% --- Apply regression for each biomarker ---
for b = 1:length(biomarkers)
    fn = biomarkers{b};
    if ~isfield(fNIR, fn)
        continue;
    end

    Y = fNIR.(fn);  % [T x nOpt]
    [T, nCols] = size(Y);

    % Handle case where data columns don't match optode count
    % (e.g., short channels already removed from data)
    if nCols ~= nOpt
        warning('pf2:ssr:dimMismatch', ...
            '%s has %d columns but probe has %d optodes. Skipping.', fn, nCols, nOpt);
        continue;
    end

    shortData = Y(:, shortIdx);  % [T x nShort]
    nShort = length(shortIdx);

    switch method
        case 'nearest'
            for li = 1:length(longIdx)
                lch = longIdx(li);
                % Find nearest short channel by 3D Euclidean distance
                longPos = optPos3D(lch, :);
                dists = sqrt(sum((optPos3D(shortIdx, :) - longPos).^2, 2));
                [~, nearestSCidx] = min(dists);

                % Regress out nearest short channel
                sc = shortData(:, nearestSCidx);
                Y(:, lch) = regressOut(Y(:, lch), sc, centerReg);
            end

        case 'pca'
            % PCA on short-channel data
            shortCentered = shortData - mean(shortData, 1, 'omitnan');
            % Replace NaN for SVD
            shortCentered(isnan(shortCentered)) = 0;

            if nShort > 1
                [U, S, ~] = svd(shortCentered, 'econ');
                nPC = min(numPCs, size(U, 2));
                pcRegressors = U(:, 1:nPC) * S(1:nPC, 1:nPC);
            else
                pcRegressors = shortCentered;
            end

            % Regress PCs from each long channel
            for li = 1:length(longIdx)
                lch = longIdx(li);
                Y(:, lch) = regressOut(Y(:, lch), pcRegressors, centerReg);
            end

        case 'all'
            % Use all short channels as regressors
            for li = 1:length(longIdx)
                lch = longIdx(li);
                Y(:, lch) = regressOut(Y(:, lch), shortData, centerReg);
            end
    end

    fNIR.(fn) = Y;
end

% --- Add SSR metadata ---
fNIR.ssrInfo.method = method;
fNIR.ssrInfo.shortChannels = shortIdx;
fNIR.ssrInfo.longChannels = longIdx;
fNIR.ssrInfo.biomarkers = biomarkers;
fNIR.ssrInfo.centerRegressors = centerReg;
if strcmp(method, 'pca')
    fNIR.ssrInfo.numPCs = numPCs;
end

end

%%_Subfunctions_________________________________________________________

function y = regressOut(y, X, centerReg)
% REGRESSOUT Remove signal explained by regressors from target
%
% Inputs:
%   y         - Target signal [T x 1]
%   X         - Regressors [T x K]
%   centerReg - Mean-center the regressors before removal (default: false).
%               true gives an exactly mean-preserving correction; false
%               leaves the historical mean(X)*beta DC shift.
%
% Outputs:
%   y - Residual signal [T x 1]

if nargin < 3 || isempty(centerReg)
    centerReg = false;
end

% Fit beta on samples where both target and regressors are valid.
validMask = ~isnan(y) & all(~isnan(X), 2);
if sum(validMask) < size(X, 2) + 1
    return;  % Not enough valid samples
end

% OLS slope(s) with an intercept in the model (the intercept is fit but not
% applied, so the long-channel level is retained rather than zeroed).
Xreg = [X(validMask, :), ones(sum(validMask), 1)];
beta = pinv(Xreg) * y(validMask);
slope = beta(1:end-1);

% Effective regressors: optionally mean-centered so that removing them does
% not shift the channel mean (otherwise the mean moves by mean(X)*slope).
Xv = X(validMask, :);
if centerReg
    Xv = Xv - mean(Xv, 1);
end

% Remove the regressor contribution only on valid rows. Rows where the target
% or a regressor is NaN are left at their original value, so a NaN gap in a
% short channel cannot stamp NaN onto an otherwise-valid long-channel sample.
% This can leave a small level step at gap boundaries, which is preferable to
% fabricating a correction on the untrusted (NaN-gap) samples.
y(validMask) = y(validMask) - Xv * slope;

end

function [isShort, pos3D] = resolveShortChannels(fNIR, shortSepMax)
% RESOLVESHORTCHANNELS Identify short channels and positions from any source
%
% Detection precedence:
%   1. probeinfo.Probe{1}.IsShortSeparation (+ OptPos3D / OptPosXYZ)
%   2. fNIR.device.isShortSep() (+ device.mniPositions())
%   3. fNIR.device.sdDistances() < shortSepMax (if shortSepMax provided)
%
% Inputs:
%   fNIR        - fNIRS data structure
%   shortSepMax - SD-distance threshold for geometry-based detection, or []
%
% Outputs:
%   isShort - [1 x nOpt] logical flag, or [] if nothing could be resolved
%   pos3D   - [nOpt x 3] positions for nearest matching, or [] if unavailable

isShort = [];
pos3D = [];

% --- 1. probeinfo flags ---
probeInfo = getProbeInfo(fNIR);
if ~isempty(probeInfo) && isfield(probeInfo, 'IsShortSeparation') ...
        && ~isempty(probeInfo.IsShortSeparation)
    isShort = logical(probeInfo.IsShortSeparation(:)');
    pos3D = getOptPos3D(probeInfo, numel(isShort));
    return;
end

% --- 2 & 3. device-based detection ---
if isfield(fNIR, 'device') && ~isempty(fNIR.device)
    dev = fNIR.device;

    % Device short-separation flags
    try
        ss = dev.isShortSep();
        if ~isempty(ss) && any(ss)
            isShort = logical(ss(:)');
        end
    catch
    end

    % SD-distance threshold fallback
    if isempty(isShort) && ~isempty(shortSepMax)
        try
            sd = dev.sdDistances();
            if ~isempty(sd)
                isShort = sd(:)' < shortSepMax;
            end
        catch
        end
    end

    % Device positions for nearest matching
    if ~isempty(isShort)
        try
            if dev.hasMNI()
                pos3D = dev.mniPositions();
            end
        catch
        end
    end
end

end

function probeInfo = getProbeInfo(fNIR)
% GETPROBEINFO Extract probe info from fNIRS struct
%
% Inputs:
%   fNIR - fNIRS data structure
%
% Outputs:
%   probeInfo - Probe struct with IsShortSeparation, or [] if not found

probeInfo = [];
if isfield(fNIR, 'probeinfo') && isfield(fNIR.probeinfo, 'Probe')
    if iscell(fNIR.probeinfo.Probe) && ~isempty(fNIR.probeinfo.Probe)
        probeInfo = fNIR.probeinfo.Probe{1};
    end
end

end

function pos3D = getOptPos3D(probeInfo, nOpt)
% GETOPTPOS3D Extract 3D optode midpoint positions
%
% Inputs:
%   probeInfo - Probe struct
%   nOpt      - Number of optodes
%
% Outputs:
%   pos3D - [nOpt x 3] position matrix

% Return [] when no usable positions exist so the caller can downgrade
% 'nearest' to 'all' rather than matching against all-origin coordinates.
pos3D = [];

if isfield(probeInfo, 'OptPos3D') && size(probeInfo.OptPos3D, 1) >= nOpt
    pos3D = probeInfo.OptPos3D(1:nOpt, :);
elseif isfield(probeInfo, 'OptPosX')
    pos3D = zeros(nOpt, 3);
    nAvail = min(nOpt, length(probeInfo.OptPosX));
    pos3D(1:nAvail, 1) = probeInfo.OptPosX(1:nAvail);
    pos3D(1:nAvail, 2) = probeInfo.OptPosY(1:nAvail);
    if isfield(probeInfo, 'OptPosZ')
        pos3D(1:nAvail, 3) = probeInfo.OptPosZ(1:nAvail);
    end
end

end
