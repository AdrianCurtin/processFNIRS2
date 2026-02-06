function fig = plotWindowed(result, varargin)
% PLOTWINDOWED Time series visualization of windowed coupling values
%
% Plots coupling values over time for windowed coupling results (pearson,
% spearman, xcorr with WindowSize). Shows the coupling trajectory with
% optional confidence band and significance threshold.
%
% Syntax:
%   fig = exploreFNIRS.coupling.plotWindowed(result)
%   fig = exploreFNIRS.coupling.plotWindowed(result, 'ShowThreshold', true)
%   fig = exploreFNIRS.coupling.plotWindowed(results)  % cell array overlay
%
% Inputs:
%   result  - Struct from a windowed coupling function with fields:
%             .value (vector), .pvalue (vector), .windowTimes, .method
%             OR cell array of result structs (one line per result)
%
% Name-Value Parameters:
%   Labels       - Cell array of labels for legend (default: auto from method)
%   ShowThreshold - Show significance threshold line (default: false)
%   PThreshold   - Significance level for threshold (default: 0.05)
%   YLim         - Y-axis limits (default: auto)
%   LineWidth    - Line width (default: 1.5)
%   ShowCI       - Show confidence band as shaded area (default: false)
%   Title        - Figure title (default: auto)
%   Visible      - 'on' (default) or 'off'
%   SavePath     - File path to save figure
%   SaveWidth    - Width in pixels (default: 700)
%   SaveHeight   - Height in pixels (default: 350)
%   SaveDPI      - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.coupling.pearson, exploreFNIRS.coupling.spearman

    p = inputParser;
    addRequired(p, 'result');
    addParameter(p, 'Labels', {}, @iscell);
    addParameter(p, 'ShowThreshold', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'YLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'LineWidth', 1.5, @isnumeric);
    addParameter(p, 'ShowCI', false, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 700, @isnumeric);
    addParameter(p, 'SaveHeight', 350, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    % Normalize input to cell array
    if isstruct(result)
        results = {result};
    else
        results = result;
    end

    nSeries = length(results);
    colors = lines(nSeries);

    fig = figure('Visible', opts.Visible, ...
        'Position', [100, 100, opts.SaveWidth, opts.SaveHeight], ...
        'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');

    legendEntries = {};
    for k = 1:nSeries
        r = results{k};

        if ~r.windowed || ~isfield(r, 'windowTimes')
            warning('exploreFNIRS:coupling:plotWindowed', ...
                'Result %d is not windowed. Skipping.', k);
            continue;
        end

        t = r.windowTimes;
        v = r.value;

        plot(ax, t, v, '-', 'Color', colors(k, :), ...
            'LineWidth', opts.LineWidth);

        if ~isempty(opts.Labels) && k <= length(opts.Labels)
            legendEntries{end+1} = opts.Labels{k}; %#ok<AGROW>
        else
            legendEntries{end+1} = r.method; %#ok<AGROW>
        end

        % Significance masking: mark significant windows
        if opts.ShowThreshold && isfield(r, 'pvalue')
            sigMask = r.pvalue < opts.PThreshold;
            if any(sigMask)
                plot(ax, t(sigMask), v(sigMask), '.', ...
                    'Color', colors(k, :), 'MarkerSize', 12);
            end
        end
    end

    % Reference line at zero
    plot(ax, xlim(ax), [0, 0], '-', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);

    hold(ax, 'off');

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Coupling');

    if ~isempty(opts.YLim)
        ylim(ax, opts.YLim);
    end

    if ~isempty(legendEntries)
        legend(ax, legendEntries, 'Location', 'best');
    end

    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        title(ax, 'Windowed Coupling');
    end

    box(ax, 'on');
    grid(ax, 'on');

    % Save
    if ~isempty(opts.SavePath)
        if ~isempty(which('pf2_base.plot.saveFigure'))
            pf2_base.plot.saveFigure(fig, opts.SavePath, ...
                opts.SaveWidth, opts.SaveHeight, opts.SaveDPI);
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, opts.SavePath, '-dpng', sprintf('-r%d', opts.SaveDPI));
        end
        fprintf('Saved: %s\n', opts.SavePath);
    end

end
