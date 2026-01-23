classdef SampleDataFixture < matlab.unittest.fixtures.Fixture
% SAMPLEDATAFIXTURE Test fixture providing pre-loaded fNIRS sample data
%
% Provides shared access to sample fNIRS datasets for unit and integration
% tests. Loading sample data once per test class (via fixture) improves
% test performance compared to loading in each test method.
%
% Reference:
%   Internal pf2 test infrastructure. See matlab.unittest.fixtures.Fixture.
%
% Syntax:
%   fixture = pf2_base.tests.fixtures.SampleDataFixture()
%   testCase.applyFixture(fixture)
%
% Properties:
%   fNIR2000   - fNIR 2000 sample data [struct]
%                18-channel prefrontal probe, 10 Hz sampling rate.
%                Loaded via pf2.import.sampleData.fNIR2000().
%   fNIR1200   - fNIR 1200 sample data [struct]
%                16-channel probe configuration.
%                Loaded via pf2.import.sampleData.fNIR1200().
%   hitachi3x5 - Hitachi ETG-4000 3x5 sample data [struct]
%                22-channel probe (3x5 optode array).
%                Loaded via pf2.import.sampleData.Hitachi_ETG4000_3x5().
%
% Example:
%   classdef MyTest < matlab.unittest.TestCase
%       methods (TestClassSetup)
%           function setupFixture(testCase)
%               fixture = pf2_base.tests.fixtures.SampleDataFixture();
%               testCase.applyFixture(fixture);
%               testCase.addTeardown(@() disp('Fixture cleanup'));
%           end
%       end
%
%       methods (Test)
%           function testProcessing(testCase)
%               fixture = testCase.getSharedTestFixtures(...
%                   'pf2_base.tests.fixtures.SampleDataFixture');
%               data = fixture.fNIR2000;
%               result = processFNIRS2(data);
%               testCase.verifyNotEmpty(result.HbO);
%           end
%       end
%   end
%
% Notes:
%   - Sample data files must exist in processFNIRS2/sampledata/
%   - Fixture loads data silently (channelCheck=false, no GUI)
%   - Data is loaded once and shared across all tests using the fixture
%
% See also: matlab.unittest.fixtures.Fixture, pf2.import.sampleData

    properties (SetAccess = private)
        % fNIR2000 - fNIR 2000 sample data struct
        %   18-channel prefrontal probe, 10 Hz sampling rate.
        %   Contains raw intensity data, markers, and device configuration.
        fNIR2000

        % fNIR1200 - fNIR 1200 sample data struct
        %   16-channel probe configuration.
        %   Contains raw intensity data, markers, and device configuration.
        fNIR1200

        % hitachi3x5 - Hitachi ETG-4000 3x5 sample data struct
        %   22-channel probe from 3x5 optode array.
        %   Contains raw intensity data and device configuration.
        hitachi3x5
    end

    methods
        function setup(fixture)
            % SETUP Load all sample datasets
            %
            % Loads fNIR2000, fNIR1200, and Hitachi 3x5 sample data.
            % Called automatically when fixture is applied to test case.

            % Load fNIR 2000 sample data (18 channels, prefrontal)
            fixture.fNIR2000 = pf2.import.sampleData.fNIR2000();

            % Load fNIR 1200 sample data (16 channels)
            fixture.fNIR1200 = pf2.import.sampleData.fNIR1200();

            % Load Hitachi ETG-4000 3x5 sample data (22 channels)
            fixture.hitachi3x5 = pf2.import.sampleData.Hitachi_ETG4000_3x5();
        end

        function teardown(~)
            % TEARDOWN Clean up after fixture use
            %
            % No cleanup required - data is released when fixture is destroyed.
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fixture, other)
            % ISCOMPATIBLE Check if two fixtures are compatible
            %
            % Returns true if both fixtures are SampleDataFixture instances.
            % Required by matlab.unittest.fixtures.Fixture interface.
            %
            % Inputs:
            %   fixture - This fixture instance
            %   other   - Another fixture to compare
            %
            % Outputs:
            %   tf - True if fixtures are compatible (same class)

            tf = isa(other, 'pf2_base.tests.fixtures.SampleDataFixture');
        end
    end
end
