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
%
% Outputs:
%   fNIR - Corrected fNIRS structure with superficial signal removed from
%          specified biomarker fields. Original short-channel data is
%          preserved. A .ssrInfo field is added with regression details.
%
% Algorithm:
%   1. Identify short-separation channels from probeinfo.IsShortSeparation
%   2. Extract short-channel biomarker data
%   3. For each long channel and biomarker:
%      a. 'nearest': find closest short channel by 3D position, regress out
%      b. 'pca': compute PCA of all short channels, regress out first NumPCs
%      c. 'all': regress out all short channels simultaneously
%   4. Corrected = original - shortRegressors * beta
%
% Example:
%   data = pf2.import.importSNIRF('subject01.snirf', false);
%   processed = processFNIRS2(data, 'ShowGUI', false);
%   corrected = pf2_base.fnirs.shortChannelRegression(processed);
%
% Notes:
%   - Requires processed data (hemoglobin fields must exist)
%   - Short channels are identified by probeinfo.Probe{1}.IsShortSeparation
%   - Short-channel data in the output is not modified
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
p.parse(fNIR, varargin{:});

method = p.Results.Method;
biomarkers = p.Results.Biomarkers;
numPCs = p.Results.NumPCs;

% --- Identify short channels ---
probeInfo = getProbeInfo(fNIR);
if isempty(probeInfo)
    warning('pf2:ssr:noProbe', 'No probeinfo found. Cannot identify short channels.');
    return;
end

isShort = probeInfo.IsShortSeparation(:)';
nOpt = length(isShort);
shortIdx = find(isShort);
longIdx = find(~isShort);

if isempty(shortIdx)
    warning('pf2:ssr:noShortChannels', 'No short-separation channels found in probeinfo.');
    return;
end

if isempty(longIdx)
    warning('pf2:ssr:noLongChannels', 'No long-separation channels found.');
    return;
end

% --- Get 3D positions for nearest-channel matching ---
if strcmp(method, 'nearest')
    optPos3D = getOptPos3D(probeInfo, nOpt);
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
                Y(:, lch) = regressOut(Y(:, lch), sc);
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
                Y(:, lch) = regressOut(Y(:, lch), pcRegressors);
            end

        case 'all'
            % Use all short channels as regressors
            for li = 1:length(longIdx)
                lch = longIdx(li);
                Y(:, lch) = regressOut(Y(:, lch), shortData);
            end
    end

    fNIR.(fn) = Y;
end

% --- Add SSR metadata ---
fNIR.ssrInfo.method = method;
fNIR.ssrInfo.shortChannels = shortIdx;
fNIR.ssrInfo.longChannels = longIdx;
fNIR.ssrInfo.biomarkers = biomarkers;
if strcmp(method, 'pca')
    fNIR.ssrInfo.numPCs = numPCs;
end

end

%%_Subfunctions_________________________________________________________

function y = regressOut(y, X)
% REGRESSOUT Remove signal explained by regressors from target
%
% Inputs:
%   y - Target signal [T x 1]
%   X - Regressors [T x K]
%
% Outputs:
%   y - Residual signal [T x 1]

% Handle NaN: use valid samples for regression, apply to all
validMask = ~isnan(y) & all(~isnan(X), 2);
if sum(validMask) < size(X, 2) + 1
    return;  % Not enough valid samples
end

% Add constant to regressors
Xreg = [X(validMask, :), ones(sum(validMask), 1)];
beta = pinv(Xreg) * y(validMask);

% Remove regressor contribution (exclude constant)
Xfull = [X, ones(size(X, 1), 1)];
y = y - Xfull * beta + beta(end);  % Keep the mean (remove only regressor part)

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

pos3D = zeros(nOpt, 3);

if isfield(probeInfo, 'OptPos3D') && size(probeInfo.OptPos3D, 1) >= nOpt
    pos3D = probeInfo.OptPos3D(1:nOpt, :);
elseif isfield(probeInfo, 'OptPosX')
    nAvail = min(nOpt, length(probeInfo.OptPosX));
    pos3D(1:nAvail, 1) = probeInfo.OptPosX(1:nAvail);
    pos3D(1:nAvail, 2) = probeInfo.OptPosY(1:nAvail);
    if isfield(probeInfo, 'OptPosZ')
        pos3D(1:nAvail, 3) = probeInfo.OptPosZ(1:nAvail);
    end
end

end
