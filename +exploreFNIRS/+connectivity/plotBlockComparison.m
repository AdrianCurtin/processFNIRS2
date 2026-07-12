function fig = plotBlockComparison(blockResults, varargin)
% PLOTBLOCKCOMPARISON Compare connectivity across blocks
%
% Visualizes how connectivity changes across blocks (e.g., different task
% conditions or time periods). Accepts the block-wise output from
% Experiment.connectivity('Blocks', blocks).
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotBlockComparison(blockResults)
%   fig = exploreFNIRS.connectivity.plotBlockComparison(blockResults, ...
%       'Metric', 'mean', 'GroupIndex', 1)
%
% Inputs:
%   blockResults - Struct array from Experiment.connectivity('Blocks', blocks)
%                  Each element has .blockNumber, .blockInfo, .groups
%
% Name-Value Parameters:
%   GroupIndex   - Which group to plot (default: 1, first group)
%   Metric       - How to summarize each connectivity matrix:
%                  'mean' (default) - mean of upper triangle
%                  'median' - median of upper triangle
%                  'density' - fraction of significant connections
%   ChannelPair  - [i, j] specific channel pair to track (default: [])
%                  If provided, plots that pair's coupling across blocks
%   PThreshold   - Significance threshold for density metric (default: 0.05)
%   BarWidth     - Bar width (default: 0.6)
%   ShowIndividual - Show individual subject dots (default: true)
%   Colors       - Custom color matrix [nBlocks x 3] (default: auto)
%   Title        - Figure title (default: auto)
%   Visible      - 'on' (default) or 'off'
%   SavePath     - File path to save figure
%   SaveWidth    - Width in pixels (default: 700)
%   SaveHeight   - Height in pixels (default: 400)
%   SaveDPI      - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.connectivity.plotMatrix, pf2.data.defineBlocks

    p = inputParser;
    addRequired(p, 'blockResults', @isstruct);
    addParameter(p, 'GroupIndex', 1, @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'Metric', 'mean', @ischar);
    addParameter(p, 'ChannelPair', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'BarWidth', 0.6, @isnumeric);
    addParameter(p, 'ShowIndividual', true, @islogical);
    addParameter(p, 'Colors', [], @isnumeric);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 700, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, blockResults, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    nBlocks = length(blockResults);
    gi = opts.GroupIndex;

    % Extract per-block metrics
    blockMeans = zeros(1, nBlocks);
    blockSEMs = zeros(1, nBlocks);
    blockLabels = cell(1, nBlocks);
    subjectValues = cell(1, nBlocks);

    for b = 1:nBlocks
        grp = blockResults(b).groups(gi);

        if ~isempty(opts.ChannelPair)
            % Track a specific channel pair
            ci = opts.ChannelPair(1);
            cj = opts.ChannelPair(2);
            blockMeans(b) = grp.Mean(ci, cj);
            blockSEMs(b) = grp.SEM(ci, cj);

            % Individual subject values
            nSubj = length(grp.matrices);
            vals = zeros(nSubj, 1);
            for s = 1:nSubj
                m = grp.matrices{s};
                if ci <= size(m, 1) && cj <= size(m, 2)
                    vals(s) = m(ci, cj);
                else
                    vals(s) = NaN;
                end
            end
            subjectValues{b} = vals;
        else
            % Summarize the whole matrix
            mat = grp.Mean;
            nCh = size(mat, 1);

            switch lower(opts.Metric)
                case 'mean'
                    offVals = getOffDiagonal(mat);
                    blockMeans(b) = mean(offVals, 'omitnan');
                    % SEM from individual subjects
                    nSubj = length(grp.matrices);
                    subjMeans = zeros(nSubj, 1);
                    for s = 1:nSubj
                        subjMeans(s) = mean(getOffDiagonal(grp.matrices{s}), 'omitnan');
                    end
                    blockSEMs(b) = std(subjMeans, 'omitnan') / sqrt(nSubj);
                    subjectValues{b} = subjMeans;

                case 'median'
                    offVals = getOffDiagonal(mat);
                    blockMeans(b) = median(offVals, 'omitnan');
                    nSubj = length(grp.matrices);
                    subjMeds = zeros(nSubj, 1);
                    for s = 1:nSubj
                        subjMeds(s) = median(getOffDiagonal(grp.matrices{s}), 'omitnan');
                    end
                    blockSEMs(b) = std(subjMeds, 'omitnan') / sqrt(nSubj);
                    subjectValues{b} = subjMeds;

                case 'density'
                    % Fraction of significant connections (one-sample t-test)
                    nSubj = length(grp.matrices);
                    if nSubj < 3
                        warning('exploreFNIRS:connectivity:plotBlockComparison', ...
                            'Density metric requires >= 3 subjects, got %d', nSubj);
                        blockMeans(b) = NaN;
                        blockSEMs(b) = 0;
                        subjectValues{b} = [];
                    else
                        % Detect directed methods: check matrix asymmetry
                        testMat = grp.Mean;
                        isAsymmetric = any(abs(testMat - testMat') > 1e-10, 'all');
                        if isAsymmetric
                            mask = ~eye(nCh, 'logical');
                        else
                            mask = triu(true(nCh), 1);
                        end
                        [ri, ci] = find(mask);
                        nPairs = length(ri);
                        pVals = ones(nPairs, 1);
                        for pi = 1:nPairs
                            vals = cellfun(@(m) m(ri(pi), ci(pi)), grp.matrices);
                            [~, pVals(pi)] = pf2_base.compat.ttest(vals);
                        end
                        blockMeans(b) = mean(pVals < opts.PThreshold);
                        blockSEMs(b) = 0;
                        subjectValues{b} = [];
                    end

                otherwise
                    error('exploreFNIRS:connectivity:plotBlockComparison', ...
                        'Unknown metric "%s". Use: mean, median, density', opts.Metric);
            end
        end

        % Block label
        if isfield(blockResults(b).blockInfo, 'Condition')
            blockLabels{b} = blockResults(b).blockInfo.Condition;
        else
            blockLabels{b} = sprintf('Block %d', blockResults(b).blockNumber);
        end
    end

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    if isempty(opts.Colors)
        cmap = lines(nBlocks);
    else
        cmap = opts.Colors;
    end

    hold(ax, 'on');

    for b = 1:nBlocks
        bar(ax, b, blockMeans(b), opts.BarWidth, ...
            'FaceColor', cmap(b, :), 'EdgeColor', 'none', ...
            'FaceAlpha', 0.7);
    end

    % Error bars
    errorbar(ax, 1:nBlocks, blockMeans, blockSEMs, 'k.', ...
        'LineWidth', sty.AxisLineWidth, 'CapSize', 6);

    % Individual subject dots
    if opts.ShowIndividual
        for b = 1:nBlocks
            vals = subjectValues{b};
            if ~isempty(vals)
                jitter = (rand(length(vals), 1) - 0.5) * 0.2;
                plot(ax, b + jitter, vals, 'o', ...
                    'MarkerSize', 4, 'MarkerFaceColor', cmap(b, :) * 0.7, ...
                    'MarkerEdgeColor', 'none');
            end
        end
    end

    % Zero line
    plot(ax, [0.5, nBlocks + 0.5], [0, 0], '-', ...
        'Color', sty.ZeroLineColor, 'LineWidth', 0.5);

    hold(ax, 'off');

    set(ax, 'XTick', 1:nBlocks, 'XTickLabel', pf2_base.plot.escapeTeX(blockLabels));
    xlabel(ax, 'Block');

    if ~isempty(opts.ChannelPair)
        ylabel(ax, sprintf('Coupling (Ch%d-Ch%d)', opts.ChannelPair(1), opts.ChannelPair(2)));
    else
        ylabel(ax, sprintf('Connectivity (%s)', opts.Metric));
    end

    if ~isempty(opts.Title)
        title(ax, pf2_base.plot.escapeTeX(opts.Title));
    else
        grp = blockResults(1).groups(gi);
        titleStr = sprintf('Connectivity by Block (%s, %s, %s)', ...
            grp.method, grp.biomarker, grp.label);
        title(ax, pf2_base.plot.escapeTeX(titleStr));
    end

    box(ax, 'on');
    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);

end


function vals = getOffDiagonal(mat)
% Extract off-diagonal values (upper triangle for symmetric, all for directed)
    isAsymmetric = any(abs(mat - mat') > 1e-10, 'all');
    if isAsymmetric
        mask = ~eye(size(mat), 'logical');
    else
        mask = triu(true(size(mat)), 1);
    end
    vals = mat(mask);
end
