function suite = buildSuite(lane)
%BUILDSUITE Authoritative test-suite builder for processFNIRS2.
%
%   suite = pf2_base.tests.buildSuite(lane) returns a matlab.unittest.TestSuite
%   for the requested execution lane. This is the single source of truth for
%   which tests exist: every runner (runAllTests, runCI) and every CI gate
%   should build its suite here rather than discovering packages ad hoc.
%
%   Syntax:
%       suite = pf2_base.tests.buildSuite()          % 'full' (default)
%       suite = pf2_base.tests.buildSuite(lane)
%
%   Inputs:
%       lane - (char/string, optional) execution lane. Default 'full'.
%              'full'  - every headless-safe TestCase under pf2_base.tests,
%                        excluding the UI lane. This is the main gate.
%              'ui'    - only tests that create app/uifigure surfaces and may
%                        need a display; run these in their own invocation.
%              'clean' - only the global-state isolation tests, meant to be
%                        run in a fresh MATLAB process (matlab -batch) so a
%                        clean-process replay is genuinely clean. This lane is
%                        a subset of 'full'; it also runs inside 'full'.
%              'all'   - full + ui (everything discoverable).
%
%   Outputs:
%       suite - matlab.unittest.TestSuite (possibly empty for a lane).
%
%   Description:
%       Discovery is authoritative: TestSuite.fromPackage('pf2_base.tests',
%       'IncludingSubpackages', true) sweeps in the root testExperiment class
%       AND every unit/integration subpackage. Non-TestCase helpers (fixtures,
%       synthetic generators, golden utilities, quick scripts) are ignored by
%       fromPackage automatically, so they never leak into a gated run.
%
%       Lane membership for the UI and clean-process lanes is declared once, in
%       the registries below, keyed by fully-qualified test class name. Moving
%       a test between lanes is a one-line edit here; the runners do not encode
%       any lane knowledge of their own.
%
%   Example:
%       % Confirm the root testExperiment class is actually discovered
%       s = pf2_base.tests.buildSuite('full');
%       names = unique(regexprep(string({s.Name}), '/.*$', ''));
%       assert(any(contains(names, 'testExperiment')));
%
%   See also: pf2_base.tests.runAllTests, pf2_base.tests.runCI,
%             pf2_base.tests.runQuickTests, matlab.unittest.TestSuite

    import matlab.unittest.TestSuite;

    if nargin < 1 || isempty(lane)
        lane = 'full';
    end
    lane = lower(string(lane));

    % --- Lane registries (single source of truth) -----------------------
    % Tests that build app/uifigure surfaces. Kept out of 'full' so the main
    % gate does not depend on a display; run explicitly via the 'ui' lane.
    % Add more as a list: ["a.Test", "b.Test"].
    uiClasses = "pf2_base.tests.integration.MethodsEditorTest";

    % Tests that assert global-state isolation (PF2/setF untouched) or a clean
    % replay. Intended to be launched in a fresh process for a true guarantee.
    cleanClasses = [ ...
        "pf2_base.tests.unit.ProcessingContextTest", ...
        "pf2_base.tests.unit.PublicProcessingContextTest", ...
        "pf2_base.tests.integration.ProcessingContextIntegrationTest" ];

    % --- Authoritative discovery ----------------------------------------
    full = TestSuite.fromPackage('pf2_base.tests', 'IncludingSubpackages', true);

    if isempty(full)
        error('pf2:tests:buildSuite:noTests', ...
            ['No tests discovered under pf2_base.tests. Ensure the toolbox is ', ...
             'on the path and test classes inherit from matlab.unittest.TestCase.']);
    end

    parents = regexprep(string({full.Name}), '/.*$', '');
    isUI    = ismember(parents, uiClasses);
    isClean = ismember(parents, cleanClasses);

    % Warn if a registry entry never matched a discovered test: a rename or a
    % typo would otherwise silently shrink a lane.
    warnMissing(uiClasses, parents, 'ui');
    warnMissing(cleanClasses, parents, 'clean');

    switch lane
        case {"full", "headless"}
            suite = full(~isUI);
        case "ui"
            suite = full(isUI);
        case {"clean", "clean-process", "cleanprocess"}
            suite = full(isClean);
        case "all"
            suite = full;
        otherwise
            error('pf2:tests:buildSuite:unknownLane', ...
                'Unknown lane "%s". Use one of: full | ui | clean | all.', lane);
    end
end

function warnMissing(registry, parents, laneName)
    known = unique(parents);
    for i = 1:numel(registry)
        if ~ismember(registry(i), known)
            warning('pf2:tests:buildSuite:unknownLaneMember', ...
                'Lane "%s" registers "%s", which matched no discovered test.', ...
                laneName, registry(i));
        end
    end
end
