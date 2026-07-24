classdef BeerLambertPPFTest < matlab.unittest.TestCase
    % BEERLAMBERTPPFTEST Unit tests for the DPF / PVC / PPF pathlength model
    %
    %   Verifies bvoxy's three mutually exclusive pathlength conventions:
    %     - Fixed/Calc DPF optionally divided by a partial-volume correction
    %       PVC (scalar or per-optode): L = SD .* DPF ./ PVC
    %     - a complete effective factor supplied directly (PPF escape hatch):
    %       L = SD .* ppf, with the DPF/PVC components recorded as unknown
    %   plus the validation (PVC>=1, ppf>0, ppf-vs-dpf/pvc mutual exclusion,
    %   ppf shape/finiteness), the SD unit guard, DPFmode case-insensitivity,
    %   the auto-PVC extrapolation warning, and threading through
    %   ProcessingContext / processStageOD2Hb.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.BeerLambertPPFTest');
    %
    %   See also: pf2_base.fnirs.bvoxy, pf2_base.fnirs.strangmanPVC,
    %             pf2_base.fnirs.processStageOD2Hb, pf2.ProcessingContext

    properties
        data, channels, wave, sdCm, blSamp
    end

    methods (TestClassSetup)
        function buildSynthetic(testCase)
            rng(7);
            T = 200;
            testCase.channels = [1 1 2 2];
            testCase.wave = [730 850 730 850];
            testCase.sdCm = [2.7; 2.7];
            testCase.blSamp = 1:40;
            t = (1:T)';
            testCase.data = 1000 ...
                + [20*sin(2*pi*t/80), 15*sin(2*pi*t/70+1), ...
                   25*sin(2*pi*t/90+2), 10*sin(2*pi*t/60+0.5)] ...
                + 2*randn(T, 4);
        end
    end

    methods (Test)
        function pvcScalesCalcByPVC(testCase)
            % L = SD.*DPF./PVC, so HbO scales by exactly PVC vs plain Calc.
            fCalc = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25);
            fPVC = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialVolumeCorrection', 10);
            good = abs(fCalc.HbO) > 1e-9;
            ratio = fPVC.HbO(good) ./ fCalc.HbO(good);
            testCase.verifyEqual(ratio, 10*ones(size(ratio)), 'RelTol', 1e-9);
        end

        function pvcOneEqualsCalc(testCase)
            fCalc = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25);
            fPVC1 = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialVolumeCorrection', 1);
            testCase.verifyEqual(fPVC1.HbO, fCalc.HbO, 'AbsTol', 1e-9);
        end

        function perOptodePVCVector(testCase)
            % A per-optode PVC scales each optode's HbO by its own value.
            fCalc = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25);
            fVec = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialVolumeCorrection', [8; 12]);
            testCase.verifyEqual(fVec.HbO(:,1), 8*fCalc.HbO(:,1), 'RelTol', 1e-9);
            testCase.verifyEqual(fVec.HbO(:,2), 12*fCalc.HbO(:,2), 'RelTol', 1e-9);
        end

        function ppfBareEqualsFixedSameValue(testCase)
            % PPF is a complete effective factor: L = SD.*ppf, so ppf=6 matches
            % a fixed DPF of 6 exactly.
            fPPF = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', 6);
            fFix = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'DiffPathlengthFactor', 6);
            testCase.verifyEqual(fPPF.HbO, fFix.HbO, 'AbsTol', 1e-9);
        end

        function ppfRecordsComponentsAsUnknown(testCase)
            f = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', 0.12);
            testCase.verifyEqual(f.pathlengthInfo.mode, 'ppf');
            testCase.verifyTrue(all(isnan(f.pathlengthInfo.dpf)));
            testCase.verifyTrue(isnan(f.pathlengthInfo.pvc));
        end

        function calcProvenanceRecordsPVC(testCase)
            f = pf2_base.fnirs.bvoxy(testCase.data, testCase.channels, ...
                testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialVolumeCorrection', 10);
            testCase.verifyEqual(f.pathlengthInfo.mode, 'calc');
            testCase.verifyEqual(f.pathlengthInfo.pvc, 10, 'AbsTol', 1e-9);
        end

        function pvcFloorErrors(testCase)
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialVolumeCorrection', 0.5), 'pf2_base:fnirs:bvoxy:pvcFloor');
        end

        function ppfPositiveErrors(testCase)
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', 0), 'pf2_base:fnirs:bvoxy:ppfPositive');
        end

        function ppfLengthThreeErrorsBadPPF(testCase)
            % A stray third element must error rather than be silently
            % truncated to the first two (previously: [1 2 99] -> [1 2]).
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', [1 2 99]), 'pf2_base:fnirs:bvoxy:badPPF');
        end

        function ppfNaNErrorsBadPPF(testCase)
            % A NaN element must error rather than propagate to an all-NaN
            % HbO/HbR output (previously: [NaN 2] -> all-NaN).
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', [NaN 2]), 'pf2_base:fnirs:bvoxy:badPPF');
        end

        function ppfInfErrorsBadPPF(testCase)
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', [Inf 2]), 'pf2_base:fnirs:bvoxy:badPPF');
        end

        function ppfPvcMutuallyExclusive(testCase)
            testCase.verifyError(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'PartialPathlengthFactor', 6, 'PartialVolumeCorrection', 10), ...
                'pf2_base:fnirs:bvoxy:ppfConflict');
        end

        function fixedDPFRangeWarns(testCase)
            testCase.verifyWarning(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'DiffPathlengthFactor', 1), 'pf2_base:fnirs:bvoxy:dpfRange');
            testCase.verifyWarningFree(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, testCase.sdCm, testCase.blSamp, 25, ...
                'DiffPathlengthFactor', 6));
        end

        function unitGuardWarnsOnMillimeters(testCase)
            testCase.verifyWarning(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, [27; 27], testCase.blSamp, 25), ...
                'pf2_base:fnirs:bvoxy:distanceUnits');
            testCase.verifyWarningFree(@() pf2_base.fnirs.bvoxy(testCase.data, ...
                testCase.channels, testCase.wave, [2.7; 2.7], testCase.blSamp, 25));
        end

        function contextCarriesPvcAndPpf(testCase)
            ctx = pf2.ProcessingContext('DPFmode', 'PPF', 'PPF', [0.1 0.2], 'PVC', 8);
            testCase.verifyEqual(ctx.ppf, [0.1 0.2]);
            testCase.verifyEqual(ctx.pvc, 8);
            s = ctx.toStruct();
            ctx2 = pf2_base.ProcessingContext.fromStruct(s);
            testCase.verifyEqual(ctx2.ppf, [0.1 0.2]);
            testCase.verifyEqual(ctx2.pvc, 8);
        end

        function dpfModeValidatorAcceptsPPF(testCase)
            ctx = pf2_base.ProcessingContext();
            assignDpfMode(ctx, 'PPF');
            testCase.verifyEqual(ctx.dpfMode, 'PPF');
            testCase.verifyError(@() assignDpfMode(ctx, 'Bogus'), ?MException);
        end

        function processStageRequiresPPFValue(testCase)
            probe.TableOpt = table((1:2)', [2.7; 2.7], 'VariableNames', {'OptodeNum','SD'});
            probe.TableCh = table([1;1;2;2], [730;850;730;850], true(4,1), ...
                'VariableNames', {'OptodeNumber','Wavelength','isCh'});
            baseline = struct('startTime', 0, 'blLength', 4);
            time = (0:size(testCase.data,1)-1)'/10;
            testCase.verifyError(@() pf2_base.fnirs.processStageOD2Hb( ...
                testCase.data, time, 25, false, probe, baseline, 'PPF', 0, 25), ...
                'pf2_base:fnirs:processStageOD2Hb:ppfRequired');
        end

        function dpfModeCaseInsensitive(testCase)
            % processStageOD2Hb's DPFmode dispatch must be case-insensitive
            % (defense-in-depth for processFNIRS2's canonicalizing validator):
            % a lowercase mode string selects the SAME branch/result as its
            % canonical spelling. The original bug: 'PPF' worked, 'ppf'
            % silently fell through to the Calc branch instead of erroring or
            % matching.
            probe.TableOpt = table((1:2)', [2.7; 2.7], 'VariableNames', {'OptodeNum','SD'});
            probe.TableCh = table([1;1;2;2], [730;850;730;850], true(4,1), ...
                'VariableNames', {'OptodeNumber','Wavelength','isCh'});
            baseline = struct('startTime', 0, 'blLength', 4);
            time = (0:size(testCase.data,1)-1)'/10;

            modePairs = {'None','none'; 'Fixed','fixed'; 'Calc','calc'; 'PPF','ppf'};
            for i = 1:size(modePairs, 1)
                canon = modePairs{i,1};
                lower = modePairs{i,2};
                outCanon = pf2_base.fnirs.processStageOD2Hb(testCase.data, time, ...
                    25, false, probe, baseline, canon, 6, 25, 'PPF', 6);
                outLower = pf2_base.fnirs.processStageOD2Hb(testCase.data, time, ...
                    25, false, probe, baseline, lower, 6, 25, 'PPF', 6);
                testCase.verifyEqual(outLower.HbO, outCanon.HbO, 'AbsTol', 1e-9, ...
                    sprintf('DPFmode ''%s'' did not match ''%s''', lower, canon));
                testCase.verifyEqual(outLower.units, outCanon.units);
            end

            % Specifically confirm 'ppf' (lowercase) selects the PPF branch
            % rather than silently falling through to Calc: the two modes
            % must give materially different HbO for the same input.
            outPPFLower = pf2_base.fnirs.processStageOD2Hb(testCase.data, time, ...
                25, false, probe, baseline, 'ppf', 0, 25, 'PPF', 6);
            outCalc = pf2_base.fnirs.processStageOD2Hb(testCase.data, time, ...
                25, false, probe, baseline, 'Calc', 0, 25);
            testCase.verifyNotEqual(outPPFLower.HbO, outCalc.HbO);
        end

        function autoPVCClampWarnsOnShortSeparation(testCase)
            % PVC='auto' with a <20 mm separation (e.g. a short-separation
            % regressor channel) must surface the extrapolation/clamp
            % warning rather than silently applying the 20 mm-bound PVC.
            probe.TableOpt = table((1:2)', [0.8; 2.7], ...
                'VariableNames', {'OptodeNum','SD'});   % 8 mm, 27 mm
            probe.TableCh = table([1;1;2;2], [730;850;730;850], true(4,1), ...
                'VariableNames', {'OptodeNumber','Wavelength','isCh'});
            baseline = struct('startTime', 0, 'blLength', 4);
            time = (0:size(testCase.data,1)-1)'/10;

            testCase.verifyWarning(@() pf2_base.fnirs.processStageOD2Hb( ...
                testCase.data, time, 25, false, probe, baseline, 'Calc', 0, 25, ...
                'PVC', 'auto'), 'pf2_base:fnirs:processStageOD2Hb:pvcExtrapolated');
        end
    end
end

function assignDpfMode(ctx, mode)
% ASSIGNDPFMODE Helper so property-set errors are catchable by verifyError.
ctx.dpfMode = mode;
end
