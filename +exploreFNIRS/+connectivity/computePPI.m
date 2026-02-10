function result = computePPI(data, blocks, seedChannels, varargin)
% COMPUTEPPI Psychophysiological Interaction connectivity analysis
%
% Tests whether functional coupling between a seed region and target
% channels changes as a function of task condition. Implements generalized
% PPI (gPPI) by fitting a GLM that includes: (1) standard task regressors,
% (2) the seed time course, and (3) the interaction of seed activity with
% the psychological (task) variable.
%
% Reference:
%   McLaren, D. G., Ries, M. L., Xu, G., & Johnson, S. C. (2012).
%   A generalized form of context-dependent psychophysiological interactions
%   (gPPI): a comparison to standard approaches. NeuroImage, 61(4), 1277-1286.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, seedChannels)
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, [1 2 3], ...
%       'Contrast', {'Hard', 'Easy'}, 'Biomarker', 'HbO')
%
% Inputs:
%   data         - Processed fNIRS struct with .HbO, .HbR, .time, .fs, .fchMask
%   blocks       - Struct array from pf2.data.defineBlocks
%   seedChannels - Scalar or vector of seed channel indices. If multiple,
%                  the seed time course is the mean across channels.
%
% Name-Value Parameters:
%   Biomarker    - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Contrast     - Task contrast specification:
%                  Cell pair {'condA', 'condB'}: condA=+1, condB=-1
%                  Single string 'cond': condition vs rest (default: first two conditions)
%   DriftOrder   - Legendre drift polynomial order (default: 3)
%   FitMethod    - GLM fit method: 'OLS' (default) or 'AR-IRLS'
%   Deconvolve   - Wiener deconvolution of seed before interaction (default: false)
%   Channels     - Target channel subset (default: all good channels)
%   UseROI       - Use ROI-level data for targets (default: false)
%   SeedROI      - Use ROI index for seed instead of channel (default: false)
%
% Outputs:
%   result - Struct with fields:
%     .ppi_beta    - [1 x nTargets] PPI regressor beta weights
%     .ppi_tstat   - [1 x nTargets] PPI regressor t-statistics
%     .ppi_pval    - [1 x nTargets] PPI regressor p-values
%     .matrix      - [1 x nTargets] PPI betas (for plot compatibility)
%     .pmatrix     - [1 x nTargets] PPI p-values (for plot compatibility)
%     .channels    - Target channel/ROI indices
%     .labels      - Cell array of target labels
%     .seedChannels - Seed channel indices used
%     .method      - 'PPI'
%     .biomarker   - Biomarker used
%     .useROI      - Whether ROI mode was used for targets
%     .contrast    - Contrast specification used
%     .fullResults - Full fitGLM results struct
%     .designMatrix - Extended design matrix used
%     .regressorNames - Names of all regressors
%
% Example:
%   [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
%   d = processFNIRS2(subjects{1});
%   result = exploreFNIRS.connectivity.computePPI(d, blockDefs{1}, 1:3, ...
%       'Contrast', {'Hard', 'Easy'});
%   bar(result.ppi_beta);
%   xlabel('Target Channel'); ylabel('PPI Beta');
%
% See also: exploreFNIRS.connectivity.computeBetaSeries,
%   exploreFNIRS.connectivity.computeMatrix, pf2_base.fnirs.fitGLM

% --- Parse inputs ---
p = inputParser;
addRequired(p, 'data', @isstruct);
addRequired(p, 'blocks', @isstruct);
addRequired(p, 'seedChannels', @isnumeric);
addParameter(p, 'Biomarker', 'HbO', @ischar);
addParameter(p, 'Contrast', {}, @(x) ischar(x) || iscell(x));
addParameter(p, 'DriftOrder', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FitMethod', 'OLS', @(x) ischar(x) && ismember(upper(x), {'OLS','AR-IRLS'}));
addParameter(p, 'Deconvolve', false, @islogical);
addParameter(p, 'Channels', [], @isnumeric);
addParameter(p, 'UseROI', false, @islogical);
addParameter(p, 'SeedROI', false, @islogical);
parse(p, data, blocks, seedChannels, varargin{:});
opts = p.Results;

bioM = opts.Biomarker;

% --- Extract signal matrices ---
if opts.UseROI
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, bioM)
        error('exploreFNIRS:connectivity:computePPI', ...
            'ROI data not found. Run defineROI + buildROI first.');
    end
    targetSignal = data.ROI.(bioM);
    roiNames = {};
    if isfield(data.ROI, 'info') && istable(data.ROI.info)
        roiNames = data.ROI.info.Properties.RowNames;
    end
else
    if ~isfield(data, bioM)
        error('exploreFNIRS:connectivity:computePPI', ...
            'Biomarker "%s" not found in data.', bioM);
    end
    targetSignal = data.(bioM);
    roiNames = {};
end

% Seed signal
if opts.SeedROI
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, bioM)
        error('exploreFNIRS:connectivity:computePPI', ...
            'ROI data not found for seed. Run defineROI + buildROI first.');
    end
    seedSig = mean(data.ROI.(bioM)(:, seedChannels), 2, 'omitnan');
else
    if ~isfield(data, bioM)
        error('exploreFNIRS:connectivity:computePPI', ...
            'Biomarker "%s" not found in data.', bioM);
    end
    seedSig = mean(data.(bioM)(:, seedChannels), 2, 'omitnan');
end

% Determine target channels
nTotal = size(targetSignal, 2);
if ~isempty(opts.Channels)
    targetCh = opts.Channels;
elseif opts.UseROI
    targetCh = 1:nTotal;
elseif isfield(data, 'fchMask')
    targetCh = find(data.fchMask);
else
    targetCh = 1:nTotal;
end
targetCh = targetCh(targetCh <= nTotal);
nTargets = length(targetCh);

T = length(data.time);

% --- Determine contrast conditions ---
contrastSpec = opts.Contrast;
if ischar(contrastSpec) && ~isempty(contrastSpec)
    contrastSpec = {contrastSpec};
end

% Auto-detect conditions from blocks if contrast not specified
if isempty(contrastSpec)
    condNames = {};
    for b = 1:length(blocks)
        if isfield(blocks(b), 'info') && isfield(blocks(b).info, 'Condition')
            cond = blocks(b).info.Condition;
            if ~ismember(cond, condNames)
                condNames{end+1} = cond; %#ok<AGROW>
            end
        end
    end
    condNames = sort(condNames);  % deterministic order across subjects
    if length(condNames) >= 2
        contrastSpec = condNames(1:2);
    elseif length(condNames) == 1
        contrastSpec = condNames(1);
    else
        error('exploreFNIRS:connectivity:computePPI', ...
            'Could not auto-detect conditions. Specify ''Contrast'' explicitly.');
    end
end

% --- Build psychological variable ---
% +1 for condA blocks, -1 for condB blocks (or +1 for single condition)
psychVar = zeros(T, 1);
if length(contrastSpec) >= 2
    condA = contrastSpec{1};
    condB = contrastSpec{2};
    for b = 1:length(blocks)
        if ~isfield(blocks(b), 'info') || ~isfield(blocks(b).info, 'Condition')
            continue;
        end
        tMask = data.time >= blocks(b).startTime & ...
                data.time < (blocks(b).startTime + blocks(b).duration);
        if strcmp(blocks(b).info.Condition, condA)
            psychVar(tMask) = 1;
        elseif strcmp(blocks(b).info.Condition, condB)
            psychVar(tMask) = -1;
        end
    end
else
    condA = contrastSpec{1};
    condB = '';
    for b = 1:length(blocks)
        if ~isfield(blocks(b), 'info') || ~isfield(blocks(b).info, 'Condition')
            continue;
        end
        tMask = data.time >= blocks(b).startTime & ...
                data.time < (blocks(b).startTime + blocks(b).duration);
        if strcmp(blocks(b).info.Condition, condA)
            psychVar(tMask) = 1;
        end
    end
end

% Convolve psychological variable with HRF
hrfData = pf2_base.fnirs.buildHRF(data.fs);
hrf = hrfData(:, 2);
psychConv = conv(psychVar, hrf);
psychConv = psychConv(1:T);

% --- Optionally deconvolve seed ---
if opts.Deconvolve
    seedNeural = wienerDeconv(seedSig, hrf, data.fs);
else
    seedNeural = seedSig;
end

% --- Build interaction term (gPPI) ---
interaction = seedNeural .* psychConv;

% --- Build standard task design matrix ---
events = pf2.data.blocksToEvents(blocks, 'GroupBy', 'Condition');
[Xtask, taskNames] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'DriftOrder', opts.DriftOrder, 'IncludeConstant', true);

% --- Extend design matrix with PPI regressors ---
% Add: seed, psychConv, interaction (PPI term)
X = [Xtask, seedNeural, psychConv, interaction];
ppiIdx = size(X, 2);  % interaction is the last column
regressorNames = [taskNames, {'seed', 'psych', 'PPI'}];

% --- Fit GLM on target channels ---
glmResult = pf2_base.fnirs.fitGLM(targetSignal(:, targetCh), X, regressorNames, ...
    'Method', opts.FitMethod);

% --- Extract PPI regressor statistics ---
result.ppi_beta  = glmResult.beta(ppiIdx, :);
result.ppi_tstat = glmResult.tstat(ppiIdx, :);
result.ppi_pval  = glmResult.pval(ppiIdx, :);

% Plot-compatible fields
result.matrix  = result.ppi_beta;
result.pmatrix = result.ppi_pval;

result.channels = targetCh;
result.seedChannels = seedChannels;
result.method = 'PPI';
result.biomarker = bioM;
result.useROI = opts.UseROI;
result.contrast = contrastSpec;
result.fullResults = glmResult;
result.designMatrix = X;
result.regressorNames = regressorNames;

% Build labels
if opts.UseROI && ~isempty(roiNames)
    result.labels = roiNames(targetCh);
else
    result.labels = arrayfun(@(c) sprintf('Ch%d', c), targetCh, ...
        'UniformOutput', false);
end

end


%% Local helper functions

function neural = wienerDeconv(signal, hrf, fs)
% WIENERDECONV Estimate neural signal via Wiener deconvolution
%
% Deconvolves the HRF from the hemodynamic signal to recover an estimate
% of the underlying neural activity. Uses frequency-domain Wiener filter.

    T = length(signal);

    % Zero-pad HRF to match signal length
    hrfPad = zeros(T, 1);
    hrfPad(1:length(hrf)) = hrf;

    % FFT
    S = fft(signal);
    H = fft(hrfPad);

    % Wiener filter: estimate noise power as fraction of signal power
    noisePower = 0.01 * mean(abs(S).^2);
    W = conj(H) ./ (abs(H).^2 + noisePower);

    % Deconvolve and return to time domain
    neural = real(ifft(S .* W));
end
