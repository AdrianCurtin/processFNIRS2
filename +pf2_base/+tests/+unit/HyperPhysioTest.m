classdef HyperPhysioTest < matlab.unittest.TestCase
    % HYPERPHYSIOTEST Unit tests for hyperscanning physiology controls
    %
    % Covers exploreFNIRS.coupling.partialCoherence (partialling out a shared
    % confound) and exploreFNIRS.hyperscanning.physioConfoundQC (shared-aux
    % coherence flag).
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.HyperPhysioTest');

    methods (Test)
        function testPartialCoherenceRemovesSharedConfound(testCase)
            rng(11);
            fs = 10;
            t = (0:1/fs:300)';
            z = sin(2*pi*0.1*t);                 % shared ~0.1 Hz oscillation
            x = z + 0.2*randn(size(t));
            y = z + 0.2*randn(size(t));          % x,y correlated only via z

            r = exploreFNIRS.coupling.partialCoherence(x, y, z, fs, ...
                'FreqRange', [0.05 0.15]);

            testCase.verifyGreaterThan(r.ordinary, 0.5, ...
                'Ordinary coherence should be high (shared oscillation)');
            testCase.verifyLessThan(r.value, r.ordinary, ...
                'Partial coherence should be lower than ordinary');
            testCase.verifyGreaterThan(r.reduction, 0.3, ...
                'Partialling the shared signal should reduce coherence markedly');
            testCase.verifyLessThan(r.value, 0.3);
        end

        function testPartialCoherenceKeepsDirectLink(testCase)
            % x and y share a component NOT present in z -> partialling z should
            % NOT remove their coherence.
            rng(12);
            fs = 10;
            t = (0:1/fs:300)';
            shared = sin(2*pi*0.1*t);            % direct shared link
            z = sin(2*pi*0.3*t) + 0.2*randn(size(t));   % unrelated confound
            x = shared + 0.2*randn(size(t));
            y = shared + 0.2*randn(size(t));

            r = exploreFNIRS.coupling.partialCoherence(x, y, z, fs, ...
                'FreqRange', [0.05 0.15]);
            testCase.verifyGreaterThan(r.value, 0.4, ...
                'Direct x-y coherence should survive partialling an unrelated z');
        end

        function testPhysioQCFlagsSharedPhysiology(testCase)
            rng(31);
            fs = 10;
            t = (0:1/fs:300)';
            shared = 5*sin(2*pi*0.1*t);
            A = makeSubj(t, fs, 70 + shared + 1*randn(size(t)));
            B = makeSubj(t, fs, 72 + shared + 1*randn(size(t)));
            qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B, 'Aux', 'heartRate');
            testCase.verifyTrue(qc.available);
            testCase.verifyTrue(qc.flag, 'Shared 0.1 Hz physiology should be flagged');
            testCase.verifyGreaterThan(qc.auxCoherence, 0.5);
        end

        function testPhysioQCIndependentNotFlagged(testCase)
            rng(13);
            fs = 10;
            t = (0:1/fs:300)';
            A = makeSubj(t, fs, 70 + 5*sin(2*pi*0.1*t) + 1*randn(size(t)));
            B = makeSubj(t, fs, 72 + 3*randn(size(t)));   % independent noise
            qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B, 'Aux', 'heartRate');
            testCase.verifyTrue(qc.available);
            testCase.verifyFalse(qc.flag, 'Independent physiology should not be flagged');
        end

        function testPhysioQCAutoDetectsSignal(testCase)
            % No 'Aux' given -> auto-detect a shared cardio-respiratory signal
            rng(32);
            fs = 10;
            t = (0:1/fs:300)';
            shared = 5*sin(2*pi*0.1*t);
            A = makeSubj(t, fs, 70 + shared + 1*randn(size(t)));
            B = makeSubj(t, fs, 72 + shared + 1*randn(size(t)));
            qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B);
            testCase.verifyTrue(qc.available);
            testCase.verifyEqual(qc.signal, 'heartRate');
            testCase.verifyTrue(qc.flag);
        end

        function testComputeDyadPhysioQCOptIn(testCase)
            rng(33);
            fs = 10;
            t = (0:1/fs:300)';
            shared = 5*sin(2*pi*0.1*t);
            A = makeSubj(t, fs, 70 + shared + 1*randn(size(t)));
            B = makeSubj(t, fs, 72 + shared + 1*randn(size(t)));

            % Off by default: no physioQC field
            r0 = exploreFNIRS.hyperscanning.computeDyad(A, B, 'Channels', 1);
            testCase.verifyFalse(isfield(r0, 'physioQC'));

            % Opt-in: physioQC surfaced and flags shared physiology
            r1 = exploreFNIRS.hyperscanning.computeDyad(A, B, 'Channels', 1, ...
                'PhysioQC', true, 'PhysioQCArgs', {'Aux', 'heartRate'});
            testCase.verifyTrue(isfield(r1, 'physioQC'));
            testCase.verifyTrue(r1.physioQC.available);
            testCase.verifyTrue(r1.physioQC.flag);
        end

        function testPhysioQCNoAuxUnavailable(testCase)
            fs = 10;
            t = (0:1/fs:60)';
            A = makeSubj(t, fs, 70 + randn(size(t)));
            B = struct('time', t, 'fs', fs, 'HbO', randn(numel(t),2));   % no Aux
            qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B);
            testCase.verifyFalse(qc.available);
            testCase.verifyFalse(qc.flag);
        end
    end
end

function d = makeSubj(t, fs, hr)
% MAKESUBJ Minimal subject with HbO and a heartRate aux signal
n = numel(t);
d.time = t(:);
d.fs = fs;
d.HbO = randn(n, 2);
d.Aux.heartRate.data = hr(:);
d.Aux.heartRate.time = t(:);
d.Aux.heartRate.unit = 'bpm';
d.Aux.heartRate.varNames = {'HR'};
end
