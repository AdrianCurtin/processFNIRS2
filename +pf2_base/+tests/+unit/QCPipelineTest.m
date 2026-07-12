classdef QCPipelineTest < matlab.unittest.TestCase
% QCPIPELINETEST Unit tests for pf2.qc.pipeline functions
%
% Tests the standalone QC pipeline: assess, apply, report, plotReport.
%
% Run:
%   results = runtests('pf2_base.tests.unit.QCPipelineTest');

    properties
        OrigRng
    end

    methods (TestMethodSetup)
        function saveRng(testCase)
            testCase.OrigRng = rng;
            rng(42);
        end
    end

    methods (TestMethodTeardown)
        function restoreRng(testCase)
            rng(testCase.OrigRng);
        end
    end

    methods (Static)
        function data = makeGoodData()
            % Generate synthetic data with heartbeat (good coupling)
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'heartAmplitude', 0.01, ...
                'noiseLevel', 0.005, 'seed', 42);
        end

        function data = makeDataWithDeadChannel()
            % Generate data then kill one channel
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'heartAmplitude', 0.01, ...
                'noiseLevel', 0.005, 'seed', 42);
            % Make channel 3 constant (dead)
            col1 = 5;  % ch3 wl1
            col2 = 6;  % ch3 wl2
            data.raw(:, col1) = 1000;
            data.raw(:, col2) = 1000;
        end

        function data = makeLowFsData()
            % Generate synthetic data at 2 Hz (low sampling rate)
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 120, 'fs', 2, 'nChannels', 4, ...
                'addHeartbeat', false, 'noiseLevel', 0.005, 'seed', 42);
        end

        function data = makeDataWithNaN()
            % Generate data with NaN values injected
            data = pf2_base.tests.synthetic.generateFNIRS( ...
                'duration', 60, 'fs', 10, 'nChannels', 4, ...
                'addHeartbeat', true, 'heartAmplitude', 0.01, ...
                'noiseLevel', 0.005, 'seed', 42);
            % Inject NaN into channel 2 (columns 3-4)
            data.raw(100:150, 3) = NaN;
            data.raw(100:150, 4) = NaN;
        end
    end

    %% assess tests

    methods (Test)
        function testAssessBasic(testCase)
            % assess() on synthetic data returns valid report struct
            data = testCase.makeGoodData();
            report = pf2.qc.pipeline.assess(data);

            testCase.verifyTrue(isstruct(report));
            testCase.verifyEqual(numel(report.channels), 4);
            testCase.verifyTrue(islogical(report.pass));
            testCase.verifyEqual(numel(report.pass), 4);
        end

        function testAssessAllFieldsPresent(testCase)
            % All expected fields exist in report
            data = testCase.makeGoodData();
            report = pf2.qc.pipeline.assess(data);

            % Top-level fields
            testCase.verifyTrue(isfield(report, 'channels'));
            testCase.verifyTrue(isfield(report, 'pass'));
            testCase.verifyTrue(isfield(report, 'nChecks'));
            testCase.verifyTrue(isfield(report, 'summary'));
            testCase.verifyTrue(isfield(report, 'fs'));
            testCase.verifyTrue(isfield(report, 'timestamp'));
            testCase.verifyTrue(isfield(report, 'processing'));
            testCase.verifyTrue(isfield(report, 'params'));
            testCase.verifyTrue(isfield(report, 'checkNames'));

            % Per-check fields
            testCase.verifyTrue(isfield(report, 'sci'));
            testCase.verifyTrue(isfield(report.sci, 'values'));
            testCase.verifyTrue(isfield(report.sci, 'pass'));
            testCase.verifyTrue(isfield(report.sci, 'threshold'));

            testCase.verifyTrue(isfield(report, 'cardiac'));
            testCase.verifyTrue(isfield(report.cardiac, 'detected'));
            testCase.verifyTrue(isfield(report.cardiac, 'snr'));
            testCase.verifyTrue(isfield(report.cardiac, 'freq'));
            testCase.verifyTrue(isfield(report.cardiac, 'pass'));

            testCase.verifyTrue(isfield(report, 'cov'));
            testCase.verifyTrue(isfield(report.cov, 'values'));
            testCase.verifyTrue(isfield(report.cov, 'pass'));
            testCase.verifyTrue(isfield(report.cov, 'threshold'));

            testCase.verifyTrue(isfield(report, 'takizawa'));
            testCase.verifyTrue(isfield(report.takizawa, 'rules'));
            testCase.verifyTrue(isfield(report.takizawa, 'ruleNames'));
            testCase.verifyTrue(isfield(report.takizawa, 'pass'));
        end

        function testAssessGoodDataPasses(testCase)
            % Clean synthetic data with heartbeat should pass most checks
            data = testCase.makeGoodData();
            report = pf2.qc.pipeline.assess(data);

            % At least some channels should pass overall
            testCase.verifyGreaterThan(sum(report.pass), 0, ...
                'Good synthetic data should have at least one passing channel');

            % CoV should pass for all channels (low noise)
            testCase.verifyTrue(all(report.cov.pass), ...
                'Low-noise data should pass CoV check');
        end

        function testAssessBadChannelFails(testCase)
            % Dead channel (constant signal) should fail SCI and related checks
            data = testCase.makeDataWithDeadChannel();
            report = pf2.qc.pipeline.assess(data);

            % Channel 3 should fail SCI (constant signal = 0 correlation)
            testCase.verifyFalse(report.sci.pass(3), ...
                'Dead channel should fail SCI');
            testCase.verifyEqual(report.sci.values(3), 0, ...
                'Dead channel SCI should be 0');
        end

        function testAssessSubsetChecks(testCase)
            % Running only SCI should only include SCI results
            data = testCase.makeGoodData();
            report = pf2.qc.pipeline.assess(data, 'Checks', {'sci'});

            testCase.verifyEqual(report.nChecks, 1);
            testCase.verifyTrue(isfield(report, 'sci'));
            testCase.verifyFalse(isfield(report, 'cardiac'));
            testCase.verifyFalse(isfield(report, 'cov'));
            testCase.verifyFalse(isfield(report, 'takizawa'));
        end

        function testAssessCustomThresholds(testCase)
            % Custom thresholds should be applied correctly
            data = testCase.makeGoodData();

            % Very strict SCI threshold
            report1 = pf2.qc.pipeline.assess(data, ...
                'Checks', {'sci'}, 'SCIThreshold', 0.99);

            % Very lenient SCI threshold
            report2 = pf2.qc.pipeline.assess(data, ...
                'Checks', {'sci'}, 'SCIThreshold', 0.01);

            % Strict should reject more than lenient
            testCase.verifyGreaterThanOrEqual(sum(report2.sci.pass), ...
                sum(report1.sci.pass), ...
                'Lenient threshold should pass >= strict threshold');

            testCase.verifyEqual(report1.sci.threshold, 0.99);
            testCase.verifyEqual(report2.sci.threshold, 0.01);
        end

        %% apply tests

        function testApplyUpdatesFchMask(testCase)
            % apply() should AND report with existing fchMask
            data = testCase.makeDataWithDeadChannel();
            report = pf2.qc.pipeline.assess(data, 'Checks', {'sci'});

            dataOut = pf2.qc.pipeline.apply(data, report, 'Checks', {'sci'});

            % Channel 3 was dead -> should now be rejected
            testCase.verifyEqual(dataOut.fchMask(3), 0, ...
                'Dead channel should be rejected after apply');
        end

        function testApplyNeverPromotes(testCase)
            % apply() should never set a 0-channel back to 1
            data = testCase.makeGoodData();
            data.fchMask(2) = 0;  % Pre-reject channel 2

            report = pf2.qc.pipeline.assess(data, 'Checks', {'cov'});
            dataOut = pf2.qc.pipeline.apply(data, report, 'Checks', {'cov'});

            testCase.verifyEqual(dataOut.fchMask(2), 0, ...
                'Pre-rejected channel should remain rejected');
        end

        function testApplySelectiveChecks(testCase)
            % apply() with selective checks should only use those checks
            data = testCase.makeDataWithDeadChannel();
            report = pf2.qc.pipeline.assess(data);

            % Apply only CoV (dead channel may still pass CoV)
            dataOut = pf2.qc.pipeline.apply(data, report, 'Checks', {'cov'});

            % CoV for constant signal is 0 which passes
            testCase.verifyEqual(dataOut.fchMask(3), double(report.cov.pass(3)));
        end

        function testApplyStoresReport(testCase)
            % apply() should store qcReport on data struct
            data = testCase.makeGoodData();
            report = pf2.qc.pipeline.assess(data, 'Checks', {'cov'});
            dataOut = pf2.qc.pipeline.apply(data, report, 'Checks', {'cov'});

            testCase.verifyTrue(isfield(dataOut, 'qcReport'));
            testCase.verifyEqual(dataOut.qcReport.nChecks, report.nChecks);
        end

        %% report and plotReport tests

        function testReportPrints(testCase)
            % report() should run without error
            data = testCase.makeGoodData();
            rpt = pf2.qc.pipeline.assess(data);

            % Should not throw
            pf2.qc.pipeline.report(rpt);
        end

        function testPlotReportCreates(testCase)
            % plotReport() with Visible=off should return figure handle
            data = testCase.makeGoodData();
            rpt = pf2.qc.pipeline.assess(data);

            fig = pf2.qc.pipeline.plotReport(rpt, 'Visible', 'off');
            testCase.addTeardown(@() close(fig));

            testCase.verifyTrue(isgraphics(fig, 'figure'));
        end

        %% Low sampling rate tests

        function testSciSkipsAtLowFs(testCase)
            % SCI should be skipped (not crash) at 2 Hz
            data = testCase.makeLowFsData();
            result = pf2.qc.sci(data);

            testCase.verifyTrue(result.skipped, ...
                'SCI should be skipped at 2 Hz');
            testCase.verifyTrue(all(isnan(result.sci)), ...
                'Skipped SCI should return NaN values');
            testCase.verifyTrue(all(result.isGood), ...
                'Skipped SCI should not penalize channels');
        end

        function testAssessLowFsDoesNotCrash(testCase)
            % Full assess() should not crash on 2 Hz data
            data = testCase.makeLowFsData();
            report = pf2.qc.pipeline.assess(data);

            testCase.verifyTrue(isstruct(report));
            testCase.verifyEqual(numel(report.pass), 4);
        end

        function testAssessLowFsSkipsSciAndCardiac(testCase)
            % At 2 Hz, SCI and cardiac should be skipped
            data = testCase.makeLowFsData();
            report = pf2.qc.pipeline.assess(data);

            testCase.verifyTrue(report.sci.skipped, ...
                'SCI should be marked as skipped at 2 Hz');
            testCase.verifyTrue(report.cardiac.skipped, ...
                'Cardiac should be marked as skipped at 2 Hz');
        end

        function testAssessLowFsSkipsDoNotReject(testCase)
            % Skipped checks should not cause channel rejection
            data = testCase.makeLowFsData();
            report = pf2.qc.pipeline.assess(data, 'Checks', {'sci', 'cardiac'});

            % Both checks skipped → all channels should pass
            testCase.verifyTrue(all(report.pass), ...
                'Skipped checks should result in all channels passing');
        end

        function testAssessLowFsCovAndTakizawaStillRun(testCase)
            % CoV and Takizawa should still run at 2 Hz
            data = testCase.makeLowFsData();
            report = pf2.qc.pipeline.assess(data, 'Checks', {'cov', 'takizawa'});

            testCase.verifyFalse(isfield(report.cov, 'skipped') && report.cov.skipped, ...
                'CoV should not be skipped at 2 Hz');
            testCase.verifyFalse(isfield(report.takizawa, 'skipped') && report.takizawa.skipped, ...
                'Takizawa should not be skipped at 2 Hz');
        end

        function testReportHandlesSkippedChecks(testCase)
            % report() should print without error when checks are skipped
            data = testCase.makeLowFsData();
            rpt = pf2.qc.pipeline.assess(data);

            % Should not throw
            pf2.qc.pipeline.report(rpt);
        end

        function testPlotReportHandlesSkippedChecks(testCase)
            % plotReport() should show "Skipped" panels for low-fs data
            data = testCase.makeLowFsData();
            rpt = pf2.qc.pipeline.assess(data);

            fig = pf2.qc.pipeline.plotReport(rpt, 'Visible', 'off');
            testCase.addTeardown(@() close(fig));

            testCase.verifyTrue(isgraphics(fig, 'figure'));
        end

        %% NaN handling tests

        function testSciHandlesNaN(testCase)
            % SCI should handle NaN in raw data without crashing
            data = testCase.makeDataWithNaN();
            result = pf2.qc.sci(data);

            testCase.verifyEqual(numel(result.sci), 4);
            % Channel 2 has NaN — should still compute (bpf handles NaN)
            testCase.verifyFalse(isnan(result.sci(2)), ...
                'SCI should handle NaN in raw data (partial NaN, not all)');
        end

        function testAssessHandlesNaN(testCase)
            % Full pipeline should not crash on data with NaN
            data = testCase.makeDataWithNaN();
            report = pf2.qc.pipeline.assess(data);

            testCase.verifyTrue(isstruct(report));
            testCase.verifyEqual(numel(report.pass), 4);
        end

        function testApplyOnLowFsData(testCase)
            % apply() should work correctly on low-fs report
            data = testCase.makeLowFsData();
            report = pf2.qc.pipeline.assess(data);

            dataOut = pf2.qc.pipeline.apply(data, report);
            testCase.verifyTrue(isfield(dataOut, 'qcReport'));
            % The result fchMask should match what we get from only
            % the non-skipped checks (CoV + Takizawa)
            combinedNonSkipped = report.cov.pass & report.takizawa.pass;
            expectedMask = double(data.fchMask > 0) .* double(combinedNonSkipped);
            testCase.verifyEqual(dataOut.fchMask, expectedMask, ...
                'Only CoV and Takizawa should affect mask at low fs');
        end
    end

end
