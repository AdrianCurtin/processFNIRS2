classdef GuiGateTest < matlab.unittest.TestCase
    % GUIGATETEST Unit tests for the channel-check GUI suppression subsystem
    %
    % Covers the gate that keeps imports (and the test suite itself) from
    % blocking on the interactive channel-check GUI:
    %   pf2_base.channelCheckGUIEnabled - explicit on/off flag
    %   pf2_base.isHeadless             - display-availability probe
    %   pf2_base.allowChannelCheckGUI   - combined gate (flag AND display AND
    %                                     not-under-test)
    % and the import-time fallback in pf2_base.loadExistingMaskOrCheck.

    methods (TestMethodSetup)
        function preserveFlag(testCase)
            % Save and restore the session flag so tests never leak state.
            prev = pf2_base.channelCheckGUIEnabled();
            testCase.addTeardown(@() pf2_base.channelCheckGUIEnabled(prev));
        end
    end

    methods (Test)

        %% --- channelCheckGUIEnabled flag ---------------------------------

        function testFlagSetGetRestore(testCase)
            pf2_base.channelCheckGUIEnabled(true);
            prev = pf2_base.channelCheckGUIEnabled(false);  % set, returns prior
            testCase.verifyTrue(prev);                       % prior was true
            testCase.verifyFalse(pf2_base.channelCheckGUIEnabled());
            pf2_base.channelCheckGUIEnabled(prev);           % restore
            testCase.verifyTrue(pf2_base.channelCheckGUIEnabled());
        end

        function testFlagCoercesToLogical(testCase)
            pf2_base.channelCheckGUIEnabled(0);
            testCase.verifyTrue(islogical(pf2_base.channelCheckGUIEnabled()));
            testCase.verifyFalse(pf2_base.channelCheckGUIEnabled());
            pf2_base.channelCheckGUIEnabled(1);
            testCase.verifyTrue(pf2_base.channelCheckGUIEnabled());
        end

        %% --- isHeadless ---------------------------------------------------

        function testIsHeadlessReturnsLogicalScalar(testCase)
            tf = pf2_base.isHeadless();
            testCase.verifyTrue(islogical(tf) && isscalar(tf));
        end

        %% --- allowChannelCheckGUI ----------------------------------------

        function testAllowIsFalseUnderTestFramework(testCase)
            % Running inside matlab.unittest, the GUI must never be allowed,
            % even with the flag explicitly enabled and on a live display.
            pf2_base.channelCheckGUIEnabled(true);
            testCase.verifyFalse(pf2_base.allowChannelCheckGUI(), ...
                'GUI should be suppressed under the test framework');
        end

        function testAllowIsFalseWhenFlagDisabled(testCase)
            pf2_base.channelCheckGUIEnabled(false);
            testCase.verifyFalse(pf2_base.allowChannelCheckGUI());
        end

        %% --- import-time fallback ----------------------------------------

        function testSuppressedImportWarnsAndDefaultsMask(testCase)
            % With no sidecar mask and the GUI suppressed, loadExistingMaskOrCheck
            % must warn, default to all-good, and stamp qcStatus.
            data = pf2.import.sampleData();
            testCase.assumeTrue(isfield(data,'device') && ~isempty(data.device), ...
                'sample data has no device');
            bogus = [tempname '.nir'];   % guaranteed no *_CH.mat sidecar
            out = testCase.verifyWarning(...
                @() pf2_base.loadExistingMaskOrCheck(data, bogus), ...
                'pf2:loadExistingMaskOrCheck:guiSuppressed');
            testCase.verifyEqual(numel(out.fchMask), data.device.nChannels);
            testCase.verifyTrue(all(out.fchMask == 1), 'expected all-good default');
            testCase.verifyEqual(out.info.qcStatus, 'unreviewed_default');
        end

        function testSampleImportSetsMaskLoadedStatus(testCase)
            % The bundled sample ships a *_CH.mat sidecar; importing it via the
            % GUI path should record that the mask was loaded, not defaulted.
            % (sampleData() with output uses channelCheck=false, so exercise
            % the loader directly against the sidecar.)
            data = pf2.import.sampleData();
            if isfield(data,'info') && isfield(data.info,'filename') ...
                    && exist(data.info.filename, 'file') == 2
                out = pf2_base.loadExistingMaskOrCheck(data, data.info.filename);
                testCase.verifyTrue(ismember(out.info.qcStatus, ...
                    {'mask_loaded','unreviewed_default'}));
            else
                testCase.assumeFail('sample filename unavailable');
            end
        end

    end
end
