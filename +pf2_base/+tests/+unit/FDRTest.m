classdef FDRTest < matlab.unittest.TestCase
    % FDRTEST Unit tests for FDR correction functions in exploreFNIRS.fx
    %
    %   This test class verifies the False Discovery Rate correction functions:
    %     - exploreFNIRS.fx.performFDR (standard Benjamini-Hochberg)
    %     - exploreFNIRS.fx.performFDR_twostep (adaptive two-step BH)
    %
    %   Tests cover:
    %     - Basic FDR correction behavior
    %     - Q-value calculation correctness
    %     - Critical k determination
    %     - Edge cases (all significant, none significant, NaN handling)
    %     - Vector and matrix inputs
    %     - Custom threshold parameters
    %     - Two-step adaptive FDR power improvement
    %
    %   Example:
    %       results = runtests('pf2_base.tests.unit.FDRTest');
    %       disp(results);
    %
    %   See also: matlab.unittest.TestCase, exploreFNIRS.fx.performFDR,
    %             exploreFNIRS.fx.performFDR_twostep

    properties
        % Standard test p-value arrays
        sortedPvalues      % Sorted array with mixed significance
        pvaluesWithNaN     % Array containing NaN values
        allSmallPvalues    % All highly significant
        allLargePvalues    % None significant
    end

    methods (TestClassSetup)
        function setupTestData(testCase)
            % Initialize test p-value arrays with known properties

            % Sorted array: mixture of significant and non-significant
            testCase.sortedPvalues = [0.001, 0.01, 0.02, 0.03, 0.06, ...
                                      0.1, 0.2, 0.5, 0.8, 0.9];

            % Array with NaN values
            testCase.pvaluesWithNaN = [0.01, NaN, 0.05, 0.1];

            % All small p-values (highly significant)
            testCase.allSmallPvalues = [0.001, 0.002, 0.003, 0.004, 0.005];

            % All large p-values (none significant)
            testCase.allLargePvalues = [0.5, 0.6, 0.7, 0.8, 0.9];
        end
    end

    %% Standard FDR Tests (performFDR)
    methods (Test)
        function testPerformFDRBasic(testCase)
            % Basic Benjamini-Hochberg procedure with known p-values
            %
            % Verifies that the function runs without error and returns
            % outputs of the expected size and type.

            pvals = testCase.sortedPvalues;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR(pvals);

            % Verify output sizes match input
            testCase.verifyEqual(size(qvalues), size(pvals), ...
                'Q-values must have same size as input p-values');

            % Verify k is a positive scalar
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Critical k must be at least 1');
            testCase.verifyTrue(isscalar(k), ...
                'Critical k must be a scalar');

            % Verify passed is logical array of same size
            testCase.verifyEqual(size(passed), size(pvals), ...
                'Passed array must have same size as input p-values');
            testCase.verifyTrue(islogical(passed), ...
                'Passed must be a logical array');
        end

        function testPerformFDRQvalues(testCase)
            % Q-value calculation correctness
            %
            % Q-values should be >= original p-values (they are adjusted upward).
            % Note: Q-values may exceed 1 for non-significant tests in this
            % implementation (capping only occurs for significant tests).

            pvals = testCase.sortedPvalues;
            [qvalues, ~, passed] = exploreFNIRS.fx.performFDR(pvals);

            % Q-values should be >= p-values (correction makes them larger or equal)
            testCase.verifyGreaterThanOrEqual(qvalues, pvals, ...
                'Q-values must be >= original p-values');

            % Q-values for passed tests should be <= threshold
            if any(passed)
                testCase.verifyLessThanOrEqual(qvalues(passed), 0.05, ...
                    'Q-values for passed tests must be <= threshold');
            end

            % Q-values should not be negative
            testCase.verifyGreaterThanOrEqual(qvalues, 0, ...
                'Q-values must be non-negative');
        end

        function testPerformFDRCriticalK(testCase)
            % Critical k determination
            %
            % The critical k is the largest i where p(i) <= q*i/m.
            % For the sorted p-values array, we can verify k is reasonable.

            pvals = testCase.sortedPvalues;
            m = length(pvals);
            q = 0.05;  % Default threshold

            [~, k, ~] = exploreFNIRS.fx.performFDR(pvals, q);

            % k must be between 1 and m
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Critical k must be at least 1');
            testCase.verifyLessThanOrEqual(k, m, ...
                'Critical k must be at most m');

            % For this specific array, we expect some rejections
            % p=0.001 at i=1: threshold = 0.05*1/10 = 0.005 -> passes
            % p=0.01 at i=2: threshold = 0.05*2/10 = 0.01 -> passes (equals)
            % p=0.02 at i=3: threshold = 0.05*3/10 = 0.015 -> fails
            % So k should be around 2-4 depending on implementation details
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Expected at least 1 rejection for this test array');
        end

        function testPerformFDRAllSignificant(testCase)
            % All p-values small (all should be significant)
            %
            % When all p-values are very small, most or all should pass FDR.

            pvals = testCase.allSmallPvalues;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR(pvals);

            % With very small p-values, most should pass
            testCase.verifyGreaterThanOrEqual(sum(passed), 3, ...
                'Expected most p-values to pass with all small inputs');

            % Q-values should still be reasonable
            testCase.verifyLessThanOrEqual(max(qvalues), 1, ...
                'Q-values should be capped at 1');

            % k should be close to m since many pass
            testCase.verifyGreaterThanOrEqual(k, 3, ...
                'Critical k should be high when many pass');
        end

        function testPerformFDRNoneSignificant(testCase)
            % All p-values large (none should be significant)
            %
            % When all p-values are large (> 0.5), none should pass FDR.

            pvals = testCase.allLargePvalues;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR(pvals);

            % None should pass (all p > 0.5 >> 0.05 threshold)
            testCase.verifyEqual(sum(passed), 0, ...
                'Expected no p-values to pass with all large inputs');

            % Q-values should all be 1 (capped)
            testCase.verifyEqual(qvalues, ones(size(pvals)), ...
                'Q-values should all be 1 when no tests pass');
        end

        function testPerformFDRNaNHandling(testCase)
            % NaN p-values should be handled gracefully
            %
            % NaN values should result in NaN q-values and not pass.

            pvals = testCase.pvaluesWithNaN;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR(pvals);

            % Output should have same size
            testCase.verifyEqual(size(qvalues), size(pvals), ...
                'Output size should match input with NaN values');

            % NaN positions should remain NaN in qvalues or be handled
            nanIdx = isnan(pvals);
            testCase.verifyTrue(all(isnan(qvalues(nanIdx)) | qvalues(nanIdx) == 1), ...
                'NaN p-values should result in NaN or 1 q-values');

            % NaN positions should not pass
            testCase.verifyFalse(any(passed(nanIdx)), ...
                'NaN p-values should not pass FDR');
        end

        function testPerformFDRVectorInput(testCase)
            % Vector input works correctly
            %
            % Both row and column vectors should work.

            pvals_row = testCase.sortedPvalues;  % 1x10 row vector
            pvals_col = pvals_row';              % 10x1 column vector

            [qvals_row, k_row, passed_row] = exploreFNIRS.fx.performFDR(pvals_row);
            [qvals_col, k_col, passed_col] = exploreFNIRS.fx.performFDR(pvals_col);

            % Row vector output should be same size as input
            testCase.verifyEqual(size(qvals_row), size(pvals_row), ...
                'Row vector output should match row vector input size');

            % Column vector output should be same size as input
            testCase.verifyEqual(size(qvals_col), size(pvals_col), ...
                'Column vector output should match column vector input size');

            % k values should be the same regardless of vector orientation
            testCase.verifyEqual(k_row, k_col, ...
                'Critical k should be same for row and column vectors');

            % Number of passed should be the same
            testCase.verifyEqual(sum(passed_row), sum(passed_col), ...
                'Number of passed tests should be same for row and column vectors');
        end

        function testPerformFDRMatrixInput(testCase)
            % Matrix input works correctly
            %
            % The function should handle 2D matrix inputs.

            % Create 3x4 matrix of p-values
            pvals_matrix = [0.001, 0.01, 0.02, 0.03; ...
                           0.05, 0.06, 0.1, 0.2; ...
                           0.3, 0.5, 0.8, 0.9];

            [qvalues, k, passed] = exploreFNIRS.fx.performFDR(pvals_matrix);

            % Output should have same size as input matrix
            testCase.verifyEqual(size(qvalues), size(pvals_matrix), ...
                'Q-values matrix should match input matrix size');
            testCase.verifyEqual(size(passed), size(pvals_matrix), ...
                'Passed matrix should match input matrix size');

            % Q-values should be non-negative
            testCase.verifyGreaterThanOrEqual(qvalues, 0, ...
                'Q-values should be >= 0');

            % Q-values for passed tests should be <= threshold
            if any(passed(:))
                testCase.verifyLessThanOrEqual(qvalues(passed), 0.05, ...
                    'Q-values for passed tests should be <= threshold');
            end

            % k should be a valid positive scalar
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Critical k should be >= 1');
        end

        function testPerformFDRThresholdParameter(testCase)
            % Custom threshold parameter (e.g., 0.1 instead of 0.05)
            %
            % Using a more lenient threshold should result in more rejections.

            pvals = testCase.sortedPvalues;

            [~, ~, passed_strict] = exploreFNIRS.fx.performFDR(pvals, 0.01);
            [~, ~, passed_default] = exploreFNIRS.fx.performFDR(pvals, 0.05);
            [~, ~, passed_lenient] = exploreFNIRS.fx.performFDR(pvals, 0.10);

            % More lenient threshold should result in >= rejections
            testCase.verifyGreaterThanOrEqual(sum(passed_lenient), sum(passed_default), ...
                'Lenient threshold (0.10) should reject >= default (0.05)');
            testCase.verifyGreaterThanOrEqual(sum(passed_default), sum(passed_strict), ...
                'Default threshold (0.05) should reject >= strict (0.01)');
        end

        function testPerformFDRPassedOutput(testCase)
            % Logical array of significant results
            %
            % The passed array should correctly indicate which tests are significant.

            pvals = testCase.sortedPvalues;
            [qvalues, ~, passed] = exploreFNIRS.fx.performFDR(pvals, 0.05);

            % Passed values should have q-value <= threshold AND p < 0.05
            % (Based on implementation: passed requires both conditions)
            for i = 1:length(pvals)
                if passed(i)
                    testCase.verifyLessThanOrEqual(qvalues(i), 0.05, ...
                        'Passed tests should have q-value <= threshold');
                    testCase.verifyLessThan(pvals(i), 0.05, ...
                        'Passed tests should have raw p-value < 0.05');
                end
            end
        end
    end

    %% Two-Step Adaptive FDR Tests (performFDR_twostep)
    methods (Test)
        function testPerformFDRTwostepBasic(testCase)
            % Basic two-step adaptive FDR procedure
            %
            % Verifies that the function runs without error and returns
            % outputs of the expected size and type.

            pvals = testCase.sortedPvalues;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR_twostep(pvals);

            % Verify output sizes match input
            testCase.verifyEqual(size(qvalues), size(pvals), ...
                'Q-values must have same size as input p-values');

            % Verify k is a positive scalar
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Critical k must be at least 1');
            testCase.verifyTrue(isscalar(k), ...
                'Critical k must be a scalar');

            % Verify passed is logical array of same size
            testCase.verifyEqual(size(passed), size(pvals), ...
                'Passed array must have same size as input p-values');
            testCase.verifyTrue(islogical(passed), ...
                'Passed must be a logical array');

            % Q-values should be valid
            testCase.verifyLessThanOrEqual(qvalues, 1, ...
                'Q-values should be <= 1');
        end

        function testPerformFDRTwostepMorePowerful(testCase)
            % Two-step should reject more than standard when many nulls true
            %
            % The adaptive two-step procedure has more power when the
            % proportion of true null hypotheses is high.

            % Create array with few true effects (many nulls)
            % 3 small p-values (true effects), 17 large p-values (true nulls)
            pvals = [0.001, 0.005, 0.01, ...  % True effects
                     0.2, 0.3, 0.4, 0.5, 0.55, 0.6, 0.65, ...  % True nulls
                     0.7, 0.75, 0.8, 0.82, 0.85, 0.88, 0.9, 0.92, 0.95, 0.99];

            [~, ~, passed_standard] = exploreFNIRS.fx.performFDR(pvals, 0.05);
            [~, ~, passed_twostep] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.05);

            % Two-step should reject at least as many as standard
            testCase.verifyGreaterThanOrEqual(sum(passed_twostep), sum(passed_standard), ...
                'Two-step FDR should reject >= standard FDR');

            % Both methods should reject at least the obvious cases (p=0.001, 0.005)
            % Note: This depends on the specific implementation and m value
            % With 20 tests: p=0.001 at i=1, threshold = 0.05*1/20 = 0.0025 -> passes
            testCase.verifyGreaterThanOrEqual(sum(passed_twostep), 1, ...
                'Two-step should reject at least the most significant p-value');
        end

        function testPerformFDRTwostepNaNHandling(testCase)
            % Two-step NaN handling
            %
            % NaN values should be handled gracefully in two-step procedure.

            pvals = testCase.pvaluesWithNaN;
            [qvalues, k, passed] = exploreFNIRS.fx.performFDR_twostep(pvals);

            % Output should have same size
            testCase.verifyEqual(size(qvalues), size(pvals), ...
                'Output size should match input with NaN values');

            % NaN positions should not pass
            nanIdx = isnan(pvals);
            testCase.verifyFalse(any(passed(nanIdx)), ...
                'NaN p-values should not pass two-step FDR');
        end

        function testPerformFDRTwostepAllSignificant(testCase)
            % Two-step with all significant p-values
            %
            % When all p-values are very small, behavior should be similar
            % to standard FDR (no power gain needed).

            pvals = testCase.allSmallPvalues;

            [~, ~, passed_standard] = exploreFNIRS.fx.performFDR(pvals, 0.05);
            [~, ~, passed_twostep] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.05);

            % When all are significant, both methods should give similar results
            % Two-step may actually give same or fewer due to its adjustment
            testCase.verifyGreaterThanOrEqual(sum(passed_twostep), sum(passed_standard) - 1, ...
                'Two-step should have similar rejections to standard when all p-values small');
        end

        function testPerformFDRTwostepNoneSignificant(testCase)
            % Two-step with no significant p-values
            %
            % When all p-values are large, neither method should reject.

            pvals = testCase.allLargePvalues;

            [~, ~, passed_standard] = exploreFNIRS.fx.performFDR(pvals, 0.05);
            [~, ~, passed_twostep] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.05);

            % Neither should reject any
            testCase.verifyEqual(sum(passed_standard), 0, ...
                'Standard FDR should reject none with all large p-values');
            testCase.verifyEqual(sum(passed_twostep), 0, ...
                'Two-step FDR should reject none with all large p-values');
        end

        function testPerformFDRTwostepThresholdParameter(testCase)
            % Two-step with custom threshold
            %
            % Custom threshold should affect rejection rate appropriately.

            pvals = testCase.sortedPvalues;

            [~, ~, passed_strict] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.01);
            [~, ~, passed_default] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.05);
            [~, ~, passed_lenient] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.10);

            % More lenient threshold should result in >= rejections
            testCase.verifyGreaterThanOrEqual(sum(passed_lenient), sum(passed_default), ...
                'Lenient threshold (0.10) should reject >= default (0.05)');
            testCase.verifyGreaterThanOrEqual(sum(passed_default), sum(passed_strict), ...
                'Default threshold (0.05) should reject >= strict (0.01)');
        end

        function testPerformFDRTwostepMatrixInput(testCase)
            % Two-step with matrix input
            %
            % The function should handle 2D matrix inputs.

            % Create 3x4 matrix of p-values
            pvals_matrix = [0.001, 0.01, 0.02, 0.03; ...
                           0.05, 0.06, 0.1, 0.2; ...
                           0.3, 0.5, 0.8, 0.9];

            [qvalues, k, passed] = exploreFNIRS.fx.performFDR_twostep(pvals_matrix);

            % Output should have same size as input matrix
            testCase.verifyEqual(size(qvalues), size(pvals_matrix), ...
                'Q-values matrix should match input matrix size');
            testCase.verifyEqual(size(passed), size(pvals_matrix), ...
                'Passed matrix should match input matrix size');

            % Q-values should be non-negative
            testCase.verifyGreaterThanOrEqual(qvalues, 0, ...
                'Q-values should be >= 0');

            % Q-values for passed tests should be <= threshold
            if any(passed(:))
                testCase.verifyLessThanOrEqual(qvalues(passed), 0.05, ...
                    'Q-values for passed tests should be <= threshold');
            end

            % k should be a valid positive scalar
            testCase.verifyGreaterThanOrEqual(k, 1, ...
                'Critical k should be >= 1');
        end
    end

    %% Consistency Tests Between Methods
    methods (Test)
        function testBothMethodsProduceSameOutputTypes(testCase)
            % Both methods should produce outputs of same types
            %
            % Ensures API consistency between standard and two-step FDR.

            pvals = testCase.sortedPvalues;

            [q1, k1, p1] = exploreFNIRS.fx.performFDR(pvals);
            [q2, k2, p2] = exploreFNIRS.fx.performFDR_twostep(pvals);

            % Same output classes
            testCase.verifyEqual(class(q1), class(q2), ...
                'Q-values should be same class for both methods');
            testCase.verifyEqual(class(k1), class(k2), ...
                'Critical k should be same class for both methods');
            testCase.verifyEqual(class(p1), class(p2), ...
                'Passed should be same class for both methods');

            % Same output sizes
            testCase.verifyEqual(size(q1), size(q2), ...
                'Q-values should be same size for both methods');
            testCase.verifyEqual(size(p1), size(p2), ...
                'Passed should be same size for both methods');
        end

        function testDefaultThresholdIs005(testCase)
            % Default threshold is 0.05 for both methods
            %
            % When no threshold is specified, default should be 0.05.

            pvals = testCase.sortedPvalues;

            % Call without threshold argument
            [~, ~, passed_default] = exploreFNIRS.fx.performFDR(pvals);

            % Call with explicit 0.05
            [~, ~, passed_explicit] = exploreFNIRS.fx.performFDR(pvals, 0.05);

            % Should produce identical results
            testCase.verifyEqual(passed_default, passed_explicit, ...
                'Default threshold should be 0.05 for performFDR');

            % Same test for two-step
            [~, ~, passed_default_2s] = exploreFNIRS.fx.performFDR_twostep(pvals);
            [~, ~, passed_explicit_2s] = exploreFNIRS.fx.performFDR_twostep(pvals, 0.05);

            testCase.verifyEqual(passed_default_2s, passed_explicit_2s, ...
                'Default threshold should be 0.05 for performFDR_twostep');
        end
    end
end
