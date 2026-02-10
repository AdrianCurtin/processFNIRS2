function result = computeBetaSeries(data, blocks, varargin)
% COMPUTEBETASERIES Beta-series correlation connectivity
%
% Computes trial-by-trial GLM beta weights and correlates them across
% channels (or ROIs) to produce a connectivity matrix. Two estimation
% strategies are available: Least Squares All (LSA) fits a single GLM with
% one regressor per trial, while Least Squares Separate (LSS) fits N
% separate GLMs, each isolating one trial from the rest.
%
% Reference:
%   Rissman, J., Gazzaley, A., & D'Esposito, M. (2004). Measuring
%   functional connectivity during distinct stages of a cognitive task.
%   NeuroImage, 23(2), 752-763.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computeBetaSeries(data, blocks)
%   result = exploreFNIRS.connectivity.computeBetaSeries(data, blocks, ...
%       'Method', 'LSS', 'Correlation', 'spearman')
%
% Inputs:
%   data   - Processed fNIRS struct with .HbO, .HbR, .time, .fs, .fchMask
%   blocks - Struct array from pf2.data.defineBlocks
%
% Name-Value Parameters:
%   Method      - Estimation method: 'LSA' (default) or 'LSS'
%   Biomarker   - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Correlation - Correlation type: 'pearson' (default) or 'spearman'
%   Condition   - Condition name(s) to include (default: all)
%                 Char or cell array of chars matching blocks.info.Condition
%   DriftOrder  - Legendre drift polynomial order (default: 3)
%   FitMethod   - GLM fit method: 'OLS' (default) or 'AR-IRLS'
%   UseROI      - Use ROI-level data (default: false)
%   Channels    - Channel subset (default: all good channels)
%
% Outputs:
%   result - Struct compatible with computeMatrix output format:
%     .matrix      - [N x N] correlation matrix of trial betas
%     .pmatrix     - [N x N] p-value matrix
%     .channels    - Channel/ROI indices used
%     .labels      - Cell array of labels
%     .method      - 'betaseries_LSA' or 'betaseries_LSS'
%     .biomarker   - Biomarker used
%     .useROI      - Whether ROI mode was used
%     .betas       - [nTrials x nCh] trial beta matrix
%     .nTrials     - Number of trials used
%     .trialLabels - Cell array of trial condition labels
%
% Example:
%   [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
%   d = processFNIRS2(subjects{1});
%   result = exploreFNIRS.connectivity.computeBetaSeries(d, blockDefs{1});
%   exploreFNIRS.connectivity.plotMatrix(result);
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.connectivity.computePPI, pf2_base.fnirs.fitGLM

% --- Parse inputs ---
p = inputParser;
addRequired(p, 'data', @isstruct);
addRequired(p, 'blocks', @isstruct);
addParameter(p, 'Method', 'LSA', @(x) ischar(x) && ismember(upper(x), {'LSA','LSS'}));
addParameter(p, 'Biomarker', 'HbO', @ischar);
addParameter(p, 'Correlation', 'pearson', @(x) ischar(x) && ismember(lower(x), {'pearson','spearman'}));
addParameter(p, 'Condition', {}, @(x) ischar(x) || iscell(x));
addParameter(p, 'DriftOrder', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FitMethod', 'OLS', @(x) ischar(x) && ismember(upper(x), {'OLS','AR-IRLS'}));
addParameter(p, 'UseROI', false, @islogical);
addParameter(p, 'Channels', [], @isnumeric);
parse(p, data, blocks, varargin{:});
opts = p.Results;

estMethod = upper(opts.Method);
bioM = opts.Biomarker;
corrType = lower(opts.Correlation);

% Normalize condition filter to cell
condFilter = opts.Condition;
if ischar(condFilter) && ~isempty(condFilter)
    condFilter = {condFilter};
end

% --- Determine signal and channels ---
if opts.UseROI
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, bioM)
        error('exploreFNIRS:connectivity:computeBetaSeries', ...
            'ROI data not found. Run defineROI + buildROI first.');
    end
    signal = data.ROI.(bioM);
    roiNames = {};
    if isfield(data.ROI, 'info') && istable(data.ROI.info)
        roiNames = data.ROI.info.Properties.RowNames;
    end
else
    if ~isfield(data, bioM)
        error('exploreFNIRS:connectivity:computeBetaSeries', ...
            'Biomarker "%s" not found in data.', bioM);
    end
    signal = data.(bioM);
    roiNames = {};
end

nTotal = size(signal, 2);
if ~isempty(opts.Channels)
    channels = opts.Channels;
elseif opts.UseROI
    channels = 1:nTotal;
elseif isfield(data, 'fchMask')
    channels = find(data.fchMask);
else
    channels = 1:nTotal;
end
channels = channels(channels <= nTotal);
nCh = length(channels);

% --- Filter blocks by condition ---
if ~isempty(condFilter)
    keep = false(1, length(blocks));
    for b = 1:length(blocks)
        if isfield(blocks(b), 'info') && isfield(blocks(b).info, 'Condition')
            keep(b) = ismember(blocks(b).info.Condition, condFilter);
        end
    end
    blocks = blocks(keep);
end

nTrials = length(blocks);
if nTrials < 2
    error('exploreFNIRS:connectivity:computeBetaSeries', ...
        'Need at least 2 trials for beta-series correlation (got %d).', nTrials);
end

% Build trial labels
trialLabels = cell(1, nTrials);
for t = 1:nTrials
    if isfield(blocks(t), 'info') && isfield(blocks(t).info, 'Condition')
        trialLabels{t} = blocks(t).info.Condition;
    else
        trialLabels{t} = sprintf('trial_%03d', t);
    end
end

% --- Extract trial betas ---
switch estMethod
    case 'LSA'
        trialBetas = fitLSA(data, blocks, signal, channels, opts);
    case 'LSS'
        trialBetas = fitLSS(data, blocks, signal, channels, opts);
end

% --- Correlate trial betas across channels ---
[R, P] = corr(trialBetas, 'Type', corrType, 'Rows', 'pairwise');

% --- Build output struct (computeMatrix-compatible) ---
result.matrix = R;
result.pmatrix = P;
result.channels = channels;
result.method = sprintf('betaseries_%s', estMethod);
result.biomarker = bioM;
result.useROI = opts.UseROI;
result.betas = trialBetas;
result.nTrials = nTrials;
result.trialLabels = trialLabels;

if opts.UseROI && ~isempty(roiNames)
    result.labels = roiNames(channels);
else
    result.labels = arrayfun(@(c) sprintf('Ch%d', c), channels, ...
        'UniformOutput', false);
end

end


%% Local helper functions

function trialBetas = fitLSA(data, blocks, signal, channels, opts)
% FITLSA Least Squares All — one regressor per trial in a single GLM

    nTrials = length(blocks);

    % Build per-trial events: each trial is its own regressor
    events = struct('name', {}, 'onsets', {}, 'duration', {}, 'amplitude', {});
    for t = 1:nTrials
        events(t).name = sprintf('trial_%03d', t);
        events(t).onsets = blocks(t).startTime;
        events(t).duration = blocks(t).duration;
        events(t).amplitude = 1;
    end

    % Build design matrix and fit
    [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
        'DriftOrder', opts.DriftOrder, 'IncludeConstant', true);
    glmResult = pf2_base.fnirs.fitGLM(signal(:, channels), X, names, ...
        'Method', opts.FitMethod);

    % Extract trial betas: first nTrials regressors are the trial regressors
    trialBetas = glmResult.beta(1:nTrials, :);  % [nTrials x nCh]
end


function trialBetas = fitLSS(data, blocks, signal, channels, opts)
% FITLSS Least Squares Separate — isolate each trial in its own GLM

    nTrials = length(blocks);
    nCh = length(channels);
    trialBetas = zeros(nTrials, nCh);

    for t = 1:nTrials
        % Build events: isolated trial + all others lumped
        evTarget = struct('name', 'target', ...
            'onsets', blocks(t).startTime, ...
            'duration', blocks(t).duration, ...
            'amplitude', 1);

        otherIdx = setdiff(1:nTrials, t);
        if ~isempty(otherIdx)
            evOther = struct('name', 'others', ...
                'onsets', [blocks(otherIdx).startTime], ...
                'duration', [blocks(otherIdx).duration], ...
                'amplitude', 1);
            events = [evTarget, evOther];
        else
            events = evTarget;
        end

        [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
            'DriftOrder', opts.DriftOrder, 'IncludeConstant', true);
        glmResult = pf2_base.fnirs.fitGLM(signal(:, channels), X, names, ...
            'Method', opts.FitMethod);

        % Target regressor is first
        trialBetas(t, :) = glmResult.beta(1, :);

        if mod(t, 10) == 0 || t == nTrials
            fprintf('  LSS: fitted trial %d/%d\n', t, nTrials);
        end
    end
end
