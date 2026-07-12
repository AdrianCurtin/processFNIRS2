%% Generate Sample Report
% Demonstrates the exploreFNIRS.report pipeline using synthetic data
% derived from the built-in fNIR2000 sample dataset.
%
% Outputs:
%   examples/notebooks/sample_report/report.html   - HTML report
%   examples/notebooks/sample_report/report_figures/ - Saved figures

%% Setup
% Ensure we're in the project directory
projectDir = fullfile(fileparts(mfilename('fullpath')), '..');
if ~strcmp(pwd, projectDir)
    cd(projectDir);
end

outDir = fullfile(fileparts(mfilename('fullpath')), 'sample_report');
if ~isfolder(outDir), mkdir(outDir); end

fprintf('=== Generating Sample Report ===\n');
fprintf('Output: %s\n\n', outDir);

%% 1. Import and Process Sample Data
fprintf('--- Step 1: Import & process sample data ---\n');
% Use direct path to sample data
nirFilePath = fullfile(projectDir, 'sampledata', 'sampleNIR_ss.nir');
mrkFilePath = fullfile(projectDir, 'sampledata', 'sampleNIR_ss.mrk');
raw = pf2.import.importNIR(nirFilePath, mrkFilePath, false);
processed = processFNIRS2(raw);

%% 2. Create Synthetic Multi-Subject Dataset
% Duplicate the processed data to simulate 12 subjects across 2 groups
% and 2 conditions (3 per cell).

fprintf('--- Step 2: Building synthetic dataset ---\n');

rng(42);
nPerCell = 5;
groups = {'Control', 'Treatment'};
conditions = {'TaskA', 'TaskB'};

data = {};
idx = 0;
nT = size(processed.HbO, 1);
nCh = size(processed.HbO, 2);

for g = 1:length(groups)
    for c = 1:length(conditions)
        for s = 1:nPerCell
            idx = idx + 1;
            subj = processed;

            % Subject-level random intercept (large, realistic variance)
            subjOffset = randn(1, nCh) * 0.01;

            % Group effect: Treatment has higher HbO activation
            if g == 2
                groupEffect = 0.008 + randn(1, nCh) * 0.002;
            else
                groupEffect = zeros(1, nCh);
            end

            % Condition effect: TaskB has slightly higher activation
            if c == 2
                condEffect = 0.004 + randn(1, nCh) * 0.001;
            else
                condEffect = zeros(1, nCh);
            end

            % Trial-level noise (within-subject variability)
            trialNoise = randn(nT, nCh) * 0.005;

            subj.HbO = subj.HbO + subjOffset + groupEffect + condEffect + trialNoise;
            subj.HbR = subj.HbR + randn(nT, nCh) * 0.002 - groupEffect * 0.3;
            subj.HbTotal = subj.HbO + subj.HbR;
            subj.HbDiff = subj.HbO - subj.HbR;

            % Set metadata
            subj.info.SubjectID = sprintf('S%02d', idx);
            subj.info.Group = groups{g};
            subj.info.Condition = conditions{c};
            subj.info.Age = randi([20, 40]);
            subj.info.Sex = randsample({'M', 'F'}, 1);
            subj.info.Sex = subj.info.Sex{1};

            data{end+1} = subj; %#ok<SAGROW>
        end
    end
end

data = data(:);
fprintf('Created %d synthetic subjects\n', length(data));

%% 3. Create Experiment
fprintf('--- Step 3: Create Experiment ---\n');

ex = exploreFNIRS.core.Experiment(data);
ex.settings.baseline = [-5, 0];
ex.settings.taskStart = 0;
ex.settings.resampleRate = 0.5;
ex.settings.barBinSize = 5;
ex.settings.useBaseline = false;  % Sample data has no clear baseline
ex.summary();

%% 4. Group and Aggregate
fprintf('--- Step 4: Group & Aggregate ---\n');

ex.groupby({'Group', 'Condition'});
ex.aggregate('flat');

%% 5. Run Pipeline
fprintf('--- Step 5: Run report pipeline ---\n');

channels = 1:min(8, size(processed.HbO, 2));

pipe = exploreFNIRS.report.Pipeline(ex, ...
    'Title', 'Sample fNIRS Analysis Report', ...
    'Author', 'processFNIRS2 Demo');

pipe.addStep('demographics', 'Variables', {'Age', 'Sex'});
pipe.addStep('temporal', 'Biomarkers', {'HbO', 'HbR'}, 'Channels', channels, ...
    'PlotBy', 'Condition');
pipe.addStep('bar', 'Biomarker', 'HbO', 'Channels', channels, ...
    'PlotBy', 'Condition');
pipe.addStep('lme', 'Biomarkers', {'HbO'}, 'Channels', channels, 'ShowBar', true);
pipe.addStep('anova', 'AllChannels', true);
pipe.addStep('contrast', 'Channel', 1, 'CI', true);

pipe.run();

%% 6. Generate HTML Report
fprintf('\n--- Step 6: Generate HTML report ---\n');

reportPath = exploreFNIRS.report.generate(pipe, ...
    fullfile(outDir, 'report'), ...
    'DPI', 150, ...
    'IncludeLatex', true);

%% 7. Also generate standalone tables
fprintf('\n--- Step 7: Standalone tables ---\n');

tblNames = fieldnames(pipe.tables);
for i = 1:length(tblNames)
    fprintf('\n%s:\n', tblNames{i});
    disp(pipe.tables.(tblNames{i}));
end

% LaTeX for ANOVA if available
if isfield(pipe.tables, 'anova_5') && height(pipe.tables.anova_5) > 0
    fprintf('\nLaTeX ANOVA table:\n');
    latex = exploreFNIRS.report.toLatex(pipe.tables.anova_5, ...
        'Caption', 'ANOVA Results for HbO Activation', ...
        'Label', 'tab:anova', ...
        'Environment', 'table');
    fprintf('%s\n', latex);
end

% Formatted stats from LME
if isfield(pipe.results, 'lme_4')
    lmeResults = pipe.results.lme_4;
    fprintf('\nFormatted APA statistics:\n');
    for ch = 1:min(3, length(channels))
        str = exploreFNIRS.report.formatStats(lmeResults, ...
            'Type', 'anova', 'Channel', ch);
        fprintf('  Channel %d: %s\n', channels(ch), str);
    end
end

%% Done
fprintf('\n=== Report generation complete ===\n');
fprintf('Open in browser: %s\n', reportPath);

% Close all figures to clean up
close all;
