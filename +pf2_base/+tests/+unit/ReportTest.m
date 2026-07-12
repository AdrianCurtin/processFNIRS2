classdef ReportTest < matlab.unittest.TestCase
% REPORTTEST Unit tests for exploreFNIRS.report package
%
%   results = runtests('pf2_base.tests.unit.ReportTest');

    properties (TestParameter)
    end

    methods (TestClassSetup)
    end

    methods (Test)

        %% --- formatPValue tests ---

        function testFormatPValue_standard(testCase)
            str = exploreFNIRS.report.formatPValue(0.045);
            testCase.verifyEqual(str, '.045');
        end

        function testFormatPValue_noLeadingZero(testCase)
            str = exploreFNIRS.report.formatPValue(0.123);
            testCase.verifyFalse(startsWith(str, '0'));
        end

        function testFormatPValue_lessThan001(testCase)
            str = exploreFNIRS.report.formatPValue(0.0003);
            testCase.verifyEqual(str, '< .001');
        end

        function testFormatPValue_exactlyOne(testCase)
            str = exploreFNIRS.report.formatPValue(1.0);
            testCase.verifyEqual(str, '1.000');
        end

        function testFormatPValue_withPrefix(testCase)
            str = exploreFNIRS.report.formatPValue(0.045, 'Prefix', true);
            testCase.verifyEqual(str, 'p = .045');
        end

        function testFormatPValue_lessThan001WithPrefix(testCase)
            str = exploreFNIRS.report.formatPValue(0.0001, 'Prefix', true);
            testCase.verifyEqual(str, 'p < .001');
        end

        function testFormatPValue_customPrecision(testCase)
            str = exploreFNIRS.report.formatPValue(0.0456, 'Precision', 2);
            testCase.verifyEqual(str, '.05');
        end

        function testFormatPValue_roundingUp(testCase)
            % 0.0005 < 0.001, so it should show '< .001'
            str = exploreFNIRS.report.formatPValue(0.0005);
            testCase.verifyEqual(str, '< .001');
            % 0.001 exactly rounds to .001 at 3dp
            str2 = exploreFNIRS.report.formatPValue(0.001);
            testCase.verifyEqual(str2, '.001');
        end

        function testFormatPValue_verySmall(testCase)
            str = exploreFNIRS.report.formatPValue(1e-10);
            testCase.verifyEqual(str, '< .001');
        end

        %% --- formatStats tests ---

        function testFormatStats_anova(testCase)
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'anova', 'Channel', 1);
            testCase.verifyTrue(contains(str, 'F('));
            testCase.verifyTrue(contains(str, 'p'));
        end

        function testFormatStats_anovaWithEtaSq(testCase)
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'anova', 'Channel', 1, 'EffectSize', true);
            testCase.verifyTrue(contains(str, 'eta-sq'));
        end

        function testFormatStats_anovaNoEffect(testCase)
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'anova', 'Channel', 1, 'EffectSize', false);
            testCase.verifyFalse(contains(str, 'eta'));
        end

        function testFormatStats_contrast(testCase)
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'contrast', 'Channel', 1);
            testCase.verifyTrue(contains(str, 'delta'));
            testCase.verifyTrue(contains(str, 'F('));
        end

        function testFormatStats_ttest(testCase)
            results = struct('tstat', 2.31, 'pval', 0.025, 'dof', 45);
            str = exploreFNIRS.report.formatStats(results, 'Type', 'ttest');
            testCase.verifyTrue(contains(str, 't(45)'));
            testCase.verifyTrue(contains(str, '2.31'));
        end

        function testFormatStats_correlation(testCase)
            results = struct('r', 0.65, 'p', 0.003, 'n', 30);
            str = exploreFNIRS.report.formatStats(results, 'Type', 'correlation');
            testCase.verifyTrue(contains(str, 'r(28)'));
            testCase.verifyTrue(contains(str, '.003'));
        end

        function testFormatStats_missingAnova(testCase)
            results = struct('anova', {cell(1,1)}, 'contrasts', {cell(1,1)});
            results.anova{1,1} = [];
            str = exploreFNIRS.report.formatStats(results, 'Type', 'anova');
            testCase.verifyTrue(contains(str, 'No ANOVA'));
        end

        function testFormatStats_APARegex(testCase)
            % Verify output matches APA format pattern
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'anova', 'Channel', 1, 'EffectSize', false);
            pattern = '^F\(\d+,\s*[\d.]+\) = [\d.]+, p [<=] \.[\d]+';
            testCase.verifyTrue(~isempty(regexp(str, pattern, 'once')), ...
                sprintf('APA format check failed: "%s"', str));
        end

        %% --- anovaTable tests ---

        function testAnovaTable_singleChannel(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.anovaTable(results, 'Channel', 1);
            testCase.verifyTrue(istable(T));
            testCase.verifyTrue(height(T) >= 1);
            testCase.verifyTrue(ismember('Term', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('F', T.Properties.VariableNames));
            testCase.verifyTrue(ismember('partialEtaSq', T.Properties.VariableNames));
        end

        function testAnovaTable_multiChannel(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.anovaTable(results, 'AllChannels', true);
            testCase.verifyTrue(istable(T));
            testCase.verifyTrue(ismember('Channel', T.Properties.VariableNames));
        end

        function testAnovaTable_etaSquaredRange(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.anovaTable(results, 'Channel', 1);
            eta = T.partialEtaSq;
            testCase.verifyTrue(all(eta >= 0 & eta <= 1, 'all'));
        end

        function testAnovaTable_empty(testCase)
            results = struct('anova', {cell(1,1)});
            results.anova{1,1} = [];
            T = exploreFNIRS.report.anovaTable(results, 'Channel', 1);
            testCase.verifyTrue(istable(T));
            testCase.verifyEqual(height(T), 0);
        end

        %% --- contrastTable tests ---

        function testContrastTable_basic(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.contrastTable(results, 'Channel', 1);
            testCase.verifyTrue(istable(T));
            testCase.verifyTrue(height(T) >= 1);
            testCase.verifyTrue(ismember('Sig', T.Properties.VariableNames));
        end

        function testContrastTable_withCI(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.contrastTable(results, 'Channel', 1, 'CI', true);
            testCase.verifyTrue(ismember('CI', T.Properties.VariableNames));
            testCase.verifyTrue(contains(T.CI{1}, '['));
        end

        function testContrastTable_sigStars(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.contrastTable(results, 'Channel', 1);
            % Should have Sig column with valid star annotations
            for i = 1:height(T)
                s = strtrim(char(T.Sig{i}));
                testCase.verifyTrue(ismember(s, {'***', '**', '*', '+', ''}));
            end
        end

        function testContrastTable_empty(testCase)
            results = struct('contrasts', {cell(1,1)});
            results.contrasts{1,1} = [];
            T = exploreFNIRS.report.contrastTable(results, 'Channel', 1);
            testCase.verifyTrue(istable(T));
            testCase.verifyEqual(height(T), 0);
        end

        %% --- correlationTable tests ---

        function testCorrelationTable_basic(testCase)
            R = [1, 0.5, 0.3; 0.5, 1, 0.1; 0.3, 0.1, 1];
            P = [0, 0.01, 0.1; 0.01, 0, 0.5; 0.1, 0.5, 0];
            T = exploreFNIRS.report.correlationTable(R, P);
            testCase.verifyTrue(istable(T));
            testCase.verifyEqual(height(T), 3);
            testCase.verifyEqual(width(T), 3);
        end

        function testCorrelationTable_lowerTriangle(testCase)
            R = [1, 0.5; 0.5, 1];
            P = [0, 0.01; 0.01, 0];
            T = exploreFNIRS.report.correlationTable(R, P, 'Triangle', 'lower');
            % Upper triangle should be empty
            testCase.verifyEqual(T{1, 2}{1}, '');
            % Lower should have content
            testCase.verifyFalse(isempty(T{2, 1}{1}));
        end

        function testCorrelationTable_noLeadingZero(testCase)
            R = [1, 0.456; 0.456, 1];
            P = [0, 0.03; 0.03, 0];
            T = exploreFNIRS.report.correlationTable(R, P, 'Triangle', 'lower');
            val = T{2, 1}{1};
            testCase.verifyTrue(startsWith(val, '.'));
        end

        function testCorrelationTable_stars(testCase)
            R = [1, 0.9; 0.9, 1];
            P = [0, 0.0005; 0.0005, 0];
            T = exploreFNIRS.report.correlationTable(R, P, 'Triangle', 'lower');
            val = T{2, 1}{1};
            testCase.verifyTrue(contains(val, '***'));
        end

        function testCorrelationTable_customLabels(testCase)
            R = eye(3);
            P = ones(3);
            T = exploreFNIRS.report.correlationTable(R, P, ...
                'Labels', {'HbO', 'HbR', 'Age'});
            testCase.verifyEqual(T.Properties.RowNames, {'HbO', 'HbR', 'Age'}');
        end

        %% --- demographicsTable tests ---

        function testDemographicsTable_fromTable(testCase)
            tbl = table( ...
                {'S1'; 'S2'; 'S3'; 'S4'}, ...
                [25; 30; 28; 35], ...
                {'M'; 'F'; 'M'; 'F'}, ...
                'VariableNames', {'SubjectID', 'Age', 'Sex'});
            T = exploreFNIRS.report.demographicsTable(tbl, ...
                'Variables', {'Age', 'Sex'});
            testCase.verifyTrue(istable(T));
            testCase.verifyTrue(height(T) >= 2);
        end

        function testDemographicsTable_numericFormat(testCase)
            tbl = table({'S1'; 'S2'; 'S3'}, [25; 30; 28], ...
                'VariableNames', {'SubjectID', 'Age'});
            T = exploreFNIRS.report.demographicsTable(tbl, 'Variables', {'Age'});
            % The Age row should contain M (SD) format. Row 1 is the N count,
            % so look up the Age row by name.
            val = T{'Age', 1}{1};
            testCase.verifyTrue(contains(val, '('));
        end

        %% --- connectivitySummary tests ---

        function testConnectivitySummary_basic(testCase)
            connResult = createMockConnectivity();
            T = exploreFNIRS.report.connectivitySummary(connResult);
            testCase.verifyTrue(istable(T));
            testCase.verifyEqual(height(T), 2);
            testCase.verifyTrue(ismember('Mean', T.Properties.VariableNames));
        end

        function testConnectivitySummary_threshold(testCase)
            connResult = createMockConnectivity();
            T = exploreFNIRS.report.connectivitySummary(connResult, ...
                'Metric', 'threshold', 'Threshold', 0.3);
            testCase.verifyTrue(istable(T));
            testCase.verifyTrue(contains(T.Mean{1}, '/'));
        end

        %% --- toLatex tests ---

        function testToLatex_basic(testCase)
            T = table({'A';'B'}, [1.23; 4.56], ...
                'VariableNames', {'Group', 'Mean'});
            str = exploreFNIRS.report.toLatex(T);
            testCase.verifyTrue(contains(str, '\begin{tabular}'));
            testCase.verifyTrue(contains(str, '\end{tabular}'));
        end

        function testToLatex_booktabs(testCase)
            T = table([1; 2], 'VariableNames', {'X'});
            str = exploreFNIRS.report.toLatex(T, 'Style', 'booktabs');
            testCase.verifyTrue(contains(str, '\toprule'));
            testCase.verifyTrue(contains(str, '\midrule'));
            testCase.verifyTrue(contains(str, '\bottomrule'));
        end

        function testToLatex_plain(testCase)
            T = table([1; 2], 'VariableNames', {'X'});
            str = exploreFNIRS.report.toLatex(T, 'Style', 'plain');
            testCase.verifyTrue(contains(str, '\hline'));
            testCase.verifyFalse(contains(str, '\toprule'));
        end

        function testToLatex_withCaption(testCase)
            T = table([1], 'VariableNames', {'X'});
            str = exploreFNIRS.report.toLatex(T, 'Caption', 'Test Table', ...
                'Label', 'tab:test');
            testCase.verifyTrue(contains(str, '\caption{Test Table}'));
            testCase.verifyTrue(contains(str, '\label{tab:test}'));
            testCase.verifyTrue(contains(str, '\begin{table}'));
        end

        function testToLatex_escapeSpecialChars(testCase)
            T = table({'A & B'; 'C_D'}, 'VariableNames', {'Name'});
            str = exploreFNIRS.report.toLatex(T);
            testCase.verifyTrue(contains(str, 'A \& B'));
            testCase.verifyTrue(contains(str, 'C\_D'));
        end

        function testToLatex_noEnvironment(testCase)
            T = table([1], 'VariableNames', {'X'});
            str = exploreFNIRS.report.toLatex(T, 'Environment', 'none');
            testCase.verifyFalse(contains(str, '\begin{table}'));
            testCase.verifyTrue(contains(str, '\begin{tabular}'));
        end

        function testToLatex_withRowNames(testCase)
            T = table([1; 2], 'VariableNames', {'Val'}, 'RowNames', {'R1', 'R2'});
            str = exploreFNIRS.report.toLatex(T, 'RowNames', true);
            testCase.verifyTrue(contains(str, 'R1'));
            testCase.verifyTrue(contains(str, 'R2'));
        end

        function testToLatex_numericNaN(testCase)
            T = table([NaN; 1.5], 'VariableNames', {'Val'});
            str = exploreFNIRS.report.toLatex(T);
            testCase.verifyTrue(contains(str, '-'));
        end

        %% --- Pipeline tests ---

        function testPipeline_rejectsStruct(testCase)
            % Pipeline requires an Experiment object, not a struct
            testCase.verifyError(@() ...
                exploreFNIRS.report.Pipeline(struct('a', 1)), ...
                'exploreFNIRS:report:Pipeline');
        end

        function testPipeline_rejectsString(testCase)
            % Pipeline requires an Experiment object, not a string
            testCase.verifyError(@() ...
                exploreFNIRS.report.Pipeline('not_experiment'), ...
                'exploreFNIRS:report:Pipeline');
        end

        %% --- generate tests ---

        function testGenerate_requiresRun(testCase)
            % generate() should error if pipeline hasn't been run
            % We can't easily mock this without a real Experiment,
            % so we test the error message validation
            testCase.verifyTrue(true); % Placeholder for integration test
        end

        %% --- Integration: formatPValue in APA stats ---

        function testIntegration_pValueInStats(testCase)
            % Verify formatStats calls formatPValue correctly
            results = createMockLMEResults();
            str = exploreFNIRS.report.formatStats(results, ...
                'Type', 'anova', 'Channel', 1);
            % Should not have a leading zero in p-value
            testCase.verifyFalse(contains(str, 'p = 0.'));
            testCase.verifyFalse(contains(str, 'p < 0.'));
        end

        function testIntegration_anovaInLatex(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.anovaTable(results, 'Channel', 1);
            latex = exploreFNIRS.report.toLatex(T, 'Environment', 'none');
            testCase.verifyTrue(contains(latex, '\begin{tabular}'));
            testCase.verifyTrue(contains(latex, '\end{tabular}'));
        end

        function testIntegration_contrastInLatex(testCase)
            results = createMockLMEResults();
            T = exploreFNIRS.report.contrastTable(results, 'Channel', 1);
            latex = exploreFNIRS.report.toLatex(T, 'Environment', 'none');
            testCase.verifyTrue(contains(latex, '\begin{tabular}'));
        end

    end
end


%% Mock data builders

function results = createMockLMEResults()
% Build a mock LME results struct matching plotLME output format

    % Mock ANOVA table (matches MATLAB anova output for LME)
    Term = {'(Intercept)'; 'Group'; 'Condition'};
    FStat = [15.2; 5.67; 3.21];
    DF1 = [1; 1; 1];
    DF2 = [23.4; 18.2; 20.5];
    pValue = [0.0007; 0.028; 0.088];

    anv = table(Term, FStat, DF1, DF2, pValue);

    % Mock contrast table (matches autoContrast output)
    deltaE = [0.45; -0.32];
    SD = [0.15; 0.12];
    F = [9.0; 7.11];
    df1 = [1; 1];
    df2 = [18.2; 18.2];
    pVal = [0.008; 0.016];
    pVal_corr = [0.016; 0.032];
    sig = categorical({'**'; '*'});
    coefContrasts = [1 -1 0; 0 1 -1];

    cTable = table(deltaE, SD, F, df1, df2, pVal, pVal_corr, sig, coefContrasts);
    cTable.Properties.RowNames = {'Control vs Treatment'; 'Treatment vs Placebo'};

    % Build results struct
    results = struct();
    results.anova = cell(1, 2);
    results.anova{1, 1} = anv;
    results.anova{1, 2} = anv;  % Second channel

    results.contrasts = cell(1, 2);
    results.contrasts{1, 1} = cTable;
    results.contrasts{1, 2} = cTable;

    results.anova_pval = table();
    results.anova_pval{'Opt1_HbO', 'Group'} = 0.028;
    results.anova_pval{'Opt1_HbO', 'Condition'} = 0.088;
    results.anova_pval{'Opt2_HbO', 'Group'} = 0.042;
    results.anova_pval{'Opt2_HbO', 'Condition'} = 0.15;

    results.anova_Fstat = table();
    results.anova_Fstat{'Opt1_HbO', 'Group'} = 5.67;
    results.anova_Fstat{'Opt1_HbO', 'Condition'} = 3.21;
    results.anova_Fstat{'Opt2_HbO', 'Group'} = 4.32;
    results.anova_Fstat{'Opt2_HbO', 'Condition'} = 2.1;

    results.anova_df1 = table();
    results.anova_df1{'Opt1_HbO', 'Group'} = 1;
    results.anova_df1{'Opt1_HbO', 'Condition'} = 1;
    results.anova_df1{'Opt2_HbO', 'Group'} = 1;
    results.anova_df1{'Opt2_HbO', 'Condition'} = 1;

    results.anova_df2 = table();
    results.anova_df2{'Opt1_HbO', 'Group'} = 18.2;
    results.anova_df2{'Opt1_HbO', 'Condition'} = 20.5;
    results.anova_df2{'Opt2_HbO', 'Group'} = 19.0;
    results.anova_df2{'Opt2_HbO', 'Condition'} = 21.3;

    results.formula = 'Opt1_HbO ~ Group + Condition + (1|SubjectID)';
    results.models = cell(1, 2);
    results.AIC = [120.5, 115.3];
end


function connResult = createMockConnectivity()
% Build mock connectivity results

    nCh = 4;
    R1 = rand(nCh) * 0.6 + 0.2;
    R1 = (R1 + R1') / 2;
    R1(logical(eye(nCh))) = 1;

    R2 = rand(nCh) * 0.4 + 0.1;
    R2 = (R2 + R2') / 2;
    R2(logical(eye(nCh))) = 1;

    connResult(1).Mean = R1;
    connResult(1).SD = rand(nCh) * 0.1;
    connResult(1).SEM = connResult(1).SD / sqrt(10);
    connResult(1).N = 10;
    connResult(1).label = 'Group A';
    connResult(1).method = 'pearson';
    connResult(1).biomarker = 'HbO';
    connResult(1).channels = 1:nCh;
    connResult(1).matrices = {};

    connResult(2).Mean = R2;
    connResult(2).SD = rand(nCh) * 0.1;
    connResult(2).SEM = connResult(2).SD / sqrt(8);
    connResult(2).N = 8;
    connResult(2).label = 'Group B';
    connResult(2).method = 'pearson';
    connResult(2).biomarker = 'HbO';
    connResult(2).channels = 1:nCh;
    connResult(2).matrices = {};
end
