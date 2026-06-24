classdef Oxy3AuxTest < matlab.unittest.TestCase
    % OXY3AUXTEST Unit tests for pf2_base.oxy3Aux (Artinis .oxy3 AD channels)
    %
    % Verifies that the OxySoft AD-channel exporter preserves the legacy
    % Aux.trigger and additionally exports non-trigger analog AD channels as
    % typed auxiliary signals, with name mapping and generic fallback.
    %
    % Run all tests:
    %   results = runtests('pf2_base.tests.unit.Oxy3AuxTest');

    methods (Test)
        function testNamedADChannels(testCase)
            [M, time, isTrig, opticalCols, counterCol] = synthOxy3();
            % adcNames describes only the analog AD inputs (cols 7,8); the
            % trigger (col 6) is named via trigNames.
            adcNames = {'Battery', 'Respiration'};
            Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, ...
                adcNames, {'Port'});

            % Legacy trigger preserved
            testCase.verifyTrue(isfield(Aux, 'trigger'));
            testCase.verifyEqual(Aux.trigger.data, M(:, 6));
            testCase.verifyEqual(Aux.trigger.unit, 'code');

            % Non-trigger AD channels exported and typed
            testCase.verifyTrue(isfield(Aux, 'Battery'));
            testCase.verifyTrue(isfield(Aux, 'Respiration'));
            testCase.verifyEqual(Aux.Respiration.data, M(:, 8));
            % Respiration -> RESP type -> 'a.u.' unit; Battery -> generic -> 'V'
            testCase.verifyEqual(Aux.Respiration.unit, 'a.u.');
            testCase.verifyEqual(Aux.Battery.unit, 'V');
            % Trigger column is not double-exported as an analog channel
            testCase.verifyEqual(numel(fieldnames(Aux)), 3);
        end

        function testGenericFallbackNames(testCase)
            [M, time, isTrig, opticalCols, counterCol] = synthOxy3();
            % No names -> generic adc<col> for non-trigger AD channels
            Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, {}, {});
            testCase.verifyTrue(isfield(Aux, 'trigger'));
            testCase.verifyTrue(isfield(Aux, 'adc7'));
            testCase.verifyTrue(isfield(Aux, 'adc8'));
            testCase.verifyEqual(Aux.adc7.unit, 'V');   % unknown -> raw ADC
        end

        function testNoTrigger(testCase)
            [M, time, isTrig, opticalCols, counterCol] = synthOxy3();
            isTrig = false(1, 8);                 % no trigger line
            Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, ...
                {'Port', 'Battery', 'Respiration'}, {});
            testCase.verifyFalse(isfield(Aux, 'trigger'));
            % Now col 6 ('Port') is exported as a plain AD channel
            testCase.verifyTrue(isfield(Aux, 'Port'));
            testCase.verifyEqual(numel(fieldnames(Aux)), 3);
        end

        function testNameCountMismatchFallsBackToGeneric(testCase)
            % Name count != analog AD-column count (2) -> names ignored, generic
            [M, time, isTrig, opticalCols, counterCol] = synthOxy3();
            Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, ...
                {'OnlyOneName'}, {});              % 1 name, 2 analog AD cols
            testCase.verifyTrue(isfield(Aux, 'trigger'));
            testCase.verifyTrue(isfield(Aux, 'adc7'));
            testCase.verifyTrue(isfield(Aux, 'adc8'));
            testCase.verifyFalse(isfield(Aux, 'OnlyOneName'));
        end

        function testMultipleTriggersFirstOnly(testCase)
            % Only the first trigger line becomes Aux.trigger; others are not
            % double-exported as analog channels.
            [M, time, isTrig, opticalCols, counterCol] = synthOxy3();
            isTrig([6 7]) = true;                  % two trigger lines
            Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, {}, {});
            testCase.verifyTrue(isfield(Aux, 'trigger'));
            testCase.verifyEqual(Aux.trigger.data, M(:, 6));
            testCase.verifyFalse(isfield(Aux, 'adc7'));   % col 7 is a trigger -> skipped
            testCase.verifyTrue(isfield(Aux, 'adc8'));
        end

        function testZeroADChannels(testCase)
            % If every non-optical/non-counter column is a trigger, only the
            % trigger field is produced.
            nSamp = 100; time = (0:nSamp-1)'/50;
            counter = (1:nSamp)';
            optical = 2000 + 50*randn(nSamp, 4);
            trig = zeros(nSamp, 1); trig(20:30) = 1;
            M = [counter, optical, trig];
            isTrig = false(1, 6); isTrig(6) = true;
            Aux = pf2_base.oxy3Aux(M, time, isTrig, 2:5, 1, {}, {});
            testCase.verifyEqual(fieldnames(Aux), {'trigger'});
        end
    end
end

function [M, time, isTrig, opticalCols, counterCol] = synthOxy3()
% SYNTHOXY3 Synthetic .oxy3 column layout: counter | optical*4 | trig | batt | resp
nSamp = 200;
time = (0:nSamp-1)' / 50;            % 50 Hz
counter = (1:nSamp)';
optical = 2000 + 50*randn(nSamp, 4);
trig = zeros(nSamp, 1); trig(50:60) = 1; trig(120:130) = 2;
battery = 3.7 + 0.001*randn(nSamp, 1);
resp = sin(2*pi*0.25*time);
M = [counter, optical, trig, battery, resp];
isTrig = false(1, 8); isTrig(6) = true;
opticalCols = 2:5;
counterCol = 1;
end
