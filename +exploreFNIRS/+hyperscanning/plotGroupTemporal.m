function fig = plotGroupTemporal(result, varargin)
% PLOTGROUPTEMPORAL Time-resolved group hyperscanning coupling
%
% Plots the mean coupling across dyads over time with shaded error bands.
% Requires windowed coupling results from computeGroup where dyads have
% .windowed=true and .windowTimes fields. Optionally shades time windows
% where coupling is statistically significant.
%
% Syntax:
%   fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result)
%   fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, 'ErrorType', 'SD')
%   fig = exploreFNIRS.hyperscanning.plotGroupTemporal(result, 'Channels', [1 3 5])
%
% Inputs:
%   result - Struct from computeGroup where dyads have windowed=true:
%            .dyads{d}.values     - [nWin x nCh] windowed coupling values
%            .dyads{d}.windowTimes - [nWin x 1] time vector for windows
%            .dyads{d}.windowed   - true
%            .channels, .method, .biomarker
%
% Name-Value Parameters:
%   Channels        - Which channels to average across (default: all)
%   ErrorType       - Error band type: 'SEM' (default), 'SD', 'none'
%   ShowSignificance - Shade significant time windows (default: false)
%   PThreshold      - Significance threshold (default: 0.05)
%   LineColor       - Main line color [r g b] (default: [0.2, 0.4, 0.7])
%   FillColor       - Error band color [r g b] (default: same as LineColor)
%   Title           - Figure title (default: auto)
%   Visible         - 'on' (default) or 'off'
%   SavePath        - File path to save figure
%   SaveWidth       - Width in pixels (default: 800)
%   SaveHeight      - Height in pixels (default: 450)
%   SaveDPI         - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.hyperscanning.computeGroup,
%   exploreFNIRS.hyperscanning.plotGroup

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'Channels', [], @(v) isempty(v) || isnumeric(v));
    addParameter(p, 'ErrorType', 'SEM', @ischar);
    addParameter(p, 'ShowSignificance', false, @islogical);
    addParameter(p, 'PThreshold', 0.05, @isnumeric);
    addParameter(p, 'LineColor', [0.2, 0.4, 0.7], @(v) isnumeric(v) && length(v) == 3);
    addParameter(p, 'FillColor', [], @(v) isempty(v) || (isnumeric(v) && length(v) == 3));
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 450, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    addParameter(p, 'TightLayout', false, @islogical);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    if isempty(opts.FillColor)
        opts.FillColor = opts.LineColor;
    end

    % Validate windowed data
    if ~isfield(result, 'dyads') || isempty(result.dyads)
        error('exploreFNIRS:hyperscanning:plotGroupTemporal', ...
            'Result must have .dyads cell array from computeGroup.');
    end

    firstDyad = result.dyads{1};
    if ~isfield(firstDyad, 'windowed') || ~firstDyad.windowed
        error('exploreFNIRS:hyperscanning:plotGroupTemporal', ...
            ['Dyad results must be windowed (windowed=true). ' ...
             'Note: computeGroup collapses windowed coupling to scalar means, ' ...
             'so its output cannot be used here. To get windowed group data, ' ...
             'call computeDyad directly with a windowed coupling method ' ...
             '(e.g., ''CouplingArgs'', {''WindowSize'', 10}) for each dyad, ' ...
             'then pass the collected results to this function.']);
    end

    if ~isfield(firstDyad, 'windowTimes')
        error('exploreFNIRS:hyperscanning:plotGroupTemporal', ...
            'Dyad results must have .windowTimes field.');
    end

    nDyads = length(result.dyads);
    timeVec = firstDyad.windowTimes(:);
    nWin = length(timeVec);

    % Determine channel subset
    if isempty(opts.Channels)
        if isfield(result, 'channels')
            chIdx = 1:length(result.channels);
        else
            nCh = size(firstDyad.values, 2);
            chIdx = 1:nCh;
        end
    else
        if isfield(result, 'channels')
            [~, chIdx] = ismember(opts.Channels, result.channels);
            chIdx(chIdx == 0) = [];
        else
            chIdx = opts.Channels;
        end
    end

    % For each dyad, average values across selected channels to get [nWin x 1]
    dyadTimeSeries = zeros(nWin, nDyads);
    for d = 1:nDyads
        dyad = result.dyads{d};
        vals = dyad.values;  % [nWin x nCh]

        % Handle case where values might be column vector (single channel)
        if isvector(vals)
            vals = vals(:);
        end

        % Select channels and average
        if size(vals, 2) >= max(chIdx)
            selectedVals = vals(:, chIdx);
        else
            selectedVals = vals;
        end

        dyadTimeSeries(:, d) = mean(selectedVals, 2, 'omitnan');
    end

    % Compute group mean and error across dyads
    groupMean = mean(dyadTimeSeries, 2, 'omitnan');
    groupSD = std(dyadTimeSeries, 0, 2, 'omitnan');
    groupSEM = groupSD / sqrt(nDyads);

    switch upper(opts.ErrorType)
        case 'SEM'
            errorVals = groupSEM;
        case 'SD'
            errorVals = groupSD;
        case 'NONE'
            errorVals = zeros(nWin, 1);
        otherwise
            errorVals = groupSEM;
    end

    % Get style
    sty = pf2_base.plot.PlotStyle.getDefault();

    % Create figure
    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'SavePath', opts.SavePath, 'Width', opts.SaveWidth, ...
        'Height', opts.SaveHeight);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % Shaded error band
    if ~strcmpi(opts.ErrorType, 'none')
        upperBound = groupMean + errorVals;
        lowerBound = groupMean - errorVals;

        fillX = [timeVec; flipud(timeVec)];
        fillY = [upperBound; flipud(lowerBound)];

        fill(ax, fillX, fillY, opts.FillColor, ...
            'FaceAlpha', sty.ErrorAlpha, 'EdgeColor', 'none');
    end

    % Main line
    plot(ax, timeVec, groupMean, '-', 'Color', opts.LineColor, ...
        'LineWidth', sty.LineWidth);

    % Significance shading
    if opts.ShowSignificance
        % Perform one-sample t-test at each time window
        for w = 1:nWin
            vals = dyadTimeSeries(w, :);
            if nDyads >= 3
                [~, pVal] = pf2_base.compat.ttest(vals);
            else
                pVal = 1;
            end

            if pVal < opts.PThreshold
                % Shade this window
                wStart = timeVec(w);
                if w < nWin
                    wEnd = timeVec(w + 1);
                elseif nWin > 1
                    wEnd = timeVec(w) + (timeVec(w) - timeVec(w - 1));
                else
                    wEnd = wStart + 1;
                end
                yRange = ylim(ax);
                patch(ax, [wStart, wEnd, wEnd, wStart], ...
                    [yRange(1), yRange(1), yRange(2), yRange(2)], ...
                    [0.9, 0.8, 0.2], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
            end
        end
    end

    % Zero line
    plot(ax, [timeVec(1), timeVec(end)], [0, 0], '-', ...
        'Color', sty.ZeroLineColor, 'LineWidth', 0.5);

    hold(ax, 'off');

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Coupling');

    % Title
    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        methodStr = '';
        bioStr = '';
        if isfield(result, 'method')
            methodStr = result.method;
        end
        if isfield(result, 'biomarker')
            bioStr = result.biomarker;
        end
        errLabel = '';
        if ~strcmpi(opts.ErrorType, 'none')
            errLabel = sprintf(', %s', upper(opts.ErrorType));
        end
        title(ax, pf2_base.plot.escapeTeX(sprintf('Temporal Coupling (%s, %s, N=%d%s)', ...
            methodStr, bioStr, nDyads, errLabel)));
    end

    box(ax, 'on');

    % Apply style
    sty.applyToAxes(ax);

    % Save
    pf2_base.plot.handleSave(fig, opts);

end
