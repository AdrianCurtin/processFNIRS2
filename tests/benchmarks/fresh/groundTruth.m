function gt = groundTruth()
% GROUNDTRUTH FRESH study ground truth: group pipeline configs and hypothesis outcomes
%
% Returns a struct containing the published hypothesis results from all 38
% contributing groups in the FRESH study (Yuecel et al. 2025), along with
% the pipeline configuration each group used. This serves as the reference
% for processing symmetry validation — comparing pf2 outputs against the
% published results when using equivalent preprocessing steps.
%
% Data source: https://github.com/ibs-lab/FRESH/tree/main/data
%
% Syntax:
%   gt = groundTruth()
%
% Outputs:
%   gt - Struct with fields:
%     .study1  - Study 1 (Auditory) results
%       .consensus   - [1x7] majority vote (true = Yes)
%       .rates       - [1x7] fraction of groups voting Yes
%       .groups      - Struct array of per-group results
%     .study2  - Study 2 (Motor) per-participant results
%     .pipelineMap - Mapping from FRESH pipeline archetypes to pf2 equivalents
%
% See also: benchmarks.fresh.compareToGroups, benchmarks.fresh.definePipelines

gt = struct();

%% Study 1 (Auditory): H1-H7 group-level results
% Hypotheses:
%   H1: Speech activates bilateral Heschl's gyri (HbO increase)
%   H2: Noise activates bilateral Heschl's gyri (HbO increase)
%   H3: Speech activates left IFG (HbO increase)
%   H4: Speech > noise in left Heschl's gyrus
%   H5: Speech > noise in left IFG
%   H6: No significant activation in occipital cortex (speech)
%   H7: No significant activation in occipital cortex (noise)

% Per-group results (NaN = not reported)
%          ID   H1  H2  H3  H4  H5  H6  H7
results = [
     2,    1,   1,   0,   0,   1,   0,   0
     4,    1, NaN, NaN, NaN, NaN, NaN, NaN
     5,    0,   0,   0,   0,   0,   0,   0
     6,    0,   0,   0,   0,   0,   0,   0
     7,    1,   0,   0,   0,   0,   0,   0
     8,    0,   0, NaN,   0,   0,   0,   0
     9,    1, NaN, NaN, NaN, NaN, NaN, NaN
    10,    1,   1,   0,   0,   0,   0,   1
    11,    0, NaN, NaN, NaN, NaN, NaN, NaN
    12,    1,   1,   1,   1,   1,   1,   0
    14,    1,   0,   1,   0,   0,   0,   0
    15,    1,   1,   0,   0,   0,   0,   0
    17,    1, NaN, NaN, NaN, NaN, NaN, NaN
    18,    1, NaN, NaN, NaN, NaN, NaN, NaN
    19,    1,   1,   0,   0,   0,   0,   0
    20,    1,   1,   0,   0,   0,   0,   0
    21,    1, NaN, NaN, NaN, NaN, NaN, NaN
    22,    1,   1,   0,   0,   0,   0,   0
    24,    0,   0,   0,   0,   0,   0,   0
    25,    1, NaN, NaN, NaN, NaN, NaN, NaN
    26,    1, NaN, NaN, NaN, NaN, NaN, NaN
    28,    1, NaN, NaN, NaN, NaN, NaN, NaN
    29,  NaN, NaN, NaN,   1,   1,   1,   1
    30,    1,   0,   1,   0,   1,   0,   0
    31,    1, NaN, NaN, NaN, NaN, NaN, NaN
    32,    1, NaN, NaN, NaN, NaN, NaN, NaN
    33,    1,   1, NaN, NaN, NaN, NaN, NaN
    34,    1, NaN, NaN, NaN, NaN, NaN, NaN
    35,    1, NaN, NaN, NaN, NaN, NaN, NaN
    36,    1, NaN, NaN, NaN, NaN, NaN, NaN
    37,    1,   1,   0,   0,   0,   0,   0
    38,    0,   0,   0,   1,   0,   0,   1
];

gt.study1.results = results;
gt.study1.groupIDs = results(:, 1);
gt.study1.hypotheses = results(:, 2:8);

% Consensus: majority vote (>50% of groups that reported)
for h = 1:7
    vals = results(:, h+1);
    vals = vals(~isnan(vals));
    gt.study1.rates(h) = mean(vals);
    gt.study1.consensus(h) = mean(vals) > 0.5;
end

gt.study1.nGroups = size(results, 1);
gt.study1.hypothesisNames = {
    'H1: Speech activates bilateral Heschl''s gyri'
    'H2: Noise activates bilateral Heschl''s gyri'
    'H3: Speech activates left IFG'
    'H4: Speech > noise in left Heschl''s gyrus'
    'H5: Speech > noise in left IFG'
    'H6: No activation in occipital (speech)'
    'H7: No activation in occipital (noise)'
};

%% Study 2 (Motor): H1-H4 per-participant results
% Hypotheses:
%   H1: Left tapping activates right motor cortex (HbO increase)
%   H2: Right tapping activates left motor cortex (HbO increase)
%   H3: Contralateral > ipsilateral activation
%   H4: 3s blocks produce larger responses than 2s blocks
%
% Unlike Study 1 (group-level binary), Study 2 reports individual-level
% results for 10 participants. We store the fraction of participants
% in each group that confirmed each hypothesis.
% NaN = not investigated by that group.

%            ID    H1    H2    H3    H4
results2 = [
     1,   0.40, 0.40, 0.30, 0.00
     2,   0.40, 0.60, 0.60, 0.40
     3,   0.20, 0.30, 0.70, 0.40
     4,   0.20, 0.00, 0.00, 0.00
     5,   0.00, 0.10, 0.10, 0.10
     6,   0.00, 0.29, 0.43, 0.00
     7,   0.20, 0.90, 0.90, 0.00
     8,   0.00, 0.22, 0.44, 0.11
     9,   0.80, 0.90, 0.80, 0.60
    10,   0.20, 0.00, 0.00, 0.00
    11,   0.80, 0.40, 0.30,  NaN
    12,   0.90, 1.00, 1.00, 0.70
    13,   0.50, 0.30, 0.30, 0.10
    14,   0.30, 0.00, 0.10, 0.00
    15,   0.70, 0.70, 0.60, 0.50
    16,   0.00, 1.00, 0.33, 1.00
    17,   0.70, 0.80, 0.80, 0.20
    18,   0.50, 0.50, 0.40, 0.50
    19,   0.80, 1.00, 1.00, 0.00
    20,   0.30, 0.30, 0.10, 0.40
    21,   0.70, 0.90, 1.00, 0.30
    22,   0.40, 0.80, 0.90, 0.30
    24,   0.00, 0.00, 0.00, 0.00
    25,   0.30, 0.10, 0.10, 0.10
    26,   0.50, 0.40, 0.90, 0.10
    27,   0.70, 0.60, 0.80, 0.00
    28,   0.40,  NaN,  NaN,  NaN
    29,   0.22, 0.67, 1.00, 0.11
    30,   0.50, 0.70, 0.80, 0.20
    32,   0.80, 1.00, 1.00, 1.00
    33,   0.30, 0.30, 0.00, 0.00
    36,   0.60, 0.90, 0.90, 0.60
    38,   0.60, 0.60, 0.80, 0.00
];

gt.study2.results = results2;
gt.study2.groupIDs = results2(:, 1);
gt.study2.passRates = results2(:, 2:5);  % fraction of participants passing

% Consensus: mean pass rate across groups, threshold at 0.5
for h = 1:4
    vals = results2(:, h+1);
    vals = vals(~isnan(vals));
    gt.study2.meanRates(h) = mean(vals);
    gt.study2.consensus(h) = mean(vals) > 0.5;
end

gt.study2.nGroups = size(results2, 1);
gt.study2.nParticipants = 10;
gt.study2.hypothesisNames = {
    'H1: Left tapping activates right motor cortex'
    'H2: Right tapping activates left motor cortex'
    'H3: Contralateral > ipsilateral activation'
    'H4: 3s blocks > 2s blocks'
};

%% Per-group pipeline configurations (from FreshData.csv)
% Each group's actual processing pipeline, mapped to the closest pf2
% equivalent. Data extracted from the FRESH GitHub CSV.
%
% Fields:
%   .id         - FRESH group ID
%   .toolbox    - Original toolbox used
%   .motion     - Motion correction method
%   .motionType - Simplified: 'TDDR','Wavelet','Spline+Wavelet','tPCA',
%                 'SplineSG','CBSI','AR-IRLS','None','Combo'
%   .filter     - Filter description
%   .filterHP   - Highpass cutoff Hz (NaN if none)
%   .filterLP   - Lowpass cutoff Hz (NaN if none)
%   .dpf        - DPF/PPF setting used
%   .analysis   - 'GLM' or 'BlockAvg'
%   .ssr        - Short-channel regression used [logical]
%   .pf2Name    - Closest pf2 block-averaging pipeline name
%   .pf2GLMName - Closest pf2 GLM pipeline name ('' if none)
%   .gap        - Description of key difference between FRESH and pf2

idx = 0;

% --- Group 1: OpenPoTATo, no MC, BP 0.01-1.0, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(1, 'OpenPoTATo', 'None', 'None', ...
    'BP 0.01-1.0', 0.01, 1.0, 'N/A', 'BlockAvg', false, ...
    'minimal', '', '');

% --- Group 2: TDDR, LP 0.4, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(2, 'Custom', 'TDDR', 'TDDR', ...
    'LP 0.4', NaN, 0.4, 'DPF=[6 6]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 3: Spline+Wavelet, BP 0.01-0.2, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(3, 'HOMER3', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'BP 0.01-0.2', 0.01, 0.2, 'DPF=[6 6]', 'BlockAvg', false, ...
    'spline_wavelet', '', '');

% --- Group 4: Rejection only, BP 0.01-0.7, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(4, 'Matlab', 'Rejection', 'None', ...
    'BP 0.01-0.7', 0.01, 0.7, 'N/A', 'BlockAvg', false, ...
    'minimal', '', 'MC=rejection only (not correction)');

% --- Group 5: Targeted PCA, BP 0.01-0.5, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(5, 'HOMER3', 'Targeted PCA', 'tPCA', ...
    'BP 0.01-0.5', 0.01, 0.5, 'DPF=[6 6]', 'BlockAvg', false, ...
    'tddr_bpf', '', 'tPCA not implemented in pf2');

% --- Group 6: Wavelet, LP 0.5, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(6, 'HOMER3+QT-NIRS', 'Wavelet', 'Wavelet', ...
    'LP 0.5', NaN, 0.5, 'PPF=[1 1]', 'BlockAvg', false, ...
    'wavelet_bpf', '', '');

% --- Group 7: TDDR, BP 0.01-0.3, GLM (AR1), SSR ---
idx=idx+1; gp(idx) = makeGroup(7, 'MNE', 'TDDR', 'TDDR', ...
    'BP 0.01-0.3 FIR', 0.01, 0.3, 'PPF=[0.115 0.115]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 8: Wavelet, BP 0.01-0.3, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(8, 'HOMER3+QT-NIRS', 'Wavelet', 'Wavelet', ...
    'BP 0.01-0.3', 0.01, 0.3, 'DPF=[6 6]', 'GLM', true, ...
    'wavelet_bpf', '', '');

% --- Group 9: Wavelet, BP 0.016-0.5, GLM (pre-whiten), SSR ---
idx=idx+1; gp(idx) = makeGroup(9, 'AnalyzIR', 'Wavelet', 'Wavelet', ...
    'BP 0.016-0.5', 0.016, 0.5, 'DPF=[5 5]', 'GLM', true, ...
    'wavelet_bpf', '', '');

% --- Group 10: Spline+Wavelet, BP 0.01-0.7, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(10, 'HOMER3', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'BP 0.01-0.7', 0.01, 0.7, 'PPF=[1 1]', 'BlockAvg', false, ...
    'spline_wavelet', '', '');

% --- Group 11: TDDR, BP 0.02-0.7, GLM, PCA SSR ---
idx=idx+1; gp(idx) = makeGroup(11, 'AnalyzIR', 'TDDR', 'TDDR', ...
    'BP 0.02-0.7', 0.02, 0.7, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 12: No MC (AR-IRLS handles it), No filter, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(12, 'HOMER3', 'AR-IRLS', 'AR-IRLS', ...
    'None', NaN, NaN, 'PPF=[1 1]', 'GLM', true, ...
    'minimal', '', 'AR model handles motion');

% --- Group 13: TDDR, BP 0.01-0.09, GLM (AR1), SSR ---
idx=idx+1; gp(idx) = makeGroup(13, 'MNE', 'TDDR', 'TDDR', ...
    'BP 0.01-0.09 FIR', 0.01, 0.09, 'DPF=[6 6]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm_arirls', '');

% --- Group 14: Spline+Wavelet, HP wavelet, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(14, 'AnalyzIR+HOMER3', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'HP wavelet', NaN, NaN, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'spline_wavelet', 'spline_ssr_glm', '');

% --- Group 15: CBSI, BP 0.01-0.7, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(15, 'HOMER3+MNE', 'CBSI', 'CBSI', ...
    'BP 0.01-0.7', 0.01, 0.7, 'PPF=[1 1]', 'GLM', true, ...
    'cbsi_tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 16: TDDR, BP 0.02-0.6, GLM (AR5), SSR ---
idx=idx+1; gp(idx) = makeGroup(16, 'MNE+Python', 'TDDR', 'TDDR', ...
    'BP 0.02-0.6', 0.02, 0.6, 'DPF=[6 6]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 17: Spline SG, BP 0.01-0.5, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(17, 'HOMER3', 'Spline SG', 'SplineSG', ...
    'BP 0.01-0.5', 0.01, 0.5, 'PPF=[1 1]', 'GLM', true, ...
    'splineSG_bpf', '', '');

% --- Group 18: TDDR+tPCA, BP 0.01-0.09, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(18, 'AnalyzIR+NIRSToolbox', 'TDDR+tPCA', 'Combo', ...
    'BP 0.01-0.09', 0.01, 0.09, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm_arirls', 'tPCA step not in pf2');

% --- Group 19: Targeted PCA, LP 0.2, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(19, 'NIRS-KIT', 'Targeted PCA', 'tPCA', ...
    'LP 0.2', NaN, 0.2, 'DPF=[6.15 5.09]', 'GLM', true, ...
    'tddr_bpf', 'tddr_glm_ols', 'tPCA not implemented in pf2');

% --- Group 20: TDDR+Monotonic, BP 0.01-0.4, GLM (AR20), SSR ---
idx=idx+1; gp(idx) = makeGroup(20, 'Satori', 'TDDR+Monotonic', 'Combo', ...
    'BP 0.01-0.4', 0.01, 0.4, 'DPF=[6.40 5.75]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', 'Monotonic interp step not in pf2');

% --- Group 21: Spline+Wavelet, BP 0.01-0.5, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(21, 'HOMER3+R', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'BP 0.01-0.5', 0.01, 0.5, 'PPF=[1 1]', 'GLM', true, ...
    'spline_wavelet', 'spline_ssr_glm', '');

% --- Group 22: Targeted PCA, BP 0.01-0.5, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(22, 'HOMER2', 'Targeted PCA', 'tPCA', ...
    'BP 0.01-0.5', 0.01, 0.5, 'DPF=[6 6]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', 'tPCA not implemented in pf2');

% --- Group 23: TDDR, BP 0.01-0.09, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(23, 'AnalyzIR+NIRSToolbox', 'TDDR', 'TDDR', ...
    'BP 0.01-0.09', 0.01, 0.09, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm_arirls', '');

% --- Group 24: Spline+Wavelet, LP 0.5, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(24, 'HOMER3', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'LP 0.5', NaN, 0.5, 'PPF=[1 1]', 'BlockAvg', false, ...
    'spline_wavelet', '', '');

% --- Group 25: AR-IRLS, BP 0.5-2.5, GLM ---
idx=idx+1; gp(idx) = makeGroup(25, 'AnalyzIR+QT-NIRS', 'AR-IRLS', 'AR-IRLS', ...
    'BP 0.5-2.5', 0.5, 2.5, 'PPF=[0.1 0.1]', 'GLM', false, ...
    'minimal', '', 'AR model handles motion; unusual filter band');

% --- Group 26: Spline+Wavelet, LP 0.5, GLM, PCA SSR ---
idx=idx+1; gp(idx) = makeGroup(26, 'HOMER3+HOMER2', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'LP 0.5', NaN, 0.5, 'DPF=[6 6]', 'GLM', true, ...
    'spline_wavelet', 'spline_ssr_glm', '');

% --- Group 27: TDDR, BP 0.01-0.7 FIR, GLM (AR21), SSR ---
idx=idx+1; gp(idx) = makeGroup(27, 'MNE+Python', 'TDDR', 'TDDR', ...
    'BP 0.01-0.7 FIR', 0.01, 0.7, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 28: CBSI+Spline SG, BP 0.01-0.5, Block Avg ---
idx=idx+1; gp(idx) = makeGroup(28, 'HOMER3+AnalyzIR', 'CBSI+SplineSG', 'Combo', ...
    'BP 0.01-0.5', 0.01, 0.5, 'N/A', 'BlockAvg', false, ...
    'splineSG_bpf', '', 'CBSI used as analysis signal');

% --- Group 29: TDDR, BP 0.005-0.3, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(29, 'AnalyzIR+AtlasViewer', 'TDDR', 'TDDR', ...
    'BP 0.005-0.3', 0.005, 0.3, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 30: TDDR, BP adaptive-0.7, GLM (AR5), PCA SSR ---
idx=idx+1; gp(idx) = makeGroup(30, 'MNE', 'TDDR', 'TDDR', ...
    'BP adaptive-0.7 FIR', NaN, 0.7, 'DPF=[6 6]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 31: No MC, No filter, GLM (AR1), SSR ---
idx=idx+1; gp(idx) = makeGroup(31, 'MNE', 'None', 'None', ...
    'None', NaN, NaN, 'PPF=[1 1]', 'GLM', true, ...
    'minimal', '', 'AR model handles motion and drift');

% --- Group 32: TDDR+Interp, BP 0.01-2.0, GLM (AR20), SSR ---
idx=idx+1; gp(idx) = makeGroup(32, 'Satori', 'Interp+TDDR', 'Combo', ...
    'BP 0.01-2.0', 0.01, 2.0, 'PPF=[1 1]', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', 'Interp step not in pf2');

% --- Group 33: No MC, BP 0.02-1.0, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(33, 'NeuroDOT+NIRFAST', 'None', 'None', ...
    'BP 0.02-1.0', 0.02, 1.0, 'N/A', 'GLM', true, ...
    'tddr_bpf', 'tddr_ssr_glm', 'No MC in original');

% --- Group 34: CBSI+TDDR, BP 0.02-0.3, GLM, PCA ---
idx=idx+1; gp(idx) = makeGroup(34, 'Matlab', 'CBSI+TDDR', 'Combo', ...
    'BP 0.02-0.3', 0.02, 0.3, 'N/A', 'GLM', true, ...
    'cbsi_tddr_bpf', 'tddr_ssr_glm', '');

% --- Group 35: AR-IRLS, No filter, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(35, 'AnalyzIR', 'AR-IRLS', 'AR-IRLS', ...
    'None', NaN, NaN, 'PPF=[0.1 0.1]', 'GLM', true, ...
    'minimal', '', 'AR model handles motion');

% --- Group 36: Spline+Wavelet, LP 0.5, GLM, PCA SSR ---
idx=idx+1; gp(idx) = makeGroup(36, 'HOMER2+Matlab', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'LP 0.5', NaN, 0.5, 'DPF=[6 6]', 'GLM', true, ...
    'spline_wavelet', 'spline_ssr_glm', '');

% --- Group 37: Spline+Wavelet, LP 3.0, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(37, 'HOMER3', 'Spline+Wavelet', 'Spline+Wavelet', ...
    'LP 3.0', NaN, 3.0, 'N/A', 'GLM', true, ...
    'spline_wavelet', 'qc_sci_spline_wavelet', '');

% --- Group 38: Spline SG, BP 0.01-0.7, GLM, SSR ---
idx=idx+1; gp(idx) = makeGroup(38, 'HOMER3', 'Spline SG', 'SplineSG', ...
    'BP 0.01-0.7', 0.01, 0.7, 'PPF=[1 1]', 'GLM', true, ...
    'splineSG_bpf', '', '');

gt.groupPipelines = gp;

% Index by motionType for convenience
motionTypes = {gp.motionType};
gt.pipelinesByMotion = struct();
for mt = unique(motionTypes)
    safeKey = matlab.lang.makeValidName(mt{1});
    gt.pipelinesByMotion.(safeKey) = [gp(strcmp(motionTypes, mt{1})).id];
end

%% Summary statistics from FRESH paper (for reference)
gt.summary.nTeams = 38;
gt.summary.nSubmissions = 70;  % some teams submitted for both studies
gt.summary.groupLevelAgreement = 0.80;  % ~80% agreement on group-level
gt.summary.motionCorrectionDistribution = struct( ...
    'TDDR', numel(gt.pipelinesByMotion.TDDR), ...
    'SplineWavelet', numel(gt.pipelinesByMotion.Spline_Wavelet), ...
    'Wavelet', numel(gt.pipelinesByMotion.Wavelet), ...
    'tPCA', numel(gt.pipelinesByMotion.tPCA), ...
    'SplineSG', numel(gt.pipelinesByMotion.SplineSG), ...
    'AR_IRLS', numel(gt.pipelinesByMotion.AR_IRLS), ...
    'CBSI', numel(gt.pipelinesByMotion.CBSI), ...
    'None', numel(gt.pipelinesByMotion.None), ...
    'Combo', numel(gt.pipelinesByMotion.Combo));

end

%%_Subfunctions_________________________________________________________

function g = makeGroup(id, toolbox, motion, motionType, filter, ...
    filterHP, filterLP, dpf, analysis, ssr, pf2Name, pf2GLMName, gap)
    g.id = id;
    g.toolbox = toolbox;
    g.motion = motion;
    g.motionType = motionType;
    g.filter = filter;
    g.filterHP = filterHP;
    g.filterLP = filterLP;
    g.dpf = dpf;
    g.analysis = analysis;
    g.ssr = ssr;
    g.pf2Name = pf2Name;
    g.pf2GLMName = pf2GLMName;
    g.gap = gap;
end
