%% example_group_stats_bridge.m
% Bridge group statistics (Layer 2) to brain projection (Layer 1 viz).
%
% The two visualization families serve different roles:
%   - exploreFNIRS Experiment.plotLME / plotTopoLME  COMPUTE group statistics
%     (fits an LME per channel) and can map them.
%   - pf2.probe.project.*  only RENDER a stat vector you already have.
%
% This script closes the loop most users miss: run an LME with plotLME,
% pull the per-channel p-values and F-statistics out of its results struct,
% and project them onto the cortical surface with pf2.probe.project.pvalues
% and pf2.probe.project.fstats.
%
% Sections:
%   1. Build a group in one call
%   2. Fit the group LME (compute) and inspect results
%   3. Map the Condition term to the full probe and project p-values
%   4. Project F-statistics
%   5. The all-in-one alternative: plotTopoLME
%
% See also: pf2.import.sampleData.group, exploreFNIRS.core.Experiment,
%           pf2.probe.project.pvalues, pf2.probe.project.fstats

% Optional: where to save figures. Leave commented to just display them.
% outDir = '/tmp/group_stats_bridge';
% if ~exist(outDir, 'dir'); mkdir(outDir); end

%% Section 1: Build a group in one call
fprintf('\n=== Section 1: Build group ===\n');

% pf2.import.sampleData.group() returns a ready, grouped, aggregated
% Experiment plus the underlying segments. No block boilerplate required.
[ex, allData] = pf2.import.sampleData.group();
seg = allData{1};                 % any segment carries the probe geometry
nOpt = size(seg.HbO, 2);          % full optode count (includes short-sep)
fprintf('Built Experiment with %d segments, %d-optode probe.\n', ...
    numel(allData), nOpt);

%% Section 2: Fit the group LME (compute) and inspect results
fprintf('\n=== Section 2: Fit LME ===\n');

% plotLME fits one LME per channel: HbO ~ Condition + (1|SubjectID).
% Short-separation channels are excluded by default, so results cover the
% non-SS channels and results.channels tells us which probe optodes those are.
[~, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Visible', 'off');

% results.anova_pval / anova_Fstat are [channels x terms] tables.
fprintf('ANOVA terms: %s\n', ...
    strjoin(results.anova_pval.Properties.VariableNames, ', '));
fprintf('Channels modeled: %s\n', mat2str(results.channels));

%% Section 3: Map the Condition term to the full probe and project p-values
fprintf('\n=== Section 3: Project p-values ===\n');

% Pull the Condition column (per modeled channel) ...
pCondition = results.anova_pval.Condition;       % [nModeled x 1]

% ... and scatter it into a full-probe vector. results.channels are absolute
% optode numbers, so unmodeled optodes (e.g. short-separation) stay NaN and
% render transparent.
pFull = nan(1, nOpt);
pFull(results.channels) = pCondition;

% Project. Channels with p >= pThreshold render transparent (brain shows
% through); 'includeSS', true keeps the full-probe layout so our indices line up.
pf2.probe.project.pvalues(pFull, seg, ...
    'pThreshold', 0.05, 'includeSS', true, ...
    'titleString', 'Condition effect (p)', 'ForceLightMode', true);
% Headless save (the supported way — see interpolateValues3D Notes):
% pf2.probe.project.pvalues(pFull, seg, 'pThreshold', 0.05, 'includeSS', true, ...
%     'ForceLightMode', true, 'savePath', fullfile(outDir, 'pvalues_condition.png'));

%% Section 4: Project F-statistics
fprintf('\n=== Section 4: Project F-statistics ===\n');

Fcondition = results.anova_Fstat.Condition;      % [nModeled x 1]
Ffull = nan(1, nOpt);
Ffull(results.channels) = Fcondition;

pf2.probe.project.fstats(Ffull, seg, ...
    'includeSS', true, ...
    'titleString', 'Condition effect (F)', 'ForceLightMode', true);
% pf2.probe.project.fstats(Ffull, seg, 'includeSS', true, 'ForceLightMode', true, ...
%     'savePath', fullfile(outDir, 'fstats_condition.png'));

%% Section 5: The all-in-one alternative
fprintf('\n=== Section 5: plotTopoLME (compute + project together) ===\n');

% If you just want the map and do not need the raw stat vector, plotTopoLME
% computes the LME and projects it in a single call. Use the bridge above
% when you need the p-values/F-stats themselves (e.g. to FDR-correct, export,
% or threshold differently before projecting).
ex.plotTopoLME('Biomarkers', {'HbO'}, 'Visible', 'off');
% ex.plotTopoLME('Biomarkers', {'HbO'}, 'Visible', 'off', ...
%     'SavePath', fullfile(outDir, 'topoLME.png'));

fprintf('\nDone. plotLME results -> project.pvalues/fstats bridge complete.\n');
