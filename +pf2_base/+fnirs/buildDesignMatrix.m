function [X, regressorNames] = buildDesignMatrix(time, fs, events, varargin)
% BUILDDESIGNMATRIX Construct GLM design matrix for fNIRS analysis
%
% Builds a design matrix for general linear model (GLM) analysis of fNIRS
% data. Each event condition is convolved with a hemodynamic response
% function (HRF) to produce expected signal regressors, or modelled with a
% finite-impulse-response (FIR) basis set when Basis='fir'. Optionally
% includes temporal and dispersion derivatives, drift regressors (Legendre
% polynomial or DCT cosine basis), and short-channel signals as nuisance
% regressors.
%
% FIR basis: places N stick (impulse) regressors at successive TR-spaced lags
% starting from event onset, spanning a post-stimulus window. This is a
% non-parametric approach that makes no assumption about HRF shape, which is
% valuable for validating assumed HRF shapes in fNIRS (where responses lag
% more than fMRI). FIR regressors are NOT normalised to peak = 1 (unlike HRF
% convolution). Using FIR with temporal or dispersion derivatives is invalid
% because the FIR basis already estimates the impulse response directly; an
% error is raised if this combination is requested.
%
% FIR regressors model onset timing only: each stick is a unit impulse at
% onset + lag, so event amplitude scaling and non-zero event duration (both
% honoured by the HRF basis) have no effect on the FIR columns. A single
% pf2:buildDesignMatrix:firIgnoresAmplitude warning is emitted if any event
% supplies a non-default amplitude (~= 1) or duration (~= 0) while
% Basis='fir'.
%
% Near-singular FIR designs arise when the window is long or trials are short
% relative to the number of sticks -- most severely when the recording is
% shorter than the number of stick regressors (T < nSticks), which is
% guaranteed rank-deficient. A condition-number warning
% (pf2:buildDesignMatrix:firNearSingular) is emitted whenever a condition has
% more than one FIR column and its FIR block is close to rank-deficient
% (cond > 1e6); the check always runs for nSticks > 1, since cond() handles
% non-square/rank-deficient matrices without error.
%
% References:
%   Huppert, T. J. (2016). Commentary on the statistical properties of
%   noise and its implication on general linear models in functional
%   near-infrared spectroscopy. Neurophotonics, 3(1), 010401.
%   DOI: 10.1117/1.NPh.3.1.010401
%
% Syntax:
%   [X, regressorNames] = pf2_base.fnirs.buildDesignMatrix(time, fs, events)
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(time, fs, events, 'Name', Value)
%
% Inputs:
%   time   - Time vector [1 x T] or [T x 1] in seconds
%   fs     - Sampling frequency in Hz [scalar]
%   events - Struct array with fields:
%            .name      - Condition label [char]
%            .onsets    - Stimulus onset times in seconds [1 x N]
%            .duration  - Duration of each stimulus in seconds [scalar or 1 x N]
%                         Use 0 for impulse (event-related) designs. Ignored
%                         when Basis='fir' (see Notes above).
%            .amplitude - (Optional) Amplitude scaling per event [scalar or 1 x N]
%                         Default: 1. Use with parametric modulation designs.
%                         Ignored when Basis='fir' (see Notes above).
%
% Name-Value Parameters:
%   'Basis'              - Stimulus basis type: 'hrf' (default) or 'fir'
%                          'hrf' convolves stimulus boxcars with the HRF (or
%                          custom HRF) and optionally its derivatives.
%                          'fir' places N stick regressors from onset to
%                          onset+FIRWindow, at spacing 1/fs. Not compatible
%                          with IncludeDerivative or IncludeDispersion. Uses
%                          onset timing only -- event amplitude/duration are
%                          not applied (see events.amplitude/.duration below).
%   'FIRWindow'          - Post-stimulus window length in seconds for FIR
%                          basis (default: 20). Determines the number of FIR
%                          sticks: N = round(FIRWindow * fs) + 1.
%   'HRF'                - Custom HRF vector [N x 1] (default: canonical via
%                          buildHRF). Ignored when Basis='fir'.
%   'DriftOrder'         - Order of Legendre polynomial drift regressors
%                          (default: 3). Set to -1 to disable drift regressors.
%                          Ignored when DriftType is 'dct'.
%   'DriftType'          - Type of drift regressors: 'legendre' or 'dct'
%                          (default: 'legendre')
%                          'legendre' - Legendre polynomial basis (orders 0..DriftOrder)
%                          'dct'      - Discrete cosine transform basis (SPM-style).
%                                       Number of components set by DriftCutoff.
%   'DriftCutoff'        - High-pass cutoff period in seconds for DCT drift
%                          (default: 128). Frequencies below 1/DriftCutoff Hz
%                          are modeled by the DCT basis. Only used when
%                          DriftType='dct'.
%   'ShortChannels'      - Short-channel time series [T x S] to add as
%                          regressors (default: [])
%   'Nuisance'           - Arbitrary nuisance regressors [T x K] (default: [])
%                          e.g. auxiliary physiology (respiration, cardiac,
%                          accelerometer norm) aligned to the time vector via
%                          pf2.data.auxOnGrid. Added as confound columns; not
%                          HRF-convolved. NaN-containing columns are dropped
%                          with a warning.
%   'NuisanceNames'      - Cell array of labels for the nuisance columns
%                          (default: nuis1..nuisK)
%   'IncludeDerivative'  - Include temporal derivative of HRF (default: false)
%                          Cannot be true when Basis='fir'.
%   'IncludeDispersion'  - Include dispersion derivative of HRF (default: false)
%                          Cannot be true when Basis='fir'.
%   'IncludeConstant'    - Include constant (intercept) column (default: true)
%
% Outputs:
%   X              - Design matrix [T x P] where P depends on Basis:
%                    HRF: nConditions*(1 + nDerivatives) + nDrift + nSC + nNuis
%                    FIR: nConditions*N_sticks + nDrift + nSC + nNuis
%   regressorNames - Cell array {1 x P} of regressor labels
%                    FIR columns are labelled '<cond>_fir<lag>' (e.g. 'TaskA_fir3')
%
% Algorithm (HRF basis):
%   1. For each condition, create a stimulus boxcar/impulse vector
%   2. Convolve with HRF (and optionally its temporal/dispersion derivatives)
%   3. Append drift regressors (Legendre or DCT)
%   4. Append short-channel and nuisance columns
%
% Algorithm (FIR basis):
%   1. For each condition and each lag k = 0..N-1 (in samples):
%      a. Create an impulse vector at onset + k/fs (amplitude/duration
%         ignored; a single warning is issued if either is non-default)
%      b. Use impulse as the k-th FIR regressor column (no HRF convolution)
%   2. Check condition number of each condition's FIR block; warn if > 1e6
%      (checked whenever nSticks > 1, regardless of T vs nSticks)
%   3. Append drift, short-channel, and nuisance columns
%
% Example:
%   % Build design matrix with Legendre drift (default HRF basis)
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%
%   % FIR basis over a 20-second window
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
%       'Basis', 'fir', 'FIRWindow', 20);
%   fprintf('FIR columns per condition: %d\n', round(20 * data.fs) + 1);
%
%   % DCT drift (SPM-style, 128s cutoff)
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
%       'DriftType', 'dct', 'DriftCutoff', 128);
%
% See also: pf2_base.fnirs.buildHRF, pf2_base.fnirs.fitGLM, pf2.data.defineBlocks

% --- Parse inputs ---
p = inputParser;
p.addRequired('time', @isnumeric);
p.addRequired('fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addRequired('events', @isstruct);
p.addParameter('Basis', 'hrf', @(x) ismember(lower(char(x)), {'hrf', 'fir'}));
p.addParameter('FIRWindow', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('HRF', [], @isnumeric);
p.addParameter('DriftOrder', 3, @(x) isnumeric(x) && isscalar(x));
p.addParameter('DriftType', 'legendre', @(x) ismember(lower(char(x)), {'legendre', 'dct'}));
p.addParameter('DriftCutoff', 128, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('ShortChannels', [], @isnumeric);
p.addParameter('Nuisance', [], @isnumeric);
p.addParameter('NuisanceNames', {}, @iscell);
p.addParameter('IncludeDerivative', false, @islogical);
p.addParameter('IncludeDispersion', false, @islogical);
p.addParameter('IncludeConstant', true, @islogical);
p.parse(time, fs, events, varargin{:});

basis = lower(char(p.Results.Basis));
firWindow = p.Results.FIRWindow;
customHRF = p.Results.HRF;
driftOrder = p.Results.DriftOrder;
driftType = lower(char(p.Results.DriftType));
driftCutoff = p.Results.DriftCutoff;
shortCh = p.Results.ShortChannels;
nuisance = p.Results.Nuisance;
nuisanceNames = p.Results.NuisanceNames;
includeDerivative = p.Results.IncludeDerivative;
includeDispersion = p.Results.IncludeDispersion;
includeConstant = p.Results.IncludeConstant;

% Guard: FIR + derivatives is conceptually invalid
if strcmp(basis, 'fir') && (includeDerivative || includeDispersion)
    error('pf2:buildDesignMatrix:firWithDerivative', ...
        ['Basis=''fir'' estimates the full impulse response directly; ' ...
         'combining it with IncludeDerivative or IncludeDispersion is ' ...
         'invalid. Set both flags to false when using the FIR basis.']);
end

% Ensure time is a column vector for indexing
time = time(:);
T = length(time);

% --- Build stimulus regressors ---
nConditions = length(events);
stimColumns = {};
stimNames = {};

if strcmp(basis, 'fir')
    % ----------------------------------------------------------------
    % FIR basis: one impulse regressor per lag per condition
    % ----------------------------------------------------------------
    nSticks = round(firWindow * fs) + 1;  % number of lag columns
    firAmplitudeIgnoredWarned = false;  % emit the amplitude/duration warning at most once

    for c = 1:nConditions
        ev = events(c);
        condName = ev.name;
        onsets = ev.onsets(:)';

        % FIR uses onset timing only (see header Notes): amplitude scaling
        % and non-zero duration are silently inapplicable to stick
        % regressors. Warn once, across the whole call, if either is set.
        if ~firAmplitudeIgnoredWarned
            hasNonDefaultAmplitude = isfield(ev, 'amplitude') && ~isempty(ev.amplitude) ...
                && any(ev.amplitude(:) ~= 1);
            hasNonDefaultDuration = isfield(ev, 'duration') && ~isempty(ev.duration) ...
                && any(ev.duration(:) ~= 0);
            if hasNonDefaultAmplitude || hasNonDefaultDuration
                warning('pf2:buildDesignMatrix:firIgnoresAmplitude', ...
                    ['Basis=''fir'' models onset timing only: event amplitude ' ...
                     'scaling and non-zero duration are not applied to the FIR ' ...
                     'stick regressors (condition ''%s''). Use Basis=''hrf'' if ' ...
                     'amplitude/duration modulation is required.'], condName);
                firAmplitudeIgnoredWarned = true;
            end
        end

        firBlock = zeros(T, nSticks);
        for lag = 0:(nSticks - 1)
            col = zeros(T, 1);
            for n = 1:length(onsets)
                % Place a unit impulse at onset + lag/fs. Omit lags that fall
                % outside the recording: nearest-sample lookup always returns a
                % valid index, so without this guard an event near the end would
                % stack every out-of-range lag onto the final sample.
                targetTime = onsets(n) + lag / fs;
                if targetTime < time(1) - 0.5/fs || targetTime > time(end) + 0.5/fs
                    continue;
                end
                [~, idx] = min(abs(time - targetTime));
                if idx >= 1 && idx <= T
                    col(idx) = col(idx) + 1;
                end
            end
            firBlock(:, lag + 1) = col;
            stimColumns{end+1} = col; %#ok<AGROW>
            stimNames{end+1} = sprintf('%s_fir%d', condName, lag); %#ok<AGROW>
        end

        % Condition-number guard: warn if FIR block is near-singular. This
        % must run whenever there is more than one stick regressor -- in
        % particular when T < nSticks (fewer samples than stick columns),
        % which is guaranteed rank-deficient and is the worst case this
        % guard exists to catch. cond() handles non-square/rank-deficient
        % matrices without erroring, so no size(firBlock,1) >= nSticks gate
        % is needed (or wanted) here.
        if nSticks > 1
            cn = cond(firBlock);
            if ~isfinite(cn) || cn > 1e6
                warning('pf2:buildDesignMatrix:firNearSingular', ...
                    ['FIR design for condition ''%s'' has condition number ' ...
                     '%.2e (> 1e6). The design may be near-rank-deficient. ' ...
                     'Consider reducing FIRWindow or increasing trial count.'], ...
                    condName, cn);
            end
        end
    end

else
    % ----------------------------------------------------------------
    % HRF basis: convolve stimulus boxcar/impulse with canonical HRF
    % ----------------------------------------------------------------

    % Build HRF
    if isempty(customHRF)
        hrfData = pf2_base.fnirs.buildHRF(fs);
        hrf = hrfData(:, 2);  % Column 2 is amplitude
        hrfDuration = hrfData(end, 1);  % Duration in seconds
    else
        hrf = customHRF(:);
        hrfDuration = (length(hrf) - 1) / fs;  % Infer duration from length
    end

    % Build temporal derivative if requested
    if includeDerivative
        hrfDeriv = diff([0; hrf]) * fs;  % Numerical derivative
    else
        hrfDeriv = [];
    end

    % Build dispersion derivative if requested
    if includeDispersion
        % Dispersion derivative: HRF with wider primary gamma (alpha1=7 vs 6)
        % Use same duration as primary HRF so subtraction is valid
        hrfWide = pf2_base.fnirs.buildHRF(fs, hrfDuration, 7, 16, 1, 1, 1/6);
        hrfDisp = hrfWide(:, 2);
        % Match length to primary HRF
        if length(hrfDisp) > length(hrf)
            hrfDisp = hrfDisp(1:length(hrf));
        elseif length(hrfDisp) < length(hrf)
            hrfDisp(end+1:length(hrf)) = 0;
        end
        hrfDisp = hrfDisp - hrf;  % Difference is the dispersion derivative
    else
        hrfDisp = [];
    end

    for c = 1:nConditions
        ev = events(c);
        condName = ev.name;
        onsets = ev.onsets(:)';

        % Handle scalar vs vector duration
        if isscalar(ev.duration)
            durations = repmat(ev.duration, 1, length(onsets));
        else
            durations = ev.duration(:)';
        end

        % Handle scalar vs vector amplitude (default: 1)
        if isfield(ev, 'amplitude') && ~isempty(ev.amplitude)
            if isscalar(ev.amplitude)
                amplitudes = repmat(ev.amplitude, 1, length(onsets));
            else
                amplitudes = ev.amplitude(:)';
            end
        else
            amplitudes = ones(1, length(onsets));
        end

        % Create stimulus vector
        stim = zeros(T, 1);
        for n = 1:length(onsets)
            amp = amplitudes(min(n, numel(amplitudes)));
            if durations(n) <= 0
                % Impulse: find nearest sample
                [~, idx] = min(abs(time - onsets(n)));
                stim(idx) = amp;
            else
                % Boxcar: set samples within duration to amplitude
                mask = time >= onsets(n) & time < (onsets(n) + durations(n));
                stim(mask) = amp;
            end
        end

        % Convolve with HRF (primary)
        convolved = conv(stim, hrf);
        stimColumns{end+1} = convolved(1:T); %#ok<AGROW>
        stimNames{end+1} = condName; %#ok<AGROW>

        % Temporal derivative
        if includeDerivative && ~isempty(hrfDeriv)
            convDeriv = conv(stim, hrfDeriv);
            stimColumns{end+1} = convDeriv(1:T); %#ok<AGROW>
            stimNames{end+1} = [condName '_deriv']; %#ok<AGROW>
        end

        % Dispersion derivative
        if includeDispersion && ~isempty(hrfDisp)
            convDisp = conv(stim, hrfDisp);
            stimColumns{end+1} = convDisp(1:T); %#ok<AGROW>
            stimNames{end+1} = [condName '_disp']; %#ok<AGROW>
        end
    end
end

% --- Build drift regressors ---
driftColumns = {};
driftNames = {};

if strcmp(driftType, 'dct')
    % DCT cosine basis set (SPM-style high-pass filter)
    [driftColumns, driftNames] = buildDCTDrift(T, fs, driftCutoff, includeConstant);
elseif driftOrder >= 0
    % Legendre polynomial drift regressors
    [driftColumns, driftNames] = buildLegendreDrift(T, driftOrder, includeConstant);
end

% --- Short-channel regressors ---
scColumns = {};
scNames = {};

if ~isempty(shortCh)
    if size(shortCh, 1) ~= T
        error('pf2:buildDesignMatrix:sizeMismatch', ...
            'ShortChannels must have %d rows (same as time vector).', T);
    end
    nSC = size(shortCh, 2);
    for s = 1:nSC
        scColumns{end+1} = shortCh(:, s); %#ok<AGROW>
        scNames{end+1} = sprintf('short_ch%d', s); %#ok<AGROW>
    end
end

% --- Nuisance regressors ---
nuisColumns = {};
nuisNames = {};

if ~isempty(nuisance)
    if size(nuisance, 1) ~= T
        error('pf2:buildDesignMatrix:sizeMismatch', ...
            'Nuisance must have %d rows (same as time vector).', T);
    end
    nNuis = size(nuisance, 2);
    for s = 1:nNuis
        col = nuisance(:, s);
        if any(isnan(col))
            warning('pf2:buildDesignMatrix:nuisanceNaN', ...
                'Nuisance column %d contains NaN; dropping it.', s);
            continue;
        end
        nuisColumns{end+1} = col; %#ok<AGROW>
        if numel(nuisanceNames) >= s && ~isempty(nuisanceNames{s})
            nuisNames{end+1} = nuisanceNames{s}; %#ok<AGROW>
        else
            nuisNames{end+1} = sprintf('nuis%d', s); %#ok<AGROW>
        end
    end
end

% --- Assemble design matrix ---
allColumns = [stimColumns, driftColumns, scColumns, nuisColumns];
allNames = [stimNames, driftNames, scNames, nuisNames];

X = zeros(T, length(allColumns));
for j = 1:length(allColumns)
    X(:, j) = allColumns{j};
end

regressorNames = allNames;

end


function [columns, names] = buildLegendreDrift(T, driftOrder, includeConstant)
% BUILDLEGENDREDRIFT Legendre polynomial drift regressors

columns = {};
names = {};

tNorm = linspace(-1, 1, T)';

startOrder = 0;
if ~includeConstant
    startOrder = 1;
end

for k = startOrder:driftOrder
    switch k
        case 0
            poly = ones(T, 1);
            names{end+1} = 'constant'; %#ok<AGROW>
        case 1
            poly = tNorm;
            names{end+1} = 'drift_linear'; %#ok<AGROW>
        case 2
            poly = (3*tNorm.^2 - 1) / 2;
            names{end+1} = 'drift_quad'; %#ok<AGROW>
        case 3
            poly = (5*tNorm.^3 - 3*tNorm) / 2;
            names{end+1} = 'drift_cubic'; %#ok<AGROW>
        otherwise
            P_prev2 = ones(T, 1);
            P_prev1 = tNorm;
            for j = 2:k
                P_curr = ((2*j - 1) * tNorm .* P_prev1 - (j - 1) * P_prev2) / j;
                P_prev2 = P_prev1;
                P_prev1 = P_curr;
            end
            poly = P_curr;
            names{end+1} = sprintf('drift_order%d', k); %#ok<AGROW>
    end
    columns{end+1} = poly; %#ok<AGROW>
end

end


function [columns, names] = buildDCTDrift(T, fs, cutoffPeriod, includeConstant)
% BUILDDCTDRIFT Discrete cosine transform drift regressors (SPM-style)
%
% Generates a DCT basis set that models low-frequency drift below
% 1/cutoffPeriod Hz. Follows the SPM convention (spm_dctmtx).
%
% The number of basis functions K is:
%   K = floor(2 * duration / cutoffPeriod) + 1
% where duration = T / fs.
%
% The k-th basis function (k = 0, 1, ..., K-1) is:
%   C(n, k) = sqrt(2/T) * cos(pi * (2*n + 1) * k / (2*T))
% with C(n, 0) = sqrt(1/T) (constant term).

columns = {};
names = {};

duration = T / fs;

% Number of DCT components: frequencies up to 1/cutoffPeriod Hz
K = floor(2 * duration / cutoffPeriod) + 1;
K = max(K, 1);  % At least the constant

% Sample indices 0:T-1
n = (0:T-1)';

startK = 0;
if ~includeConstant
    startK = 1;
end

for k = startK:K-1
    if k == 0
        % DC component (constant)
        basis = ones(T, 1) * sqrt(1/T);
        names{end+1} = 'constant'; %#ok<AGROW>
    else
        % Cosine basis function
        basis = sqrt(2/T) * cos(pi * (2*n + 1) * k / (2*T));
        names{end+1} = sprintf('dct_%d', k); %#ok<AGROW>
    end
    columns{end+1} = basis; %#ok<AGROW>
end

end
