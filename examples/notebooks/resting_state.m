%% Resting-State fNIRS Connectivity Analysis
% Template for analyzing resting-state functional connectivity.
%
% This notebook covers:
%   1. Import resting-state data
%   2. Compute functional connectivity matrices
%   3. Intra-ROI and inter-ROI connectivity
%   4. Group comparison of connectivity patterns
%   5. Publication-ready matrices and summary tables

%% Configuration

dataDir    = 'path/to/processed/data';
outputDir  = 'results/resting_state';
groupVar   = 'Group';
biomarker  = 'HbO';
channels   = 1:16;
method     = 'pearson';       % 'pearson', 'spearman', 'coherence'
timeWindow = [];              % Full recording (or [start, end] in seconds)

%% 1. Load Data

files = dir(fullfile(dataDir, '*.mat'));
data = cell(length(files), 1);

for i = 1:length(files)
    tmp = load(fullfile(files(i).folder, files(i).name));
    data{i} = tmp.processed;
end

fprintf('Loaded %d datasets\n', length(data));

%% 2. Create Experiment

ex = exploreFNIRS.core.Experiment(data);
ex.summary();

%% 3. Group Data

ex.groupby({groupVar});

%% 4. Compute Connectivity Matrices
% Per-subject connectivity averaged within each group.

connResult = ex.connectivity( ...
    'Method', method, ...
    'Biomarker', biomarker, ...
    'Channels', channels, ...
    'TimeWindow', timeWindow);

%% 5. Visualize Connectivity Matrices

for g = 1:length(connResult)
    fig = exploreFNIRS.connectivity.plotMatrix(connResult(g), ...
        'Title', connResult(g).label, ...
        'Visible', 'off');

    if ~isfolder(outputDir), mkdir(outputDir); end
    pf2_base.plot.saveFigure(fig, ...
        fullfile(outputDir, sprintf('conn_matrix_%s.png', ...
        matlab.lang.makeValidName(connResult(g).label))), ...
        800, 800, 300);
end

%% 6. Connectivity Summary Table

T_conn = exploreFNIRS.report.connectivitySummary(connResult);
disp(T_conn);

%% 7. Correlation Matrix
% Check correlation between connectivity and behavioral/demographic variables.

% Example: correlate global connectivity with age
% nSubj = length(data);
% ages = zeros(nSubj, 1);
% globalConn = zeros(nSubj, 1);
% for s = 1:nSubj
%     ages(s) = data{s}.info.Age;
%     res = exploreFNIRS.connectivity.computeMatrix(data{s}, ...
%         'Method', method, 'Biomarker', biomarker);
%     mask = triu(true(size(res.matrix)), 1);
%     globalConn(s) = mean(res.matrix(mask), 'omitnan');
% end
% [R, P] = corrcoef([ages, globalConn]);
% T_corr = exploreFNIRS.report.correlationTable(R, P, ...
%     'Labels', {'Age', 'GlobalConn'});
% disp(T_corr);

%% 8. Intra-ROI Connectivity (if ROIs defined)
% Requires ROI definitions in the processed data.

% intraResult = ex.intraROI('Method', method, 'Biomarker', biomarker);
% for g = 1:length(intraResult)
%     fprintf('Group: %s\n', intraResult(g).label);
%     for r = 1:length(intraResult(g).roiMetrics)
%         roi = intraResult(g).roiMetrics(r);
%         fprintf('  %s: M=%.3f, SEM=%.3f\n', ...
%             roi.roiName, roi.groupMean, roi.groupSEM);
%     end
% end

%% 9. Demographics

T_demo = exploreFNIRS.report.demographicsTable(ex, ...
    'Variables', {'Age', 'Sex'});
disp(T_demo);

%% 10. LaTeX Tables

latex_conn = exploreFNIRS.report.toLatex(T_conn, ...
    'Caption', 'Resting-State Connectivity', 'Label', 'tab:conn');
fprintf('%s\n', latex_conn);

fprintf('Analysis complete. Results in: %s\n', outputDir);
