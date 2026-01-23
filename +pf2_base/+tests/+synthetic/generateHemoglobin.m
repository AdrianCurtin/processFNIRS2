function data = generateHemoglobin(varargin)
% GENERATEHEMOGLOBIN Generate synthetic HbO/HbR data for testing
%
% Creates synthetic hemoglobin concentration data with configurable
% properties for testing analysis functions without requiring raw data
% processing. Generates data that mimics real fNIRS output including
% hemodynamic responses, physiological noise, and signal drift.
%
% Reference:
%   Canonical HRF based on:
%   Lindquist MA, Meng Loh J, Atlas LY, Wager TD. (2009).
%   Modeling the hemodynamic response function in fMRI: efficiency, bias
%   and mis-modeling. Neuroimage, 45(1 Suppl), S187-S198.
%   DOI: 10.1016/j.neuroimage.2008.10.065
%
%   HbR/HbO ratio typical values:
%   Cui X, Bray S, Reiss AL. (2010). Functional near infrared spectroscopy
%   (NIRS) signal improvement based on negative correlation between
%   oxygenated and deoxygenated hemoglobin dynamics. Neuroimage, 49(4),
%   3039-3046. DOI: 10.1016/j.neuroimage.2009.11.050
%
% Syntax:
%   data = generateHemoglobin()
%   data = generateHemoglobin('Name', Value, ...)
%
% Name-Value Parameters:
%   'duration'       - Duration in seconds (default: 60)
%                      Must be positive. Determines length of time series.
%   'fs'             - Sampling frequency in Hz (default: 10)
%                      Must be positive. Common fNIRS rates: 2-50 Hz.
%   'nChannels'      - Number of channels (default: 18)
%                      Must be positive integer. Typical: 8-52 channels.
%   'addHRF'         - Add hemodynamic response (default: false)
%                      When true, convolves stimulus with canonical HRF.
%   'hrfOnsets'      - Stimulus onset times in seconds (default: [])
%                      Vector of times when stimuli occur. Ignored if
%                      addHRF is false.
%   'hrfAmplitude'   - HRF amplitude in micromolar (default: 1)
%                      Peak amplitude of HbO response. Typical: 0.1-5 uM.
%   'hbRatio'        - HbR/HbO ratio (default: -0.3)
%                      Ratio of HbR to HbO amplitude. Typically negative
%                      (-0.5 to -0.2) reflecting inverse coupling.
%   'addNoise'       - Add Gaussian noise (default: true)
%                      When true, adds independent noise to each channel.
%   'noiseLevel'     - Noise standard deviation in micromolar (default: 0.1)
%                      Higher values simulate noisier recordings.
%   'addDrift'       - Add slow baseline drift (default: false)
%                      When true, adds linear trend to signal.
%   'driftSlope'     - Drift slope in uM per second (default: 0.01)
%                      Rate of baseline drift when addDrift is true.
%   'addOscillations'- Add Mayer waves ~0.1 Hz (default: false)
%                      When true, adds low-frequency oscillations.
%   'oscillationAmp' - Mayer wave amplitude in uM (default: 0.2)
%                      Amplitude of ~0.1 Hz oscillations.
%   'channels'       - Channel numbers (default: 1:nChannels)
%                      Vector of channel identifiers. Length must match
%                      nChannels or will be truncated/padded.
%   'seed'           - Random seed for reproducibility (default: [])
%                      When set, produces identical output across calls.
%
% Outputs:
%   data - Processed fNIRS struct with fields:
%          .t0        - Reference time point [datetime]
%          .time      - Time vector [T x 1] in seconds
%          .fs        - Sampling frequency [scalar] in Hz
%          .fchMask   - Channel mask [1 x nChannels] all ones (good)
%          .markers   - Event markers [M x 3] from hrfOnsets if provided
%                       Format: [time, value, duration]
%          .info      - Metadata struct with generation parameters
%          .HbO       - Oxygenated hemoglobin [T x nChannels] in uM
%          .HbR       - Deoxygenated hemoglobin [T x nChannels] in uM
%          .HbTotal   - Total hemoglobin (HbO + HbR) [T x nChannels]
%          .HbDiff    - Differential hemoglobin (HbO - HbR) [T x nChannels]
%          .CBSI      - Correlation-based signal index [T x nChannels]
%          .channels  - Channel numbers [1 x nChannels]
%          .units     - Unit string 'uM' (micromolar)
%          .DPF_factor- Differential pathlength factor [scalar] = 5.93
%
% Algorithm:
%   1. Generate time vector based on duration and sampling frequency
%   2. Initialize HbO/HbR as zeros (baseline = 0)
%   3. If addHRF: convolve stimulus train with canonical double-gamma HRF
%   4. If addNoise: add independent Gaussian noise to each channel
%   5. If addDrift: add linear ramp to baseline
%   6. If addOscillations: add 0.1 Hz sinusoid (Mayer waves)
%   7. Compute derived biomarkers (HbTotal, HbDiff, CBSI)
%   8. Package into standard fNIRS struct format
%
% Example:
%   % Generate 60 seconds of baseline data with noise
%   data = pf2_base.tests.synthetic.generateHemoglobin();
%   plot(data.time, data.HbO(:,1));
%   xlabel('Time (s)'); ylabel('HbO (uM)');
%
%   % Generate data with HRF responses at 10, 30, 50 seconds
%   data = pf2_base.tests.synthetic.generateHemoglobin(...
%       'duration', 120, ...
%       'addHRF', true, ...
%       'hrfOnsets', [10, 30, 50], ...
%       'hrfAmplitude', 2);
%   plot(data.time, mean(data.HbO, 2));
%   title('Average HbO with HRF responses');
%
%   % Generate noisy data with drift and Mayer waves
%   data = pf2_base.tests.synthetic.generateHemoglobin(...
%       'addNoise', true, 'noiseLevel', 0.2, ...
%       'addDrift', true, 'driftSlope', 0.005, ...
%       'addOscillations', true);
%
%   % Reproducible generation with seed
%   data1 = pf2_base.tests.synthetic.generateHemoglobin('seed', 42);
%   data2 = pf2_base.tests.synthetic.generateHemoglobin('seed', 42);
%   assert(isequal(data1.HbO, data2.HbO), 'Should be identical');
%
% Notes:
%   - Output struct matches processFNIRS2 output format
%   - CBSI computed as (HbO - HbR) ./ sqrt(HbO.^2 + HbR.^2 + eps)
%   - Markers created with value=1 and duration=0 for each HRF onset
%   - All channels receive identical HRF but independent noise
%   - Default DPF_factor=5.93 matches typical fixed DPF value
%
% See also: pf2_base.fnirs.buildHRF, processFNIRS2, pf2.import.sampleData

    % Parse input arguments
    p = inputParser;
    p.FunctionName = 'generateHemoglobin';

    % Time parameters
    addParameter(p, 'duration', 60, @(x) isscalar(x) && x > 0);
    addParameter(p, 'fs', 10, @(x) isscalar(x) && x > 0);

    % Channel parameters
    addParameter(p, 'nChannels', 18, @(x) isscalar(x) && x > 0 && x == round(x));
    addParameter(p, 'channels', [], @(x) isnumeric(x) && isvector(x));

    % HRF parameters
    addParameter(p, 'addHRF', false, @(x) islogical(x) || x == 0 || x == 1);
    addParameter(p, 'hrfOnsets', [], @(x) isnumeric(x) && (isempty(x) || isvector(x)));
    addParameter(p, 'hrfAmplitude', 1, @(x) isscalar(x) && x > 0);
    addParameter(p, 'hbRatio', -0.3, @isscalar);

    % Noise parameters
    addParameter(p, 'addNoise', true, @(x) islogical(x) || x == 0 || x == 1);
    addParameter(p, 'noiseLevel', 0.1, @(x) isscalar(x) && x >= 0);

    % Drift parameters
    addParameter(p, 'addDrift', false, @(x) islogical(x) || x == 0 || x == 1);
    addParameter(p, 'driftSlope', 0.01, @isscalar);

    % Oscillation parameters (Mayer waves)
    addParameter(p, 'addOscillations', false, @(x) islogical(x) || x == 0 || x == 1);
    addParameter(p, 'oscillationAmp', 0.2, @(x) isscalar(x) && x >= 0);

    % Reproducibility
    addParameter(p, 'seed', [], @(x) isempty(x) || (isscalar(x) && x >= 0));

    parse(p, varargin{:});
    opts = p.Results;

    % Set random seed if provided
    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    % Generate time vector
    nSamples = round(opts.duration * opts.fs);
    time = (0:nSamples-1)' / opts.fs;

    % Handle channel numbers
    nChannels = opts.nChannels;
    if isempty(opts.channels)
        channels = 1:nChannels;
    else
        channels = opts.channels(:)';
        if length(channels) < nChannels
            % Pad with sequential numbers
            channels = [channels, (max(channels)+1):(max(channels)+nChannels-length(channels))];
        elseif length(channels) > nChannels
            channels = channels(1:nChannels);
        end
    end

    % Initialize hemoglobin signals as zeros
    HbO = zeros(nSamples, nChannels);
    HbR = zeros(nSamples, nChannels);

    % Add HRF responses if requested
    markers = [];
    if opts.addHRF && ~isempty(opts.hrfOnsets)
        % Generate canonical HRF
        hrf = generateCanonicalHRF(opts.fs);
        hrfLen = length(hrf);

        % Create stimulus train
        stimTrain = zeros(nSamples, 1);
        validOnsets = opts.hrfOnsets(opts.hrfOnsets >= 0 & opts.hrfOnsets < opts.duration);
        onsetSamples = round(validOnsets * opts.fs) + 1;
        onsetSamples = onsetSamples(onsetSamples <= nSamples);
        stimTrain(onsetSamples) = 1;

        % Convolve stimulus with HRF
        hrfResponse = conv(stimTrain, hrf);
        hrfResponse = hrfResponse(1:nSamples);  % Trim to original length

        % Scale by amplitude and apply to all channels
        HbO = HbO + opts.hrfAmplitude * repmat(hrfResponse, 1, nChannels);
        HbR = HbR + opts.hrfAmplitude * opts.hbRatio * repmat(hrfResponse, 1, nChannels);

        % Create markers from onsets
        if ~isempty(validOnsets)
            markers = [validOnsets(:), ones(length(validOnsets), 1), zeros(length(validOnsets), 1)];
        end
    end

    % Add Gaussian noise
    if opts.addNoise && opts.noiseLevel > 0
        HbO = HbO + opts.noiseLevel * randn(nSamples, nChannels);
        HbR = HbR + opts.noiseLevel * randn(nSamples, nChannels);
    end

    % Add baseline drift
    if opts.addDrift
        driftSignal = opts.driftSlope * time;
        HbO = HbO + repmat(driftSignal, 1, nChannels);
        HbR = HbR + repmat(driftSignal * opts.hbRatio, 1, nChannels);
    end

    % Add Mayer wave oscillations (~0.1 Hz)
    if opts.addOscillations && opts.oscillationAmp > 0
        mayerFreq = 0.1;  % Hz
        % Add random phase offset per channel for realism
        phases = 2 * pi * rand(1, nChannels);
        for ch = 1:nChannels
            oscillation = opts.oscillationAmp * sin(2 * pi * mayerFreq * time + phases(ch));
            HbO(:, ch) = HbO(:, ch) + oscillation;
            HbR(:, ch) = HbR(:, ch) + oscillation * opts.hbRatio;
        end
    end

    % Compute derived biomarkers
    HbTotal = HbO + HbR;
    HbDiff = HbO - HbR;

    % Compute CBSI (correlation-based signal improvement index)
    % Using normalized difference to avoid division issues
    denominator = sqrt(HbO.^2 + HbR.^2 + eps);
    CBSI = (HbO - HbR) ./ denominator;

    % Build output structure matching processFNIRS2 format
    data = struct();

    % Time information
    data.t0 = datetime('now');
    data.time = time;
    data.fs = opts.fs;

    % Channel information
    data.fchMask = ones(1, nChannels);
    data.channels = channels;

    % Markers
    if isempty(markers)
        data.markers = zeros(0, 3);  % Empty but proper size
    else
        data.markers = markers;
    end

    % Metadata
    data.info = struct();
    data.info.SubjectID = 'Synthetic';
    data.info.header = struct('filename', 'synthetic_data', 'format', 'synthetic');
    data.info.mrkheaders = struct();
    data.info.filename = 'synthetic_hemoglobin_data';
    data.info.baseline = struct('startTime', 0, 'length', 5);
    data.info.probename = 'SyntheticProbe';
    data.info.generationParams = opts;  % Store generation parameters

    % Hemoglobin data
    data.HbO = HbO;
    data.HbR = HbR;
    data.HbTotal = HbTotal;
    data.HbDiff = HbDiff;
    data.CBSI = CBSI;

    % Units and DPF
    data.units = 'uM';
    data.DPF_factor = 5.93;
end


function hrf = generateCanonicalHRF(fs)
% GENERATECANONICALHRF Generate canonical double-gamma hemodynamic response
%
% Creates a canonical HRF using the difference-of-gammas model commonly
% used in fMRI/fNIRS analysis. The HRF consists of a primary positive
% peak followed by a smaller undershoot.
%
% Reference:
%   Lindquist MA, Meng Loh J, Atlas LY, Wager TD. (2009).
%   Modeling the hemodynamic response function in fMRI.
%   DOI: 10.1016/j.neuroimage.2008.10.065
%
%   Parameters optimized for fNIRS based on:
%   Ye JC, Tak S, Jang KE, Jung J, Jang J. (2009).
%   NIRS-SPM: statistical parametric mapping for near-infrared spectroscopy.
%   Neuroimage, 44(2), 428-447.
%
% Inputs:
%   fs - Sampling frequency in Hz
%
% Outputs:
%   hrf - HRF vector [N x 1], normalized to peak = 1
%         Duration ~25-30 seconds, truncated at zero crossing
%
% Notes:
%   - Peak at approximately 5-6 seconds
%   - Undershoot trough at approximately 15-16 seconds
%   - Function returns to baseline around 25-30 seconds

    % HRF duration in seconds
    hrfDuration = 30;

    % Time vector
    t = (0:1/fs:hrfDuration)';

    % Double-gamma parameters (standard SPM/Lindquist values)
    % Primary response parameters
    alpha1 = 6;      % Shape parameter (determines time-to-peak)
    beta1 = 1;       % Rate parameter

    % Undershoot parameters
    alpha2 = 16;     % Shape parameter (determines undershoot timing)
    beta2 = 1;       % Rate parameter
    c = 1/6;         % Ratio of undershoot to main response

    % Compute double-gamma HRF
    % Primary response: gamma PDF
    gamma1 = (t.^(alpha1-1) .* beta1^alpha1 .* exp(-beta1.*t)) / gamma(alpha1);

    % Undershoot: gamma PDF
    gamma2 = (t.^(alpha2-1) .* beta2^alpha2 .* exp(-beta2.*t)) / gamma(alpha2);

    % Combine with undershoot subtraction
    hrf = gamma1 - c * gamma2;

    % Normalize to peak = 1
    hrf = hrf / max(hrf);

    % Truncate at first zero crossing after peak (keep only positive response + undershoot)
    peakIdx = find(hrf == max(hrf), 1);
    zeroCrossings = find(hrf(peakIdx:end) < 0, 1);

    if ~isempty(zeroCrossings)
        % Find where it returns to near-zero after undershoot
        undershootEnd = peakIdx + zeroCrossings - 1;
        postUndershoot = find(hrf(undershootEnd:end) > -0.01, 1);
        if ~isempty(postUndershoot)
            endIdx = undershootEnd + postUndershoot - 1;
            hrf = hrf(1:endIdx);
        end
    end
end
