function data = generateFNIRS(varargin)
% GENERATEFNIRS Generate synthetic fNIRS data for testing signal processing
%
% Creates realistic synthetic fNIRS data with configurable physiological
% signals (hemodynamic response, cardiac, respiratory) and artifacts (motion,
% drift, noise). Useful for validating signal processing algorithms and
% testing pipeline components with known ground truth.
%
% Reference:
%   Glover, G.H. (1999). Deconvolution of impulse response in event-related
%   BOLD fMRI. NeuroImage, 9(4), 416-429.
%   DOI: 10.1006/nimg.1998.0419
%
% Syntax:
%   data = generateFNIRS()
%   data = generateFNIRS('Name', Value, ...)
%
% Name-Value Parameters:
%   'duration'          - Duration in seconds (default: 60)
%                         Range: 1-3600 seconds
%   'fs'                - Sampling frequency in Hz (default: 10)
%                         Range: 1-1000 Hz
%   'nChannels'         - Number of fNIRS channels (default: 18)
%                         Each channel produces 2 raw signals (one per wavelength)
%   'wavelengths'       - Wavelengths in nm (default: [730, 850])
%                         Must be a 2-element vector
%   'addHRF'            - Add hemodynamic response function (default: false)
%                         Simulates neural activation response
%   'hrfOnsets'         - Stimulus onset times in seconds (default: [])
%                         Times when HRF should be triggered
%                         If addHRF=true and hrfOnsets=[], defaults to [10, 30, 50]
%   'hrfAmplitude'      - Peak amplitude of HRF as fraction of baseline (default: 0.02)
%                         Typical range: 0.01-0.05 (1-5% change)
%   'addHeartbeat'      - Add cardiac artifact (~1 Hz) (default: false)
%                         Simulates pulsatile blood flow artifact
%   'heartRate'         - Heart rate in beats per minute (default: 70)
%                         Range: 40-200 BPM
%   'heartAmplitude'    - Cardiac artifact amplitude as fraction (default: 0.005)
%                         Typical range: 0.001-0.01
%   'addRespiration'    - Add respiratory artifact (~0.25 Hz) (default: false)
%                         Simulates breathing-related signal fluctuation
%   'respRate'          - Respiration rate per minute (default: 15)
%                         Range: 8-30 breaths/min
%   'respAmplitude'     - Respiratory amplitude as fraction (default: 0.003)
%                         Typical range: 0.001-0.01
%   'addMotion'         - Add motion artifacts (spikes) (default: false)
%                         Simulates head movement artifacts
%   'motionTimes'       - Times for motion artifacts in seconds (default: [])
%                         If addMotion=true and motionTimes=[], defaults to random
%   'motionAmplitude'   - Motion spike amplitude as fraction (default: 0.1)
%                         Range: 0.01-0.5 (1-50% of signal)
%   'noiseLevel'        - Gaussian noise level as fraction of signal (default: 0.01)
%                         Range: 0-0.1
%   'drift'             - Add slow drift (default: false)
%                         Simulates baseline drift from temperature, etc.
%   'driftAmplitude'    - Drift amplitude as fraction (default: 0.05)
%   'baselineIntensity' - Baseline light intensity in AU (default: 1000)
%                         Raw intensity value before any modulation
%   'seed'              - Random seed for reproducibility (default: [])
%                         Set to integer for reproducible output
%
% Outputs:
%   data - Standard fNIRS struct with fields:
%          t0       - Reference time point (datetime)
%          raw      - Raw light intensity [T x C*nWavelengths]
%                     Columns alternate: ch1_wl1, ch1_wl2, ch2_wl1, ch2_wl2, ...
%          time     - Time vector [T x 1] in seconds
%          fs       - Sampling frequency in Hz
%          fchMask  - Channel mask [1 x nChannels], all ones (all good)
%          markers  - Event markers [M x 3] from hrfOnsets
%                     Format: [time, value, duration]
%          info     - Metadata struct with:
%                     .header.filename = 'synthetic'
%                     .probename = 'synthetic'
%                     .synthetic = struct with generation parameters
%          channels - Channel numbers [1 x nChannels]
%
% Algorithm:
%   1. Generate baseline intensity signal at specified level
%   2. Optionally add HRF at specified onset times (convolution with canonical HRF)
%   3. Optionally add cardiac oscillation (~1 Hz sinusoid)
%   4. Optionally add respiratory oscillation (~0.25 Hz sinusoid)
%   5. Optionally add slow drift (very low frequency sinusoid)
%   6. Add Gaussian noise scaled to baseline
%   7. Optionally add motion spikes at specified times
%   8. Apply wavelength-specific scaling (shorter wavelength = lower intensity)
%
% Example:
%   % Basic synthetic data with defaults
%   data = pf2_base.tests.synthetic.generateFNIRS();
%   plot(data.time, data.raw(:,1));
%   xlabel('Time (s)'); ylabel('Intensity (AU)');
%
%   % Data with HRF and physiological artifacts
%   data = pf2_base.tests.synthetic.generateFNIRS(...
%       'duration', 120, ...
%       'addHRF', true, ...
%       'hrfOnsets', [20, 50, 80], ...
%       'addHeartbeat', true, ...
%       'addRespiration', true);
%
%   % Data with motion artifacts for testing SMAR
%   data = pf2_base.tests.synthetic.generateFNIRS(...
%       'addMotion', true, ...
%       'motionTimes', [15, 45], ...
%       'seed', 42);  % Reproducible
%
%   % Process synthetic data through pipeline
%   data = pf2_base.tests.synthetic.generateFNIRS('addHRF', true);
%   processed = processFNIRS2(data);
%   pf2.data.plot.Oxy(processed);
%
% Notes:
%   - Raw output has nChannels * nWavelengths columns (e.g., 18 channels -> 36 columns)
%   - Column order: [ch1_730nm, ch1_850nm, ch2_730nm, ch2_850nm, ...]
%   - HRF amplitude affects both wavelengths differently (simulates HbO/HbR)
%   - Motion artifacts affect all channels simultaneously
%   - Use 'seed' parameter for reproducible test data
%
% See also: pf2_base.fnirs.buildHRF, pf2_SMAR, processFNIRS2

%% Parse input arguments
p = inputParser;
p.FunctionName = 'generateFNIRS';

% Signal parameters
addParameter(p, 'duration', 60, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'fs', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'nChannels', 18, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'wavelengths', [730, 850], @(x) isnumeric(x) && length(x) == 2);
addParameter(p, 'baselineIntensity', 1000, @(x) isnumeric(x) && isscalar(x) && x > 0);

% HRF parameters
addParameter(p, 'addHRF', false, @islogical);
addParameter(p, 'hrfOnsets', [], @isnumeric);
addParameter(p, 'hrfAmplitude', 0.02, @(x) isnumeric(x) && isscalar(x) && x >= 0);

% Cardiac parameters
addParameter(p, 'addHeartbeat', false, @islogical);
addParameter(p, 'heartRate', 70, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'heartAmplitude', 0.005, @(x) isnumeric(x) && isscalar(x) && x >= 0);

% Respiratory parameters
addParameter(p, 'addRespiration', false, @islogical);
addParameter(p, 'respRate', 15, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'respAmplitude', 0.003, @(x) isnumeric(x) && isscalar(x) && x >= 0);

% Motion artifact parameters
addParameter(p, 'addMotion', false, @islogical);
addParameter(p, 'motionTimes', [], @isnumeric);
addParameter(p, 'motionAmplitude', 0.1, @(x) isnumeric(x) && isscalar(x) && x >= 0);

% Noise and drift
addParameter(p, 'noiseLevel', 0.01, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'drift', false, @islogical);
addParameter(p, 'driftAmplitude', 0.05, @(x) isnumeric(x) && isscalar(x) && x >= 0);

% Reproducibility
addParameter(p, 'seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));

parse(p, varargin{:});
opts = p.Results;

%% Set random seed if specified
if ~isempty(opts.seed)
    rng(opts.seed);
end

%% Generate time vector
nSamples = round(opts.duration * opts.fs);
time = (0:nSamples-1)' / opts.fs;

%% Initialize raw signal matrix
% Each channel has signals for each wavelength
nWavelengths = length(opts.wavelengths);
nRawChannels = opts.nChannels * nWavelengths;
raw = ones(nSamples, nRawChannels) * opts.baselineIntensity;

%% Apply wavelength-specific baseline scaling
% Shorter wavelengths typically have lower tissue penetration and intensity
wavelengthScaling = opts.wavelengths / mean(opts.wavelengths);
for ch = 1:opts.nChannels
    for wl = 1:nWavelengths
        colIdx = (ch-1) * nWavelengths + wl;
        raw(:, colIdx) = raw(:, colIdx) * wavelengthScaling(wl);
    end
end

%% Add hemodynamic response function
markers = [];
if opts.addHRF
    % Default HRF onset times if not specified
    hrfOnsets = opts.hrfOnsets;
    if isempty(hrfOnsets)
        hrfOnsets = [10, 30, 50];
        hrfOnsets = hrfOnsets(hrfOnsets < opts.duration - 15);  % Ensure within duration
    end

    % Generate canonical HRF
    hrf = generateHRF(opts.fs);

    % Create stimulus train
    stimTrain = zeros(nSamples, 1);
    for onset = hrfOnsets(:)'
        if onset >= 0 && onset < opts.duration
            sampleIdx = round(onset * opts.fs) + 1;
            if sampleIdx <= nSamples
                stimTrain(sampleIdx) = 1;
            end
        end
    end

    % Convolve stimulus train with HRF
    hrfResponse = conv(stimTrain, hrf, 'full');
    hrfResponse = hrfResponse(1:nSamples);

    % Normalize HRF response
    if max(abs(hrfResponse)) > 0
        hrfResponse = hrfResponse / max(abs(hrfResponse));
    end

    % Apply HRF to each channel with wavelength-dependent effects
    % HbO increases -> 850nm decreases more than 730nm (absorption)
    % HbR decreases -> 730nm decreases less (different extinction)
    hrfEffects = [0.6, 1.0];  % Relative effect at each wavelength [730, 850]

    for ch = 1:opts.nChannels
        % Add small channel-to-channel variation
        chVariation = 1 + 0.1 * (rand - 0.5);

        for wl = 1:nWavelengths
            colIdx = (ch-1) * nWavelengths + wl;
            % HRF causes decrease in light intensity (increased absorption)
            hrfModulation = -opts.hrfAmplitude * hrfEffects(wl) * chVariation * hrfResponse;
            raw(:, colIdx) = raw(:, colIdx) .* (1 + hrfModulation);
        end
    end

    % Create markers from HRF onsets
    markers = zeros(length(hrfOnsets), 3);
    markers(:, 1) = hrfOnsets(:);  % Time
    markers(:, 2) = 1;              % Marker value
    markers(:, 3) = 0;              % Duration (impulse)
end

%% Add cardiac artifact (heartbeat)
if opts.addHeartbeat
    heartFreq = opts.heartRate / 60;  % Convert BPM to Hz
    cardiac = generateHeartbeat(time, heartFreq, opts.heartAmplitude);

    % Apply cardiac artifact to all channels
    for ch = 1:opts.nChannels
        % Cardiac effect varies slightly between wavelengths
        cardiacEffects = [0.8, 1.0];  % 730nm slightly less affected

        for wl = 1:nWavelengths
            colIdx = (ch-1) * nWavelengths + wl;
            chVariation = 1 + 0.05 * (rand - 0.5);
            raw(:, colIdx) = raw(:, colIdx) .* (1 + cardiac * cardiacEffects(wl) * chVariation);
        end
    end
end

%% Add respiratory artifact
if opts.addRespiration
    respFreq = opts.respRate / 60;  % Convert breaths/min to Hz
    respiration = opts.respAmplitude * sin(2 * pi * respFreq * time);

    % Add slight phase variation across channels
    for ch = 1:opts.nChannels
        phaseShift = 0.1 * pi * rand;
        chResp = opts.respAmplitude * sin(2 * pi * respFreq * time + phaseShift);

        for wl = 1:nWavelengths
            colIdx = (ch-1) * nWavelengths + wl;
            raw(:, colIdx) = raw(:, colIdx) .* (1 + chResp);
        end
    end
end

%% Add slow drift
if opts.drift
    % Very slow drift (period = duration)
    driftFreq = 1 / (2 * opts.duration);
    driftSignal = opts.driftAmplitude * sin(2 * pi * driftFreq * time);

    % Add drift to all channels
    for col = 1:nRawChannels
        % Vary drift phase across channels
        phaseShift = 2 * pi * rand;
        chDrift = opts.driftAmplitude * sin(2 * pi * driftFreq * time + phaseShift);
        raw(:, col) = raw(:, col) .* (1 + chDrift);
    end
end

%% Add Gaussian noise
if opts.noiseLevel > 0
    noise = opts.noiseLevel * opts.baselineIntensity * randn(nSamples, nRawChannels);
    raw = raw + noise;
end

%% Add motion artifacts
if opts.addMotion
    motionTimes = opts.motionTimes;

    % Generate random motion times if not specified
    if isempty(motionTimes)
        nMotionEvents = max(1, round(opts.duration / 30));  % ~1 event per 30 seconds
        motionTimes = sort(rand(1, nMotionEvents) * opts.duration);
    end

    % Add motion spikes at specified times
    for motionTime = motionTimes(:)'
        if motionTime >= 0 && motionTime < opts.duration
            spike = generateMotionSpike(time, motionTime, opts.fs, ...
                opts.motionAmplitude, opts.baselineIntensity);

            % Apply spike to all channels with variation
            for col = 1:nRawChannels
                spikeVariation = 0.5 + rand;  % 0.5 to 1.5x amplitude variation
                spikeSign = sign(rand - 0.5);  % Random positive or negative
                if spikeSign == 0
                    spikeSign = 1;
                end
                raw(:, col) = raw(:, col) + spikeSign * spike * spikeVariation;
            end
        end
    end
end

%% Ensure non-negative intensities
raw = max(raw, 0);

%% Build output structure
data = struct();
data.t0 = datetime('now');
data.raw = raw;
data.time = time;
data.fs = opts.fs;
data.fchMask = ones(1, opts.nChannels);
data.markers = markers;
data.channels = 1:opts.nChannels;

% Build info structure
data.info = struct();
data.info.header = struct();
data.info.header.filename = 'synthetic';
data.info.mrkheaders = struct();
data.info.filename = 'synthetic';
data.info.probename = 'synthetic';

% Store generation parameters for reference
data.info.synthetic = struct();
data.info.synthetic.duration = opts.duration;
data.info.synthetic.fs = opts.fs;
data.info.synthetic.nChannels = opts.nChannels;
data.info.synthetic.wavelengths = opts.wavelengths;
data.info.synthetic.baselineIntensity = opts.baselineIntensity;
data.info.synthetic.addHRF = opts.addHRF;
data.info.synthetic.hrfOnsets = opts.hrfOnsets;
data.info.synthetic.hrfAmplitude = opts.hrfAmplitude;
data.info.synthetic.addHeartbeat = opts.addHeartbeat;
data.info.synthetic.heartRate = opts.heartRate;
data.info.synthetic.heartAmplitude = opts.heartAmplitude;
data.info.synthetic.addRespiration = opts.addRespiration;
data.info.synthetic.respRate = opts.respRate;
data.info.synthetic.respAmplitude = opts.respAmplitude;
data.info.synthetic.addMotion = opts.addMotion;
data.info.synthetic.motionTimes = opts.motionTimes;
data.info.synthetic.motionAmplitude = opts.motionAmplitude;
data.info.synthetic.noiseLevel = opts.noiseLevel;
data.info.synthetic.drift = opts.drift;
data.info.synthetic.driftAmplitude = opts.driftAmplitude;
data.info.synthetic.seed = opts.seed;

end


%% Helper Functions

function hrf = generateHRF(fs)
% GENERATEHRF Generate canonical hemodynamic response function
%
% Generates a canonical HRF using the difference-of-gammas model from
% Glover (1999). The HRF represents the expected fNIRS signal response
% to a brief neural event.
%
% Reference:
%   Glover, G.H. (1999). Deconvolution of impulse response in event-related
%   BOLD fMRI. NeuroImage, 9(4), 416-429.
%   DOI: 10.1006/nimg.1998.0419
%
% Inputs:
%   fs - Sampling frequency in Hz
%
% Outputs:
%   hrf - HRF amplitude vector [N x 1], normalized to peak = 1
%         Duration approximately 15 seconds

% HRF duration
hrfDuration = 15;  % seconds

% Time vector
t = (0:1/fs:hrfDuration)';

% Glover (1999) canonical HRF parameters
% Primary response parameters
a1 = 6;     % Shape parameter
b1 = 1;     % Scale parameter

% Undershoot parameters
a2 = 16;    % Shape parameter
b2 = 1;     % Scale parameter
c = 1/6;    % Undershoot ratio

% Difference of gammas model
% h(t) = (t^(a1-1) * b1^a1 * exp(-b1*t)) / gamma(a1)
%      - c * (t^(a2-1) * b2^a2 * exp(-b2*t)) / gamma(a2)

% Primary response (gamma function)
g1 = (t.^(a1-1) .* b1^a1 .* exp(-b1.*t)) / gamma(a1);

% Undershoot (gamma function)
g2 = (t.^(a2-1) .* b2^a2 .* exp(-b2.*t)) / gamma(a2);

% Combined HRF
hrf = g1 - c * g2;

% Normalize to peak = 1
hrf = hrf / max(hrf);

% Handle edge case of t=0
hrf(1) = 0;

end


function cardiac = generateHeartbeat(time, heartFreq, amplitude)
% GENERATEHEARTBEAT Generate cardiac artifact signal
%
% Creates a sinusoidal signal simulating cardiac pulsation in fNIRS data.
% The cardiac signal appears as a ~1 Hz oscillation due to pulsatile
% blood flow in surface vessels.
%
% Inputs:
%   time      - Time vector [T x 1] in seconds
%   heartFreq - Heart rate in Hz (typically 0.8-1.5 Hz)
%   amplitude - Peak amplitude as fraction of baseline
%
% Outputs:
%   cardiac - Cardiac modulation signal [T x 1]

% Basic sinusoidal cardiac signal
cardiac = amplitude * sin(2 * pi * heartFreq * time);

% Add slight heart rate variability (realistic)
% ~5% variation in period
hrvFreq = 0.1;  % HRV modulation frequency (respiratory sinus arrhythmia)
hrvDepth = 0.05;  % 5% frequency modulation
phaseModulation = hrvDepth * sin(2 * pi * hrvFreq * time);

% Apply frequency modulation
instantPhase = 2 * pi * heartFreq * time + phaseModulation .* time;
cardiac = amplitude * sin(instantPhase);

end


function spike = generateMotionSpike(time, spikeTime, fs, amplitude, baseline)
% GENERATEMOTIONSPIKE Generate motion artifact spike
%
% Creates a spike artifact that simulates head movement in fNIRS data.
% Motion artifacts typically appear as rapid, sharp deflections followed
% by a slower recovery period.
%
% Inputs:
%   time      - Time vector [T x 1] in seconds
%   spikeTime - Time of spike onset in seconds
%   fs        - Sampling frequency in Hz
%   amplitude - Spike amplitude as fraction of baseline
%   baseline  - Baseline intensity value
%
% Outputs:
%   spike - Spike artifact signal [T x 1]

% Initialize spike signal
spike = zeros(size(time));

% Spike parameters
riseTime = 0.05;     % 50 ms rise time
fallTime = 0.3;      % 300 ms fall time
spikeWidth = riseTime + fallTime;

% Find indices within spike window
spikeStart = spikeTime;
spikePeak = spikeTime + riseTime;
spikeEnd = spikeTime + spikeWidth;

% Rising phase (rapid increase)
riseIdx = (time >= spikeStart) & (time < spikePeak);
if any(riseIdx)
    t_rise = time(riseIdx) - spikeStart;
    spike(riseIdx) = amplitude * baseline * (t_rise / riseTime);
end

% Falling phase (exponential decay)
fallIdx = (time >= spikePeak) & (time < spikeEnd);
if any(fallIdx)
    t_fall = time(fallIdx) - spikePeak;
    tau = fallTime / 3;  % Time constant
    spike(fallIdx) = amplitude * baseline * exp(-t_fall / tau);
end

end
