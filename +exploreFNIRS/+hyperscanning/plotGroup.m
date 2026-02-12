function fig = plotGroup(result, varargin)
% PLOTGROUP Group-level hyperscanning coupling bar chart
%
% Displays mean coupling per channel with SEM error bars for group-level
% hyperscanning results. Supports significance markers from permutation
% tests and comparison of multiple groups or blocks.
%
% Syntax:
%   fig = exploreFNIRS.hyperscanning.plotGroup(result)
%   fig = exploreFNIRS.hyperscanning.plotGroup(result, 'ShowSignificance', true)
%   fig = exploreFNIRS.hyperscanning.plotGroup(blockResults)  % from Blocks
%
% Inputs:
%   result - Struct from computeGroup or Experiment.hyperscanning() with:
%            .Mean, .SEM, .channels, .method, .biomarker
%            OR struct array from block-wise hyperscanning with:
%            .blockInfo, .coupling (each containing group result)
%
% Name-Value Parameters:
%   ShowSignificance - Show significance stars from p-values (default: true)
%   PThreshold       - Significance threshold (default: 0.05)
%   ChannelLabels    - Custom channel labels (default: 'Ch1', 'Ch2', ...)
%   BarWidth         - Bar width (default: 0.7)
%   Colors           - Custom color matrix [nGroups x 3] (default: auto)
%   ShowZeroLine     - Show horizontal line at y=0 (default: true)
%   Title            - Figure title (default: auto)
%   Visible          - 'on' (default) or 'off'
%   SavePath         - File path to save figure
%   SaveWidth        - Width in pixels (default: 800)
%   SaveHeight       - Height in pixels (default: 450)
%   SaveDPI          - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.hyperscanning.computeGroup,
%   exploreFNIRS.hyperscanning.permutationTest

    p = inputParser;
    addRequired(p, 'result');
    addParameter(p, 'ShowSignificance', true, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'ChannelLabels', {}, @iscell);
    addParameter(p, 'BarWidth', 0.7, @isnumeric);
    addParameter(p, 'Colors', [], @isnumeric);
    addParameter(p, 'ShowZeroLine', true, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 450, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Detect input type: block results vs single group result
    isBlockResult = isstruct(result) && isfield(result, 'coupling');

    if isBlockResult
        plotBlockGroupBars(result, opts);
        fig = gcf;
    else
        plotSingleGroup(result, opts);
        fig = gcf;
    end

end


function plotSingleGroup(result, opts)
% Plot a single group result as bar chart

    meanVals = result.Mean(:)';
    semVals = result.SEM(:)';
    nCh = length(meanVals);

    if ~isempty(opts.ChannelLabels)
        chLabels = opts.ChannelLabels;
    elseif isfield(result, 'channels')
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), result.channels, ...
            'UniformOutput', false);
    else
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
            'UniformOutput', false);
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    if isempty(opts.Colors)
        barColor = [0.3, 0.5, 0.8];
    else
        barColor = opts.Colors(1, :);
    end

    b = bar(ax, 1:nCh, meanVals, opts.BarWidth, 'FaceColor', barColor, ...
        'EdgeColor', 'none');
    hold(ax, 'on');

    % Error bars
    errorbar(ax, 1:nCh, meanVals, semVals, '.', 'Color', sty.ForegroundColor, ...
        'LineWidth', sty.AxisLineWidth, 'CapSize', 4);

    % Zero line
    if opts.ShowZeroLine
        plot(ax, [0.5, nCh + 0.5], [0, 0], '-', ...
            'Color', sty.ZeroLineColor, 'LineWidth', 0.5);
    end

    % Significance stars
    if opts.ShowSignificance && isfield(result, 'pvalue')
        pvals = result.pvalue(:)';
        yMax = max(abs(meanVals) + semVals);
        for ch = 1:nCh
            if pvals(ch) < opts.PThreshold
                starY = meanVals(ch) + semVals(ch) + yMax * 0.05;
                if pvals(ch) < 0.001
                    starTxt = '***';
                elseif pvals(ch) < 0.01
                    starTxt = '**';
                else
                    starTxt = '*';
                end
                text(ax, ch, starY, starTxt, ...
                    'HorizontalAlignment', 'center', 'FontSize', 12);
            end
        end
    end

    % Permutation test significance
    if opts.ShowSignificance && isfield(result, 'permutation')
        perm = result.permutation;
        if isfield(perm, 'significant')
            sigMask = perm.significant(:)';
            yMax = max(abs(meanVals) + semVals);
            for ch = 1:nCh
                if sigMask(ch)
                    starY = meanVals(ch) + semVals(ch) + yMax * 0.05;
                    text(ax, ch, starY, '*', ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 14, 'Color', [0.8, 0, 0]);
                end
            end
        end
    end

    hold(ax, 'off');

    set(ax, 'XTick', 1:nCh, 'XTickLabel', pf2_base.plot.escapeTeX(chLabels), 'XTickLabelRotation', 45);
    xlabel(ax, 'Channel');
    ylabel(ax, 'Coupling');

    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        titleStr = sprintf('Group Hyperscanning (%s, %s, N=%d)', ...
            result.method, result.biomarker, max(result.N(:)));
        title(ax, titleStr);
    end

    box(ax, 'on');
    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);

end


function plotBlockGroupBars(blockResults, opts)
% Plot block-wise results as grouped bars

    nBlocks = length(blockResults);

    % Get channel info from first block
    firstResult = blockResults(1).coupling;
    if isfield(firstResult, 'channels')
        nCh = length(firstResult.channels);
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), firstResult.channels, ...
            'UniformOutput', false);
    else
        nCh = length(firstResult.Mean);
        chLabels = arrayfun(@(c) sprintf('Ch%d', c), 1:nCh, ...
            'UniformOutput', false);
    end

    if ~isempty(opts.ChannelLabels)
        chLabels = opts.ChannelLabels;
    end

    % Build data matrix [nCh x nBlocks]
    meanMat = zeros(nCh, nBlocks);
    semMat = zeros(nCh, nBlocks);
    blockLabels = cell(1, nBlocks);

    for b = 1:nBlocks
        r = blockResults(b).coupling;
        meanMat(:, b) = r.Mean(:);
        semMat(:, b) = r.SEM(:);

        if isfield(blockResults(b).blockInfo, 'Condition')
            blockLabels{b} = blockResults(b).blockInfo.Condition;
        else
            blockLabels{b} = sprintf('Block %d', blockResults(b).blockNumber);
        end
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    b = bar(ax, meanMat, 'grouped');

    if ~isempty(opts.Colors) && size(opts.Colors, 1) >= nBlocks
        for k = 1:nBlocks
            b(k).FaceColor = opts.Colors(k, :);
        end
    end

    % Error bars
    hold(ax, 'on');
    nGroups = size(meanMat, 1);
    groupWidth = min(0.8, nBlocks / (nBlocks + 1.5));
    for k = 1:nBlocks
        xOff = (2 * k - nBlocks - 1) / (2 * nBlocks) * groupWidth;
        errorbar(ax, (1:nGroups) + xOff, meanMat(:, k), semMat(:, k), ...
            '.', 'Color', sty.ForegroundColor, 'LineWidth', 1, 'CapSize', 3);
    end

    if opts.ShowZeroLine
        plot(ax, [0.5, nGroups + 0.5], [0, 0], '-', ...
            'Color', sty.ZeroLineColor, 'LineWidth', 0.5);
    end
    hold(ax, 'off');

    set(ax, 'XTick', 1:nGroups, 'XTickLabel', pf2_base.plot.escapeTeX(chLabels), 'XTickLabelRotation', 45);
    xlabel(ax, 'Channel');
    ylabel(ax, 'Coupling');
    legend(ax, pf2_base.plot.escapeTeX(blockLabels), 'Location', 'best');

    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        title(ax, sprintf('Hyperscanning by Block (%s)', firstResult.method));
    end

    box(ax, 'on');
    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);

end
