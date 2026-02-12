function result = computeInterROI(data, varargin)
% COMPUTEINTERROI Between-ROI pairwise coupling analysis
%
% Computes pairwise coupling between all ROI-averaged time series. This is
% a convenience wrapper around computeMatrix with UseROI=true, provided for
% clarity and discoverability in ROI-level analyses.
%
% Requires data to have ROI-level time series (data.ROI.<Biomarker>) and
% ROI definitions (data.ROI.info). Generate these by running defineROI and
% buildROI (pf2_build_nanmean_ROI) before calling this function.
%
% Syntax:
%   result = exploreFNIRS.connectivity.computeInterROI(data)
%   result = exploreFNIRS.connectivity.computeInterROI(data, 'Method', 'spearman')
%   result = exploreFNIRS.connectivity.computeInterROI(data, ...
%       'Biomarker', 'HbR', 'TimeWindow', [5, 30])
%
% Inputs:
%   data - Processed fNIRS struct with .ROI.<Biomarker> (ROI-averaged time
%          series) and .ROI.info (table with ROI names as RowNames)
%
% Name-Value Parameters:
%   Method       - Coupling method: 'pearson' (default), 'spearman', 'xcorr',
%                  'coherence', 'wcoherence'
%   Biomarker    - Biomarker to use: 'HbO' (default), 'HbR', 'HbTotal',
%                  'HbDiff', 'CBSI'
%   TimeWindow   - [start, end] in seconds to restrict analysis (default: [] = full)
%   CouplingArgs - Cell array of extra args passed to coupling function (default: {})
%
% Outputs:
%   result - Struct with fields:
%     .matrix    - [nROI x nROI] symmetric coupling matrix
%     .pmatrix   - [nROI x nROI] p-value matrix
%     .labels    - Cell array of ROI names
%     .method    - Coupling method name
%     .biomarker - Biomarker used
%     .channels  - ROI indices (1:nROI)
%     .useROI    - true
%     .nSamples  - Number of time samples used
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   processed = pf2.probe.roi.defineROI(processed, {1:6, 7:12, 13:18}, ...
%       {'Left', 'Center', 'Right'});
%   processed = pf2_build_nanmean_ROI(processed);
%   result = exploreFNIRS.connectivity.computeInterROI(processed, ...
%       'Method', 'pearson');
%   disp(result.matrix);
%   disp(result.labels);
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.connectivity.computeIntraROI,
%   exploreFNIRS.connectivity.plotInterROI,
%   pf2.probe.roi.defineROI, pf2_build_nanmean_ROI

    p = inputParser;
    addRequired(p, 'data', @isstruct);
    addParameter(p, 'Method', 'pearson', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
    addParameter(p, 'CouplingArgs', {}, @iscell);
    parse(p, data, varargin{:});
    opts = p.Results;

    % Build argument list for computeMatrix
    args = {'UseROI', true, ...
            'Method', opts.Method, ...
            'Biomarker', opts.Biomarker};

    if ~isempty(opts.TimeWindow)
        args = [args, {'TimeWindow', opts.TimeWindow}];
    end

    if ~isempty(opts.CouplingArgs)
        args = [args, {'CouplingArgs', opts.CouplingArgs}];
    end

    % Delegate to computeMatrix with UseROI=true
    result = exploreFNIRS.connectivity.computeMatrix(data, args{:});
end
