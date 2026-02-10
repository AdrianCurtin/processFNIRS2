classdef PlotStyle
% PLOTSTYLE Centralized style configuration for all pf2 plot functions
%
% Value class holding default font sizes, line widths, and colors used
% across all plotting functions. Provides static factories for common
% output contexts (screen, publication, presentation).
%
% Theme-aware: factory methods automatically detect MATLAB's dark mode
% theme and adjust foreground/background colors accordingly. Saved
% figures always export with white background (handled by saveFigure).
%
% Syntax:
%   s = pf2_base.plot.PlotStyle.getDefault()
%   s = pf2_base.plot.PlotStyle.getPublication()
%   s = pf2_base.plot.PlotStyle.getPresentation()
%   s.applyToAxes(ax)
%   s.applyToFigure(fig)
%
% Theme control:
%   pf2_base.plot.PlotStyle.isDarkMode()           % query current theme
%   pf2_base.plot.PlotStyle.setForceLightMode(true) % force light mode
%
% Example:
%   s = pf2_base.plot.PlotStyle.getDefault();
%   fig = figure('Color', s.FigureColor);
%   ax = axes('Parent', fig);
%   plot(ax, 1:10);
%   s.applyToAxes(ax);
%
% See also: pf2_base.plot.createFigure, pf2_base.plot.handleSave

    properties
        FontSize        = 11
        TitleFontSize   = 13
        LegendFontSize  = 9
        LineWidth       = 1.5
        AxisLineWidth   = 0.8
        ErrorAlpha      = 0.2
        FigureColor     = [1 1 1]
        GridAlpha       = 0.15
        GridColor       = [0.5, 0.5, 0.5]
        ForegroundColor = [0 0 0]
        BackgroundColor = [1 1 1]
        DimColor        = [0.4 0.4 0.4]
        ZeroLineColor   = [0 0 0]
        LegendBgColor   = [1 1 1]
        LegendTextColor = [0 0 0]
        LegendEdgeColor = [0.5 0.5 0.5]
    end

    methods (Static)

        function s = getDefault()
        % GETDEFAULT Standard screen display style (theme-aware)
            s = pf2_base.plot.PlotStyle();
            s = pf2_base.plot.PlotStyle.applyTheme(s);
        end

        function s = getPublication()
        % GETPUBLICATION Higher-resolution style for journal figures
            s = pf2_base.plot.PlotStyle();
            s.FontSize = 10;
            s.TitleFontSize = 12;
            s.LegendFontSize = 8;
            s.LineWidth = 1.0;
            s.AxisLineWidth = 0.6;
            s = pf2_base.plot.PlotStyle.applyTheme(s);
        end

        function s = getPresentation()
        % GETPRESENTATION Larger fonts and thicker lines for slides
            s = pf2_base.plot.PlotStyle();
            s.FontSize = 14;
            s.TitleFontSize = 16;
            s.LegendFontSize = 11;
            s.LineWidth = 2.0;
            s.AxisLineWidth = 1.2;
            s = pf2_base.plot.PlotStyle.applyTheme(s);
        end

        function tf = isDarkMode()
        % ISDARKMODE Detect whether MATLAB is using a dark theme
        %
        %   Returns true if MATLAB's figure background is dark, unless
        %   ForceLightMode is enabled via setForceLightMode(true).
            if getpref('pf2', 'ForceLightMode', false)
                tf = false;
                return;
            end
            bgColor = get(groot, 'defaultFigureColor');
            tf = isnumeric(bgColor) && mean(bgColor) < 0.5;
        end

        function setForceLightMode(tf)
        % SETFORCELIGHTMODE Override dark mode detection
        %
        %   pf2_base.plot.PlotStyle.setForceLightMode(true)
        %   Forces all plots to use light-mode colors regardless of theme.
            setpref('pf2', 'ForceLightMode', logical(tf));
        end

        function tf = getForceLightMode()
        % GETFORCELIGHTMODE Query the ForceLightMode preference
            tf = getpref('pf2', 'ForceLightMode', false);
        end

    end

    methods (Static, Access = private)

        function s = applyTheme(s)
        % APPLYTHEME Set theme-aware colors based on MATLAB dark mode state
            if pf2_base.plot.PlotStyle.isDarkMode()
                figBg = get(groot, 'defaultFigureColor');
                axBg  = get(groot, 'defaultAxesColor');
                if ~isnumeric(figBg), figBg = [0.15 0.15 0.15]; end
                if ~isnumeric(axBg),  axBg  = figBg;             end
                s.FigureColor     = figBg;
                s.ForegroundColor = [1 1 1];
                s.BackgroundColor = axBg;
                s.GridColor       = [0.55 0.55 0.55];
                s.DimColor        = [0.65 0.65 0.65];
                s.ZeroLineColor   = [0.8 0.8 0.8];
                s.LegendBgColor   = axBg;
                s.LegendTextColor = [1 1 1];
                s.LegendEdgeColor = [0.5 0.5 0.5];
            end
        end

    end

    methods

        function applyToAxes(obj, ax)
        % APPLYTOAXES Apply style settings to an axes handle
        %
        %   s.applyToAxes(ax)

            set(ax, 'FontSize', obj.FontSize);
            set(ax, 'LineWidth', obj.AxisLineWidth);
            set(ax, 'GridAlpha', obj.GridAlpha);
            set(ax, 'GridColor', obj.GridColor);
            set(ax, 'XColor', obj.ForegroundColor);
            set(ax, 'YColor', obj.ForegroundColor);
            if isprop(ax, 'ZColor')
                set(ax, 'ZColor', obj.ForegroundColor);
            end
            set(ax, 'Color', obj.BackgroundColor);
            if ~isempty(ax.Title)
                set(ax.Title, 'Color', obj.ForegroundColor);
            end
            if ~isempty(ax.XLabel)
                set(ax.XLabel, 'Color', obj.ForegroundColor);
            end
            if ~isempty(ax.YLabel)
                set(ax.YLabel, 'Color', obj.ForegroundColor);
            end
        end

        function applyToFigure(obj, fig)
        % APPLYTOFIGURE Apply style settings to a figure handle
        %
        %   s.applyToFigure(fig)

            set(fig, 'Color', obj.FigureColor);

            % Apply to all axes in the figure
            allAx = findobj(fig, 'Type', 'Axes');
            for i = 1:length(allAx)
                obj.applyToAxes(allAx(i));
            end

            % Legends
            allLeg = findobj(fig, 'Type', 'Legend');
            for i = 1:length(allLeg)
                set(allLeg(i), 'TextColor', obj.LegendTextColor);
                set(allLeg(i), 'Color', obj.LegendBgColor);
                set(allLeg(i), 'EdgeColor', obj.LegendEdgeColor);
            end

            % Colorbars
            allCb = findobj(fig, 'Type', 'Colorbar');
            for i = 1:length(allCb)
                set(allCb(i), 'Color', obj.ForegroundColor);
                if isprop(allCb(i), 'Label')
                    set(allCb(i).Label, 'Color', obj.ForegroundColor);
                end
            end
        end

    end

end
