function [X, regressorNames] = buildDesignMatrix(time, fs, events, varargin)
% BUILDDESIGNMATRIX Construct GLM design matrix for fNIRS analysis
%
% Builds a design matrix for general linear model (GLM) analysis of fNIRS
% data. Each event condition is convolved with a hemodynamic response
% function (HRF) to produce expected signal regressors. Optionally includes
% temporal and dispersion derivatives, polynomial drift regressors, and
% short-channel signals as nuisance regressors.
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
%            .name     - Condition label [char]
%            .onsets   - Stimulus onset times in seconds [1 x N]
%            .duration - Duration of each stimulus in seconds [scalar or 1 x N]
%                        Use 0 for impulse (event-related) designs.
%
% Name-Value Parameters:
%   'HRF'                - Custom HRF vector [N x 1] (default: canonical via buildHRF)
%   'DriftOrder'         - Order of Legendre polynomial drift regressors (default: 3)
%                          Set to -1 to disable drift regressors.
%   'ShortChannels'      - Short-channel time series [T x S] to add as regressors
%                          (default: [])
%   'IncludeDerivative'  - Include temporal derivative of HRF (default: false)
%   'IncludeDispersion'  - Include dispersion derivative of HRF (default: false)
%   'IncludeConstant'    - Include constant (intercept) column (default: true)
%
% Outputs:
%   X              - Design matrix [T x P] where P = nConditions*(1 + nDerivatives)
%                    + (DriftOrder+1) + nShortChannels
%   regressorNames - Cell array {1 x P} of regressor labels
%
% Algorithm:
%   1. For each condition, create a stimulus boxcar/impulse vector
%   2. Convolve with HRF (and optionally its temporal/dispersion derivatives)
%   3. Append Legendre polynomial drift regressors (orders 0 through DriftOrder)
%   4. Append short-channel columns if provided
%   5. Column names encode condition and regressor type
%
% Example:
%   % Build design matrix from block definitions
%   data = pf2.import.sampleData.fNIR2000();
%   blocks = pf2.data.defineBlocks(data, [49, 50], 30, ...
%       'ConditionMap', {49, 'Speech'; 50, 'Noise'});
%   events = blocksToEvents(blocks);
%   [X, names] = pf2_base.fnirs.buildDesignMatrix(data.time, data.fs, events);
%   imagesc(X); set(gca, 'XTickLabel', names);
%
% See also: pf2_base.fnirs.buildHRF, pf2_base.fnirs.fitGLM, pf2.data.defineBlocks

% --- Parse inputs ---
p = inputParser;
p.addRequired('time', @isnumeric);
p.addRequired('fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addRequired('events', @isstruct);
p.addParameter('HRF', [], @isnumeric);
p.addParameter('DriftOrder', 3, @(x) isnumeric(x) && isscalar(x));
p.addParameter('ShortChannels', [], @isnumeric);
p.addParameter('IncludeDerivative', false, @islogical);
p.addParameter('IncludeDispersion', false, @islogical);
p.addParameter('IncludeConstant', true, @islogical);
p.parse(time, fs, events, varargin{:});

customHRF = p.Results.HRF;
driftOrder = p.Results.DriftOrder;
shortCh = p.Results.ShortChannels;
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
else
    hrf = customHRF(:);
end

% Build temporal derivative if requested
if includeDerivative
    hrfDeriv = diff([0; hrf]) * fs;  % Numerical derivative
else
    hrfDeriv = [];
end

% Build dispersion derivative if requested
if includeDispersion
    % Dispersion derivative: HRF with wider primary gamma
    hrfWide = pf2_base.fnirs.buildHRF(fs, 15, 7, 16, 1, 1, 1/6);
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

    % Create stimulus vector
    stim = zeros(T, 1);
    for n = 1:length(onsets)
        if durations(n) <= 0
            % Impulse: find nearest sample
            [~, idx] = min(abs(time - onsets(n)));
            stim(idx) = 1;
        else
            % Boxcar: set samples within duration to 1
            mask = time >= onsets(n) & time < (onsets(n) + durations(n));
            stim(mask) = 1;
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

if driftOrder >= 0
    % Normalized time for Legendre polynomials: [-1, 1]
    tNorm = linspace(-1, 1, T)';

    startOrder = 0;
    if ~includeConstant
        startOrder = 1;  % Skip constant term
    end

    for k = startOrder:driftOrder
        switch k
            case 0
                poly = ones(T, 1);
                driftNames{end+1} = 'constant'; %#ok<AGROW>
            case 1
                poly = tNorm;
                driftNames{end+1} = 'drift_linear'; %#ok<AGROW>
            case 2
                poly = (3*tNorm.^2 - 1) / 2;
                driftNames{end+1} = 'drift_quad'; %#ok<AGROW>
            case 3
                poly = (5*tNorm.^3 - 3*tNorm) / 2;
                driftNames{end+1} = 'drift_cubic'; %#ok<AGROW>
            otherwise
                % General Legendre polynomial via recurrence
                P_prev2 = ones(T, 1);
                P_prev1 = tNorm;
                for j = 2:k
                    P_curr = ((2*j - 1) * tNorm .* P_prev1 - (j - 1) * P_prev2) / j;
                    P_prev2 = P_prev1;
                    P_prev1 = P_curr;
                end
                poly = P_curr;
                driftNames{end+1} = sprintf('drift_order%d', k); %#ok<AGROW>
        end
        driftColumns{end+1} = poly; %#ok<AGROW>
    end
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

% --- Assemble design matrix ---
allColumns = [stimColumns, driftColumns, scColumns];
allNames = [stimNames, driftNames, scNames];

X = zeros(T, length(allColumns));
for j = 1:length(allColumns)
    X(:, j) = allColumns{j};
end

regressorNames = allNames;

end
