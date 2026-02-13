function fig = plotHBICA(result, varargin)
% PLOTHBICA Visualize HB-ICA decomposition results
%
% Creates a multi-panel figure showing: (1) GOF bar chart with inter-brain
% classification, (2) spatial mixing weight patterns for both subjects,
% and (3) source time courses for inter-brain components.
%
% Syntax:
%   fig = exploreFNIRS.hyperscanning.plotHBICA(result)
%   fig = exploreFNIRS.hyperscanning.plotHBICA(result, 'Components', 1:3)
%   fig = exploreFNIRS.hyperscanning.plotHBICA(result, 'ShowIntraBrain', true)
%   fig = exploreFNIRS.hyperscanning.plotHBICA(result, 'SavePath', 'hbica.png')
%
% Inputs:
%   result - Struct from exploreFNIRS.hyperscanning.hbica with fields:
%            .sources, .mixingMatrix, .GOF, .isInterBrain, .channelsA,
%            .channelsB, .nComponents, .fs, .sourcesA, .sourcesB,
%            .mixingA, .mixingB
%
% Name-Value Parameters:
%   Components     - Component indices to display (default: inter-brain only)
%   ShowIntraBrain - Include intra-brain components (default: false)
%   MaxComponents  - Maximum components to show (default: 6)
%   Title          - Figure title (default: auto)
%   Visible        - 'on' (default) or 'off'
%   SavePath       - File path to save figure
%   SaveWidth      - Width in pixels (default: 1000)
%   SaveHeight     - Height in pixels (default: 700)
%   SaveDPI        - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.hyperscanning.hbica,
%   exploreFNIRS.hyperscanning.plotGroup

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'Components', [], @isnumeric);
    addParameter(p, 'ShowIntraBrain', false, @islogical);
    addParameter(p, 'MaxComponents', 6, @(v) isnumeric(v) && isscalar(v));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 1000, @isnumeric);
    addParameter(p, 'SaveHeight', 700, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Determine which components to show
    if ~isempty(opts.Components)
        compIdx = opts.Components;
    elseif opts.ShowIntraBrain
        compIdx = 1:result.nComponents;
    else
        compIdx = result.interBrainIdx(:)';
        if isempty(compIdx)
            compIdx = 1:min(3, result.nComponents);
        end
    end
    compIdx = compIdx(compIdx <= result.nComponents);
    if length(compIdx) > opts.MaxComponents
        compIdx = compIdx(1:opts.MaxComponents);
    end
    nShow = length(compIdx);

    K = result.nComponents;
    Ca = length(result.channelsA);
    Cb = length(result.channelsB);
    fs = result.fs;

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight);
    sty = pf2_base.plot.PlotStyle.getDefault();

    if isempty(opts.Title)
        nIB = sum(result.isInterBrain);
        titleStr = sprintf('HB-ICA: %d inter-brain / %d components (%s)', ...
            nIB, K, result.biomarker);
    else
        titleStr = opts.Title;
    end

    % Layout: top row = GOF bar chart (full width)
    %         bottom rows = one row per component (mixing A | source | mixing B)
    nRows = 1 + nShow;
    if nShow == 0
        nRows = 1;
    end

    % Panel 1: GOF bar chart (spans full width = 3 columns)
    ax1 = subplot(nRows, 3, 1:3, 'Parent', fig);
    barColors = zeros(K, 3);
    for k = 1:K
        if result.isInterBrain(k)
            barColors(k,:) = [0.85, 0.33, 0.10];  % Orange for inter-brain
        else
            barColors(k,:) = [0.30, 0.60, 0.90];  % Blue for intra-brain
        end
    end

    bh = bar(ax1, 1:K, result.GOF, 'FaceColor', 'flat');
    bh.CData = barColors;

    hold(ax1, 'on');
    % GOF threshold line
    yline(ax1, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    hold(ax1, 'off');

    xlabel(ax1, 'Component', 'FontSize', sty.FontSize);
    ylabel(ax1, 'GOF Index', 'FontSize', sty.FontSize);
    title(ax1, titleStr, 'FontSize', sty.FontSize + 1);
    set(ax1, 'FontSize', sty.FontSize);
    xlim(ax1, [0.5, K + 0.5]);

    % Mark inter-brain components
    if any(result.isInterBrain)
        hold(ax1, 'on');
        ibIdx = find(result.isInterBrain);
        for ii = 1:length(ibIdx)
            text(ax1, ibIdx(ii), result.GOF(ibIdx(ii)) - 0.05, '*', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, ...
                'Color', [0.85, 0.33, 0.10], 'FontWeight', 'bold');
        end
        hold(ax1, 'off');
    end

    % Panels for each component: mixing weights + source time course
    for iComp = 1:nShow
        k = compIdx(iComp);
        rowIdx = iComp + 1;

        % Mixing weights for subject A
        ax_mA = subplot(nRows, 3, (rowIdx-1)*3 + 1, 'Parent', fig);
        wA = result.mixingA(:, k);
        bar(ax_mA, 1:Ca, wA, 'FaceColor', [0.30, 0.60, 0.90]);
        xlabel(ax_mA, 'Ch (A)', 'FontSize', sty.FontSize - 1);
        ylabel(ax_mA, 'Weight', 'FontSize', sty.FontSize - 1);
        if result.isInterBrain(k)
            compLabel = sprintf('IC%d (inter)', k);
        else
            compLabel = sprintf('IC%d (intra)', k);
        end
        title(ax_mA, ['A: ' compLabel], 'FontSize', sty.FontSize - 1);
        set(ax_mA, 'FontSize', sty.FontSize - 1);

        % Source time course
        ax_src = subplot(nRows, 3, (rowIdx-1)*3 + 2, 'Parent', fig);
        T = size(result.sources, 1);
        timeVec = (0:T-1)' / fs;
        plot(ax_src, timeVec, result.sources(:, k), ...
            'Color', barColors(k,:), 'LineWidth', sty.LineWidth * 0.8);
        xlabel(ax_src, 'Time (s)', 'FontSize', sty.FontSize - 1);
        ylabel(ax_src, 'Source', 'FontSize', sty.FontSize - 1);
        title(ax_src, sprintf('IC%d (GOF=%.2f)', k, result.GOF(k)), ...
            'FontSize', sty.FontSize - 1);
        set(ax_src, 'FontSize', sty.FontSize - 1);

        % Mixing weights for subject B
        ax_mB = subplot(nRows, 3, (rowIdx-1)*3 + 3, 'Parent', fig);
        wB = result.mixingB(:, k);
        bar(ax_mB, 1:Cb, wB, 'FaceColor', [0.85, 0.33, 0.10]);
        xlabel(ax_mB, 'Ch (B)', 'FontSize', sty.FontSize - 1);
        ylabel(ax_mB, 'Weight', 'FontSize', sty.FontSize - 1);
        title(ax_mB, ['B: ' compLabel], 'FontSize', sty.FontSize - 1);
        set(ax_mB, 'FontSize', sty.FontSize - 1);
    end

    pf2_base.plot.handleSave(fig, opts);
end
