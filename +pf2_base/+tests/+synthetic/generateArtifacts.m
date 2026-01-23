function [artifacts, artifactMask] = generateArtifacts(nSamples, nChannels, varargin)
% GENERATEARTIFACTS Generate motion and spike artifacts for fNIRS testing
%
% Creates synthetic motion artifacts for testing artifact detection and
% correction algorithms. Supports spike artifacts (sudden transients),
% baseline shifts (step changes), and gradual drift (slow baseline changes).
% Artifacts can be placed at specific times or generated randomly.
%
% Reference:
%   Internal pf2 test infrastructure. Artifact models based on common
%   fNIRS motion artifact patterns described in:
%   Scholkmann, F. et al. (2010). How to detect and reduce movement artifacts
%   in near-infrared imaging. Physiol. Meas. 31(5), 649-662.
%
% Syntax:
%   [artifacts, mask] = generateArtifacts(nSamples, nChannels)
%   [artifacts, mask] = generateArtifacts(nSamples, nChannels, 'type', 'spike')
%   [artifacts, mask] = generateArtifacts(..., 'times', [100, 500, 800])
%   [artifacts, mask] = generateArtifacts(..., 'probability', 0.01)
%
% Inputs:
%   nSamples  - Number of time samples [positive integer]
%   nChannels - Number of channels [positive integer]
%
% Name-Value Parameters:
%   'type'        - Artifact type (default: 'spike')
%                   'spike': Brief transient artifacts (1-3 samples)
%                   'baseline_shift': Step changes in baseline
%                   'gradual_drift': Slow ramp-like baseline changes
%   'times'       - Artifact onset times in samples (default: [])
%                   When specified, places artifacts at these exact locations.
%                   If empty and probability is 0, generates 3-5 random artifacts.
%   'amplitude'   - Artifact amplitude (default: 5)
%                   For 'spike': peak amplitude of spike
%                   For 'baseline_shift': magnitude of step change
%                   For 'gradual_drift': total drift magnitude
%                   Can be scalar (same for all) or vector [1 x nArtifacts].
%   'duration'    - Artifact duration in samples (default: varies by type)
%                   'spike': default 1-3 samples
%                   'baseline_shift': default 1 (instantaneous)
%                   'gradual_drift': default 50 samples
%   'probability' - Random artifact probability per sample (default: 0)
%                   When > 0, generates artifacts randomly with this probability.
%                   Overrides 'times' parameter. Typical range: 0.001-0.01.
%   'channels'    - Which channels to add artifacts to (default: 'all')
%                   'all': All channels get independent artifacts
%                   'same': Same artifact times across all channels
%                   Vector: Specific channel indices to affect
%   'seed'        - Random seed for reproducibility (default: [])
%
% Outputs:
%   artifacts    - Artifact signal matrix [nSamples x nChannels double]
%                  Add to clean signal: contaminated = clean + artifacts
%   artifactMask - Logical mask [nSamples x nChannels] indicating artifact
%                  locations (true = artifact present at this sample)
%
% Algorithm:
%   For 'spike':
%     1. Determine artifact times (specified, random, or auto-generated)
%     2. For each artifact: create Gaussian-shaped transient
%     3. Scale to specified amplitude
%
%   For 'baseline_shift':
%     1. Determine artifact times
%     2. For each artifact: create step function (Heaviside)
%     3. Amplitude can be positive or negative (randomly selected)
%
%   For 'gradual_drift':
%     1. Determine artifact times
%     2. For each artifact: create linear ramp over duration
%     3. Ramp direction (up/down) selected randomly
%
% Example:
%   % Generate spike artifacts at specific times
%   [artifacts, mask] = pf2_base.tests.synthetic.generateArtifacts(1000, 4, ...
%       'type', 'spike', 'times', [100, 300, 700], 'amplitude', 10);
%
%   % Generate random baseline shifts
%   [artifacts, mask] = pf2_base.tests.synthetic.generateArtifacts(1000, 4, ...
%       'type', 'baseline_shift', 'probability', 0.002, 'seed', 42);
%
%   % Generate gradual drift artifacts
%   [artifacts, mask] = pf2_base.tests.synthetic.generateArtifacts(1000, 4, ...
%       'type', 'gradual_drift', 'amplitude', 3, 'duration', 100);
%
%   % Add artifacts to a clean signal
%   cleanSignal = sin(2*pi*0.1*(1:1000)'/10);  % 0.1 Hz sine wave
%   [artifacts, mask] = pf2_base.tests.synthetic.generateArtifacts(1000, 1, ...
%       'type', 'spike', 'times', [200, 600], 'amplitude', 5);
%   contaminatedSignal = cleanSignal + artifacts;
%
% Notes:
%   - Artifact amplitudes are added to the signal; use negative amplitudes
%     for downward artifacts
%   - The mask indicates artifact regions, useful for testing detection algorithms
%   - For 'gradual_drift', the mask covers the entire drift duration
%   - Multiple artifacts can overlap; amplitudes are summed
%
% See also: generateNoise, generatePhysiological, pf2_SMAR, pf2_MotionCorrectTDDR

% Input validation using inputParser
p = inputParser;
p.FunctionName = 'generateArtifacts';

% Required inputs
addRequired(p, 'nSamples', @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);
addRequired(p, 'nChannels', @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);

% Optional name-value parameters
validTypes = {'spike', 'baseline_shift', 'gradual_drift'};
addParameter(p, 'type', 'spike', @(x) ischar(x) && ismember(lower(x), validTypes));
addParameter(p, 'times', [], @(x) isempty(x) || (isnumeric(x) && all(x > 0)));
addParameter(p, 'amplitude', 5, @(x) isnumeric(x) && all(isfinite(x)));
addParameter(p, 'duration', [], @(x) isempty(x) || (isnumeric(x) && all(x > 0)));
addParameter(p, 'probability', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
addParameter(p, 'channels', 'all', @(x) ischar(x) || (isnumeric(x) && all(x > 0)));
addParameter(p, 'seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));

parse(p, nSamples, nChannels, varargin{:});

artifactType = lower(p.Results.type);
times = p.Results.times;
amplitude = p.Results.amplitude;
duration = p.Results.duration;
probability = p.Results.probability;
channels = p.Results.channels;
seed = p.Results.seed;

% Set random seed if provided
if ~isempty(seed)
    rngState = rng;
    rng(seed);
    restoreRng = true;
else
    restoreRng = false;
end

try
    % Initialize outputs
    artifacts = zeros(nSamples, nChannels);
    artifactMask = false(nSamples, nChannels);

    % Determine which channels to affect
    if ischar(channels)
        if strcmpi(channels, 'all') || strcmpi(channels, 'same')
            channelIndices = 1:nChannels;
            sameAcrossChannels = strcmpi(channels, 'same');
        else
            error('generateArtifacts:InvalidChannels', ...
                'channels must be ''all'', ''same'', or a numeric vector');
        end
    else
        channelIndices = channels;
        channelIndices = channelIndices(channelIndices <= nChannels);
        sameAcrossChannels = false;
    end

    % Set default duration based on artifact type
    if isempty(duration)
        switch artifactType
            case 'spike'
                duration = 2;  % 2 samples
            case 'baseline_shift'
                duration = 1;  % Instantaneous
            case 'gradual_drift'
                duration = 50; % 50 samples
        end
    end

    % Generate artifacts for each channel
    if sameAcrossChannels
        % Generate one set of artifact times, apply to all channels
        artifactTimes = determineArtifactTimes(nSamples, times, probability, duration);

        for ch = channelIndices
            [channelArtifacts, channelMask] = generateChannelArtifacts(...
                nSamples, artifactTimes, artifactType, amplitude, duration);
            artifacts(:, ch) = channelArtifacts;
            artifactMask(:, ch) = channelMask;
        end
    else
        % Generate independent artifacts for each channel
        for ch = channelIndices
            artifactTimes = determineArtifactTimes(nSamples, times, probability, duration);

            [channelArtifacts, channelMask] = generateChannelArtifacts(...
                nSamples, artifactTimes, artifactType, amplitude, duration);
            artifacts(:, ch) = channelArtifacts;
            artifactMask(:, ch) = channelMask;
        end
    end

    % Restore RNG state if we changed it
    if restoreRng
        rng(rngState);
    end

catch ME
    if restoreRng
        rng(rngState);
    end
    rethrow(ME);
end

end

%%_Subfunctions_________________________________________________________

function artifactTimes = determineArtifactTimes(nSamples, times, probability, duration)
% DETERMINEARTIFACTTIMES Determine artifact onset times
%
% Inputs:
%   nSamples    - Total number of samples
%   times       - User-specified times (empty to auto-generate)
%   probability - Random artifact probability per sample
%   duration    - Artifact duration (for spacing auto-generated artifacts)
%
% Outputs:
%   artifactTimes - Vector of artifact onset sample indices

if probability > 0
    % Generate artifacts randomly based on probability
    randomVals = rand(nSamples, 1);
    artifactTimes = find(randomVals < probability);
elseif ~isempty(times)
    % Use specified times
    artifactTimes = round(times(:));
    artifactTimes = artifactTimes(artifactTimes >= 1 & artifactTimes <= nSamples);
else
    % Auto-generate 3-5 random artifact times, well-spaced
    nArtifacts = randi([3, 5]);
    minSpacing = max(duration * 3, 20);  % Minimum spacing between artifacts

    % Generate spaced artifact times
    availableRange = nSamples - 2 * duration;
    if availableRange > nArtifacts * minSpacing
        % Divide range into segments and place one artifact per segment
        segmentSize = floor(availableRange / nArtifacts);
        artifactTimes = zeros(nArtifacts, 1);
        for i = 1:nArtifacts
            segmentStart = duration + (i-1) * segmentSize;
            segmentEnd = duration + i * segmentSize - minSpacing;
            artifactTimes(i) = randi([segmentStart, max(segmentStart, segmentEnd)]);
        end
    else
        % Not enough room, just place randomly
        artifactTimes = randi([duration + 1, nSamples - duration], nArtifacts, 1);
    end
end

artifactTimes = unique(artifactTimes);  % Remove duplicates and sort

end

function [channelArtifacts, channelMask] = generateChannelArtifacts(nSamples, artifactTimes, artifactType, amplitude, duration)
% GENERATECHANNELARTIFACTS Generate artifacts for a single channel
%
% Inputs:
%   nSamples     - Total number of samples
%   artifactTimes - Vector of artifact onset times
%   artifactType - Type of artifact ('spike', 'baseline_shift', 'gradual_drift')
%   amplitude    - Artifact amplitude (scalar or vector)
%   duration     - Artifact duration in samples
%
% Outputs:
%   channelArtifacts - Artifact signal [nSamples x 1]
%   channelMask      - Logical mask [nSamples x 1]

channelArtifacts = zeros(nSamples, 1);
channelMask = false(nSamples, 1);

nArtifacts = length(artifactTimes);
if nArtifacts == 0
    return;
end

% Handle amplitude: scalar or vector
if isscalar(amplitude)
    amplitudes = repmat(amplitude, nArtifacts, 1);
else
    if length(amplitude) >= nArtifacts
        amplitudes = amplitude(1:nArtifacts);
    else
        amplitudes = [amplitude(:); repmat(amplitude(end), nArtifacts - length(amplitude), 1)];
    end
end

for i = 1:nArtifacts
    t0 = artifactTimes(i);
    amp = amplitudes(i);

    switch artifactType
        case 'spike'
            % Generate spike artifact (Gaussian-shaped transient)
            [artifact, mask] = generateSpikeArtifact(nSamples, t0, amp, duration);

        case 'baseline_shift'
            % Generate baseline shift (step function)
            [artifact, mask] = generateBaselineShift(nSamples, t0, amp);

        case 'gradual_drift'
            % Generate gradual drift (linear ramp)
            [artifact, mask] = generateGradualDrift(nSamples, t0, amp, duration);
    end

    channelArtifacts = channelArtifacts + artifact;
    channelMask = channelMask | mask;
end

end

function [artifact, mask] = generateSpikeArtifact(nSamples, t0, amplitude, duration)
% GENERATESPIKEARTIFACT Generate a spike/transient artifact
%
% Creates a Gaussian-shaped spike centered at t0.
%
% Inputs:
%   nSamples  - Total number of samples
%   t0        - Spike center time (sample index)
%   amplitude - Spike peak amplitude
%   duration  - Spike width parameter (samples, ~2*sigma)
%
% Outputs:
%   artifact - Spike artifact signal [nSamples x 1]
%   mask     - Logical mask [nSamples x 1]

artifact = zeros(nSamples, 1);
mask = false(nSamples, 1);

% Gaussian spike parameters
sigma = max(1, duration / 2);
halfWidth = ceil(3 * sigma);  % Extend 3 sigma each side

% Determine indices
startIdx = max(1, t0 - halfWidth);
endIdx = min(nSamples, t0 + halfWidth);

% Generate Gaussian spike
indices = startIdx:endIdx;
artifact(indices) = amplitude * exp(-((indices - t0).^2) / (2 * sigma^2));

% Mark significant portion of spike (> 5% of peak)
mask(indices) = abs(artifact(indices)) > 0.05 * abs(amplitude);

end

function [artifact, mask] = generateBaselineShift(nSamples, t0, amplitude)
% GENERATEBASELINESHIFT Generate a baseline shift artifact
%
% Creates a step change in baseline at t0.
%
% Inputs:
%   nSamples  - Total number of samples
%   t0        - Shift onset time (sample index)
%   amplitude - Step magnitude (positive or negative)
%
% Outputs:
%   artifact - Step artifact signal [nSamples x 1]
%   mask     - Logical mask [nSamples x 1] (marks the transition point)

artifact = zeros(nSamples, 1);
mask = false(nSamples, 1);

% Random direction if amplitude is positive
if amplitude > 0
    direction = 2 * (rand > 0.5) - 1;  % +1 or -1
    amplitude = amplitude * direction;
end

% Step function from t0 onwards
artifact(t0:end) = amplitude;

% Mark the transition region (a few samples around the step)
transitionWidth = 3;
startIdx = max(1, t0 - transitionWidth);
endIdx = min(nSamples, t0 + transitionWidth);
mask(startIdx:endIdx) = true;

end

function [artifact, mask] = generateGradualDrift(nSamples, t0, amplitude, duration)
% GENERATEGRADUALDRIFT Generate a gradual drift artifact
%
% Creates a linear ramp starting at t0.
%
% Inputs:
%   nSamples  - Total number of samples
%   t0        - Drift onset time (sample index)
%   amplitude - Total drift magnitude
%   duration  - Ramp duration in samples
%
% Outputs:
%   artifact - Drift artifact signal [nSamples x 1]
%   mask     - Logical mask [nSamples x 1]

artifact = zeros(nSamples, 1);
mask = false(nSamples, 1);

% Random direction
direction = 2 * (rand > 0.5) - 1;  % +1 or -1
amplitude = amplitude * direction;

% Determine ramp indices
endRamp = min(nSamples, t0 + duration - 1);
rampIndices = t0:endRamp;
rampLength = length(rampIndices);

if rampLength > 0
    % Linear ramp
    rampValues = amplitude * (0:rampLength-1)' / (rampLength - 1);
    artifact(rampIndices) = rampValues;

    % Hold at final value after ramp
    if endRamp < nSamples
        artifact(endRamp+1:end) = amplitude;
    end

    % Mark the ramp region
    mask(rampIndices) = true;
end

end
