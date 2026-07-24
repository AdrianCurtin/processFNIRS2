classdef ShortChannelRegressionODTest < matlab.unittest.TestCase
    % SHORTCHANNELREGRESSIONODTEST Unit tests for OD-space short-channel regression
    %
    %   Verifies pf2_base.fnirs.shortChannelRegressionOD removes shared
    %   systemic signal from long-channel optical density (per wavelength,
    %   before Beer-Lambert), that the 'Space','OD' delegation on
    %   shortChannelRegression matches it, and that the no-short-channel case is
    %   a safe no-op.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.ShortChannelRegressionODTest');
    %
    %   See also: pf2_base.fnirs.shortChannelRegressionOD,
    %             pf2_base.fnirs.shortChannelRegression

    properties
        odCols, channels, wave, probe, systemic, neural1
    end

    methods (TestClassSetup)
        function build(testCase)
            rng(11);
            T = 600; fs = 10; t = (0:T-1)'/fs;
            S  = 0.4*sin(2*pi*0.1*t) + 0.2*sin(2*pi*0.25*t);   % shared systemic
            n1 = 0.3*sin(2*pi*0.03*t);                          % neural, optode 1
            n2 = 0.25*cos(2*pi*0.04*t);                         % neural, optode 2
            e  = @() 0.02*randn(T,1);

            % Columns: [o1w1 o1w2 o2w1 o2w2 o3w1 o3w2 o4w1 o4w2]
            % Optodes 1,2 long; 3,4 short (3 near 1, 4 near 2).
            testCase.odCols = [ n1 + 2.0*S + e(), 0.5*n1 + 1.5*S + e(), ...
                                n2 + 3.0*S + e(), 0.5*n2 + 2.0*S + e(), ...
                                S + e(),          S + e(), ...
                                S + e(),          S + e() ];
            testCase.channels = [1 1 2 2 3 3 4 4];
            testCase.wave     = [730 850 730 850 730 850 730 850];
            testCase.systemic = S;
            testCase.neural1  = n1;

            TableOpt = table();
            TableOpt.OptodeNum = (1:4)';
            TableOpt.SD = [3; 3; 0.8; 0.8];
            TableOpt.IsShortSeparation = [false; false; true; true];
            TableOpt.Pos3D_x = [0; 10; 1; 11];
            TableOpt.Pos3D_y = [0; 0; 0; 0];
            TableOpt.Pos3D_z = [0; 0; 0; 0];
            testCase.probe = struct('TableOpt', TableOpt);
        end
    end

    methods (Test)
        function removesSharedSystemic(testCase)
            odCorr = pf2_base.fnirs.shortChannelRegressionOD( ...
                testCase.odCols, testCase.channels, testCase.wave, testCase.probe);

            % Long channel o1w1 (column 1): systemic correlation should collapse
            before = abs(corr(testCase.odCols(:,1), testCase.systemic));
            after  = abs(corr(odCorr(:,1),          testCase.systemic));
            testCase.verifyGreaterThan(before, 0.8, 'setup: long channel should carry systemic');
            testCase.verifyLessThan(after, 0.15, 'OD SSR should remove the shared systemic');

            % Neural content preserved
            testCase.verifyGreaterThan(abs(corr(odCorr(:,1), testCase.neural1)), 0.9);
        end

        function shortChannelsUnchanged(testCase)
            odCorr = pf2_base.fnirs.shortChannelRegressionOD( ...
                testCase.odCols, testCase.channels, testCase.wave, testCase.probe);
            % Short-channel columns (5:8) are untouched
            testCase.verifyEqual(odCorr(:,5:8), testCase.odCols(:,5:8), 'AbsTol', 1e-12);
        end

        function spaceODDelegationMatches(testCase)
            odCorr = pf2_base.fnirs.shortChannelRegressionOD( ...
                testCase.odCols, testCase.channels, testCase.wave, testCase.probe);

            fNIR.OD = testCase.odCols;
            fNIR.odChannels = testCase.channels;
            fNIR.odWavelengths = testCase.wave;
            fNIR.device = testCase.probe;
            out = pf2_base.fnirs.shortChannelRegression(fNIR, 'Space', 'OD');

            testCase.verifyEqual(out.OD, odCorr, 'AbsTol', 1e-12);
            testCase.verifyEqual(out.ssrInfo.space, 'OD');
        end

        function noShortChannelsIsSafeNoop(testCase)
            % Mark all optodes long -> warns and returns the input unchanged.
            pr = testCase.probe;
            pr.TableOpt.IsShortSeparation(:) = false;
            testCase.verifyWarning(@() pf2_base.fnirs.shortChannelRegressionOD( ...
                testCase.odCols, testCase.channels, testCase.wave, pr), ...
                'pf2:ssrOD:noShortChannels');
            odOut = pf2_base.fnirs.shortChannelRegressionOD( ...
                testCase.odCols, testCase.channels, testCase.wave, pr);
            testCase.verifyEqual(odOut, testCase.odCols, 'AbsTol', 1e-12);
        end
    end
end
