classdef SMARFamilyTest < matlab.unittest.TestCase
    % SMARFAMILYTEST Behavioral contracts for pf2_SMAR2 and pf2_sSMART
    %
    % Guards the raw-intensity SMAR family against the regressions found in
    % review: a false-positive rate that rejected most of an artifact-free
    % recording, whole-channel rejection at tauClean = 0, off-by-one artifact
    % segment indices, edge extrapolation in sSMART's gap filling, and stale
    % saved-method flags forcing SMAR onto optical density.
    %
    %   results = runtests('pf2_base.tests.unit.SMARFamilyTest');
    %
    % See also: pf2_SMAR, pf2_SMAR2, pf2_sSMART, SignalProcessingTest

    properties (Constant)
        fs = 10
        nCh = 8
        T = 3000
    end

    methods (TestClassSetup)
        function addFunctionsPath(~)
            projRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            f = fullfile(projRoot, 'functions');
            if isfolder(f), addpath(f); end
        end
    end

    methods (Static, Access = private)
        function [I, chNum] = cleanIntensity(seed)
            % Artifact-free raw intensity: slow hemodynamics, cardiac and
            % respiratory oscillations, and white noise in the OD domain,
            % mapped to two wavelengths per channel around 1000 AU
            rng(seed);
            T = pf2_base.tests.unit.SMARFamilyTest.T;
            fs = pf2_base.tests.unit.SMARFamilyTest.fs;
            nC = 2 * pf2_base.tests.unit.SMARFamilyTest.nCh;
            t = (0:T-1)' / fs;
            od = 0.01*sin(2*pi*0.02*t + rand(1,nC)*2*pi) ...
               + 0.003*sin(2*pi*1.1*t + rand(1,nC)) ...
               + 0.002*sin(2*pi*0.25*t) + 0.0015*randn(T, nC);
            I = 1000 * 10.^(-od);
            nCh = nC / 2;
            chNum = [1:nCh, 1:nCh];
        end
    end

    methods (Test)
        %% pf2_SMAR2

        function testSMAR2CleanDataFalsePositiveCeiling(tc)
            % Defaults must keep artifact-free intensity (nearly) intact
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(1);
            [~, mask] = pf2_SMAR2(I, 10, chNum);
            tc.verifyLessThan(mean(mask(2:end-1,:), 'all'), 0.05, ...
                'SMAR2 rejected more than 5% of an artifact-free recording');
        end

        function testSMAR2MasksInjectedSpikeAndStep(tc)
            % A coupling spike and an optode-slip step are both masked, the
            % spike core in full, without masking the whole channel
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(2);
            I(1000:1002, [1 9]) = I(1000:1002, [1 9]) * 1.3;   % 3-sample spike
            I(2000:end, [2 10]) = I(2000:end, [2 10]) * 0.85;  % baseline step
            [~, mask] = pf2_SMAR2(I, 10, chNum);
            m = mask(2:end-1, :);
            tc.verifyTrue(all(m(1000:1002, [1 9]), 'all'), 'Spike core not fully masked');
            tc.verifyTrue(any(m(1990:2010, [2 10]), 'all'), 'Baseline step not detected');
            tc.verifyLessThan(mean(m(:, 1)), 0.2, 'Spike masked too much of the channel');
        end

        function testSMAR2MasksRecordingEdgeSpikes(tc)
            % A spike on the first or last sample must be masked; the
            % derivative at the first sample is not a fixed zero
            for k = [1 100]
                x = 100*ones(100, 1);
                x(k) = 1e6;
                y = pf2_SMAR2(x);
                tc.verifyTrue(isnan(y(k)), sprintf('Spike at sample %d survived', k));
            end
        end

        function testSMAR2WarnsWhenWindowSpansRecording(tc)
            % A window covering the whole recording makes every dCV zero;
            % SMAR2 must say so rather than silently pass the spike
            x = [100; 100; 1e6; 100; 100];
            tc.verifyWarning(@() pf2_SMAR2(x, 10), 'pf2:smar2:insufficientData');
        end

        function testSMAR2PairsWavelengths(tc)
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(3);
            I(1500:1502, 3) = I(1500:1502, 3) * 1.3;           % one wavelength only
            [~, mask] = pf2_SMAR2(I, 10, chNum);
            tc.verifyEqual(mask(:, 3), mask(:, 3 + numel(chNum)/2), ...
                'Columns sharing a chNum must share a mask');
        end

        function testSMAR2SegmentIndicesMatchNaNRuns(tc)
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(4);
            I(800:802, 1) = I(800:802, 1) * 1.3;
            I(2200:2202, 1) = I(2200:2202, 1) * 1.3;
            [Xcorr, ~, MA_idx] = pf2_SMAR2(I, 10, chNum);
            d = diff([false; isnan(Xcorr(:,1)); false]);
            runs = [find(d == 1), find(d == -1) - 1];
            tc.verifyEqual(MA_idx{1}, runs, ...
                'MA_idx must give [start end] rows of x for each NaN run');
        end

        function testSMAR2RejectsNonPositiveTauClean(tc)
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(5);
            tc.verifyError(@() pf2_SMAR2(I, 10, chNum, 10, 0), ...
                'pf2:smar2:invalidTauClean');
        end

        function testSMAR2ValidatesChNumLength(tc)
            [I, ~] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(6);
            tc.verifyError(@() pf2_SMAR2(I, 10, 1:3), 'pf2:smar2:chNumLength');
        end

        function testSMAR2WarnsOnOpticalDensity(tc)
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(7);
            tc.verifyWarningFree(@() pf2_SMAR2(I, 10, chNum));
            tc.verifyWarning(@() pf2_SMAR2(pf2_Intensity2OD(I), 10, chNum), ...
                'pf2:smar2:nonPositiveInput');
        end

        %% pf2_sSMART

        function testSSMARTOutputBoundedForEveryMethod(tc)
            % Gap filling must never extrapolate past the clean range. The
            % shape-preserving methods stay within each channel's input
            % range; spline/makima may overshoot inside a gap (documented)
            % but must not diverge. No method may leave NaN.
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(8);
            I(1:3, 1) = I(1:3, 1) * 1.3;                       % leading artifact
            I(end-2:end, 2) = I(end-2:end, 2) * 1.3;           % trailing artifact
            lo = min(I, [], 1);
            hi = max(I, [], 1);
            span = hi - lo;
            for method = {'pchip', 'linear', 'spline', 'makima'}
                y = pf2_sSMART(I, pf2_base.tests.unit.SMARFamilyTest.fs, chNum, ...
                    [], [], [], 1, method{1});
                tc.verifyFalse(any(isnan(y), 'all'), ...
                    sprintf('%s left NaN in the output', method{1}));
                if any(strcmp(method{1}, {'pchip', 'linear'}))
                    slack = 1e-9 * hi;
                else
                    slack = span;
                end
                tc.verifyTrue(all(min(y,[],1) >= lo - slack) && ...
                    all(max(y,[],1) <= hi + slack), ...
                    sprintf('%s output left the allowed range', method{1}));
            end
        end

        function testSSMARTPreservesCleanSamples(tc)
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(9);
            I(1500:1502, 1) = I(1500:1502, 1) * 1.3;
            [y, mask] = pf2_sSMART(I, pf2_base.tests.unit.SMARFamilyTest.fs, chNum, ...
                [], [], [], 1);
            clean = ~mask(2:end-1, :);
            tc.verifyEqual(y(clean), I(clean), 'RelTol', 1e-12);
        end

        function testSSMARTEmptyArgumentsUseDefaults(tc)
            % The documented shift-correction call passes [] for defaults
            [I, chNum] = pf2_base.tests.unit.SMARFamilyTest.cleanIntensity(10);
            y = pf2_sSMART(I, pf2_base.tests.unit.SMARFamilyTest.fs, chNum, ...
                [], [], [], [], [], true);
            tc.verifySize(y, size(I));
            % tauClean is honored even when tauArtifact is left empty
            [~, m1] = pf2_sSMART(I, 10, chNum, [], 0.5, [], 1);
            [~, m2] = pf2_sSMART(I, 10, chNum, [], 5, [], 1);
            tc.verifyGreaterThanOrEqual(nnz(m1), nnz(m2));
        end

        %% Pipeline placement

        function testLibraryDefaultPipelinesValidate(tc)
            % Library defaults (including sSMART's automatic minSeg = -1)
            % must pass parameter validation when placed before the OD step
            for f = {'pf2_SMAR', 'pf2_SMAR2', 'pf2_sSMART'}
                p = pf2_base.RawPipeline('t');
                p = p.add(f{1});
                p = p.add('pf2_Intensity2OD');
                tc.verifyEmpty(p.validate(), ...
                    sprintf('%s default pipeline failed validation', f{1}));
            end
        end

        function testRawDomainStepsIgnoreStaleSavedFlags(tc)
            % Methods saved before the correction embed requiresOD = 1; the
            % function library's raw-domain flags must win on load
            for f = {'pf2_SMAR', 'pf2_SMAR_mask', 'pf2_SMAR2', 'pf2_sSMART'}
                s = struct('f', f{1}, 'args', {{'x'}}, 'argvals', {{[]}}, ...
                    'output', {{'x'}}, 'validStages', [1,2], 'requiresOD', 1);
                pf = pf2_base.PipelineFunction.fromStruct(s);
                tc.verifyFalse(pf.requiresOD, ...
                    sprintf('%s kept a stale requiresOD flag', f{1}));
                tc.verifyEqual(pf.validStages, 1, ...
                    sprintf('%s kept stale validStages', f{1}));
            end
        end
    end
end
