classdef AuxFeaturesTest < matlab.unittest.TestCase
    % AUXFEATURESTEST Unit tests for the type-aware Aux feature extractors
    %
    % Covers pf2.data.aux.heartRateFrom, edaDecompose, accelFeatures, and
    % eegBandPower on synthetic signals with known ground truth.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AuxFeaturesTest');

    methods (Test)
        function testHeartRateFromPPG(testCase)
            fs = 100;
            t = (0:1/fs:60)';
            bpmTrue = 72;                       % 1.2 Hz
            ppg = sin(2*pi*(bpmTrue/60)*t) + 0.05*randn(size(t));
            [hr, info] = pf2.data.aux.heartRateFrom(ppg, fs);
            testCase.verifyEqual(numel(hr), numel(t));
            testCase.verifyFalse(any(isnan(hr)), 'HR series should be NaN-free');
            testCase.verifyEqual(info.meanBPM, bpmTrue, 'AbsTol', 4, ...
                'Recovered mean bpm should match the synthetic rate');
        end

        function testHeartRateFromEKGLike(testCase)
            fs = 250;
            t = (0:1/fs:40)';
            bpmTrue = 90;                       % 1.5 Hz
            % Peaky EKG-like waveform: fundamental + harmonics
            f0 = bpmTrue/60;
            ekg = sin(2*pi*f0*t) + 0.5*sin(2*pi*2*f0*t) + 0.3*sin(2*pi*3*f0*t);
            info = struct();
            [~, info] = pf2.data.aux.heartRateFrom(ekg, fs, 'Band', [0.5 10]);
            testCase.verifyEqual(info.meanBPM, bpmTrue, 'AbsTol', 5);
        end

        function testEdaDecompose(testCase)
            fs = 10;
            t = (0:1/fs:120)';
            tonicTrue = 2 + 0.01*t;             % slow ramp
            phasicTrue = exp(-((t-60).^2)/(2*2^2));   % 2 s-wide bump at 60 s
            x = tonicTrue + phasicTrue;
            [tonic, phasic, info] = pf2.data.aux.edaDecompose(x, fs);
            % Tonic tracks the ramp
            testCase.verifyGreaterThan(corr(tonic, tonicTrue), 0.95);
            % Phasic captures the bump near t = 60 s
            [pk, idx] = max(phasic);
            testCase.verifyGreaterThan(pk, 0.5);
            testCase.verifyEqual(t(idx), 60, 'AbsTol', 2);
            testCase.verifyGreaterThan(info.phasicStd, 0);
        end

        function testAccelFeatures(testCase)
            fs = 50;
            N = 200;
            x = [zeros(N,2), ones(N,1)];        % 1 g resting on z
            x(50:60, 1) = 0.5;                  % brief lateral motion
            [feat, info] = pf2.data.aux.accelFeatures(x, fs);
            testCase.verifyEqual(info.gravity, 1, 'AbsTol', 1e-9);
            % Resting baseline near zero after gravity removal
            testCase.verifyLessThan(abs(median(feat.norm)), 1e-6);
            % Motion shows as a positive deflection
            expectedBump = sqrt(0.25 + 1) - 1;  % ~0.118
            testCase.verifyEqual(max(feat.norm), expectedBump, 'AbsTol', 1e-6);
            % Jerk has the same length and reacts at the transitions
            testCase.verifyEqual(numel(feat.jerk), N);
            testCase.verifyGreaterThan(max(feat.jerk), 0);
        end

        function testEegBandPowerAlphaDominant(testCase)
            fs = 256;
            t = (0:1/fs:20)';
            x = sin(2*pi*10*t);                 % 10 Hz -> alpha band
            [bp, info] = pf2.data.aux.eegBandPower(x, fs);
            testCase.verifyEqual(info.channels, 1);
            mAlpha = mean(bp.alpha);
            mBeta  = mean(bp.beta);
            mTheta = mean(bp.theta);
            mDelta = mean(bp.delta);
            mGamma = mean(bp.gamma);
            testCase.verifyGreaterThan(mAlpha, mBeta);
            testCase.verifyGreaterThan(mAlpha, mTheta);
            testCase.verifyGreaterThan(mAlpha, mDelta);
            testCase.verifyGreaterThan(mAlpha, mGamma);
        end

        function testRespFeatures(testCase)
            rng(41);
            fs = 10;
            t = (0:1/fs:120)';
            rateTrue = 15;                       % 15 breaths/min = 0.25 Hz
            resp = sin(2*pi*(rateTrue/60)*t) + 0.05*randn(size(t));
            [feat, info] = pf2.data.aux.respFeatures(resp, fs);
            testCase.verifyEqual(numel(feat.rate), numel(t));
            testCase.verifyFalse(any(isnan(feat.rate)), 'rate should be NaN-free');
            testCase.verifyFalse(any(isnan(feat.rvt)), 'rvt should be NaN-free');
            testCase.verifyEqual(info.meanRate, rateTrue, 'AbsTol', 2);
            testCase.verifyGreaterThan(mean(feat.rvt), 0);
            % Breath count: 120 s at 0.25 Hz -> ~30 breaths
            testCase.verifyEqual(info.nBreaths, 30, 'AbsTol', 2);
            % Steady breathing -> near-constant RVT in the interior
            interior = feat.rvt(300:900);
            testCase.verifyLessThan(std(interior) / mean(interior), 0.25);
        end

        function testHrvFromBeats(testCase)
            % 'beats' input should reproduce the closed-form 'ibi' metrics
            nn = 800 + 60 * (-1).^(1:40)';       % ms
            beats = cumsum([0; nn / 1000]);      % seconds
            hrv = pf2.data.aux.hrvFeatures(beats, [], 'Input', 'beats');
            testCase.verifyEqual(hrv.RMSSD, 120, 'AbsTol', 1);
            testCase.verifyEqual(hrv.SDNN, 60, 'AbsTol', 2);
            testCase.verifyEqual(hrv.pNN50, 100, 'AbsTol', 1e-9);
        end

        function testHrvFromIBI(testCase)
            % Alternating NN intervals: closed-form SDNN/RMSSD/pNN50
            nn = 800 + 60 * (-1).^(1:40)';       % 740/860 ms, |diff|=120
            hrv = pf2.data.aux.hrvFeatures(nn, [], 'Input', 'ibi', 'IBIUnit', 'ms');
            testCase.verifyEqual(hrv.meanNN, 800, 'AbsTol', 1);
            testCase.verifyEqual(hrv.meanHR, 75, 'AbsTol', 0.5);
            testCase.verifyEqual(hrv.RMSSD, 120, 'AbsTol', 1);
            testCase.verifyEqual(hrv.SDNN, 60, 'AbsTol', 2);
            testCase.verifyEqual(hrv.pNN50, 100, 'AbsTol', 1e-9);
        end

        function testHrvConstantFromPPG(testCase)
            rng(42);
            fs = 100;
            t = (0:1/fs:60)';
            ppg = sin(2*pi*1.2*t) + 0.02*randn(size(t));   % steady 72 bpm
            hrv = pf2.data.aux.hrvFeatures(ppg, fs);
            testCase.verifyEqual(hrv.meanHR, 72, 'AbsTol', 3);
            testCase.verifyLessThan(hrv.SDNN, 25, 'Steady rate -> low SDNN');
        end

        function testHrvFrequencyDomain(testCase)
            % NN tachogram modulated at 0.25 Hz -> power in HF band, not LF
            k = (1:200)';
            tBeat = k * 0.8;                     % ~75 bpm
            nn = 800 + 40 * sin(2*pi*0.25*tBeat);
            hrv = pf2.data.aux.hrvFeatures(nn, [], 'Input', 'ibi');
            testCase.verifyGreaterThan(hrv.HF, hrv.LF, ...
                '0.25 Hz NN modulation should load the HF band');
            testCase.verifyLessThan(hrv.LFHF, 1);
        end

        function testEegBandPowerMultichannel(testCase)
            fs = 256;
            t = (0:1/fs:10)';
            x = [sin(2*pi*10*t), sin(2*pi*20*t)];   % alpha, beta
            bp = pf2.data.aux.eegBandPower(x, fs);
            testCase.verifyEqual(size(bp.alpha), [numel(t) 2]);
            % Channel 1 alpha-dominant, channel 2 beta-dominant
            testCase.verifyGreaterThan(mean(bp.alpha(:,1)), mean(bp.beta(:,1)));
            testCase.verifyGreaterThan(mean(bp.beta(:,2)), mean(bp.alpha(:,2)));
        end
    end
end
