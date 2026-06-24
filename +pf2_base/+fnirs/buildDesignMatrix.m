function [X, regressorNames] = buildDesignMatrix(time, fs, events, varargin)
% BUILDDESIGNMATRIX Construct GLM design matrix for fNIRS analysis
%
% Builds a design matrix for general linear model (GLM) analysis of fNIRS
% data. Each event condition is convolved with a hemodynamic response
% function (HRF) to produce expected signal regressors. Optionally includes
% temporal and dispersion derivatives, drift regressors (Legendre polynomial
% or DCT cosine basis), and short-channel signals as nuisance regressors.
%
% Reference:
%   Huppert, T. J. (2016). Commentary on the statistical properties of
%   noise and its implication on general linear models in functional
%   near-infrared spectroscopy. Neurophotonics, 3(1), 010401.
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
%                         Use 0 for impulse (event-related) designs.
%            .amplitude - (Optional) Amplitude scaling per event [scalar or 1 x N]
%                         Default: 1. Use with parametric modulation designs.
%
% Name-Value Parameters:
%   'HRF'                - Custom HRF vector [N x 1] (default: canonical via buildHRF)
%   'DriftOrder'         - Order of Legendre polynomial drift regressors (default: 3)
%                          Set to -1 to disable drift regressors. Ignored when
%                          DriftType is 'dct'.
%   'DriftType'          - Type of drift regressors: 'legendre' or 'dct'
%                          (default: 'legendre')
%                          'legendre' - Legendre polynomial basis (orders 0..DriftOrder)
%                          'dct'      - Discrete cosine transform basis (SPM-style).
%                                       Number of components set by DriftCutoff.
%   'DriftCutoff'        - High-pass cutoff period in seconds for DCT drift
%                          (default: 128). Frequencies below 1/DriftCutoff Hz are
%                          modeled by the DCT basis. Only used when DriftType='dct'.
%   'ShortChannels'      - Short-channel time series [T x S] to add as regressors
%                          (default: [])
%   'Nuisance'           - Arbitrary nuisance regressors [T x K] (default: [])
%                          e.g. auxiliary physiology (respiration, cardiac,
%                          accelerometer norm) aligned to the time vector via
%                          pf2.data.auxOnGrid. Added as confound columns; not
%                          HRF-convolved. NaN-containing columns are dropped
%                          with a warning.
%   'NuisanceNames'      - Cell array of labels for the nuisance columns
%                          (default: nuis1..nuisK)
%   'IncludeDerivative'  - Include temporal derivative of HRF (default: false)
%   'IncludeDispersion'  - Include dispersion derivative of HRF (default: false)
%   'IncludeConstant'    - Include constant (intercept) column (default: true)
%
% Outputs:
%   X              - Design matrix [T x P] where P = nConditions*(1 + nDerivatives)
%                    + nDriftRegressors + nShortChannels + nNuisance
%   regressorNames - Cell array {1 x P} of regressor labels
%
% Algorithm:
%   1. For each condition, create a stimulus boxcar/impulse vector
%   2. Convolve with HRF (and optionally its temporal/dispersion derivatives)
%   3. Append drift regressors:
%      a. Legendre: orders 0 through DriftOrder
%      b. DCT: cosine basis functions up to 1/DriftCutoff Hz (SPM convention)
%   4. Append short-channel columns if provided
%   5. Column names encode condition and regressor type
%
% Example:
%   % Build design matrix with Legendre drift (default)
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%
%   % Build design matrix with DCT drift (SPM-style, 128s cutoff)
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events, ...
%       'DriftType', 'dct', 'DriftCutoff', 128);
%
% See also: pf2_base.fnirs.buildHRF, pf2_base.fnirs.fitGLM, pf2.data.defineBlocks

% --- Parse inputs ---
p = inputParser;
p.addRequired('time', @isnumeric);
p.addRequired('fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addRequired('events', @isstruct);
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

% Ensure time is a column vector for indexing
time = time(:);
T = length(time);

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

% --- Build stimulus regressors ---
nConditions = length(events);
stimColumns = {};
stimNames = {};

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
