function physio = generatePhysiological(nSamples, fs, varargin)
% GENERATEPHYSIOLOGICAL Generate physiological signals for fNIRS testing
%
% Creates synthetic physiological signals that contaminate fNIRS measurements,
% including cardiac pulsation (~1 Hz), respiratory oscillations (~0.25 Hz),
% Mayer waves (~0.1 Hz), and very low frequency (VLF) oscillations. These
% signals are commonly observed in fNIRS data and must be filtered or
% accounted for in analysis.
%
% Reference:
%   Tachtsidis, I. & Scholkmann, F. (2016). False positives and false negatives
%   in functional near-infrared spectroscopy. Neurophotonics, 3(3), 031405.
%   DOI: 10.1117/1.NPh.3.3.031405
%
%   Mayer waves: Julien, C. (2006). The enigma of Mayer waves: Facts and
%   models. Cardiovascular Research, 70(1), 12-21.
%
% Syntax:
%   physio = generatePhysiological(nSamples, fs)
%   physio = generatePhysiological(nSamples, fs, 'cardiac', true)
%   physio = generatePhysiological(nSamples, fs, 'heartRate', 72, 'respRate', 15)
%   physio = generatePhysiological(..., 'nChannels', 18)
%
% Inputs:
%   nSamples - Number of time samples [positive integer]
%   fs       - Sampling frequency in Hz [positive scalar]
%              Should be >= 4 Hz to adequately sample cardiac component.
%
% Name-Value Parameters:
%   'cardiac'     - Include cardiac component (default: true)
%                   Generates quasi-periodic cardiac pulsation with natural
%                   heart rate variability.
%   'heartRate'   - Heart rate in BPM (default: 70)
%                   Typical range: 50-100 BPM for resting adults.
%                   Actual instantaneous rate varies by ~5-10% (HRV).
%   'respiratory' - Include respiratory component (default: true)
%                   Generates respiratory oscillation modulated by depth
%                   variation.
%   'respRate'    - Respiratory rate in breaths per minute (default: 15)
%                   Typical range: 12-20 breaths/min at rest.
%   'mayer'       - Include Mayer waves (default: true)
%                   Low-frequency oscillations (~0.1 Hz) related to
%                   sympathetic nervous system activity.
%   'vlf'         - Include very low frequency oscillations (default: false)
%                   VLF oscillations (< 0.04 Hz) from thermoregulation,
%                   hormonal, and metabolic processes.
%   'amplitudes'  - Struct with amplitude multipliers (default: see below)
%                   Fields: cardiac, respiratory, mayer, vlf
%                   Default amplitudes: cardiac=0.3, respiratory=0.5,
%                   mayer=0.7, vlf=0.4 (relative units)
%   'nChannels'   - Number of output channels (default: 1)
%                   Each channel gets independent phase offsets and slight
%                   frequency/amplitude variations.
%   'seed'        - Random seed for reproducibility (default: [])
%
% Outputs:
%   physio - Physiological signal matrix [nSamples x nChannels double]
%            Units are arbitrary (relative amplitude).
%            Sum of all enabled components.
%
% Algorithm:
%   For each component:
%   1. Generate base sinusoid at component frequency
%   2. Add frequency modulation for natural variability:
%      - Cardiac: Heart rate variability (~5% of base rate)
%      - Respiratory: Breath-to-breath variability (~10%)
%      - Mayer: Natural variation (~20%)
%   3. Add amplitude modulation for depth variation
%   4. Apply random phase offset per channel
%   5. Sum all components
%
% Example:
%   % Basic usage: 60 seconds at 10 Hz with all defaults
%   physio = pf2_base.tests.synthetic.generatePhysiological(600, 10);
%
%   % Custom heart rate and respiratory rate
%   physio = pf2_base.tests.synthetic.generatePhysiological(600, 10, ...
%       'heartRate', 80, 'respRate', 18);
%
%   % Only cardiac and respiratory (no Mayer waves)
%   physio = pf2_base.tests.synthetic.generatePhysiological(600, 10, ...
%       'mayer', false);
%
%   % Multi-channel with custom amplitudes and seed
%   amps = struct('cardiac', 0.5, 'respiratory', 0.3, 'mayer', 0.8, 'vlf', 0.2);
%   physio = pf2_base.tests.synthetic.generatePhysiological(600, 10, ...
%       'nChannels', 18, 'amplitudes', amps, 'vlf', true, 'seed', 42);
%
%   % Verify spectral content
%   [pxx, f] = pwelch(physio(:,1), [], [], [], 10);
%   figure; plot(f, 10*log10(pxx)); xlabel('Frequency (Hz)'); ylabel('PSD (dB)');
%
% Notes:
%   - Cardiac component requires fs >= 4 Hz (Nyquist for 2 Hz max)
%   - Lower sampling rates will alias cardiac signal
%   - Component amplitudes are in arbitrary units; scale as needed
%   - Phase offsets between channels simulate spatial variation in fNIRS
%   - Heart rate variability model is simplified (sinusoidal modulation)
%
% See also: generateNoise, generateArtifacts, pf2_lpf, pf2_bpf_butter

% Input validation using inputParser
p = inputParser;
p.FunctionName = 'generatePhysiological';

% Required inputs
addRequired(p, 'nSamples', @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);
addRequired(p, 'fs', @(x) isnumeric(x) && isscalar(x) && x > 0);

% Component enable flags
addParameter(p, 'cardiac', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
addParameter(p, 'respiratory', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
addParameter(p, 'mayer', true, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));
addParameter(p, 'vlf', false, @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1)));

% Component parameters
addParameter(p, 'heartRate', 70, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'respRate', 15, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'amplitudes', struct(), @(x) isstruct(x));
addParameter(p, 'nChannels', 1, @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);
addParameter(p, 'seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));

parse(p, nSamples, fs, varargin{:});

includeCardiac = logical(p.Results.cardiac);
includeRespiratory = logical(p.Results.respiratory);
includeMayer = logical(p.Results.mayer);
includeVLF = logical(p.Results.vlf);
heartRate = p.Results.heartRate;
respRate = p.Results.respRate;
amplitudesIn = p.Results.amplitudes;
nChannels = p.Results.nChannels;
seed = p.Results.seed;

% Set default amplitudes
defaultAmplitudes = struct(...
    'cardiac', 0.3, ...
    'respiratory', 0.5, ...
    'mayer', 0.7, ...
    'vlf', 0.4);

% Merge user amplitudes with defaults
amplitudes = defaultAmplitudes;
if isfield(amplitudesIn, 'cardiac'), amplitudes.cardiac = amplitudesIn.cardiac; end
if isfield(amplitudesIn, 'respiratory'), amplitudes.respiratory = amplitudesIn.respiratory; end
if isfield(amplitudesIn, 'mayer'), amplitudes.mayer = amplitudesIn.mayer; end
if isfield(amplitudesIn, 'vlf'), amplitudes.vlf = amplitudesIn.vlf; end

% Set random seed if provided
if ~isempty(seed)
    rngState = rng;
    rng(seed);
    restoreRng = true;
else
    restoreRng = false;
end

try
    % Generate time vector
    t = (0:nSamples-1)' / fs;  % Time in seconds

    % Initialize output
    physio = zeros(nSamples, nChannels);

    for ch = 1:nChannels
        channelSignal = zeros(nSamples, 1);

        % Generate each component with channel-specific variations
        if includeCardiac
            cardiac = generateCardiacComponent(t, heartRate, amplitudes.cardiac);
            channelSignal = channelSignal + cardiac;
        end

        if includeRespiratory
            respiratory = generateRespiratoryComponent(t, respRate, amplitudes.respiratory);
            channelSignal = channelSignal + respiratory;
        end

        if includeMayer
            mayer = generateMayerComponent(t, amplitudes.mayer);
            channelSignal = channelSignal + mayer;
        end

        if includeVLF
            vlfSignal = generateVLFComponent(t, amplitudes.vlf);
            channelSignal = channelSignal + vlfSignal;
        end

        physio(:, ch) = channelSignal;
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

function cardiac = generateCardiacComponent(t, heartRateBPM, amplitude)
% GENERATECARDIACCOMPONENT Generate cardiac pulsation signal with HRV
%
% Creates a quasi-periodic cardiac signal with heart rate variability (HRV)
% modeled as sinusoidal frequency modulation.
%
% Inputs:
%   t           - Time vector in seconds [nSamples x 1]
%   heartRateBPM - Base heart rate in beats per minute
%   amplitude   - Signal amplitude
%
% Outputs:
%   cardiac - Cardiac pulsation signal [nSamples x 1]

% Base cardiac frequency
baseFreq = heartRateBPM / 60;  % Convert BPM to Hz

% Heart rate variability parameters
hrvFreq = 0.25;              % HRV modulation frequency (~respiratory sinus arrhythmia)
hrvDepth = 0.08;             % HRV depth (8% frequency variation)

% Random phase offset for this channel
phaseOffset = 2 * pi * rand;

% Generate frequency modulation (HRV)
freqModulation = 1 + hrvDepth * sin(2 * pi * hrvFreq * t + 2 * pi * rand);
instantFreq = baseFreq * freqModulation;

% Integrate instantaneous frequency to get phase
% phase(t) = integral(2*pi*f(t)) dt
dt = t(2) - t(1);
phase = cumsum(2 * pi * instantFreq * dt) + phaseOffset;

% Generate cardiac waveform (approximate pulse shape with harmonics)
% Real cardiac has sharper peaks, approximated by adding harmonics
fundamental = sin(phase);
secondHarmonic = 0.3 * sin(2 * phase);
thirdHarmonic = 0.1 * sin(3 * phase);

cardiac = amplitude * (fundamental + secondHarmonic + thirdHarmonic);

% Add slight amplitude variation
ampModFreq = 0.03;  % Very slow amplitude variation
ampMod = 1 + 0.15 * sin(2 * pi * ampModFreq * t + 2 * pi * rand);
cardiac = cardiac .* ampMod;

end

function respiratory = generateRespiratoryComponent(t, respRateBPM, amplitude)
% GENERATERESPIRATORYCOMPONENT Generate respiratory oscillation signal
%
% Creates a respiratory signal with natural breath-to-breath variability
% in both rate and depth.
%
% Inputs:
%   t          - Time vector in seconds [nSamples x 1]
%   respRateBPM - Base respiratory rate in breaths per minute
%   amplitude  - Signal amplitude
%
% Outputs:
%   respiratory - Respiratory oscillation signal [nSamples x 1]

% Base respiratory frequency
baseFreq = respRateBPM / 60;  % Convert breaths/min to Hz

% Respiratory rate variability
rrvFreq = 0.02;              % Very slow modulation
rrvDepth = 0.10;             % 10% rate variation

% Random phase offset
phaseOffset = 2 * pi * rand;

% Generate frequency modulation
freqModulation = 1 + rrvDepth * sin(2 * pi * rrvFreq * t + 2 * pi * rand);
instantFreq = baseFreq * freqModulation;

% Integrate instantaneous frequency
dt = t(2) - t(1);
phase = cumsum(2 * pi * instantFreq * dt) + phaseOffset;

% Respiratory waveform (slightly asymmetric - faster expiration)
% Approximate with fundamental and second harmonic
fundamental = sin(phase);
asymmetry = 0.2 * sin(2 * phase + pi/4);  % Adds asymmetry

respiratory = amplitude * (fundamental + asymmetry);

% Add depth variation (some breaths deeper than others)
depthModFreq = 0.01;
depthMod = 1 + 0.2 * sin(2 * pi * depthModFreq * t + 2 * pi * rand);
respiratory = respiratory .* depthMod;

end

function mayer = generateMayerComponent(t, amplitude)
% GENERATEMAYERCOMPONENT Generate Mayer wave signal
%
% Creates Mayer waves (~0.1 Hz) associated with sympathetic nervous system
% activity and blood pressure regulation.
%
% Reference:
%   Julien, C. (2006). The enigma of Mayer waves. Cardiovascular Research.
%
% Inputs:
%   t         - Time vector in seconds [nSamples x 1]
%   amplitude - Signal amplitude
%
% Outputs:
%   mayer - Mayer wave signal [nSamples x 1]

% Mayer wave frequency (~0.1 Hz, but varies)
baseFreq = 0.1;

% Natural variation in Mayer wave frequency
freqVariation = 0.02;  % +/- 0.02 Hz variation
freqModFreq = 0.005;   % Very slow frequency drift

% Random phase offset
phaseOffset = 2 * pi * rand;

% Generate slowly varying frequency
freqModulation = 1 + (freqVariation/baseFreq) * sin(2 * pi * freqModFreq * t + 2 * pi * rand);
instantFreq = baseFreq * freqModulation;

% Integrate instantaneous frequency
dt = t(2) - t(1);
phase = cumsum(2 * pi * instantFreq * dt) + phaseOffset;

% Simple sinusoidal Mayer wave
mayer = amplitude * sin(phase);

% Add amplitude waxing/waning (characteristic of Mayer waves)
ampModFreq = 0.008;
ampMod = 0.7 + 0.3 * sin(2 * pi * ampModFreq * t + 2 * pi * rand);
mayer = mayer .* ampMod;

end

function vlfSignal = generateVLFComponent(t, amplitude)
% GENERATEVLFCOMPONENT Generate very low frequency oscillations
%
% Creates VLF oscillations (< 0.04 Hz) from thermoregulation, hormonal,
% and metabolic processes.
%
% Inputs:
%   t         - Time vector in seconds [nSamples x 1]
%   amplitude - Signal amplitude
%
% Outputs:
%   vlfSignal - VLF oscillation signal [nSamples x 1]

% VLF frequencies (multiple components)
freq1 = 0.02 + 0.005 * randn;   % ~0.02 Hz
freq2 = 0.01 + 0.003 * randn;   % ~0.01 Hz
freq3 = 0.005 + 0.002 * randn;  % ~0.005 Hz

% Random phases
phase1 = 2 * pi * rand;
phase2 = 2 * pi * rand;
phase3 = 2 * pi * rand;

% Generate VLF components with different amplitudes
vlf1 = 0.5 * sin(2 * pi * freq1 * t + phase1);
vlf2 = 0.3 * sin(2 * pi * freq2 * t + phase2);
vlf3 = 0.2 * sin(2 * pi * freq3 * t + phase3);

% Combine
vlfSignal = amplitude * (vlf1 + vlf2 + vlf3);

end
