classdef SSRTest < matlab.unittest.TestCase
    % SSRTEST Unit tests for short-channel regression
    %
    %   Tests verify that shortChannelRegression correctly removes
    %   superficial signals while preserving brain signals, and that
    %   all three methods (nearest, pca, all) function correctly.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.SSRTest');
    %       disp(results);
    %
    %   See also: pf2_base.fnirs.shortChannelRegression, pf2_SSR

    properties
        testData  % Synthetic fNIRS struct with short channels
    end

    methods (TestClassSetup)
        function addFunctionsPath(~)
            % Ensure functions/ directory is on path for pf2_SSR wrapper
            projRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            funcDir = fullfile(projRoot, 'functions');
            if isfolder(funcDir)
                addpath(funcDir);
            end
        end

        function buildSyntheticData(testCase)
            % Create synthetic data with known brain and superficial signals
            rng(42);

            T = 1000;
            fs = 10;
            nLong = 8;
            nShort = 2;
            nOpt = nLong + nShort;

            time = (0:T-1)' / fs;

            % Superficial physiology (cardiac + respiration)
            superficial = 0.5 * sin(2*pi*1.0*time) + 0.3 * sin(2*pi*0.25*time);

            % Brain signal (task-related HRF response in channels 1-4)
            brain = zeros(T, nLong);
            hrf = pf2_base.fnirs.buildHRF(fs);
            hrfVec = hrf(:, 2);
            stim = zeros(T, 1);
            stim(round([10 30 50 70] * fs)) = 1;
            hrfResponse = conv(stim, hrfVec);
            hrfResponse = hrfResponse(1:T);
            brain(:, 1:4) = repmat(2 * hrfResponse, 1, 4);

            % Build HbO: brain + superficial + noise
            HbO = zeros(T, nOpt);
            for ch = 1:nLong
                HbO(:, ch) = brain(:, ch) + superficial + 0.1*randn(T, 1);
            end
            % Short channels: only superficial + noise
            for ch = 1:nShort
                HbO(:, nLong + ch) = superficial + 0.05*randn(T, 1);
            end

            HbR = -0.3 * HbO + 0.05*randn(T, nOpt);

            % Build probe info with short-channel flags
            probeInfo = struct();
            probeInfo.Probe = cell(1, 1);

            isShort = false(1, nOpt);
            isShort(nLong+1:end) = true;
            probeInfo.Probe{1}.IsShortSeparation = isShort;
            probeInfo.Probe{1}.NumOptodes = nOpt;

            % 3D positions: long channels spread out, short channels near
            optX = [(1:nLong)*30, 15 75]';
            optY = [zeros(1, nLong), 5 5]';
            optZ = zeros(nOpt, 1);
            probeInfo.Probe{1}.OptPosX = optX;
            probeInfo.Probe{1}.OptPosY = optY;
            probeInfo.Probe{1}.OptPosZ = optZ;
            probeInfo.Probe{1}.OptPos3D = [optX, optY, optZ];

            data = struct();
            data.HbO = HbO;
            data.HbR = HbR;
            data.time = time;
            data.fs = fs;
            data.probeinfo = probeInfo;

            % Store brain signal for verification
            data.testBrain = brain;
            data.testSuperficial = superficial;

            testCase.testData = data;
        end
    end

    %% Nearest method tests
    methods (Test)

        function testNearestReducesSuperficial(testCase)
            % SSR with nearest method should reduce superficial component
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

            % Correlation between corrected signal and superficial should decrease
            longIdx = find(~data.probeinfo.Probe{1}.IsShortSeparation);
            origCorr = abs(corr(data.HbO(:, longIdx(1)), data.testSuperficial));
            corrCorr = abs(corr(corrected.HbO(:, longIdx(1)), data.testSuperficial));

            testCase.verifyLessThan(corrCorr, origCorr, ...
                'Correlation with superficial signal should decrease after SSR');
        end

        function testNearestPreservesBrain(testCase)
            % Brain signal should be largely preserved after SSR
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

            % Channel 1 has brain signal - correlation should remain high
            longIdx = find(~data.probeinfo.Probe{1}.IsShortSeparation);
            brainCorr = corr(corrected.HbO(:, longIdx(1)), data.testBrain(:, 1));

            testCase.verifyGreaterThan(brainCorr, 0.5, ...
                'Brain signal correlation should remain substantial after SSR');
        end

        function testNearestShortChannelsUnchanged(testCase)
            % Short channel data should not be modified
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

            shortIdx = find(data.probeinfo.Probe{1}.IsShortSeparation);
            testCase.verifyEqual(corrected.HbO(:, shortIdx), data.HbO(:, shortIdx), ...
                'Short channel data should be unchanged');
        end

        function testNearestSSRInfoField(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

            testCase.verifyTrue(isfield(corrected, 'ssrInfo'));
            testCase.verifyEqual(corrected.ssrInfo.method, 'nearest');
        end

    end

    %% PCA method tests
    methods (Test)

        function testPCAReducesSuperficial(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'pca');

            longIdx = find(~data.probeinfo.Probe{1}.IsShortSeparation);
            origCorr = abs(corr(data.HbO(:, longIdx(1)), data.testSuperficial));
            corrCorr = abs(corr(corrected.HbO(:, longIdx(1)), data.testSuperficial));

            testCase.verifyLessThan(corrCorr, origCorr, ...
                'PCA method should reduce superficial correlation');
        end

        function testPCANumPCs(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, ...
                'Method', 'pca', 'NumPCs', 2);

            testCase.verifyTrue(isfield(corrected, 'ssrInfo'));
            testCase.verifyEqual(corrected.ssrInfo.numPCs, 2);
        end

    end

    %% All method tests
    methods (Test)

        function testAllReducesSuperficial(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'all');

            longIdx = find(~data.probeinfo.Probe{1}.IsShortSeparation);
            origCorr = abs(corr(data.HbO(:, longIdx(1)), data.testSuperficial));
            corrCorr = abs(corr(corrected.HbO(:, longIdx(1)), data.testSuperficial));

            testCase.verifyLessThan(corrCorr, origCorr, ...
                'All method should reduce superficial correlation');
        end

    end

    %% Edge case tests
    methods (Test)

        function testNoShortChannelsWarning(testCase)
            % Should warn when no short channels present
            data = testCase.testData;
            data.probeinfo.Probe{1}.IsShortSeparation = false(1, ...
                data.probeinfo.Probe{1}.NumOptodes);

            testCase.verifyWarning(@() pf2_base.fnirs.shortChannelRegression(data), ...
                'pf2:ssr:noShortChannels');
        end

        function testNoProbeInfoWarning(testCase)
            % Should warn when no probe info present
            data = struct('HbO', randn(100, 5), 'HbR', randn(100, 5));

            testCase.verifyWarning(@() pf2_base.fnirs.shortChannelRegression(data), ...
                'pf2:ssr:noProbe');
        end

        function testHbRAlsoCorrected(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, 'Method', 'nearest');

            % HbR should also be modified
            longIdx = find(~data.probeinfo.Probe{1}.IsShortSeparation);
            testCase.verifyFalse(isequal(corrected.HbR(:, longIdx), data.HbR(:, longIdx)), ...
                'HbR should also be corrected');
        end

        function testCustomBiomarkers(testCase)
            data = testCase.testData;
            corrected = pf2_base.fnirs.shortChannelRegression(data, ...
                'Method', 'nearest', 'Biomarkers', {'HbO'});

            % HbR should be unchanged when not in Biomarkers list
            testCase.verifyEqual(corrected.HbR, data.HbR, ...
                'HbR should be unchanged when not specified in Biomarkers');
        end

        function testPf2SSRWrapper(testCase)
            % Test the method-chain wrapper
            data = testCase.testData;
            corrected = pf2_SSR(data, 'nearest');

            testCase.verifyTrue(isfield(corrected, 'ssrInfo'));
            testCase.verifyEqual(corrected.ssrInfo.method, 'nearest');
        end

    end

end
