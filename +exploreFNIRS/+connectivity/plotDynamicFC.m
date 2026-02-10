function fig = plotDynamicFC(dynamicResult, varargin)
% PLOTDYNAMICFC Visualize time-varying functional connectivity
%
% Multi-panel figure showing dynamic connectivity over time. Top panel
% displays global connectivity strength per window. If state detection
% results are provided, a middle panel shows state assignments as a color
% bar and a bottom row displays centroid matrices for each state.
%
% Syntax:
%   fig = exploreFNIRS.connectivity.plotDynamicFC(dynamicResult)
%   fig = exploreFNIRS.connectivity.plotDynamicFC(dynamicResult, 'States', states)
%   fig = exploreFNIRS.connectivity.plotDynamicFC(dynamicResult, 'SavePath', 'dfc.png')
%
% Inputs:
%   dynamicResult - Output from computeDynamicFC with:
%                   .matrices [C x C x W], .windowTimes [W x 1], .method
%
% Name-Value Parameters:
%   States     - Output from detectStates (default: [], no state display)
%   Title      - Figure title (default: auto)
%   Visible    - 'on' (default) or 'off'
%   SavePath   - File path to save figure
%   SaveWidth  - Width in pixels (default: 900)
%   SaveHeight - Height in pixels (default: 700)
%   SaveDPI    - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.connectivity.computeDynamicFC,
%   exploreFNIRS.connectivity.detectStates

    p = inputParser;
    addRequired(p, 'dynamicResult', @isstruct);
    addParameter(p, 'States', [], @(v) isempty(v) || isstruct(v));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 900, @isnumeric);
    addParameter(p, 'SaveHeight', 700, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, dynamicResult, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    matrices = dynamicResult.matrices;  % [C x C x W]
    windowTimes = dynamicResult.windowTimes;
    [nCh, ~, nWin] = size(matrices);
    hasStates = ~isempty(opts.States);

    % Compute global connectivity per window (mean upper triangle)
    triMask = triu(true(nCh), 1);
    globalConn = zeros(nWin, 1);
    for w = 1:nWin
        mat = matrices(:, :, w);
        vals = mat(triMask);
        globalConn(w) = mean(vals, 'omitnan');
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();

    if hasStates
        if isfield(opts.States, 'K')
            K = opts.States.K;
        else
            K = length(opts.States.centroidMatrices);
        end
        % Layout: top = time series, middle = state bar, bottom = centroids
        ax1 = subplot(3, 1, 1, 'Parent', fig);
        ax2 = subplot(3, 1, 2, 'Parent', fig);
        ax3 = subplot(3, 1, 3, 'Parent', fig);
    else
        ax1 = axes('Parent', fig);
    end

    % Panel 1: Global connectivity over time
    plot(ax1, windowTimes, globalConn, '-', 'LineWidth', sty.LineWidth, ...
        'Color', [0.2, 0.4, 0.8]);
    xlabel(ax1, 'Time (s)');
    ylabel(ax1, 'Mean Connectivity');

    if ~isempty(opts.Title)
        title(ax1, opts.Title);
    else
        bioLabel = '';
        if isfield(dynamicResult, 'biomarker')
            bioLabel = [', ' dynamicResult.biomarker];
        end
        title(ax1, pf2_base.plot.escapeTeX(sprintf('Dynamic FC (%s%s)', ...
            dynamicResult.method, bioLabel)));
    end

    xlim(ax1, [windowTimes(1), windowTimes(end)]);
    grid(ax1, 'on');
    sty.applyToAxes(ax1);

    if hasStates
        assignments = opts.States.assignments;
        stateColors = lines(K);

        % Panel 2: State color bar
        % Create an image of state assignments
        stateImg = zeros(1, nWin, 3);
        for w = 1:nWin
            stateImg(1, w, :) = stateColors(assignments(w), :);
        end
        image(ax2, windowTimes, 1, stateImg);
        set(ax2, 'YTick', []);
        xlabel(ax2, 'Time (s)');
        ylabel(ax2, 'State');
        xlim(ax2, [windowTimes(1), windowTimes(end)]);
        title(ax2, sprintf('State Assignments (K=%d, mean silhouette=%.2f)', ...
            K, mean(opts.States.silhouette, 'omitnan')));
        sty.applyToAxes(ax2);

        % Panel 3: Centroid matrices side by side
        delete(ax3);
        centroidMatrices = opts.States.centroidMatrices;

        maxAbsVal = 0;
        for k = 1:K
            cMat = centroidMatrices{k};
            cMat(logical(eye(size(cMat)))) = NaN;
            maxAbsVal = max(maxAbsVal, max(abs(cMat(:)), [], 'omitnan'));
        end
        if maxAbsVal == 0
            maxAbsVal = 1;
        end

        for k = 1:K
            ax = subplot(3, K, 2*K + k, 'Parent', fig);
            cMat = centroidMatrices{k};
            imagesc(ax, cMat, [-maxAbsVal, maxAbsVal]);
            axis(ax, 'square');
            title(ax, sprintf('State %d', k), 'Color', stateColors(k, :));
            set(ax, 'XTick', [], 'YTick', []);
            colormap(ax, divergingColormap(256));

            nInState = sum(assignments == k);
            xlabel(ax, sprintf('n=%d', nInState));
            sty.applyToAxes(ax);
        end
    end

    % Save
    if ~isempty(opts.SavePath)
        pf2_base.plot.handleSave(fig, opts);
    end
end


function cmap = divergingColormap(n)
% Blue-white-red diverging colormap
    half = floor(n / 2);

    r1 = linspace(0.2, 1, half)';
    g1 = linspace(0.3, 1, half)';
    b1 = linspace(0.8, 1, half)';

    r2 = linspace(1, 0.8, n - half)';
    g2 = linspace(1, 0.2, n - half)';
    b2 = linspace(1, 0.2, n - half)';

    cmap = [r1 g1 b1; r2 g2 b2];
end
