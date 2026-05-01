classdef MethodsEditorTest < matlab.unittest.TestCase
% METHODSEDITORTEST Integration tests for the AppDesigner pf2.methods.Editor.
%
% Tests verify the editor can construct, load methods, react to model
% mutations (validation, undo/redo, step list), and clean up cleanly.
% These are batch-mode tests — uifigure renders but no user input is
% simulated; we exercise the underlying model and confirm the editor
% reflects state correctly.

    properties (Access = private)
        App
    end

    methods (TestMethodSetup)
        function setUp(tc)
            try, pf2_base.Pipeline.loadFuncConfig(true); end %#ok<TRYNC>
        end
    end

    methods (TestMethodTeardown)
        function tearDown(tc)
            if ~isempty(tc.App) && isvalid(tc.App)
                delete(tc.App);
            end
            tc.App = [];
        end
    end

    methods (Test)

        function testConstructLaunches(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            tc.verifyClass(tc.App, 'pf2.methods.Editor');
            tc.verifyTrue(isvalid(tc.App.UIFigure));
        end

        function testRawStageLoadsSavedMethods(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            mp = struct(tc.App); %#ok<*STRNU> % access private fields for testing
            tc.verifyNotEmpty(mp.MethodsListBox.Items);
        end

        function testOxyStageLoadsSavedMethods(tc)
            tc.App = pf2.methods.Editor('Stage','oxy');
            mp = struct(tc.App);
            tc.verifyNotEmpty(mp.MethodsListBox.Items);
        end

        function testModelMutationUpdatesValidation(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            mp = struct(tc.App);
            % Add a bad freq_cut and confirm the validation strip flags it.
            mp.Model.addStep('pf2_lpf', 'freq_cut', -5);
            mp = struct(tc.App);  % refresh
            tc.verifyTrue(contains(mp.ValidationLabel.Text, 'out of range') ...
                || contains(mp.ValidationLabel.Text, 'freq_cut'));
        end

        function testModelMutationUpdatesStepsList(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            mp = struct(tc.App);
            n0 = numel(mp.StepsListBox.Items);
            mp.Model.addStep('pf2_lpf');
            mp = struct(tc.App);
            tc.verifyEqual(numel(mp.StepsListBox.Items), n0+1);
        end

        function testUndoRedoButtonsReflectModelState(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            mp = struct(tc.App);
            mp.Model.addStep('pf2_lpf');
            mp = struct(tc.App);
            tc.verifyEqual(char(mp.UndoButton.Enable), 'on');
            tc.verifyEqual(char(mp.RedoButton.Enable), 'off');
            mp.Model.undo();
            mp = struct(tc.App);
            tc.verifyEqual(char(mp.RedoButton.Enable), 'on');
        end

        function testCleanupOnDelete(tc)
            tc.App = pf2.methods.Editor('Stage','raw');
            fig = tc.App.UIFigure;
            tc.verifyTrue(isvalid(fig));
            delete(tc.App);
            tc.verifyFalse(isvalid(fig));
            tc.App = [];
        end

    end
end
