classdef PhysioRegressTest < matlab.unittest.TestCase
    % PHYSIOREGRESSTEST Unit tests for pf2_base.fnirs.physioRegress
    %
    % Verifies adaptive cardiac regression: attenuation of a cardiac oscillation
    % at the measured heart rate (HR feature and PPG-derived), preservation of
    % the slow neural component, and the graceful no-op when no cardiac signal
    % is present.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.PhysioRegressTest');

    methods (Test)
        function testCardiacAttenuationFromHR(testCase)
            fs = 10;
            t = (0:1/fs:120)';
            n = numel(t);
            fCard = 1.1;                         % 66 bpm
            neural = sin(2*pi*0.05*t);
            cardiac = 0.8*sin(2*pi*fCard*t);
            d = makeHb(t, fs, neural + cardiac + 0.02*randn(n,1));

            % HR feature: constant 66 bpm
            d.Aux.heartRate.data = 66 + zeros(n,1);
            d.Aux.heartRate.time = t;
            d.Aux.heartRate.unit = 'bpm';
            d.Aux.heartRate.varNames = {'HR'};

            before = bandPowerAt(d.HbO(:,1), fs, fCard);
            out = pf2_base.fnirs.physioRegress(d, 'Biomarkers', {'HbO'});
            after = bandPowerAt(out.HbO(:,1), fs, fCard);

            testCase.verifyLessThan(after, 0.2*before, ...
                'Cardiac power at the measured HR should drop sharply');
            % Slow neural component preserved
            testCase.verifyGreaterThan(corr(out.HbO(:,1), neural), 0.95);
            testCase.verifyTrue(isfield(out, 'physioRegressInfo'));
            testCase.verifyEqual(out.physioRegressInfo.meanFreqHz, fCard, 'AbsTol', 0.05);
        end

        function testCardiacAttenuationFromPPG(testCase)
            rng(21);
            fs = 10;
            t = (0:1/fs:120)';
            n = numel(t);
            fCard = 1.2;                         % 72 bpm
            neural = sin(2*pi*0.05*t);
            cardiac = 0.8*sin(2*pi*fCard*t);
            d = makeHb(t, fs, neural + cardiac + 0.02*randn(n,1));

            % PPG waveform at the same rate
            d.Aux.ppg.data = sin(2*pi*fCard*t);
            d.Aux.ppg.time = t;
            d.Aux.ppg.unit = 'a.u.';
            d.Aux.ppg.varNames = {'PPG'};

            before = bandPowerAt(d.HbO(:,1), fs, fCard);
            out = pf2_base.fnirs.physioRegress(d, 'Biomarkers', {'HbO'});
            after = bandPowerAt(out.HbO(:,1), fs, fCard);

            testCase.verifyLessThan(after, 0.5*before, ...
                'PPG-derived cardiac regression should reduce cardiac power');
        end

        function testNoOpWithoutCardiacSignal(testCase)
            fs = 10;
            t = (0:1/fs:60)';
            d = makeHb(t, fs, sin(2*pi*0.05*t) + 0.01*randn(numel(t),1));
            % no Aux at all
            before = d.HbO;
            warnState = warning('off', 'pf2:physioRegress:noSignal');
            cleanup = onCleanup(@() warning(warnState));
            out = pf2_base.fnirs.physioRegress(d);
            testCase.verifyEqual(out.HbO, before, ...
                'Without a cardiac signal, the data should be unchanged');
            testCase.verifyFalse(isfield(out, 'physioRegressInfo'));
        end
    end
end

function d = makeHb(t, fs, hboCh1)
% MAKEHB Minimal processed fNIRS struct with one informative HbO channel
n = numel(t);
d.time = t(:);
d.fs = fs;
d.HbO = [hboCh1(:), 0.3*hboCh1(:) + 0.01*randn(n,1)];
d.HbR = -0.4 * d.HbO;
end

function P = bandPowerAt(x, fs, f0)
% BANDPOWERAT Magnitude of the DFT bin nearest f0
x = x - mean(x);
N = numel(x);
X = abs(fft(x));
freqs = (0:N-1)' * (fs / N);
[~, idx] = min(abs(freqs - f0));
P = X(idx);
end
