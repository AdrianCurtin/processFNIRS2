classdef HyperscanningNullTest < matlab.unittest.TestCase
% HYPERSCANNINGNULLTEST Regression tests for hyperscanning null-model fixes
%
%   Covers three related statistical-validity fixes in the hyperscanning
%   group/permutation/dyad pipeline:
%
%     1. exploreFNIRS.hyperscanning.computeGroup no longer runs an invalid
%        one-sample t-test against ZERO for strictly non-negative coupling
%        measures (PLV, |imaginary coherence|, wPLI, wavelet coherence,
%        coherence) whose finite-sample null under independence is NOT
%        centered at zero. Previously this produced false significance
%        (repro: 30 independent-noise dyad PLVs gave mean ~0.19, t~14,
%        p~2e-14 against a t-test-vs-0). computeGroup now either tests
%        against a per-dyad surrogate/null baseline (if one is attached to
%        the dyad results) or skips the vs-zero test and returns NaN with a
%        pf2:computeGroup:surrogateNullRequired warning.
%
%     2. exploreFNIRS.hyperscanning.permutationTest computes its permutation
%        p-value using the PER-ELEMENT count of non-NaN surrogate values as
%        the denominator, rather than a denominator shared across all
%        elements (rows not WHOLLY NaN), which let a NaN in one element's
%        surrogate silently inflate that element's own denominator without
%        counting as a non-exceedance (anti-conservative / falsely low p).
%
%     3. exploreFNIRS.hyperscanning.computeDyad rejects sampling-rate
%        mismatches beyond a small relative tolerance
%        (pf2:computeDyad:fsMismatch) and aligns the two recordings onto a
%        shared time grid via interpolation, rather than masking each
%        recording's own time vector and then trimming both to a common
%        SAMPLE COUNT -- the latter silently turns clock offset/drift
%        between two independently-clocked acquisition systems into
%        spurious phase lag (or apparent Granger-causality direction).
%
%   Example:
%       results = runtests('pf2_base.tests.unit.HyperscanningNullTest')
%
%   See also: exploreFNIRS.hyperscanning.computeGroup,
%             exploreFNIRS.hyperscanning.permutationTest,
%             exploreFNIRS.hyperscanning.computeDyad

    methods (Test)

        %% (1) computeGroup: no spurious vs-zero significance for PLV
        function noSpuriousSignificanceForIndependentPLV(testCase)
            testCase.assumeTrue(hasSignalProcessingToolbox(), ...
                'Signal Processing Toolbox required for PLV (butter/filtfilt/hilbert).');

            rng(11);
            nDyads = 30;
            data = buildIndependentNoiseDyads(nDyads, 8, 1200);
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data);

            lastwarn('');
            result = exploreFNIRS.hyperscanning.computeGroup(data, pairs, ...
                'Method', 'plv', 'Biomarker', 'HbO', ...
                'CouplingArgs', {'FreqRange', [0.05 0.2]});
            [~, warnID] = lastwarn();

            % Sanity: this reproduces the documented finite-sample bias
            % (mean PLV for independent noise is reliably > 0), confirming
            % this is a genuine exercise of the fix, not a vacuous scenario.
            testCase.verifyGreaterThan(mean(result.Mean, 'omitnan'), 0);

            testCase.verifyTrue(isfield(result, 'nullTest'));
            testCase.verifyTrue(ismember(result.nullTest, {'skipped', 'surrogate'}));

            if strcmp(result.nullTest, 'skipped')
                % No per-dyad surrogate baseline is attached by computeDyad
                % (see extractSurrogateBaseline in computeGroup.m), so the
                % vs-zero test must be skipped rather than falsely
                % "significant", and the caller must be warned.
                testCase.verifyEqual(warnID, 'pf2:computeGroup:surrogateNullRequired');
                testCase.verifyTrue(all(isnan(result.pvalue(:))), ...
                    'p-values must be NaN (not a spurious near-zero p) when the vs-zero test is skipped.');
                testCase.verifyTrue(all(isnan(result.tstat(:))));
            else
                % Forward-compatible path: if a surrogate baseline ever
                % becomes available, the paired test must not flag
                % independent noise as significant.
                testCase.verifyGreaterThan(min(result.pvalue(:)), 0.01, ...
                    'Independent-noise PLV must not appear significant against a valid surrogate null.');
            end
        end

        %% (2) permutationTest: per-element NaN-safe denominator
        function permutationTestPerElementDenominator(testCase)
            testCase.assumeTrue(hasSignalProcessingToolbox(), ...
                'Signal Processing Toolbox required for PLV (butter/filtfilt/hilbert).');

            % Suppress the (separately tested) computeGroup surrogate-null
            % warning here; this test is only about permutationTest's own
            % per-element denominator fix.
            warnState = warning('off', 'pf2:computeGroup:surrogateNullRequired');
            restoreWarn = onCleanup(@() warning(warnState));

            fs = 10;
            T = 100;
            tt = (0:T-1)' / fs;

            % Channel 1: fully valid for every subject, any pairing (control
            % channel -- never NaN, regardless of shuffle).
            rng(21);
            c1A1 = randn(T, 1); c1B1 = randn(T, 1);
            c1A2 = randn(T, 1); c1B2 = randn(T, 1);

            % Channel 2: valid only in a HALF-window that is MATCHED for the
            % original ("diagonal") pairing -- A1/B1 share samples 1:50,
            % A2/B2 share samples 51:100 -- but has ZERO jointly-valid
            % samples for the CROSS pairing (A1/B2, A2/B1 do not overlap at
            % all). PLV returns NaN when fewer than 3 samples are jointly
            % valid (exploreFNIRS.coupling.plv), so:
            %   - the ORIGINAL diagonal pairing (used for `observed`) is
            %     valid for channel 2 (50 jointly-valid samples per dyad),
            %   - the SWAPPED permutation config (randperm(2) == [2 1]) is
            %     guaranteed NaN for channel 2 in BOTH dyads simultaneously,
            %     so that permutation's group-mean for channel 2 is NaN,
            %   - the IDENTITY permutation config (randperm(2) == [1 2])
            %     reproduces the diagonal pairing and stays valid.
            % With nPairs = 2, randperm(2) yields each config with equal
            % probability, so a modest number of permutations reliably
            % yields a MIX of NaN and valid rows for column 2 while column 1
            % never contains a NaN -- exactly the partial-row pattern the
            % old shared-denominator formula mishandled.
            c2A1 = nan(T, 1); c2A1(1:50)   = randn(50, 1);
            c2B1 = nan(T, 1); c2B1(1:50)   = randn(50, 1);
            c2A2 = nan(T, 1); c2A2(51:100) = randn(50, 1);
            c2B2 = nan(T, 1); c2B2(51:100) = randn(50, 1);

            A1 = struct('time', tt, 'fs', fs, 'HbO', [c1A1, c2A1]);
            B1 = struct('time', tt, 'fs', fs, 'HbO', [c1B1, c2B1]);
            A2 = struct('time', tt, 'fs', fs, 'HbO', [c1A2, c2A2]);
            B2 = struct('time', tt, 'fs', fs, 'HbO', [c1B2, c2B2]);

            data = {A1, B1, A2, B2};
            pairs = exploreFNIRS.hyperscanning.pairSubjects(data, ...
                'ManualPairs', {{1, 2}, {3, 4}});  % (A1,B1), (A2,B2): the diagonal

            rng(7);
            result = exploreFNIRS.hyperscanning.permutationTest(data, pairs, ...
                'Permutations', 60, 'Method', 'plv', 'Biomarker', 'HbO', ...
                'ChannelPairing', 'same', 'CouplingArgs', {'FreqRange', [0.5 2]});

            nullCh2 = result.nullDist(:, 2);
            nanMask = isnan(nullCh2);
            testCase.assumeTrue(any(nanMask) && any(~nanMask), ...
                'Need a genuine mix of NaN (cross-shuffle) and valid (diagonal-shuffle) permutations for this check.');

            obs2 = result.observed(2);
            testCase.assertFalse(isnan(obs2), ...
                'observed(2) must come from the valid diagonal (original) pairing.');

            nValidElem = sum(~nanMask);
            nExceed = sum(abs(nullCh2(~nanMask)) >= abs(obs2));
            expectedP = (nExceed + 1) / (nValidElem + 1);
            testCase.verifyEqual(result.pvalue(2), expectedP, 'AbsTol', 1e-12, ...
                'p-value must use the PER-ELEMENT non-NaN surrogate count as its denominator.');

            % Demonstrate the fix versus the old (shared-denominator)
            % formula: channel 1 is never NaN, so no permutation row is
            % WHOLLY NaN, meaning the old denominator ("rows not wholly
            % NaN") equals nPerms for every element -- strictly larger than
            % channel 2's per-element valid count. The old formula would
            % therefore have been anti-conservative for channel 2.
            nPerms = size(result.nullDist, 1);
            buggyP = (nExceed + 1) / (nPerms + 1);
            testCase.verifyLessThan(buggyP, expectedP, ...
                'The old shared-denominator formula would have produced an anti-conservative (too-low) p-value.');

            % Channel 1 is unaffected by the fix (no NaN ever present).
            testCase.verifyGreaterThanOrEqual(result.pvalue(1), 0);
            testCase.verifyLessThanOrEqual(result.pvalue(1), 1);
        end

        %% (3a) computeDyad: sampling-rate mismatch rejection
        function rejectsFsMismatchBeyondTolerance(testCase)
            fs = 10; T = 50;
            fsB = fs * 1.01;  % 1% relative mismatch, well beyond the 0.1% tolerance
            dataA = struct('time', (0:T-1)' / fs,  'fs', fs,  'HbO', randn(T, 1));
            dataB = struct('time', (0:T-1)' / fsB, 'fs', fsB, 'HbO', randn(T, 1));

            testCase.verifyError( ...
                @() exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, 'Method', 'pearson'), ...
                'pf2:computeDyad:fsMismatch');
        end

        function acceptsFsWithinTolerance(testCase)
            fs = 10; T = 50;
            fsB = fs * 1.0005;  % 0.05% relative mismatch, within the 0.1% tolerance
            dataA = struct('time', (0:T-1)' / fs,  'fs', fs,  'HbO', randn(T, 1));
            dataB = struct('time', (0:T-1)' / fsB, 'fs', fsB, 'HbO', randn(T, 1));

            result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, 'Method', 'pearson');
            testCase.verifyTrue(isfield(result, 'values'));
            testCase.verifyFalse(isnan(result.values(1)));
        end

        %% (3b) computeDyad: shared time-grid alignment for offset clocks
        function alignsOffsetTimeVectorsOntoSharedGrid(testCase)
            % Two "recordings" of the SAME underlying sinusoid, but subject
            % B's clock is offset relative to A's by a non-whole-sample
            % amount (as if the two acquisition computers were not started
            % in perfect synchrony). Proper time-based (interpolation)
            % alignment should recover a near-perfect correlation; the
            % PREVIOUS index-trimming approach (reimplemented locally as
            % oldStyleAlign, from the pre-fix source, for comparison only --
            % NOT the current production code path) leaves a residual timing
            % error that measurably degrades it.
            fs = 4; f0 = 0.2; shift = 1.375;  % 5.5 samples: not a whole-sample offset
            T = 400;  % 100 s = 20 periods of f0
            timeA = (0:T-1)' / fs;
            timeB = timeA + shift;
            HbOA = sin(2 * pi * f0 * timeA);
            HbOB = sin(2 * pi * f0 * timeB);  % same true process, on B's own offset clock

            dataA = struct('time', timeA, 'fs', fs, 'HbO', HbOA);
            dataB = struct('time', timeB, 'fs', fs, 'HbO', HbOB);

            result = exploreFNIRS.hyperscanning.computeDyad(dataA, dataB, 'Method', 'pearson');
            rNew = result.values(1);

            rOld = oldStyleAlign(timeA, HbOA, timeB, HbOB, fs);

            testCase.verifyGreaterThan(rNew, 0.999, ...
                'Interpolation-based alignment should recover a near-perfect correlation despite the clock offset.');
            testCase.verifyLessThan(rOld, rNew - 0.01, ...
                'The previous index-trimming approach should measurably underperform proper time-grid alignment.');
        end

    end
end


%%_Local helpers_________________________________________________________

function tf = hasSignalProcessingToolbox()
% HASSIGNALPROCESSINGTOOLBOX Check for butter/cpsd availability (PLV deps)
    tf = ~isempty(which('cpsd')) && ~isempty(which('butter'));
end


function data = buildIndependentNoiseDyads(nDyads, fs, T)
% BUILDINDEPENDENTNOISEDYADS Cell array of nDyads*2 single-channel subjects
%
% Each dyad's two members carry INDEPENDENT white noise (no shared signal),
% so any coupling measure's group-level mean reflects purely its own
% finite-sample bias/null, not real inter-brain synchrony.
%
% Inputs:
%   nDyads - Number of dyads to construct [scalar]
%   fs     - Sampling frequency (Hz) [scalar]
%   T      - Number of time samples per subject [scalar]
%
% Outputs:
%   data - {1 x nDyads*2} cell array of minimal fNIRS-like structs, paired
%          via .info.DyadID for exploreFNIRS.hyperscanning.pairSubjects

    data = cell(nDyads * 2, 1);
    for d = 1:nDyads
        for role = 1:2
            idx = (d - 1) * 2 + role;
            s = struct();
            s.time = (0:T - 1)' / fs;
            s.fs = fs;
            s.fchMask = 1;
            s.HbO = randn(T, 1);
            s.info.SubjectID = sprintf('S%02d_%d', d, role);
            s.info.DyadID = sprintf('D%02d', d);
            s.info.Role = sprintf('Member%d', role);
            data{idx} = s;
        end
    end
end


function r = oldStyleAlign(timeA, sigA, timeB, sigB, fs)
% OLDSTYLEALIGN Reproduce the PRE-FIX computeDyad time-alignment approach
%
% Masks each recording to the overlapping time range using each recording's
% OWN time vector, then trims both masked segments to a common SAMPLE
% COUNT and pairs them by POSITION. This is the behavior
% exploreFNIRS.hyperscanning.computeDyad had before the shared-time-grid
% interpolation fix; it is reproduced here ONLY for comparison in
% alignsOffsetTimeVectorsOntoSharedGrid and is NOT part of any production
% code path.
%
% Inputs:
%   timeA - [T x 1] time vector for subject A (seconds)
%   sigA  - [T x 1] signal for subject A
%   timeB - [T x 1] time vector for subject B (seconds)
%   sigB  - [T x 1] signal for subject B
%   fs    - Sampling frequency (Hz), shared
%
% Outputs:
%   r - Pearson correlation between the position-trimmed segments [scalar]

    tStart = max(timeA(1), timeB(1));
    tEnd = min(timeA(end), timeB(end));

    maskA = timeA >= tStart & timeA <= tEnd;
    maskB = timeB >= tStart & timeB <= tEnd;

    a = sigA(maskA, :);
    b = sigB(maskB, :);

    n = min(size(a, 1), size(b, 1));
    a = a(1:n, :);
    b = b(1:n, :);

    res = exploreFNIRS.coupling.pearson(a, b, fs);
    r = res.value;
end
