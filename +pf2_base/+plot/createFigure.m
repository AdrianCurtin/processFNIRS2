function fig = createFigure(varargin)
% CREATEFIGURE Standardized figure creation with PlotStyle defaults
%
% Creates a figure with consistent styling. Automatically sets Visible to
% 'off' when a SavePath is provided for headless rendering.
%
% Syntax:
%   fig = pf2_base.plot.createFigure()
%   fig = pf2_base.plot.createFigure('SavePath', 'out.png')
%   fig = pf2_base.plot.createFigure('Width', 800, 'Height', 500)
%
% Name-Value Parameters:
%   Visible   - 'on' (default) or 'off'
%   SavePath  - If non-empty, forces Visible='off'
%   Width     - Figure width in pixels (default: 800)
%   Height    - Figure height in pixels (default: 500)
%   Style     - PlotStyle object (default: PlotStyle.getDefault())
%
% Outputs:
%   fig - Figure handle
%
% See also: pf2_base.plot.PlotStyle, pf2_base.plot.handleSave

    p = inputParser;
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'Width', 800, @isnumeric);
    addParameter(p, 'Height', 500, @isnumeric);
    addParameter(p, 'Style', [], @(x) isempty(x) || isa(x, 'pf2_base.plot.PlotStyle'));
    parse(p, varargin{:});
    opts = p.Results;

    if isempty(opts.Style)
        sty = pf2_base.plot.PlotStyle.getDefault();
    else
        sty = opts.Style;
    end

    vis = opts.Visible;
    if ~isempty(opts.SavePath)
        vis = 'off';
    end

    fig = figure('Visible', vis, ...
        'Position', [100, 100, opts.Width, opts.Height], ...
        'Color', sty.FigureColor);
end
