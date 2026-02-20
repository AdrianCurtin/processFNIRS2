function [fig, stats] = plotNeuralEfficiency(groups, varargin)
% PLOTNEURALEFFICIENCY Neural efficiency scatter plot (Experiment groups)
%
% Visualizes the relationship between brain activation (X-axis) and
% behavioral/cognitive performance (Y-axis). Both axes are z-scored so
% the y=x identity line separates "efficient" subjects (high performance
% with low activation — above the line) from "inefficient" subjects
% (high activation relative to performance — below the line).
%
% Default axes:
%   X = biomarker (brain activation, averaged across channels)
%   Y = InfoVar  (behavioral performance)
%   Set FlipXY=true to swap them.
%
% This wrapper extracts per-subject data from Experiment groups and
% delegates rendering to plotNeuralEfficiencyCore.
%
% Syntax:
%   [fig, stats] = plotNeuralEfficiency(groups, 'InfoVar', 'accuracy')
%   [fig, stats] = plotNeuralEfficiency(groups, 'InfoVar', 'RT', ...
%       'Channels', 1:5, 'FitLine', true)
%   [fig, stats] = plotNeuralEfficiency(groups, 'InfoVar', 'RT', ...
%       'FlipXY', true, 'ZScoreMode', 'pergroup')
%
% Inputs:
%   groups - Struct array from Experiment.groups (after aggregate())
%            Each element must have .gbyGrandBarFlat and .gbyTables
%
% Name-Value Parameters:
%   InfoVar      - (required) Behavioral/performance variable from info
%   Biomarker    - Single biomarker string (default: 'HbO')
%   Channels     - Channel indices to average over (default: all)
%   ROIs         - Alternative to Channels — use ROI indices/names
%   Averaging    - 'hierarchy' (default), 'flat', or 'none'
%   FlipXY       - Swap axes so X=performance, Y=activation (default: false)
%   Colors       - Group color palette override (default: [] = auto)
%                  [N x 3] RGB, colormap name, function handle, or
%                  ColorScheme object
%
%   All additional parameters (ZScoreMode, InvertX, ReverseAxes,
%   ShowIdentity, ShowLabels, FitLine, ShowArrows, ArrowColor, Legend,
%   Title, XLabel, YLabel, Visible, SavePath, SaveWidth, SaveHeight,
%   SaveDPI) are passed through to plotNeuralEfficiencyCore.
%
% Outputs:
%   fig   - Figure handle
%   stats - Struct array [nGroups x 1] with per-group statistics:
%           .r, .p      - Pearson correlation (on z-scored data)
%           .rho, .pval - Spearman correlation
%           .N          - Sample size
%           .zX, .zY    - Z-scored values per subject
%           .centroid   - [meanX, meanY] of z-scored values
%           .label      - Group label
%
% Example:
%   ex = exploreFNIRS.core.Experiment(allData);
%   ex.groupby({'Group'});
%   ex.aggregate();
%   [fig, stats] = ex.plotNeuralEfficiency('accuracy', ...
%       'Channels', 1:5, 'FitLine', true);
%
% References:
%   Neubauer & Fink (2009). Intelligence and neural efficiency.
%   Neuroscience & Biobehavioral Reviews, 33(7), 1004-1023.
%
% See also: plotNeuralEfficiencyCore, plotNeuralEfficiencyFromTable,
%           exploreFNIRS.core.Experiment

    p = inputParser;
    p.KeepUnmatched = true;
    addRequired(p, 'groups', @isstruct);
    addParameter(p, 'InfoVar', '', @ischar);
    addParameter(p, 'Biomarker', 'HbO', @ischar);
    addParameter(p, 'Channels', [], @isnumeric);
    addParameter(p, 'ROIs', [], @(x) isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'Averaging', 'hierarchy', @(x) ismember(lower(x), {'hierarchy','flat','none'}));
    addParameter(p, 'FlipXY', false, @islogical);
    addParameter(p, 'ShowLabels', false, @islogical);
    addParameter(p, 'InvertX', false, @islogical);
    addParameter(p, 'XLabel', '', @ischar);
    addParameter(p, 'YLabel', '', @ischar);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
    parse(p, groups, varargin{:});
    opts = p.Results;

    if isempty(opts.InfoVar)
        error('exploreFNIRS:core:plotNeuralEfficiency', ...
            'InfoVar is required. Specify the behavioral/performance variable.');
    end

    nGroups = length(groups);
    bioM = opts.Biomarker;

    % Validate groups
    for g = 1:nGroups
        if isempty(groups(g).gbyGrandBarFlat)
            error('exploreFNIRS:core:plotNeuralEfficiency', ...
                'Group %d has no bar-flat grand average. Call aggregate() first.', g);
        end
    end

    % Resolve ROIs vs Channels
    useROI = ~isempty(opts.ROIs);
    if useROI
        if ~isempty(opts.Channels)
            error('exploreFNIRS:core:plotNeuralEfficiency', ...
                'ROIs and Channels are mutually exclusive.');
        end
        if ~isfield(groups(1).gbyGrandBarFlat, 'ROI')
            error('exploreFNIRS:core:plotNeuralEfficiency', ...
                'No ROI data in grand average. Define ROIs before aggregating.');
        end
        roiIdx = resolveROIs(groups, opts.ROIs);
        allChannels = roiIdx;
    else
        if isempty(opts.Channels)
            nCh = size(groups(1).gbyGrandBarFlat.(bioM).data, 2);
            allChannels = 1:nCh;
        else
            allChannels = opts.Channels;
        end
    end

    tIdx = 1;

    % --- Resolve colors ---
    if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
        colors = opts.Colors.resolve(groups);
    else
        colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
    end

    % --- Build plotGroups struct array ---
    pgTemplate = struct('x', [], 'y', [], 'label', '', 'color', [], ...
        'subjectIDs', {{}}, 'arrowChain', 1);
    plotGroups = repmat(pgTemplate, 1, nGroups);

    for g = 1:nGroups
        curGrand = groups(g).gbyGrandBarFlat;
        curTable = groups(g).gbyTables;

        % --- Biomarker values, averaged across selected channels ---
        if useROI
            bioData = curGrand.ROI.(bioM);
        else
            bioData = curGrand.(bioM);
        end

        % bioData.data is [T x C x N]
        chVals = nan(length(allChannels), size(bioData.data, 3));
        for ci = 1:length(allChannels)
            ch = allChannels(ci);
            if ch <= size(bioData.data, 2)
                chVals(ci, :) = permute(bioData.data(tIdx, ch, :), [3, 1, 2]);
            end
        end
        bioVals = mean(chVals, 1, 'omitnan')';

        % Hierarchical averaging of biomarker
        if strcmpi(opts.Averaging, 'hierarchy') && ...
                isfield(curGrand, 'info') && isfield(curGrand.info, 'Hierarchy')
            [bioVals, ~] = pf2_base.hierarchicalAverage(bioVals, ...
                curGrand.info.Hierarchy, @nanmean);
        end

        % --- Info variable (performance) ---
        if ~ismember(opts.InfoVar, curTable.Properties.VariableNames)
            error('exploreFNIRS:core:plotNeuralEfficiency', ...
                'Variable "%s" not found in group %d table.', opts.InfoVar, g);
        end
        perfData = curTable.(opts.InfoVar);
        if ~isnumeric(perfData)
            perfData = double(string(perfData));
        end
        perfData(perfData == -9999) = NaN;

        % Hierarchical averaging of performance
        if strcmpi(opts.Averaging, 'hierarchy') && ...
                ismember('SubjectID', curTable.Properties.VariableNames)
            [perfVals] = pf2_base.hierarchicalAverage(perfData, ...
                curTable(:, 'SubjectID'), @nanmean);
        else
            perfVals = perfData;
        end

        % Align lengths and remove NaN pairs
        n = min(length(perfVals), length(bioVals));
        perfVals = perfVals(1:n);
        bioVals = bioVals(1:n);
        validIdx = ~isnan(perfVals) & ~isnan(bioVals);
        perfVals = perfVals(validIdx);
        bioVals = bioVals(validIdx);

        % Default: X = biomarker (activation), Y = performance
        % FlipXY:  X = performance, Y = biomarker
        if opts.FlipXY
            plotGroups(g).x = perfVals;
            plotGroups(g).y = bioVals;
        else
            plotGroups(g).x = bioVals;
            plotGroups(g).y = perfVals;
        end
        plotGroups(g).label = groups(g).label;
        plotGroups(g).color = colors(g, :);
        plotGroups(g).arrowChain = 1;

        % Extract SubjectIDs for labels
        if opts.ShowLabels && ...
                ismember('SubjectID', curTable.Properties.VariableNames)
            sids = curTable.SubjectID;
            if strcmpi(opts.Averaging, 'hierarchy')
                [~, ia] = unique(curTable.SubjectID, 'stable');
                sids = sids(ia);
            end
            sids = sids(1:n);
            sids = sids(validIdx);
            if ~iscell(sids)
                sids = cellstr(string(sids));
            end
            plotGroups(g).subjectIDs = sids;
        end
    end

    % --- Generate default labels ---
    infoLabel = pf2_base.plot.escapeTeX(opts.InfoVar);
    if isscalar(allChannels)
        bioLabel = sprintf('%s Ch %d', bioM, allChannels(1));
    else
        bioLabel = sprintf('%s mean', bioM);
    end

    if opts.FlipXY
        % Flipped: X = performance, Y = activation
        defaultXLabel = sprintf('%s (z-scored)', infoLabel);
        defaultYLabel = sprintf('%s (z-scored)', bioLabel);
    else
        % Default: X = activation, Y = performance
        defaultXLabel = sprintf('%s (z-scored)', bioLabel);
        defaultYLabel = sprintf('%s (z-scored)', infoLabel);
    end
    if opts.InvertX
        defaultXLabel = [defaultXLabel(1:end-1) ', inverted)'];
    end

    if isempty(opts.XLabel), opts.XLabel = defaultXLabel; end
    if isempty(opts.YLabel), opts.YLabel = defaultYLabel; end
    if isempty(opts.Title)
        opts.Title = sprintf('Neural Efficiency: %s vs %s', bioLabel, infoLabel);
    end

    % --- Delegate to core ---
    if opts.FlipXY
        highCorner = 'bottomright';
    else
        highCorner = 'topleft';
    end

    passthrough = unmatchedToCell(p.Unmatched);
    [fig, stats] = exploreFNIRS.core.plotNeuralEfficiencyCore(plotGroups, ...
        'InvertX', opts.InvertX, ...
        'ShowLabels', opts.ShowLabels, ...
        'HighCorner', highCorner, ...
        'XLabel', opts.XLabel, ...
        'YLabel', opts.YLabel, ...
        'Title', opts.Title, ...
        passthrough{:});
end


%% Local helpers

function args = unmatchedToCell(s)
% Convert inputParser Unmatched struct to name-value cell array
    fn = fieldnames(s);
    args = cell(1, 2 * numel(fn));
    for i = 1:numel(fn)
        args{2*i - 1} = fn{i};
        args{2*i} = s.(fn{i});
    end
end


function roiIdx = resolveROIs(groups, rois)
% Convert ROI input to numeric indices
    roiInfo = groups(1).gbyGrandBarFlat.ROI.info;
    allNames = roiInfo.Properties.RowNames;

    if ischar(rois) || isstring(rois)
        if strcmpi(rois, 'all')
            roiIdx = 1:length(allNames);
        else
            roiIdx = find(ismember(allNames, {char(rois)}));
        end
    elseif iscell(rois)
        roiIdx = find(ismember(allNames, rois));
    elseif islogical(rois)
        roiIdx = find(rois);
    else
        roiIdx = rois;
    end
    roiIdx = roiIdx(roiIdx <= length(allNames));
end
