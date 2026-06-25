function result = computePPI(data, blocks, seedChannels, varargin)
% COMPUTEPPI Psychophysiological Interaction connectivity analysis
%
% Tests whether functional coupling between a seed region and target
% channels changes as a function of task condition. Implements generalized
% PPI (gPPI) by fitting a GLM that includes: (1) one HRF-convolved task
% regressor per condition (psychological main effects), (2) the seed time
% course (physiological main effect), and (3) one seed x condition
% interaction term per condition (the PPI terms). The contrast of interest
% (e.g. Hard vs Easy) is then a linear contrast across the per-condition PPI
% terms.
%
% Interaction term construction: the PPI regressor for a condition is formed
% in NEURAL/psychological space, not in measured hemodynamic space. The seed
% is multiplied by the condition's UN-convolved task boxcar -- NOT by the
% HRF-convolved task regressor -- because convolution does not distribute over
% the pointwise product (HRF(seed .* boxcar) ~= HRF(seed) .* HRF(boxcar)), so
% multiplying two already-convolved signals does not estimate a neural
% interaction. With Deconvolve=true the seed is first deconvolved to a neural
% estimate, the product is formed, and the result is re-convolved with the HRF
% (McLaren et al. 2012 gPPI). With Deconvolve=false the measured seed is
% multiplied by the boxcar directly (classic Friston et al. 1997 PPI, computed
% in measured space without re-convolution).
%
% gPPI design rationale: forming a single psychological regressor as
% HRF(condA - condB) and a single interaction makes that psychological
% column an exact linear combination of the per-condition task regressors,
% so the design becomes rank deficient and the interaction beta is not an
% interpretable partialled effect. Building one interaction per condition
% (McLaren et al., 2012) keeps the design full rank and yields per-condition
% PPI slopes that can be contrasted directly.
%
% The seed is mean-centered before forming the interaction terms (so the
% interaction captures condition-dependent *changes* in coupling, not the
% mean coupling), following standard PPI practice.
%
% Reference:
%   McLaren, D. G., Ries, M. L., Xu, G., & Johnson, S. C. (2012).
%   A generalized form of context-dependent psychophysiological interactions
%   (gPPI): a comparison to standard approaches. NeuroImage, 61(4), 1277-1286.
%   DOI: 10.1016/j.neuroimage.2012.03.068
%
% Syntax:
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, seedChannels)
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, [1 2 3], ...
%       'Contrast', {'Hard', 'Easy'}, 'Biomarker', 'HbO')
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, seedChannels, ...
%       'SeedData', speaker)          % cross-brain seed (speaker -> listener)
%   result = exploreFNIRS.connectivity.computePPI(data, blocks, [], ...
%       'SeedSignal', hrvOnGrid)      % external continuous seed (e.g. HRV)
%
% Inputs:
%   data         - Processed fNIRS struct with .HbO, .HbR, .time, .fs, .fchMask.
%                  Supplies the TARGET channels (and the seed too, unless an
%                  external seed is given via SeedData/SeedSignal).
%   blocks       - Struct array from pf2.data.defineBlocks
%   seedChannels - Scalar or vector of seed channel indices. If multiple, the
%                  seed time course is the mean across channels. May be []
%                  when 'SeedSignal' is supplied.
%
% Name-Value Parameters:
%   Biomarker    - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
%   Contrast     - Task contrast specification:
%                  Cell pair {'condA', 'condB'}: condA=+1, condB=-1
%                  Single string 'cond': condition vs implicit baseline
%                  (default: first two conditions, sorted)
%   SeedData     - Processed fNIRS struct to draw the seed from instead of
%                  `data` (default: []). Enables CROSS-BRAIN PPI: e.g. pass the
%                  speaker's struct to test speaker-seed -> listener-target
%                  coupling. Must share the target time grid (same number of
%                  samples). The seed is taken from SeedData at seedChannels.
%   SeedSignal   - Arbitrary continuous seed time series [T x 1] or [T x k]
%                  aligned to data.time (default: []). When supplied, the seed
%                  is this signal (mean across columns if k>1) and seedChannels
%                  is ignored. Use for a physiological seed such as EKG-derived
%                  HRV aligned via pf2.data.auxOnGrid.
%   DriftOrder   - Legendre drift polynomial order (default: 3)
%   FitMethod    - GLM fit method: 'OLS' (default) or 'AR-IRLS'
%   Deconvolve   - Wiener deconvolution of seed before interaction (default:
%                  false). Note: the deconvolution uses a fixed-fraction noise
%                  estimate and is a simplified estimator; leave off unless you
%                  have characterized it for your data.
%   Channels     - Target channel subset (default: all good channels)
%   UseROI       - Use ROI-level data for targets (default: false)
%   SeedROI      - Use ROI index for seed instead of channel (default: false)
%
% Outputs:
%   result - Struct with fields:
%     .ppi_beta    - [1 x nTargets] PPI CONTRAST beta (e.g. Hard-Easy
%                    modulation of seed->target coupling)
%     .ppi_tstat   - [1 x nTargets] t-statistics for the PPI contrast
%     .ppi_pval    - [1 x nTargets] p-values for the PPI contrast
%     .matrix      - [1 x nTargets] PPI contrast betas (plot compatibility)
%     .pmatrix     - [1 x nTargets] PPI contrast p-values (plot compatibility)
%     .ppiConditions       - Cell array of condition names with PPI terms
%     .ppiBetaPerCondition - [nConditions x nTargets] per-condition PPI betas
%     .contrastVector      - [1 x P] contrast applied to the PPI terms
%     .channels    - Target channel/ROI indices
%     .labels      - Cell array of target labels
%     .seedChannels - Seed channel indices used ([] when SeedSignal used)
%     .seedSource  - 'data' | 'SeedData' | 'SeedSignal'
%     .method      - 'PPI'
%     .biomarker   - Biomarker used
%     .useROI      - Whether ROI mode was used for targets
%     .contrast    - Contrast specification used
%     .fullResults - Full fitGLM results struct (includes .contrast)
%     .designMatrix - Extended design matrix used
%     .regressorNames - Names of all regressors
%
% Example:
%   [subjects, blockDefs] = pf2.import.sampleData.experiment('blocks');
%   d = processFNIRS2(subjects{1});
%   result = exploreFNIRS.connectivity.computePPI(d, blockDefs{1}, 1:3, ...
%       'Contrast', {'Hard', 'Easy'});
%   bar(result.ppi_beta);
%   xlabel('Target Channel'); ylabel('PPI Beta (Hard-Easy)');
%
% See also: exploreFNIRS.connectivity.computeBetaSeries,
%   exploreFNIRS.connectivity.computeMatrix, pf2_base.fnirs.fitGLM

% --- Parse inputs ---
p = inputParser;
addRequired(p, 'data', @isstruct);
addRequired(p, 'blocks', @isstruct);
addRequired(p, 'seedChannels', @(x) isnumeric(x));
addParameter(p, 'Biomarker', 'HbO', @ischar);
addParameter(p, 'Contrast', {}, @(x) ischar(x) || iscell(x));
addParameter(p, 'SeedData', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'SeedSignal', [], @isnumeric);
addParameter(p, 'DriftOrder', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FitMethod', 'OLS', @(x) ischar(x) && ismember(upper(x), {'OLS','AR-IRLS'}));
addParameter(p, 'Deconvolve', false, @islogical);
addParameter(p, 'Channels', [], @isnumeric);
addParameter(p, 'UseROI', false, @islogical);
addParameter(p, 'SeedROI', false, @islogical);
parse(p, data, blocks, seedChannels, varargin{:});
opts = p.Results;

bioM = opts.Biomarker;
T = length(data.time);

% --- Extract target signal matrix ---
if opts.UseROI
    if ~isfield(data, 'ROI') || ~isfield(data.ROI, bioM)
        error('exploreFNIRS:connectivity:computePPI:noROI', ...
            'ROI data not found. Run defineROI + buildROI first.');
    end
    targetSignal = data.ROI.(bioM);
    roiNames = {};
    if isfield(data.ROI, 'info') && istable(data.ROI.info)
        roiNames = data.ROI.info.Properties.RowNames;
    end
else
    if ~isfield(data, bioM)
        error('exploreFNIRS:connectivity:computePPI:noBiomarker', ...
            'Biomarker "%s" not found in data.', bioM);
    end
    targetSignal = data.(bioM);
    roiNames = {};
end

% --- Extract seed signal ---
% Priority: explicit SeedSignal > SeedData struct > the target data struct.
if ~isempty(opts.SeedSignal)
    ss = opts.SeedSignal;
    if size(ss, 1) ~= T
        error('exploreFNIRS:connectivity:computePPI:seedLength', ...
            'SeedSignal must have %d rows (one per data.time sample); got %d.', ...
            T, size(ss, 1));
    end
    seedSig = mean(ss, 2, 'omitnan');
    seedSource = 'SeedSignal';
else
    if isempty(opts.SeedData)
        seedStruct = data;
        seedSource = 'data';
    else
        seedStruct = opts.SeedData;
        seedSource = 'SeedData';
    end

    if isempty(seedChannels)
        error('exploreFNIRS:connectivity:computePPI:noSeed', ...
            'Provide seedChannels (or a SeedSignal) to define the seed.');
    end

    if opts.SeedROI
        if ~isfield(seedStruct, 'ROI') || ~isfield(seedStruct.ROI, bioM)
            error('exploreFNIRS:connectivity:computePPI:noSeedROI', ...
                'ROI data not found for seed. Run defineROI + buildROI first.');
        end
        seedMat = seedStruct.ROI.(bioM);
    else
        if ~isfield(seedStruct, bioM)
            error('exploreFNIRS:connectivity:computePPI:noSeedBiomarker', ...
                'Biomarker "%s" not found in seed data.', bioM);
        end
        seedMat = seedStruct.(bioM);
    end

    if size(seedMat, 1) ~= T
        error('exploreFNIRS:connectivity:computePPI:seedLength', ...
            ['Seed data has %d samples but targets have %d. Align/resample ' ...
             'the seed to the target time grid before computing PPI.'], ...
            size(seedMat, 1), T);
    end
    if min(seedChannels) < 1 || max(seedChannels) > size(seedMat, 2)
        error('exploreFNIRS:connectivity:computePPI:seedChannelRange', ...
            'seedChannels out of range for seed data (%d columns).', ...
            size(seedMat, 2));
    end

    seedSig = mean(seedMat(:, seedChannels), 2, 'omitnan');
end

% Fill any gaps in the seed so the interaction terms are well defined. A
% continuous external seed (e.g. windowed HRV) can carry NaNs at the edges.
if any(isnan(seedSig))
    nFilled = sum(isnan(seedSig));
    seedSig = fillmissing(seedSig, 'linear', 'EndValues', 'nearest');
    warning('exploreFNIRS:connectivity:computePPI:seedGaps', ...
        'Seed contained %d NaN sample(s); filled by linear interpolation.', ...
        nFilled);
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
nTargets = length(targetCh); %#ok<NASGU>

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
            % Coerce to char the same way blocksToEvents names conditions, so
            % auto-detected names match the per-condition task regressors (and
            % numeric conditions do not error in ismember against a cellstr).
            if isnumeric(cond)
                cond = num2str(cond);
            else
                cond = char(cond);
            end
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
        error('exploreFNIRS:connectivity:computePPI:noConditions', ...
            'Could not auto-detect conditions. Specify ''Contrast'' explicitly.');
    end
end

% --- Optionally deconvolve seed (recover neural estimate) ---
hrfData = pf2_base.fnirs.buildHRF(data.fs);
hrf = hrfData(:, 2);
if opts.Deconvolve
    seedNeural = wienerDeconv(seedSig, hrf, data.fs);
else
    seedNeural = seedSig;
end

% Mean-center the seed for the interaction terms (standard PPI practice).
seedCentered = seedNeural - mean(seedNeural, 'omitnan');

% --- Build standard task design matrix (one HRF column per condition) ---
events = pf2.data.blocksToEvents(blocks, 'GroupBy', 'Condition');
[Xtask, taskNames] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'DriftOrder', opts.DriftOrder, 'IncludeConstant', true);

condList = {events.name};

% --- Un-convolved psychological boxcars (one per condition) ---
% gPPI forms the interaction in NEURAL/psychological space: the seed is
% multiplied by the condition's UN-convolved task boxcar, NOT by the
% HRF-convolved task regressor in Xtask. Re-build the design with a unit
% impulse "HRF" (so conv(stim,1) returns the raw boxcar) and no drift/constant.
[boxcars, boxNames] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
    'HRF', 1, 'DriftOrder', -1, 'IncludeConstant', false);

% --- Build one seed x condition interaction per condition (gPPI) ---
ppiColumns = zeros(T, numel(condList));
ppiNames = cell(1, numel(condList));
for c = 1:numel(condList)
    boxCol = find(strcmp(boxNames, condList{c}), 1);
    if isempty(boxCol)
        error('exploreFNIRS:connectivity:computePPI:missingCondition', ...
            'Condition "%s" has no task regressor; cannot form its PPI term.', ...
            condList{c});
    end
    % Interaction in neural space: (centered) seed x psychological boxcar.
    psi = seedCentered .* boxcars(:, boxCol);
    if opts.Deconvolve
        % McLaren gPPI: re-convolve the neural-space product to hemodynamics.
        cv = conv(psi, hrf);
        psi = cv(1:T);
    end
    ppiColumns(:, c) = psi;
    ppiNames{c} = ['PPI_' condList{c}];
end

% --- Assemble extended design matrix ---
% [ task regressors + drift | seed main effect | per-condition PPI terms ]
X = [Xtask, seedCentered, ppiColumns];
regressorNames = [taskNames, {'seed'}, ppiNames];

% --- Collinearity guard ---
% With the per-condition gPPI design this should be full rank; warn if not
% so a degenerate design (e.g. a near-constant seed, or conditions that never
% co-occur with the seed) is not silently absorbed by the pseudoinverse.
rankX = rank(X);
if rankX < size(X, 2)
    warning('exploreFNIRS:connectivity:computePPI:rankDeficient', ...
        ['PPI design matrix is rank deficient (rank %d < %d columns); beta ' ...
         'estimates rely on the pseudoinverse and may be uninterpretable. ' ...
         'Check for collinear conditions or a near-constant seed.'], ...
        rankX, size(X, 2));
end

% --- Build the PPI contrast across the per-condition interaction terms ---
C = zeros(1, size(X, 2));
condA = contrastSpec{1};
idxA = find(strcmp(regressorNames, ['PPI_' condA]), 1);
if isempty(idxA)
    error('exploreFNIRS:connectivity:computePPI:contrastCondition', ...
        'Contrast condition "%s" is not present in the blocks.', condA);
end
C(idxA) = 1;
if numel(contrastSpec) >= 2
    condB = contrastSpec{2};
    idxB = find(strcmp(regressorNames, ['PPI_' condB]), 1);
    if isempty(idxB)
        error('exploreFNIRS:connectivity:computePPI:contrastCondition', ...
            'Contrast condition "%s" is not present in the blocks.', condB);
    end
    C(idxB) = -1;
    contrastName = sprintf('PPI_%s-%s', condA, condB);
else
    contrastName = sprintf('PPI_%s', condA);
end

% --- Fit GLM on target channels with the PPI contrast ---
glmResult = pf2_base.fnirs.fitGLM(targetSignal(:, targetCh), X, regressorNames, ...
    'Method', opts.FitMethod, 'Contrasts', C, 'ContrastNames', {contrastName});

% --- Extract PPI contrast statistics (the effect of interest) ---
result.ppi_beta  = glmResult.contrast.beta(1, :);
result.ppi_tstat = glmResult.contrast.tstat(1, :);
result.ppi_pval  = glmResult.contrast.pval(1, :);

% Plot-compatible fields
result.matrix  = result.ppi_beta;
result.pmatrix = result.ppi_pval;

% Per-condition PPI slopes (for inspection / custom contrasts)
ppiIdx = find(startsWith(regressorNames, 'PPI_'));
result.ppiConditions = condList;
result.ppiBetaPerCondition = glmResult.beta(ppiIdx, :);
result.contrastVector = C;

result.channels = targetCh;
result.seedChannels = seedChannels;
result.seedSource = seedSource;
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

function neural = wienerDeconv(signal, hrf, fs) %#ok<INUSD>
% WIENERDECONV Estimate neural signal via Wiener deconvolution
%
% Deconvolves the HRF from the hemodynamic signal to recover an estimate
% of the underlying neural activity. Uses a frequency-domain Wiener filter
% with a fixed-fraction noise estimate (simplified; not a fully regularized
% deconvolution).

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
