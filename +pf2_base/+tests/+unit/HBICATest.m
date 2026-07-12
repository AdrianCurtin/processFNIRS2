classdef HBICATest < matlab.unittest.TestCase
    % HBICATEST Unit tests for HB-ICA hyperscanning analysis
    %
    %   Tests cover:
    %     - Basic decomposition output fields
    %     - Inter-brain detection with shared signals
    %     - Intra-brain detection with independent signals
    %     - Dual regression dimensions
    %     - Biomarker switching
    %     - TimeWindow / Channels subsetting
    %     - Coupling adapter interface
    %     - Dispatch registration
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.HBICATest');
    %       disp(results);

    properties
        fs
        T
        nChannels
        dataA
        dataB
    end

    methods (TestClassSetup)
        function setupData(testCase)
            rng(100);
            testCase.fs = 10;
            testCase.T = 500;
            testCase.nChannels = 8;

            T = testCase.T;
            nCh = testCase.nChannels;
            fs = testCase.fs;

            % Create two synthetic processed fNIRS structs
            testCase.dataA = makeSyntheticData(T, nCh, fs);
            testCase.dataB = makeSyntheticData(T, nCh, fs);
        end
    end

    methods (Test)

        function testBasicDecomposition(testCase)
            % Verify all expected output fields are present
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB);

            testCase.verifyTrue(isfield(result, 'sources'));
            testCase.verifyTrue(isfield(result, 'mixingMatrix'));
            testCase.verifyTrue(isfield(result, 'unmixingMatrix'));
            testCase.verifyTrue(isfield(result, 'sourcesA'));
            testCase.verifyTrue(isfield(result, 'sourcesB'));
            testCase.verifyTrue(isfield(result, 'mixingA'));
            testCase.verifyTrue(isfield(result, 'mixingB'));
            testCase.verifyTrue(isfield(result, 'GOF'));
            testCase.verifyTrue(isfield(result, 'GOF_A'));
            testCase.verifyTrue(isfield(result, 'GOF_B'));
            testCase.verifyTrue(isfield(result, 'isInterBrain'));
            testCase.verifyTrue(isfield(result, 'interBrainIdx'));
            testCase.verifyTrue(isfield(result, 'channelsA'));
            testCase.verifyTrue(isfield(result, 'channelsB'));
            testCase.verifyTrue(isfield(result, 'biomarker'));
            testCase.verifyTrue(isfield(result, 'method'));
            testCase.verifyTrue(isfield(result, 'nComponents'));
            testCase.verifyTrue(isfield(result, 'fs'));
            testCase.verifyEqual(result.method, 'hbica');
            testCase.verifyEqual(result.biomarker, 'HbO');
            testCase.verifyGreaterThan(result.nComponents, 0);
        end

        function testInterBrainDetection(testCase)
            % Inject a strong shared signal into both subjects
            % At least one component should be classified inter-brain
            rng(101);
            T = testCase.T;
            nCh = testCase.nChannels;
            fs = testCase.fs;

            shared = sin(2*pi*0.3*(0:T-1)'/fs);

            dA = makeSyntheticData(T, nCh, fs);
            dB = makeSyntheticData(T, nCh, fs);

            % Add strong shared signal with varying weights to all channels
            for c = 1:nCh
                w = 3 + randn * 0.2;  % Similar weights across channels
                dA.HbO(:,c) = shared * w + randn(T,1)*0.05;
                dB.HbO(:,c) = shared * w + randn(T,1)*0.05;
            end

            % Use a positive GOF threshold to be more inclusive
            result = exploreFNIRS.hyperscanning.hbica(dA, dB, ...
                'GOFThreshold', 0.5, 'ZScore', false, 'Detrend', 0);

            testCase.verifyTrue(any(result.isInterBrain), ...
                'Shared signal should produce at least one inter-brain component');
        end

        function testIntraBrainDetection(testCase)
            % Fully independent signals should mostly be intra-brain
            rng(102);
            T = testCase.T;
            nCh = testCase.nChannels;
            fs = testCase.fs;

            dA = makeSyntheticData(T, nCh, fs);
            dB = makeSyntheticData(T, nCh, fs);

            % Add strong subject-specific signals
            sigA = sin(2*pi*0.5*(0:T-1)'/fs) * 5;
            sigB = sin(2*pi*1.3*(0:T-1)'/fs) * 5;
            for c = 1:nCh
                dA.HbO(:,c) = dA.HbO(:,c) + sigA;
                dB.HbO(:,c) = dB.HbO(:,c) + sigB;
            end

            result = exploreFNIRS.hyperscanning.hbica(dA, dB);

            % With strong intra-brain signals, most components should be intra-brain
            nIntra = sum(~result.isInterBrain);
            testCase.verifyGreaterThanOrEqual(nIntra, 1, ...
                'Independent signals should produce intra-brain components');
        end

        function testDualRegressionDimensions(testCase)
            % sourcesA [T x K], mixingA [Ca x K]
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB);

            K = result.nComponents;
            Ca = length(result.channelsA);
            Cb = length(result.channelsB);

            testCase.verifySize(result.sourcesA, [testCase.T, K]);
            testCase.verifySize(result.sourcesB, [testCase.T, K]);
            testCase.verifySize(result.mixingA, [Ca, K]);
            testCase.verifySize(result.mixingB, [Cb, K]);
        end

        function testBiomarkerSwitch(testCase)
            % Verify HbR biomarker works
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'Biomarker', 'HbR');

            testCase.verifyEqual(result.biomarker, 'HbR');
            testCase.verifyGreaterThan(result.nComponents, 0);
        end

        function testTimeWindowSubset(testCase)
            % TimeWindow should restrict analysis
            tFull = testCase.dataA.time;
            tMid = [tFull(100), tFull(400)];

            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'TimeWindow', tMid);

            % Sources should be shorter than full
            testCase.verifyLessThan(size(result.sources, 1), testCase.T);
            testCase.verifyGreaterThan(size(result.sources, 1), 0);
        end

        function testChannelSubset(testCase)
            % Channels param should restrict which channels are used
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'Channels', [1 2 3]);

            testCase.verifyEqual(result.channelsA, [1 2 3]);
            testCase.verifyEqual(result.channelsB, [1 2 3]);
        end

        function testGOFDimensions(testCase)
            % GOF vectors should match number of components
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB);

            K = result.nComponents;
            testCase.verifySize(result.GOF, [K, 1]);
            testCase.verifySize(result.GOF_A, [K, 1]);
            testCase.verifySize(result.GOF_B, [K, 1]);
            testCase.verifySize(result.isInterBrain, [K, 1]);
        end

        function testCouplingAdapterInterface(testCase)
            % Coupling adapter should return valid struct
            rng(103);
            x = randn(200, 1);
            y = randn(200, 1);

            result = exploreFNIRS.coupling.hbica(x, y, testCase.fs);

            testCase.verifyTrue(isfield(result, 'value'));
            testCase.verifyTrue(isfield(result, 'pvalue'));
            testCase.verifyTrue(isfield(result, 'method'));
            testCase.verifyTrue(isfield(result, 'windowed'));
            testCase.verifyEqual(result.method, 'hbica');
            testCase.verifyFalse(result.windowed);
            testCase.verifyTrue(isscalar(result.value));
            testCase.verifyGreaterThanOrEqual(result.value, 0);
            testCase.verifyLessThanOrEqual(result.value, 0.5);
        end

        function testCouplingAdapterCorrelatedSignals(testCase)
            % Correlated signals should produce higher coupling than independent
            rng(104);
            T = 500;
            shared = sin(2*pi*0.5*(0:T-1)'/testCase.fs);

            x_corr = shared + randn(T,1)*0.1;
            y_corr = shared + randn(T,1)*0.1;
            x_indep = randn(T,1);
            y_indep = randn(T,1);

            res_corr = exploreFNIRS.coupling.hbica(x_corr, y_corr, testCase.fs);
            res_indep = exploreFNIRS.coupling.hbica(x_indep, y_indep, testCase.fs);

            testCase.verifyGreaterThan(res_corr.value, res_indep.value, ...
                'Correlated signals should have higher coupling');
        end

        function testNumComponentsParam(testCase)
            % Explicit NumComponents should limit the output
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'NumComponents', 3);

            testCase.verifyLessThanOrEqual(result.nComponents, 3);
        end

        function testDetrendOption(testCase)
            % Should work with detrend disabled
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'Detrend', -1);

            testCase.verifyGreaterThan(result.nComponents, 0);
        end

        function testZScoreOption(testCase)
            % Should work with z-score disabled
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'ZScore', false);

            testCase.verifyGreaterThan(result.nComponents, 0);
        end

        function testUseROIMode(testCase)
            % UseROI should pull from data.ROI.<Biomarker>
            rng(110);
            T = testCase.T;
            nROI = 3;
            fs = testCase.fs;

            dA = makeSyntheticData(T, testCase.nChannels, fs);
            dB = makeSyntheticData(T, testCase.nChannels, fs);

            % Add ROI data
            dA.ROI.HbO = randn(T, nROI) * 0.1;
            dA.ROI.info = table('RowNames', {'Left','Center','Right'});
            dB.ROI.HbO = randn(T, nROI) * 0.1;
            dB.ROI.info = table('RowNames', {'Left','Center','Right'});

            result = exploreFNIRS.hyperscanning.hbica(dA, dB, 'UseROI', true);

            testCase.verifyTrue(result.useROI);
            testCase.verifyEqual(result.channelsA, 1:nROI);
            testCase.verifyEqual(result.channelsB, 1:nROI);
            testCase.verifyGreaterThan(result.nComponents, 0);

            % Mixing dimensions should match ROI count
            testCase.verifySize(result.mixingA, [nROI, result.nComponents]);
            testCase.verifySize(result.mixingB, [nROI, result.nComponents]);

            % Labels should be ROI names
            testCase.verifyEqual(result.labelsA, {'Left','Center','Right'}');
            testCase.verifyEqual(result.labelsB, {'Left','Center','Right'}');
        end

        function testUseROIMissingErrors(testCase)
            % UseROI without ROI data should error
            testCase.verifyError( ...
                @() exploreFNIRS.hyperscanning.hbica( ...
                    testCase.dataA, testCase.dataB, 'UseROI', true), ...
                'exploreFNIRS:hyperscanning:hbica');
        end

        function testLabelsInChannelMode(testCase)
            % Channel mode should produce Ch# labels
            result = exploreFNIRS.hyperscanning.hbica( ...
                testCase.dataA, testCase.dataB, 'Channels', [1 2 3]);

            testCase.verifyFalse(result.useROI);
            testCase.verifyEqual(result.labelsA, {'Ch1','Ch2','Ch3'});
            testCase.verifyEqual(result.labelsB, {'Ch1','Ch2','Ch3'});
        end

    end
end


function data = makeSyntheticData(T, nCh, fs)
% Create a minimal synthetic processed fNIRS struct
    data.HbO = randn(T, nCh) * 0.1;
    data.HbR = randn(T, nCh) * 0.05;
    data.HbTotal = data.HbO + data.HbR;
    data.HbDiff = data.HbO - data.HbR;
    data.CBSI = randn(T, nCh) * 0.08;
    data.time = (0:T-1)' / fs;
    data.fs = fs;
    data.fchMask = ones(1, nCh);
    data.info = struct('SubjectID', 'SyntheticSubject');
end
