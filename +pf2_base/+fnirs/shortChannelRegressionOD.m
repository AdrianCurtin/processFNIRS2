function odCols = shortChannelRegressionOD(odCols, channelNumbers, wavelengths, probe, varargin)
% SHORTCHANNELREGRESSIONOD Short-separation regression in optical-density space
%
% Removes superficial (scalp) physiology from long-separation channels by
% regressing each long channel's optical density against short-separation
% channel optical density, PER WAVELENGTH, BEFORE the Beer-Lambert conversion.
% Applying short-channel regression (SSR) in OD space keeps the modified
% Beer-Lambert law from amplifying systemic residuals, which is the ordering
% recommended by Brigadoi & Cooper (2015) and used by MNE-NIRS and Cedalion.
% The complementary Hb-space variant (run after Beer-Lambert) is
% pf2_base.fnirs.shortChannelRegression; the two give different results and
% are both legitimate.
%
% This function operates on the raw-column OD layout produced by
% pf2_base.fnirs.processStageRaw2OD (one column per optode per wavelength),
% which is exactly what processFNIRS2 holds between the OD and Beer-Lambert
% stages. It is invoked from processFNIRS2 via the 'ODShortRegression' option.
%
% References:
%   Brigadoi, S. & Cooper, R. J. (2015). How short is short? Optimum
%   source-detector distance for short-separation channels in functional
%   NIRS. Neurophotonics, 2(2), 025005. DOI: 10.1117/1.NPh.2.2.025005
%
%   Saager, R. B. & Berger, A. J. (2005). Direct characterization and removal
%   of interfering absorption trends in two-layer turbid media. J. Opt. Soc.
%   Am. A, 22(9), 1874-1882. DOI: 10.1364/JOSAA.22.001874
%
% Syntax:
%   odCols = pf2_base.fnirs.shortChannelRegressionOD(odCols, channelNumbers, ...
%       wavelengths, probe)
%   odCols = pf2_base.fnirs.shortChannelRegressionOD(..., 'Name', Value)
%
% Inputs:
%   odCols         - [T x C] optical density in raw-column layout (as returned
%                    by processStageRaw2OD). Time/dark/marker columns are left
%                    untouched; only valid optode columns are modified.
%   channelNumbers - [1 x C] optode number for each column (>0 optode, 0 time,
%                    <0 marker/metadata). Same vector passed to bvoxy.
%   wavelengths    - [1 x C] wavelength (nm) for each column (>0 light,
%                    0 dark/ambient, <0 metadata).
%   probe          - Device probe struct with a TableOpt (OptodeNum,
%                    IsShortSeparation, Pos3D_*/Pos2D_*, SD), i.e. curProbe in
%                    processFNIRS2. A pf2.Device is also accepted.
%
% Name-Value Parameters:
%   'Method'          - 'nearest' (default) use the closest short channel per
%                       long channel; 'all' regress out all short channels
%                       simultaneously.
%   'ShortChannels'   - Explicit override of short-channel identity, as a
%                       logical [1 x nOpt] or optode-index vector over the
%                       sorted unique optode list. Default [] (derive from the
%                       probe).
%   'OptodePositions' - Explicit [nOpt x 3] positions (sorted-optode order) for
%                       nearest matching. Default [] (derive from the probe).
%   'ShortSepMax'     - SD threshold (same units as TableOpt.SD, typically cm)
%                       used to flag short channels when the probe carries no
%                       IsShortSeparation column. Default [].
%   'CenterRegressors'- Mean-center each regressor before removal so the
%                       correction is exactly mean-preserving (default: false,
%                       matching pf2_base.fnirs.shortChannelRegression).
%
% Outputs:
%   odCols - [T x C] optical density with superficial signal removed from the
%            long-channel columns. Short-channel and non-optode columns are
%            unchanged.
%
% Algorithm:
%   1. Identify valid optode columns and group them by optode and wavelength
%      (sub-805 nm wavelength first, matching bvoxy's channel ordering).
%   2. Resolve short channels (explicit override -> TableOpt.IsShortSeparation
%      -> SD < ShortSepMax) and optode positions (override -> Pos3D -> Pos2D).
%   3. For each wavelength and each long optode, regress out the nearest (or
%      all) short-channel OD and keep the residual. Samples where the target or
%      a regressor is NaN are left unchanged.
%
% Example:
%   % Typically used via processFNIRS2 rather than directly:
%   proc = processFNIRS2(data, 'ODShortRegression', true);
%   % ...or with options:
%   proc = processFNIRS2(data, 'ODShortRegression', {'Method','all'});
%
% See also: pf2_base.fnirs.shortChannelRegression, pf2_base.fnirs.bvoxy,
%           pf2_base.fnirs.processStageRaw2OD, processFNIRS2

% --- Parse inputs ---
p = inputParser;
p.addRequired('odCols', @(x) isnumeric(x) && ismatrix(x));
p.addRequired('channelNumbers', @(x) isnumeric(x) && isvector(x));
p.addRequired('wavelengths', @(x) isnumeric(x) && isvector(x));
p.addRequired('probe');
p.addParameter('Method', 'nearest', @(x) ismember(x, {'nearest', 'all'}));
p.addParameter('ShortChannels', [], @(x) isempty(x) || isvector(x));
p.addParameter('OptodePositions', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
p.addParameter('ShortSepMax', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('CenterRegressors', false, @(x) isscalar(x) && (islogical(x) || ismember(x, [0 1])));
p.parse(odCols, channelNumbers, wavelengths, probe, varargin{:});

method = p.Results.Method;
shortOverride = p.Results.ShortChannels;
posOverride = p.Results.OptodePositions;
shortSepMax = p.Results.ShortSepMax;
centerReg = logical(p.Results.CenterRegressors);

ch = channelNumbers(:)';
wl = wavelengths(:)';

% --- Group valid optode columns by optode and wavelength ---
valid = ch > 0 & wl > 0;
uOpt = unique(ch(valid));         % sorted, matches bvoxy / TableOpt ordering
nOpt = numel(uOpt);
if nOpt == 0
    return;    % nothing to regress
end

% colIdx(o, w): column index for optode o at wavelength band w (1 = <805 nm)
colIdx = nan(nOpt, 2);
for o = 1:nOpt
    optCols = find(ch == uOpt(o) & valid);
    for c = optCols
        if wl(c) < 805
            colIdx(o, 1) = c;
        else
            colIdx(o, 2) = c;
        end
    end
end

% Optodes missing either wavelength column cannot be corrected/used as regressors
usable = all(~isnan(colIdx), 2);

% --- Resolve short channels (override -> TableOpt flag -> SD threshold) ---
[topt, dev] = getOptTable(probe);
isShort = resolveShort(shortOverride, topt, dev, uOpt, shortSepMax);
if isempty(isShort)
    warning('pf2:ssrOD:noShortInfo', ...
        'No short-channel information available; OD-space SSR skipped.');
    return;
end
isShort = isShort(:)' & usable(:)';

shortIdx = find(isShort);
longIdx = find(~isShort & usable(:)');
if isempty(shortIdx)
    warning('pf2:ssrOD:noShortChannels', 'No short-separation channels found; OD-space SSR skipped.');
    return;
end
if isempty(longIdx)
    warning('pf2:ssrOD:noLongChannels', 'No long-separation channels found; OD-space SSR skipped.');
    return;
end

% --- Optode positions for nearest matching (override -> Pos3D -> Pos2D) ---
pos = resolvePositions(posOverride, topt, uOpt);
if strcmp(method, 'nearest') && (isempty(pos) || size(pos, 1) < nOpt)
    warning('pf2:ssrOD:noPositions', ...
        'No optode positions for nearest matching; using ''all'' method.');
    method = 'all';
end

% --- Regress each wavelength independently ---
for w = 1:2
    shortData = odCols(:, colIdx(shortIdx, w));   % [T x nShort]
    switch method
        case 'nearest'
            for li = 1:numel(longIdx)
                lch = longIdx(li);
                d = sqrt(sum((pos(shortIdx, :) - pos(lch, :)).^2, 2));
                [~, nearest] = min(d);
                col = colIdx(lch, w);
                odCols(:, col) = regressOut(odCols(:, col), shortData(:, nearest), centerReg);
            end
        case 'all'
            for li = 1:numel(longIdx)
                lch = longIdx(li);
                col = colIdx(lch, w);
                odCols(:, col) = regressOut(odCols(:, col), shortData, centerReg);
            end
    end
end

end

%%_Subfunctions_________________________________________________________

function y = regressOut(y, X, centerReg)
% REGRESSOUT Remove signal explained by regressors from target (OLS, NaN-safe)
%
% Mirrors the residualization in pf2_base.fnirs.shortChannelRegression: an
% intercept is fit but not applied (channel level retained), and rows where the
% target or a regressor is NaN are left at their original value.

validMask = ~isnan(y) & all(~isnan(X), 2);
if sum(validMask) < size(X, 2) + 1
    return;    % not enough valid samples
end

Xreg = [X(validMask, :), ones(sum(validMask), 1)];
beta = pinv(Xreg) * y(validMask);
slope = beta(1:end-1);

Xv = X(validMask, :);
if centerReg
    Xv = Xv - mean(Xv, 1);
end

y(validMask) = y(validMask) - Xv * slope;

end

function [topt, dev] = getOptTable(probe)
% GETOPTTABLE Extract a TableOpt and/or device handle from the probe argument

topt = [];
dev = [];
if isstruct(probe) && isfield(probe, 'TableOpt') && istable(probe.TableOpt)
    topt = probe.TableOpt;
elseif isobject(probe)
    dev = probe;   % e.g. a pf2.Device
    try
        topt = probe.optodeTable();   % TableOpt: OptodeNum/SD/Pos3D_* (not TableCh)
    catch
    end
end

end

function isShort = resolveShort(override, topt, dev, uOpt, shortSepMax)
% RESOLVESHORT Determine short-channel logical over the sorted optode list

nOpt = numel(uOpt);
isShort = [];

% 1. Explicit override (logical mask or index list)
if ~isempty(override)
    if islogical(override) && numel(override) == nOpt
        isShort = override(:)';
    else
        isShort = false(1, nOpt);
        isShort(override) = true;
    end
    return;
end

% 2. TableOpt.IsShortSeparation aligned by OptodeNum
if istable(topt) && ismember('IsShortSeparation', topt.Properties.VariableNames) ...
        && ismember('OptodeNum', topt.Properties.VariableNames)
    isShort = false(1, nOpt);
    for o = 1:nOpt
        idx = find(topt.OptodeNum == uOpt(o), 1);
        if ~isempty(idx)
            isShort(o) = logical(topt.IsShortSeparation(idx));
        end
    end
    return;
end

% 3. Device short-separation flags
if ~isempty(dev)
    try
        ss = dev.isShortSep();
        if numel(ss) == nOpt
            isShort = logical(ss(:)');
            return;
        end
    catch
    end
end

% 4. SD-distance threshold fallback
if ~isempty(shortSepMax) && istable(topt) ...
        && ismember('SD', topt.Properties.VariableNames) ...
        && ismember('OptodeNum', topt.Properties.VariableNames)
    isShort = false(1, nOpt);
    for o = 1:nOpt
        idx = find(topt.OptodeNum == uOpt(o), 1);
        if ~isempty(idx)
            isShort(o) = topt.SD(idx) < shortSepMax;
        end
    end
end

end

function pos = resolvePositions(override, topt, uOpt)
% RESOLVEPOSITIONS Optode positions over the sorted optode list (Pos3D -> Pos2D)

nOpt = numel(uOpt);
pos = [];

if ~isempty(override) && size(override, 1) >= nOpt
    pos = override(1:nOpt, :);
    return;
end

if ~istable(topt) || ~ismember('OptodeNum', topt.Properties.VariableNames)
    return;
end

have3D = all(ismember({'Pos3D_x', 'Pos3D_y', 'Pos3D_z'}, topt.Properties.VariableNames));
have2D = all(ismember({'Pos2D_x', 'Pos2D_y'}, topt.Properties.VariableNames));
if ~have3D && ~have2D
    return;
end

pos = zeros(nOpt, 3);
for o = 1:nOpt
    idx = find(topt.OptodeNum == uOpt(o), 1);
    if isempty(idx)
        pos = [];
        return;
    end
    if have3D
        pos(o, :) = [topt.Pos3D_x(idx), topt.Pos3D_y(idx), topt.Pos3D_z(idx)];
    else
        pos(o, 1) = topt.Pos2D_x(idx);
        pos(o, 2) = topt.Pos2D_y(idx);
        if ismember('Pos2D_z', topt.Properties.VariableNames)
            pos(o, 3) = topt.Pos2D_z(idx);
        end
    end
end

end
