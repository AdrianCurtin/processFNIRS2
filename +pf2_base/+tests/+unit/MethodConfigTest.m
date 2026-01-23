classdef MethodConfigTest < matlab.unittest.TestCase
    % METHODCONFIGTEST Unit tests for the method configuration system
    %
    %   This test class verifies that the method configuration system
    %   (pf2.methods.raw and pf2.methods.oxy) functions correctly for
    %   listing, selecting, and describing processing methods.
    %
    %   Tests cover:
    %     - Listing available raw and oxy methods
    %     - Setting methods by name and index
    %     - Describing method configurations
    %     - Verifying required methods exist
    %
    %   Note: These tests do NOT modify the user's saved method configuration.
    %   Methods are only set transiently in the global PF2 variable.
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.MethodConfigTest');
    %       disp(results);
    %
    %   See also: matlab.unittest.TestCase, pf2.methods.raw, pf2.methods.oxy

    methods (TestClassSetup)
        function initializePF2(testCase)
            % Initialize the PF2 global to ensure methods are loaded
            pf2_base.pf2_initialize();
        end
    end

    methods (TestMethodTeardown)
        function resetToNoneMethod(testCase)
            % Reset methods to 'None' after each test to avoid side effects
            % This ensures tests don't affect each other or user configuration
            try
                pf2.methods.raw.setMethod('None');
            catch
                % Ignore errors during teardown
            end
            try
                pf2.methods.oxy.setMethod('None');
            catch
                % Ignore errors during teardown
            end
        end
    end

    %% Raw Method List Tests
    methods (Test)
        function testListRawMethods(testCase)
            % Verify pf2.methods.raw.list() returns a cell array
            %
            % The raw method list should return a cell array of method names
            % when called with an output argument.

            rawMethods = pf2.methods.raw();

            testCase.verifyTrue(iscell(rawMethods), ...
                'pf2.methods.raw() must return a cell array');
        end

        function testListOxyMethods(testCase)
            % Verify pf2.methods.oxy.list() returns a cell array
            %
            % The oxy method list should return a cell array of method names
            % when called with an output argument.

            oxyMethods = pf2.methods.oxy();

            testCase.verifyTrue(iscell(oxyMethods), ...
                'pf2.methods.oxy() must return a cell array');
        end

        function testRawMethodsNotEmpty(testCase)
            % Verify that at least the 'None' method exists in raw methods
            %
            % The raw methods list should never be empty; at minimum the
            % 'None' method must be available for passthrough processing.

            rawMethods = pf2.methods.raw();

            testCase.verifyFalse(isempty(rawMethods), ...
                'Raw methods list must not be empty');
            testCase.verifyGreaterThanOrEqual(length(rawMethods), 1, ...
                'At least one raw method must exist');
        end

        function testOxyMethodsNotEmpty(testCase)
            % Verify that at least the 'None' method exists in oxy methods
            %
            % The oxy methods list should never be empty; at minimum the
            % 'None' method must be available for passthrough processing.

            oxyMethods = pf2.methods.oxy();

            testCase.verifyFalse(isempty(oxyMethods), ...
                'Oxy methods list must not be empty');
            testCase.verifyGreaterThanOrEqual(length(oxyMethods), 1, ...
                'At least one oxy method must exist');
        end
    end

    %% Set Method by Name Tests
    methods (Test)
        function testSetRawMethodByName(testCase)
            % Verify pf2.methods.raw.setMethod('None') works without error
            %
            % Setting a raw method by name should succeed and update the
            % current method in the PF2 global.

            global PF2

            % This should not throw an error
            pf2.methods.raw.setMethod('None');

            % Verify the method was set correctly
            testCase.verifyTrue(isfield(PF2, 'stageRawMethod'), ...
                'PF2.stageRawMethod should exist after setting method');
            testCase.verifyEqual(PF2.stageRawMethod.name, 'None', ...
                'Raw method name should be set to ''None''');
        end

        function testSetOxyMethodByName(testCase)
            % Verify pf2.methods.oxy.setMethod('None') works without error
            %
            % Setting an oxy method by name should succeed and update the
            % current method in the PF2 global.

            global PF2

            % This should not throw an error
            pf2.methods.oxy.setMethod('None');

            % Verify the method was set correctly
            testCase.verifyTrue(isfield(PF2, 'stageOxyMethod'), ...
                'PF2.stageOxyMethod should exist after setting method');
            testCase.verifyEqual(PF2.stageOxyMethod.name, 'None', ...
                'Oxy method name should be set to ''None''');
        end
    end

    %% Set Method by Index Tests
    methods (Test)
        function testSetRawMethodByIndex(testCase)
            % Verify pf2.methods.raw.setMethod(1) works without error
            %
            % Setting a raw method by numeric index should succeed and
            % set the corresponding method from the list.

            global PF2

            % Get method list to know what index 1 should be
            rawMethods = pf2.methods.raw();

            % This should not throw an error
            pf2.methods.raw.setMethod(1);

            % Verify a method was set
            testCase.verifyTrue(isfield(PF2, 'stageRawMethod'), ...
                'PF2.stageRawMethod should exist after setting method by index');
            testCase.verifyEqual(PF2.stageRawMethod.name, rawMethods{1}, ...
                'Raw method should match first method in list');
        end

        function testSetOxyMethodByIndex(testCase)
            % Verify pf2.methods.oxy.setMethod(1) works without error
            %
            % Setting an oxy method by numeric index should succeed and
            % set the corresponding method from the list.

            global PF2

            % Get method list to know what index 1 should be
            oxyMethods = pf2.methods.oxy();

            % This should not throw an error
            pf2.methods.oxy.setMethod(1);

            % Verify a method was set
            testCase.verifyTrue(isfield(PF2, 'stageOxyMethod'), ...
                'PF2.stageOxyMethod should exist after setting method by index');
            testCase.verifyEqual(PF2.stageOxyMethod.name, oxyMethods{1}, ...
                'Oxy method should match first method in list');
        end
    end

    %% Describe Method Tests
    methods (Test)
        function testDescribeRawMethod(testCase)
            % Verify pf2.methods.raw.describeMethod('None') returns a string
            %
            % The describe function should return a string containing
            % information about the specified method.

            descrip = pf2.methods.raw.describeMethod('None');

            testCase.verifyTrue(ischar(descrip) || isstring(descrip), ...
                'describeMethod must return a string or char array');
            testCase.verifyFalse(isempty(descrip), ...
                'Method description must not be empty');
            testCase.verifyTrue(contains(descrip, 'None'), ...
                'Description should contain the method name');
        end

        function testDescribeOxyMethod(testCase)
            % Verify pf2.methods.oxy.describeMethod('None') returns a string
            %
            % The describe function should return a string containing
            % information about the specified method.

            descrip = pf2.methods.oxy.describeMethod('None');

            testCase.verifyTrue(ischar(descrip) || isstring(descrip), ...
                'describeMethod must return a string or char array');
            testCase.verifyFalse(isempty(descrip), ...
                'Method description must not be empty');
            testCase.verifyTrue(contains(descrip, 'None'), ...
                'Description should contain the method name');
        end
    end

    %% None Method Existence Tests
    methods (Test)
        function testNoneMethodAlwaysExists(testCase)
            % Verify 'None' is in both raw and oxy method lists
            %
            % The 'None' method is a required passthrough method that must
            % always be available in both processing stages.

            rawMethods = pf2.methods.raw();
            oxyMethods = pf2.methods.oxy();

            testCase.verifyTrue(ismember('None', rawMethods), ...
                '''None'' method must exist in raw methods list');
            testCase.verifyTrue(ismember('None', oxyMethods), ...
                '''None'' method must exist in oxy methods list');
        end
    end

    %% Method Names Type Tests
    methods (Test)
        function testMethodNamesAreStrings(testCase)
            % Verify all method names are strings or char arrays
            %
            % Method names must be text (string or char) for use in
            % setMethod and other functions.

            rawMethods = pf2.methods.raw();
            oxyMethods = pf2.methods.oxy();

            % Check raw methods
            for i = 1:length(rawMethods)
                isText = ischar(rawMethods{i}) || isstring(rawMethods{i});
                testCase.verifyTrue(isText, ...
                    sprintf('Raw method %d must be a string or char', i));
            end

            % Check oxy methods
            for i = 1:length(oxyMethods)
                isText = ischar(oxyMethods{i}) || isstring(oxyMethods{i});
                testCase.verifyTrue(isText, ...
                    sprintf('Oxy method %d must be a string or char', i));
            end
        end
    end

    %% Additional Robustness Tests
    methods (Test)
        function testDescribeRawMethodByIndex(testCase)
            % Verify describing a raw method by index works
            %
            % The describeMethod function should accept numeric indices
            % as well as method names.

            descrip = pf2.methods.raw.describeMethod(1);

            testCase.verifyTrue(ischar(descrip) || isstring(descrip), ...
                'describeMethod with index must return a string');
            testCase.verifyFalse(isempty(descrip), ...
                'Method description by index must not be empty');
        end

        function testDescribeOxyMethodByIndex(testCase)
            % Verify describing an oxy method by index works
            %
            % The describeMethod function should accept numeric indices
            % as well as method names.

            descrip = pf2.methods.oxy.describeMethod(1);

            testCase.verifyTrue(ischar(descrip) || isstring(descrip), ...
                'describeMethod with index must return a string');
            testCase.verifyFalse(isempty(descrip), ...
                'Method description by index must not be empty');
        end

        function testDescribeMethodReturnsSecondOutput(testCase)
            % Verify describeMethod returns function cell array as second output
            %
            % When called with two output arguments, describeMethod should
            % return the function configuration cell array.

            [~, funcs] = pf2.methods.raw.describeMethod('None');

            testCase.verifyTrue(iscell(funcs), ...
                'Second output of describeMethod must be a cell array');
        end

        function testMethodListIsCurrent(testCase)
            % Verify the isCurrent output indicates the current method
            %
            % The raw() and oxy() functions return a second output indicating
            % which method is currently selected.

            % Set a known method first
            pf2.methods.raw.setMethod('None');

            [rawMethods, isCurrent] = pf2.methods.raw();

            testCase.verifyEqual(length(isCurrent), length(rawMethods), ...
                'isCurrent must have same length as methods list');
            testCase.verifyTrue(islogical(isCurrent), ...
                'isCurrent must be a logical array');

            % Find 'None' in the list and verify it's marked as current
            noneIdx = find(strcmp(rawMethods, 'None'));
            if ~isempty(noneIdx)
                testCase.verifyTrue(isCurrent(noneIdx), ...
                    'None should be marked as current after setMethod(''None'')');
            end
        end
    end
end
