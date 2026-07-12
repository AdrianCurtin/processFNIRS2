classdef AuxOnGridTest < matlab.unittest.TestCase
    % AUXONGRIDTEST Unit tests for pf2.data.auxOnGrid alignment primitive
    %
    % Verifies resampling of auxiliary signals onto a target time base:
    % identity on the native grid, upsampling, anti-aliased downsampling,
    % NaN-gap preservation, clock offset, out-of-range NaN, and channel subset.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.AuxOnGridTest');

    methods (Test)
        function testIdentityOnNativeGrid(testCase)
            t = (0:0.1:9.9)';
            x = sin(2*pi*0.2*t) + 0.1*randn(size(t));
            data = makeData(t, 'sig', t, x);
            vals = pf2.data.auxOnGrid(data, 'sig');
            testCase.verifyEqual(size(vals), [numel(t) 1]);
            testCase.verifyEqual(vals, x, 'AbsTol', 1e-9);
        end

        function testUpsample(testCase)
            tSrc = (0:0.2:10)';            % 5 Hz source
            x = sin(2*pi*0.5*tSrc);
            tTgt = (0:0.05:10)';           % 20 Hz target
            data = makeData(tTgt, 'sig', tSrc, x);
            vals = pf2.data.auxOnGrid(data, 'sig');
            testCase.verifyEqual(numel(vals), numel(tTgt));
            % Interpolated samples should track the underlying sine closely
            ref = sin(2*pi*0.5*tTgt);
            testCase.verifyLessThan(rms(vals - ref), 0.05);
        end

        function testAntiAliasDownsample(testCase)
            fsSrc = 100;
            tSrc = (0:1/fsSrc:10)';
            low = sin(2*pi*1*tSrc);          % 1 Hz signal of interest
            high = 0.8*sin(2*pi*8*tSrc);     % 8 Hz noise (above 5 Hz target Nyquist)
            x = low + high;
            tTgt = (0:0.1:10)';              % 10 Hz target (Nyquist 5 Hz)
            data = makeData(tTgt, 'sig', tSrc, x);

            valsAA = pf2.data.auxOnGrid(data, 'sig', 'AntiAlias', true);
            valsNo = pf2.data.auxOnGrid(data, 'sig', 'AntiAlias', false);

            ref = sin(2*pi*1*tTgt);
            errAA = rms(valsAA - ref, 'omitnan');
            errNo = rms(valsNo - ref, 'omitnan');
            testCase.verifyLessThan(errAA, errNo, ...
                'Anti-aliasing should reduce error vs the low-freq signal');
            testCase.verifyLessThan(errAA, 0.35);
        end

        function testNaNGapPreserved(testCase)
            tSrc = [(0:0.1:2)'; (5:0.1:7)'];   % 3 s gap between 2 and 5
            x = ones(size(tSrc));
            tTgt = (0:0.1:7)';
            data = makeData(tTgt, 'sig', tSrc, x);
            vals = pf2.data.auxOnGrid(data, 'sig', 'MaxGap', 1);
            inGap = tTgt > 2 & tTgt < 5;
            testCase.verifyTrue(all(isnan(vals(inGap))), 'Gap should be NaN');
            testCase.verifyFalse(any(isnan(vals(~inGap))), 'Non-gap should be filled');
        end

        function testClockOffset(testCase)
            tSrc = (0:0.1:10)';
            x = tSrc;                          % value == source time
            tTgt = (1:0.1:9)';
            data = makeData(tTgt, 'sig', tSrc, x);
            vals = pf2.data.auxOnGrid(data, 'sig', 'Offset', 1);
            % After +1 s offset, value at target t corresponds to source time t-1
            testCase.verifyEqual(vals, tTgt - 1, 'AbsTol', 1e-9);
        end

        function testOutOfRangeNaN(testCase)
            tSrc = (0:0.1:5)';
            x = sin(tSrc);
            tTgt = (0:0.1:8)';
            data = makeData(tTgt, 'sig', tSrc, x);
            vals = pf2.data.auxOnGrid(data, 'sig');
            testCase.verifyTrue(all(isnan(vals(tTgt > 5))), ...
                'Out-of-range target points should be NaN (no extrapolation)');
            testCase.verifyFalse(any(isnan(vals(tTgt <= 5))));
        end

        function testChannelSubset(testCase)
            t = (0:0.1:9.9)';
            x = [sin(t), cos(t), t];
            data = makeData(t, 'accel', t, x, 'g', {'X','Y','Z'});
            [vals, info] = pf2.data.auxOnGrid(data, 'accel', 'Channels', {'X','Z'});
            testCase.verifyEqual(size(vals, 2), 2);
            testCase.verifyEqual(info.channels, {'X','Z'});
            testCase.verifyEqual(vals(:,1), sin(t), 'AbsTol', 1e-9);
            testCase.verifyEqual(vals(:,2), t, 'AbsTol', 1e-9);
        end

        function testInfoReport(testCase)
            tSrc = (0:0.01:10)';   % 100 Hz
            tTgt = (0:0.1:10)';    % 10 Hz
            x = sin(2*pi*1*tSrc);
            data = makeData(tTgt, 'sig', tSrc, x);
            [~, info] = pf2.data.auxOnGrid(data, 'sig');
            testCase.verifyEqual(round(info.srcFs), 100);
            testCase.verifyEqual(round(info.tgtFs), 10);
            testCase.verifyTrue(info.antiAliased);
        end

        function testNotFoundErrors(testCase)
            t = (0:0.1:1)';
            data = makeData(t, 'sig', t, sin(t));
            testCase.verifyError(@() pf2.data.auxOnGrid(data, 'nope'), ...
                'pf2:auxOnGrid:notFound');
        end

        function testResolvesFlattenedPair(testCase)
            % Pipeline-flattened form: <name>_data / <name>_time + flattened flag
            t = (0:0.1:9.9)';
            x = sin(2*pi*0.3*t);
            data.time = t;
            data.fs = 10;
            data.Aux.flattened = true;
            data.Aux.heartRate_data = x;
            data.Aux.heartRate_time = t;
            vals = pf2.data.auxOnGrid(data, 'heartRate');
            testCase.verifyEqual(vals, x, 'AbsTol', 1e-9);
        end

        function testResolvesFlattenedTable(testCase)
            % Flattened *_data field is itself a self-contained table (time + value)
            t = (0:0.1:9.9)';
            x = cos(t);
            data.time = t;
            data.fs = 10;
            data.Aux.flattened = true;
            data.Aux.heartRate_data = table(t, x, 'VariableNames', {'time', 'HR'});
            data.Aux.heartRate_time = table(t, x, 'VariableNames', {'time', 'HR'});
            vals = pf2.data.auxOnGrid(data, 'heartRate');
            testCase.verifyEqual(vals, x, 'AbsTol', 1e-9);
        end
    end
end

function data = makeData(tFnirs, auxName, auxTime, auxData, unit, varNames)
% MAKEDATA Build a minimal fNIRS-like struct carrying one Aux signal
data.time = tFnirs(:);
data.fs = 1 / median(diff(tFnirs));
s.data = auxData;
s.time = auxTime(:);
if nargin >= 5, s.unit = unit; end
if nargin >= 6, s.varNames = varNames; end
data.Aux.(auxName) = s;
end
