classdef AuxModelingIntegrationTest < matlab.unittest.TestCase
    % AUXMODELINGINTEGRATIONTEST End-to-end tests for Aux in GLM/LME modeling
    %
    % Exercises Phase 1 of the Aux roadmap against real sample data:
    %   - GLMExperiment auxNuisance: an aligned Aux signal becomes a nuisance
    %     regressor (aux_<signal>_<channel>) in the first-level design.
    %   - autoModelLME AuxCovariates: aux_ columns are promoted to candidate
    %     predictors only when opted in (default behavior unchanged).
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.integration.AuxModelingIntegrationTest');

    methods (TestMethodSetup)
        function quiet(~)
            warning('off', 'all');
        end
    end

    methods (Test)
        function testGLMExperimentAuxNuisance(testCase)
            % Continuous subject with markers -> process -> add nested aux ->
            % defineBlocks -> GLMExperiment with auxNuisance.
            d = pf2.import.sampleData();
            proc = processFNIRS2(d);

            n = numel(proc.time);
            proc.Aux.heartRate.data = 70 + 3*sin(2*pi*0.1*proc.time) + randn(n,1);
            proc.Aux.heartRate.time = proc.time;
            proc.Aux.heartRate.unit = 'bpm';
            proc.Aux.heartRate.varNames = {'HR'};

            mcodes = unique(proc.markers.Code);
            proc = pf2.data.defineBlocks(proc, mcodes(1), 15, 'Embed', true);

            gx = exploreFNIRS.core.GLMExperiment({proc});
            gx.glm.biomarkers = {'HbO'};
            gx.glm.auxNuisance = {'heartRate'};
            gx = gx.fit();

            rn = gx.subjectResults{1}.regressorNames;
            testCase.verifyTrue(any(contains(rn, 'aux_heartRate')), ...
                'auxNuisance should add an aux_heartRate regressor to the design');
        end

        function testAutoModelLMEAuxCovariateOptIn(testCase)
            % Sample group carries heartRate + accelerometer aux.
            [ex, ~] = pf2.import.sampleData.group();
            ex = ex.aggregate();

            % Default: aux columns are excluded from candidates
            r0 = ex.statsAutoLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
                'Verbose', false);
            testCase.verifyFalse(any(contains(r0.candidates, 'aux_')), ...
                'Aux columns should be excluded by default');

            % Opt-in: heartRate promoted to a candidate covariate
            r1 = ex.statsAutoLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
                'Verbose', false, 'AuxCovariates', {'heartRate'});
            testCase.verifyTrue(any(contains(r1.candidates, 'aux_heartRate')), ...
                'AuxCovariates should promote aux_heartRate to a candidate');
            % The accelerometer was not whitelisted -> still excluded
            testCase.verifyFalse(any(contains(r1.candidates, 'aux_accelerometer')), ...
                'Non-whitelisted aux signals should remain excluded');
            % Aux time bookkeeping columns are never candidates
            testCase.verifyFalse(any(endsWith(r1.candidates, '_time')), ...
                'Aux _time columns should not be candidates');

            % Wildcard {'all'} admits every aux signal
            r2 = ex.statsAutoLME('Biomarkers', {'HbO'}, 'Channels', 1, ...
                'Verbose', false, 'AuxCovariates', {'all'});
            testCase.verifyTrue(any(contains(r2.candidates, 'aux_heartRate')));
            testCase.verifyTrue(any(contains(r2.candidates, 'aux_accelerometer')));
        end
    end
end
