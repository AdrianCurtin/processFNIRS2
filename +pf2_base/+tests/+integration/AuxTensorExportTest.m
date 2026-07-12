classdef AuxTensorExportTest < matlab.unittest.TestCase
    % AUXTENSOREXPORTTEST Aligned + derived aux export via pf2.export.asTensor
    %
    % Verifies the 'Aux' option writes a /aux dataset aligned to the tensor
    % time grid (continuous and windowed), with auxNames/auxUnits attributes,
    % and that it is omitted by default.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.integration.AuxTensorExportTest');

    properties
        proc   % processed sample data with heartRate + accelerometer aux
    end

    methods (TestClassSetup)
        function build(testCase)
            warning('off', 'all');
            d = pf2.import.sampleData();
            p = processFNIRS2(d);
            n = numel(p.time);
            p.Aux.heartRate.data = 70 + 5*sin(2*pi*0.1*p.time);
            p.Aux.heartRate.time = p.time;
            p.Aux.heartRate.unit = 'bpm';
            p.Aux.heartRate.varNames = {'HR'};
            p.Aux.accelerometer.data = 0.01*randn(n, 3);
            p.Aux.accelerometer.time = p.time;
            p.Aux.accelerometer.unit = 'g';
            p.Aux.accelerometer.varNames = {'X','Y','Z'};
            testCase.proc = p;
        end
    end

    methods (Test)
        function testContinuousAuxAll(testCase)
            tmp = [tempname '.h5'];
            c = onCleanup(@() deleteIfExists(tmp));
            pf2.export.asTensor(testCase.proc, tmp, 'Features', {'HbO'}, 'Aux', 'all');

            names = cellstr(h5readatt(tmp, '/aux', 'auxNames'));
            units = cellstr(h5readatt(tmp, '/aux', 'auxUnits'));
            testCase.verifyTrue(ismember('heartRate', names));
            testCase.verifyTrue(ismember('accelerometer_X', names));
            testCase.verifyEqual(numel(names), 4);   % HR + 3 accel axes
            testCase.verifyEqual(units{strcmp(names, 'heartRate')}, 'bpm');

            % /aux is stored axis-reversed: on disk [K x T]
            A = h5read(tmp, '/aux');
            ref = pf2.data.auxOnGrid(testCase.proc, 'heartRate', 'Time', testCase.proc.time);
            hrRow = A(strcmp(names, 'heartRate'), :)';
            testCase.verifyEqual(hrRow, single(ref), 'AbsTol', 1e-4);
        end

        function testContinuousAuxNamedSubset(testCase)
            tmp = [tempname '.h5'];
            c = onCleanup(@() deleteIfExists(tmp));
            pf2.export.asTensor(testCase.proc, tmp, 'Features', {'HbO'}, ...
                'Aux', {'heartRate'});
            names = cellstr(h5readatt(tmp, '/aux', 'auxNames'));
            testCase.verifyEqual(names(:)', {'heartRate'});
            testCase.verifyEqual(double(h5readatt(tmp, '/', 'nAux')), 1);
        end

        function testNoAuxByDefault(testCase)
            tmp = [tempname '.h5'];
            c = onCleanup(@() deleteIfExists(tmp));
            pf2.export.asTensor(testCase.proc, tmp, 'Features', {'HbO'});
            info = h5info(tmp);
            testCase.verifyFalse(ismember('aux', {info.Datasets.Name}), ...
                '/aux should be absent by default');
            testCase.verifyEqual(double(h5readatt(tmp, '/', 'nAux')), 0);
        end

        function testWindowedAuxValuesAndMultichannel(testCase)
            blocks = pf2.data.slidingWindows(testCase.proc, 'Length', 10, ...
                'Overlap', 0.5, 'Embed', false);
            wins = pf2.data.extractBlocks(testCase.proc, blocks, ...
                'PreTime', 0, 'PostTime', 0);
            tmp = [tempname '.h5'];
            c = onCleanup(@() deleteIfExists(tmp));
            pf2.export.asTensor(testCase.proc, tmp, 'Features', {'HbO'}, ...
                'Windows', wins, 'Aux', {'heartRate', 'accelerometer'});

            names = cellstr(h5readatt(tmp, '/aux', 'auxNames'));
            testCase.verifyEqual(char(h5readatt(tmp, '/aux', 'dims')), ...
                'window x time x auxChannel');
            % HR (1) + accel (3 axes) = 4 aux columns
            testCase.verifyEqual(double(h5readatt(tmp, '/', 'nAux')), 4);
            testCase.verifyTrue(ismember('accelerometer_Z', names));

            % Value check on a LATER window (catches a "always window 1" bug):
            % /aux is stored axis-reversed -> on disk [K x T x W]
            A = h5read(tmp, '/aux');
            W = size(A, 3);
            testCase.verifyGreaterThan(W, 1);
            T = size(A, 2);
            wLast = W;
            ref = pf2.data.auxOnGrid(wins{wLast}, 'heartRate', ...
                'Time', wins{wLast}.time(1:T));
            hrK = find(strcmp(names, 'heartRate'), 1);
            got = squeeze(A(hrK, :, wLast))';
            testCase.verifyEqual(got, single(ref), 'AbsTol', 1e-4);
        end
    end
end

function deleteIfExists(f)
    if exist(f, 'file'), delete(f); end
end
