classdef NewMethodsTest < matlab.unittest.TestCase
% NEWMETHODSTEST Unit tests for Butterworth IIR, Spline MC, SCI Rejection, SC PCA
%
% Tests the four new processing functions added from FRESH study analysis:
%   1. pf2_bpf_iir     - Butterworth IIR bandpass filter
%   2. pf2_MotionCorrectSpline - Spline motion artifact correction
%   3. pf2_SCIRejection - SCI-based channel rejection
%   4. pf2_base.fnirs.extractShortChannelPCs - Short-channel PCA extraction

    properties (TestParameter)
        FilterMode = {'bandpass', 'lowpass', 'highpass'}
    end

    methods (Test)

        %% ============================================================
        %% Butterworth IIR Filter Tests
        %% ============================================================

        function testIIR_BandpassBasic(testCase)
            % Basic bandpass filtering preserves signal in passband
            fs = 10;
            t = (0:1/fs:60)';
            % Signal at 0.1 Hz (in band) + 3 Hz (out of band)
            signal = sin(2*pi*0.1*t) + sin(2*pi*3*t);

            filtered = pf2_bpf_iir(signal, fs, 0.05, 0.5);

            % Out-of-band component (3 Hz) should be attenuated
            testCase.verifyEqual(size(filtered), size(signal));
            % Power at 0.1 Hz should be preserved, power at 3 Hz attenuated
            testCase.verifyGreaterThan(std(filtered), 0.3);
        end

        function testIIR_LowpassOnly(testCase)
            % Lowpass mode (lowF = 0)
            fs = 10;
            t = (0:1/fs:60)';
            signal = sin(2*pi*0.1*t) + sin(2*pi*3*t);

            filtered = pf2_bpf_iir(signal, fs, 0, 0.5);

            testCase.verifyEqual(size(filtered), size(signal));
            % Should not be all zeros
            testCase.verifyGreaterThan(std(filtered), 0.1);
        end

        function testIIR_HighpassOnly(testCase)
            % Highpass mode (highF = 0)
            fs = 10;
            t = (0:1/fs:60)';
            % Low freq drift + higher freq signal
            signal = 5*sin(2*pi*0.005*t) + sin(2*pi*0.5*t);

            filtered = pf2_bpf_iir(signal, fs, 0.01, 0);

            testCase.verifyEqual(size(filtered), size(signal));
            % Drift should be removed, so amplitude should be lower
            testCase.verifyLessThan(max(abs(filtered)), max(abs(signal)));
        end

        function testIIR_MultiChannel(testCase)
            % Multichannel data filtered correctly
            fs = 10;
            t = (0:1/fs:60)';
            nCh = 5;
            data = repmat(sin(2*pi*0.2*t), 1, nCh) + randn(length(t), nCh)*0.1;

            filtered = pf2_bpf_iir(data, fs, 0.05, 0.5, 4);

            testCase.verifyEqual(size(filtered), [length(t), nCh]);
        end

        function testIIR_RowVector(testCase)
            % Row vector input is handled correctly
            fs = 10;
            t = (0:1/fs:30);
            signal = sin(2*pi*0.2*t);

            filtered = pf2_bpf_iir(signal, fs, 0.05, 0.5);

            testCase.verifyEqual(size(filtered, 1), 1);
            testCase.verifyEqual(size(filtered, 2), length(t));
        end

        function testIIR_FilterOrders(testCase)
            % Different filter orders work without error
            fs = 10;
            t = (0:1/fs:60)';
            signal = sin(2*pi*0.2*t);

            for order = [2, 3, 4, 5]
                filtered = pf2_bpf_iir(signal, fs, 0.05, 0.5, order);
                testCase.verifyEqual(size(filtered), size(signal));
            end
        end

        function testIIR_RestoreMean(testCase)
            % restoreMean option preserves DC component
            fs = 10;
            t = (0:1/fs:60)';
            offset = 100;
            signal = offset + sin(2*pi*0.2*t);

            filteredNoMean = pf2_bpf_iir(signal, fs, 0.05, 0.5, 4, false);
            filteredWithMean = pf2_bpf_iir(signal, fs, 0.05, 0.5, 4, true);

            testCase.verifyLessThan(abs(mean(filteredNoMean)), 10);
            testCase.verifyGreaterThan(mean(filteredWithMean), 50);
        end

        function testIIR_ShortDataWarning(testCase)
            % Very short data produces warning and NaN output
            fs = 10;
            signal = [1; 2; 3];  % Only 3 samples

            testCase.verifyWarning(@() pf2_bpf_iir(signal, fs, 0.05, 0.5), ...
                'pf2:bpf_iir:tooShort');
        end

        %% ============================================================
        %% Spline Motion Correction Tests
        %% ============================================================

        function testSpline_BasicCorrection(testCase)
            % Spline correction reduces motion artifact amplitude
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addMotion', true, 'motionTimes', [15, 35], ...
                'motionAmplitude', 0.3, 'noiseLevel', 0.001, 'seed', 42);

            % Convert to OD
            od = -log(data.raw ./ mean(data.raw, 1));

            corrected = pf2_MotionCorrectSpline(od, data.fs);

            testCase.verifyEqual(size(corrected), size(od));
            % Corrected should have less extreme values
            testCase.verifyLessThanOrEqual(max(abs(corrected(:))), ...
                max(abs(od(:))) * 1.1);
        end

        function testSpline_NoArtifactPassthrough(testCase)
            % Clean signal passes through unchanged
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 30, 'fs', 10, 'nChannels', 2, ...
                'noiseLevel', 0.001, 'seed', 1);

            od = -log(data.raw ./ mean(data.raw, 1));

            corrected = pf2_MotionCorrectSpline(od, data.fs, 0.99, 0.5, 1, 20, 1.0);

            % With high thresholds and clean data, no correction should be applied
            maxDiff = max(abs(corrected(:) - od(:)));
            testCase.verifyLessThan(maxDiff, 1e-10);
        end

        function testSpline_OutputSize(testCase)
            % Output has same size as input
            nSamples = 500;
            nCh = 8;
            od = randn(nSamples, nCh) * 0.01;
            fs = 10;

            corrected = pf2_MotionCorrectSpline(od, fs);

            testCase.verifyEqual(size(corrected), [nSamples, nCh]);
        end

        function testSpline_CustomParams(testCase)
            % Custom parameters are accepted without error
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 30, 'fs', 10, 'nChannels', 2, ...
                'addMotion', true, 'motionTimes', [10], ...
                'motionAmplitude', 0.2, 'seed', 5);

            od = -log(data.raw ./ mean(data.raw, 1));

            % Various parameter combos
            c1 = pf2_MotionCorrectSpline(od, data.fs, 0.95);
            c2 = pf2_MotionCorrectSpline(od, data.fs, 0.99, 1.0, 2.0, 5, 0.3);

            testCase.verifyEqual(size(c1), size(od));
            testCase.verifyEqual(size(c2), size(od));
        end

        function testSpline_PreservesSignalShape(testCase)
            % Correction preserves general signal trend outside artifact region
            fs = 10;
            T = 600;
            t = (0:T-1)'/fs;
            % Slow signal + artifact spike at t=20-21s
            signal = 0.01 * sin(2*pi*0.05*t);
            signal(200:210) = signal(200:210) + 0.5;  % Big spike

            corrected = pf2_MotionCorrectSpline(signal, fs, 0.99, 0.5, 1, 10, 0.3);

            % Signal far from artifact should be similar
            testCase.verifyLessThan(max(abs(corrected(1:150) - signal(1:150))), 0.01);
        end

        %% ============================================================
        %% SCI Rejection Tests
        %% ============================================================

        function testSCI_BasicRejection(testCase)
            % SCI rejection returns correct-sized mask
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 30, 'fs', 10, 'nChannels', 6, ...
                'addHeartbeat', true, 'seed', 42);

            fMask = pf2_SCIRejection(data);

            testCase.verifyEqual(numel(fMask), 6);
            testCase.verifyTrue(islogical(fMask));
        end

        function testSCI_GoodChannelsDetected(testCase)
            % Data with heartbeat should have good SCI channels
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'heartAmplitude', 0.02, ...
                'noiseLevel', 0.001, 'seed', 10);

            fMask = pf2_SCIRejection(data, 0.5);

            % With strong heartbeat, at least some channels should pass
            testCase.verifyGreaterThan(sum(fMask), 0);
        end

        function testSCI_CustomThreshold(testCase)
            % Stricter threshold rejects more channels
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 60, 'fs', 10, 'nChannels', 8, ...
                'addHeartbeat', true, 'heartAmplitude', 0.01, ...
                'noiseLevel', 0.005, 'seed', 7);

            fMaskLoose = pf2_SCIRejection(data, 0.3);
            fMaskStrict = pf2_SCIRejection(data, 0.9);

            % Stricter threshold should keep fewer or equal channels
            testCase.verifyGreaterThanOrEqual(sum(fMaskLoose), sum(fMaskStrict));
        end

        function testSCI_RequiresRaw(testCase)
            % Error when no .raw field
            noRaw = struct('fs', 10, 'HbO', randn(100, 5));

            testCase.verifyError(@() pf2_SCIRejection(noRaw), ...
                'pf2:SCIRejection:noRaw');
        end

        function testSCI_CustomCardiacBand(testCase)
            % Custom cardiac band is accepted
            data = pf2_base.tests.synthetic.generateFNIRS(...
                'duration', 30, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'seed', 42);

            fMask = pf2_SCIRejection(data, 0.75, [0.8, 2.0]);

            testCase.verifyEqual(numel(fMask), 4);
            testCase.verifyTrue(islogical(fMask));
        end

        %% ============================================================
        %% Short-Channel PCA Extraction Tests
        %% ============================================================

        function testSCPCA_BasicExtraction(testCase)
            % Extract PCs from short channels
            fNIR = createMockDataWithShortChannels(100, 10, 4);

            [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR);

            testCase.verifyEqual(size(pcMatrix, 1), 100);
            testCase.verifyEqual(size(pcMatrix, 2), 2);  % Default NumPCs=2
            testCase.verifyEqual(pcInfo.numPCs, 2);
        end

        function testSCPCA_VarianceExplained(testCase)
            % Variance explained sums to <= 1
            fNIR = createMockDataWithShortChannels(200, 10, 4);

            [~, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR, 'NumPCs', 4);

            testCase.verifyLessThanOrEqual(sum(pcInfo.varianceExplained), 1.001);
            testCase.verifyGreaterThan(pcInfo.varianceExplained(1), 0);
        end

        function testSCPCA_CustomNumPCs(testCase)
            % Custom number of PCs
            fNIR = createMockDataWithShortChannels(100, 10, 4);

            [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR, 'NumPCs', 3);

            testCase.verifyEqual(size(pcMatrix, 2), 3);
            testCase.verifyEqual(pcInfo.numPCs, 3);
        end

        function testSCPCA_CapsAtNumShort(testCase)
            % NumPCs capped at number of short channels
            fNIR = createMockDataWithShortChannels(100, 10, 2);

            [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR, 'NumPCs', 10);

            testCase.verifyEqual(size(pcMatrix, 2), 2);
            testCase.verifyEqual(pcInfo.numPCs, 2);
        end

        function testSCPCA_HbRBiomarker(testCase)
            % Works with HbR biomarker
            fNIR = createMockDataWithShortChannels(100, 10, 3);

            [pcMatrix, pcInfo] = pf2_base.fnirs.extractShortChannelPCs(fNIR, ...
                'Biomarker', 'HbR', 'NumPCs', 2);

            testCase.verifyEqual(size(pcMatrix, 1), 100);
            testCase.verifyEqual(pcInfo.biomarker, 'HbR');
        end

        function testSCPCA_ErrorNoShortChannels(testCase)
            % Error when no short channels exist
            fNIR = struct();
            fNIR.HbO = randn(100, 10);
            fNIR.probeinfo.Probe = {struct('IsShortSeparation', false(1, 10))};

            testCase.verifyError(...
                @() pf2_base.fnirs.extractShortChannelPCs(fNIR), ...
                'pf2:extractShortChannelPCs:noShort');
        end

        function testSCPCA_IntegrationWithDesignMatrix(testCase)
            % PCs can be fed directly to buildDesignMatrix
            fNIR = createMockDataWithShortChannels(200, 10, 4);
            fNIR.time = (0:199)'/10;
            fNIR.fs = 10;

            [pcMatrix, ~] = pf2_base.fnirs.extractShortChannelPCs(fNIR, 'NumPCs', 2);

            events = struct('name', 'task', 'onsets', [2, 8, 14], 'duration', 3);
            [X, names] = pf2_base.fnirs.buildDesignMatrix(fNIR.time, fNIR.fs, events, ...
                'ShortChannels', pcMatrix);

            % Should have: task + constant + 3 drift + 2 short channel PCs = 7
            testCase.verifyEqual(size(X, 2), 7);
            testCase.verifyTrue(any(contains(names, 'short')));
        end

    end
end


%% Helper functions

function fNIR = createMockDataWithShortChannels(T, nLong, nShort)
% Create mock processed data with short-separation channels

nTotal = nLong + nShort;

% Short channels share a common systemic signal
systemic = sin(2*pi*0.1*(0:T-1)'/10) + 0.5*sin(2*pi*0.25*(0:T-1)'/10);

% Long channels: brain signal + systemic + noise
HbO = randn(T, nTotal) * 0.01;
HbR = randn(T, nTotal) * 0.005;

% Add systemic to all channels
for ch = 1:nTotal
    HbO(:, ch) = HbO(:, ch) + systemic * (0.8 + 0.4*rand);
    HbR(:, ch) = HbR(:, ch) + systemic * 0.5 * (0.8 + 0.4*rand);
end

% Add brain signal to long channels only
brainSignal = zeros(T, 1);
brainSignal(50:70) = 0.1;  % Simple activation
for ch = 1:nLong
    HbO(:, ch) = HbO(:, ch) + brainSignal * (0.5 + rand);
end

fNIR = struct();
fNIR.HbO = HbO;
fNIR.HbR = HbR;

% Mark last nShort channels as short-separation
isShort = false(1, nTotal);
isShort(nLong+1:end) = true;

% Create 3D positions (short channels near long channels)
pos3D = zeros(nTotal, 3);
for ch = 1:nLong
    pos3D(ch, :) = [randn*20, randn*20, randn*5];
end
for ch = 1:nShort
    % Place near a random long channel
    nearCh = randi(nLong);
    pos3D(nLong+ch, :) = pos3D(nearCh, :) + randn(1,3)*2;
end

fNIR.probeinfo.Probe = {struct(...
    'IsShortSeparation', isShort, ...
    'OptPos3D', pos3D)};

end
