function [pcMatrix, pcInfo] = extractShortChannelPCs(fNIR, varargin)
% EXTRACTSHORTCHANNELPCS Extract principal components from short-separation channels
%
% Computes PCA on short-separation channel data and returns the principal
% component time series as a matrix suitable for use as GLM regressors via
% buildDesignMatrix's 'ShortChannels' parameter. This captures shared
% systemic variance across multiple short channels more effectively than
% using individual short channels as regressors.
%
% Reference:
%   Brigadoi, S. & Cooper, R. J. (2015). How short is short? Optimum
%   source-detector distance for short-separation channels in functional
%   NIRS. Neurophotonics, 2(2), 025005.
%
% Syntax:
%   [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR)
%   [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR, 'Name', Value)
%
% Inputs:
%   fNIR - Processed fNIRS struct with hemoglobin fields and probeinfo
%          containing IsShortSeparation flags.
%
% Name-Value Parameters:
%   'NumPCs'    - Number of principal components to extract (default: 2)
%   'Biomarker' - Which field to compute PCs from: 'HbO' or 'HbR'
%                 (default: 'HbO')
%
% Outputs:
%   pcMatrix - [T x NumPCs] principal component time series
%              Ready to pass to buildDesignMatrix(..., 'ShortChannels', pcMatrix)
%   pcInfo   - Struct with fields:
%              .varianceExplained - [1 x NumPCs] fraction of variance per PC
%              .shortChannels     - indices of short channels used
%              .biomarker         - biomarker field used
%              .numPCs            - number of PCs extracted
%
% Algorithm:
%   1. Identify short-separation channels from probeinfo
%   2. Extract biomarker data for short channels only
%   3. Center the data (subtract column means)
%   4. Compute SVD (economy): [U, S, V] = svd(X, 'econ')
%   5. PC scores = U * S (first NumPCs columns)
%   6. Variance explained = diag(S).^2 / sum(diag(S).^2)
%
% Example:
%   data = pf2.import.importSNIRF('subject01.snirf', false);
%   processed = processFNIRS2(data);
%
%   % Extract short-channel PCs
%   [scPCs, info] = pf2_base.fnirs.extractShortChannelPCs(processed, 'NumPCs', 3);
%   fprintf('Variance explained: %.1f%%\n', sum(info.varianceExplained)*100);
%
%   % Use as GLM regressors
%   events = struct('name', 'task', 'onsets', [10, 40, 70], 'duration', 20);
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(processed.time, processed.fs, ...
%       events, 'ShortChannels', scPCs);
%
% See also: pf2_base.fnirs.shortChannelRegression, pf2_base.fnirs.buildDesignMatrix,
%           pf2_base.fnirs.fitGLM

%% Parse inputs
p = inputParser;
p.addRequired('fNIR', @isstruct);
p.addParameter('NumPCs', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('Biomarker', 'HbO', @(x) ischar(x) || isstring(x));
p.parse(fNIR, varargin{:});

numPCs = round(p.Results.NumPCs);
biomarker = char(p.Results.Biomarker);

%% Validate biomarker field exists
assert(isfield(fNIR, biomarker), 'pf2:extractShortChannelPCs:noBiomarker', ...
    'Data struct does not contain .%s field.', biomarker);

%% Identify short channels
probeInfo = [];
if isfield(fNIR, 'probeinfo') && isfield(fNIR.probeinfo, 'Probe')
    if iscell(fNIR.probeinfo.Probe) && ~isempty(fNIR.probeinfo.Probe)
        probeInfo = fNIR.probeinfo.Probe{1};
    end
end

if isempty(probeInfo) || ~isfield(probeInfo, 'IsShortSeparation')
    error('pf2:extractShortChannelPCs:noProbe', ...
        'Cannot identify short channels. probeinfo.Probe{1}.IsShortSeparation required.');
end

isShort = probeInfo.IsShortSeparation(:)';
shortIdx = find(isShort);

if isempty(shortIdx)
    error('pf2:extractShortChannelPCs:noShort', ...
        'No short-separation channels found in probeinfo.');
end

%% Extract short-channel data
Y = fNIR.(biomarker);
nCols = size(Y, 2);

if max(shortIdx) > nCols
    error('pf2:extractShortChannelPCs:dimMismatch', ...
        'Short channel indices exceed %s column count (%d).', biomarker, nCols);
end

shortData = Y(:, shortIdx);  % [T x nShort]
nShort = length(shortIdx);

%% Cap NumPCs
numPCs = min(numPCs, nShort);

%% Center data
shortCentered = shortData - mean(shortData, 1, 'omitnan');

% Replace NaN with 0 for SVD
nanMask = isnan(shortCentered);
shortCentered(nanMask) = 0;

%% Compute PCA via SVD
[U, S, ~] = svd(shortCentered, 'econ');

% PC scores: U * S gives the projection onto principal components
scores = U * S;
pcMatrix = scores(:, 1:numPCs);

% Variance explained
singularValues = diag(S);
totalVar = sum(singularValues.^2);
varianceExplained = singularValues(1:numPCs).^2 / totalVar;

%% Build info struct
pcInfo.varianceExplained = varianceExplained(:)';
pcInfo.shortChannels = shortIdx;
pcInfo.biomarker = biomarker;
pcInfo.numPCs = numPCs;

end
