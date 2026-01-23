function noise = generateNoise(nSamples, nChannels, varargin)
% GENERATENOISE Generate different types of noise for fNIRS testing
%
% Creates synthetic noise signals of various spectral characteristics for
% use in unit tests and signal processing validation. Supports white noise
% (flat spectrum), pink noise (1/f spectrum), brown noise (1/f^2 spectrum),
% and physiological noise (combination of cardiac, respiratory, and Mayer
% wave components).
%
% Reference:
%   Internal pf2 test infrastructure. Pink/brown noise generated using
%   spectral shaping in the frequency domain.
%
% Syntax:
%   noise = generateNoise(nSamples, nChannels)
%   noise = generateNoise(nSamples, nChannels, 'type', 'pink')
%   noise = generateNoise(..., 'amplitude', 0.5)
%   noise = generateNoise(..., 'fs', 10, 'seed', 42)
%
% Inputs:
%   nSamples  - Number of time samples [positive integer]
%   nChannels - Number of channels [positive integer]
%
% Name-Value Parameters:
%   'type'      - Noise type (default: 'white')
%                 'white': Gaussian white noise (flat spectrum)
%                 'pink': 1/f noise (more power at low frequencies)
%                 'brown': 1/f^2 noise (Brownian/red noise)
%                 'physiological': Realistic fNIRS-like noise with
%                                  cardiac, respiratory, and Mayer components
%   'amplitude' - Noise amplitude/standard deviation (default: 1)
%                 For 'physiological', scales all component amplitudes.
%   'fs'        - Sampling frequency in Hz (default: 10)
%                 Required for physiological noise generation.
%   'seed'      - Random number generator seed for reproducibility
%                 (default: [], uses current RNG state)
%                 When specified, ensures identical output across calls.
%
% Outputs:
%   noise - Noise matrix [nSamples x nChannels double]
%           Each channel contains independent noise samples.
%
% Algorithm:
%   For 'white':
%     1. Generate Gaussian random samples with randn
%     2. Scale by amplitude
%
%   For 'pink' (1/f):
%     1. Generate white noise in time domain
%     2. Transform to frequency domain via FFT
%     3. Multiply by 1/sqrt(f) amplitude scaling
%     4. Transform back to time domain via IFFT
%     5. Normalize to unit variance, scale by amplitude
%
%   For 'brown' (1/f^2):
%     1. Same as pink but with 1/f amplitude scaling
%
%   For 'physiological':
%     1. Generate cardiac component (~1 Hz, amplitude 0.3)
%     2. Generate respiratory component (~0.25 Hz, amplitude 0.5)
%     3. Generate Mayer wave component (~0.1 Hz, amplitude 0.7)
%     4. Add low-frequency drift (0.01 Hz)
%     5. Add white noise floor (amplitude 0.1)
%     6. Sum components and scale by amplitude
%
% Example:
%   % Generate white noise
%   whiteNoise = pf2_base.tests.synthetic.generateNoise(1000, 4);
%
%   % Generate pink noise with specific amplitude and seed
%   pinkNoise = pf2_base.tests.synthetic.generateNoise(1000, 4, ...
%       'type', 'pink', 'amplitude', 0.5, 'seed', 42);
%
%   % Generate physiological noise at 10 Hz
%   physioNoise = pf2_base.tests.synthetic.generateNoise(6000, 18, ...
%       'type', 'physiological', 'fs', 10, 'amplitude', 1);
%
% Notes:
%   - Pink and brown noise require nSamples > 2 for FFT-based generation
%   - Physiological noise is more realistic when fs >= 4 Hz (Nyquist for cardiac)
%   - Setting 'seed' affects global RNG state; original state is restored after
%
% See also: generateArtifacts, generatePhysiological, randn, fft, ifft

% Input validation using inputParser
p = inputParser;
p.FunctionName = 'generateNoise';

% Required inputs
addRequired(p, 'nSamples', @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);
addRequired(p, 'nChannels', @(x) isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x);

% Optional name-value parameters
validTypes = {'white', 'pink', 'brown', 'physiological'};
addParameter(p, 'type', 'white', @(x) ischar(x) && ismember(lower(x), validTypes));
addParameter(p, 'amplitude', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'fs', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'seed', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));

parse(p, nSamples, nChannels, varargin{:});

noiseType = lower(p.Results.type);
amplitude = p.Results.amplitude;
fs = p.Results.fs;
seed = p.Results.seed;

% Set random seed if provided (save state to restore later)
if ~isempty(seed)
    rngState = rng;
    rng(seed);
    restoreRng = true;
else
    restoreRng = false;
end

try
    % Generate noise based on type
    switch noiseType
        case 'white'
            noise = generateWhiteNoise(nSamples, nChannels, amplitude);

        case 'pink'
            noise = generateColoredNoise(nSamples, nChannels, amplitude, 1);

        case 'brown'
            noise = generateColoredNoise(nSamples, nChannels, amplitude, 2);

        case 'physiological'
            noise = generatePhysiologicalNoise(nSamples, nChannels, fs, amplitude);
    end

    % Restore RNG state if we changed it
    if restoreRng
        rng(rngState);
    end

catch ME
    % Restore RNG state even on error
    if restoreRng
        rng(rngState);
    end
    rethrow(ME);
end

end

%%_Subfunctions_________________________________________________________

function noise = generateWhiteNoise(nSamples, nChannels, amplitude)
% GENERATEWHITENOISE Generate Gaussian white noise
%
% Inputs:
%   nSamples  - Number of samples
%   nChannels - Number of channels
%   amplitude - Noise standard deviation
%
% Outputs:
%   noise - White noise matrix [nSamples x nChannels]

noise = amplitude * randn(nSamples, nChannels);

end

function noise = generateColoredNoise(nSamples, nChannels, amplitude, exponent)
% GENERATECOLOREDNOISE Generate 1/f^exponent colored noise via FFT
%
% Uses frequency domain shaping to create noise with specified spectral
% slope. Pink noise uses exponent=1, brown noise uses exponent=2.
%
% Inputs:
%   nSamples  - Number of samples
%   nChannels - Number of channels
%   amplitude - Target amplitude (standard deviation)
%   exponent  - Spectral exponent (1=pink, 2=brown)
%
% Outputs:
%   noise - Colored noise matrix [nSamples x nChannels]

noise = zeros(nSamples, nChannels);

for ch = 1:nChannels
    % Generate white noise
    white = randn(nSamples, 1);

    % Transform to frequency domain
    X = fft(white);

    % Create frequency vector
    % DC component at index 1, Nyquist at N/2+1 for even N
    N = nSamples;
    freqIdx = (0:N-1)';

    % Create 1/f^(exponent/2) filter (amplitude, so power is 1/f^exponent)
    % Avoid division by zero at DC
    filterMag = ones(N, 1);
    filterMag(2:end) = 1 ./ (freqIdx(2:end) .^ (exponent/2));

    % Apply filter in frequency domain
    X_filtered = X .* filterMag;

    % Transform back to time domain
    colored = real(ifft(X_filtered));

    % Normalize to unit variance, then scale by amplitude
    colored = colored / std(colored);
    noise(:, ch) = amplitude * colored;
end

end

function noise = generatePhysiologicalNoise(nSamples, nChannels, fs, amplitude)
% GENERATEPHYSIOLOGICALNOISE Generate realistic fNIRS physiological noise
%
% Combines cardiac (~1 Hz), respiratory (~0.25 Hz), Mayer waves (~0.1 Hz),
% very low frequency drift, and white noise floor to simulate realistic
% fNIRS physiological contamination.
%
% Inputs:
%   nSamples  - Number of samples
%   nChannels - Number of channels
%   fs        - Sampling frequency in Hz
%   amplitude - Overall amplitude scaling factor
%
% Outputs:
%   noise - Physiological noise matrix [nSamples x nChannels]

t = (0:nSamples-1)' / fs;  % Time vector in seconds

noise = zeros(nSamples, nChannels);

for ch = 1:nChannels
    % Component amplitudes (relative, will be scaled by amplitude parameter)
    cardiacAmp = 0.3;
    respiratoryAmp = 0.5;
    mayerAmp = 0.7;
    driftAmp = 0.4;
    whiteAmp = 0.1;

    % Add slight random variation to frequencies across channels
    cardiacFreq = 1.0 + 0.2 * randn;      % ~1 Hz (60 BPM nominal)
    respiratoryFreq = 0.25 + 0.05 * randn; % ~0.25 Hz (15 breaths/min)
    mayerFreq = 0.1 + 0.02 * randn;        % ~0.1 Hz (Mayer waves)
    driftFreq = 0.01 + 0.005 * randn;      % ~0.01 Hz (very slow drift)

    % Random phases for each component
    cardiacPhase = 2 * pi * rand;
    respiratoryPhase = 2 * pi * rand;
    mayerPhase = 2 * pi * rand;
    driftPhase = 2 * pi * rand;

    % Generate each component
    cardiac = cardiacAmp * sin(2 * pi * cardiacFreq * t + cardiacPhase);
    respiratory = respiratoryAmp * sin(2 * pi * respiratoryFreq * t + respiratoryPhase);
    mayer = mayerAmp * sin(2 * pi * mayerFreq * t + mayerPhase);
    drift = driftAmp * sin(2 * pi * driftFreq * t + driftPhase);
    white = whiteAmp * randn(nSamples, 1);

    % Combine all components
    combined = cardiac + respiratory + mayer + drift + white;

    % Scale by amplitude parameter
    noise(:, ch) = amplitude * combined;
end

end
