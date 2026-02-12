function handleSave(fig, opts)
% HANDLESAVE Save figure if SavePath is non-empty, no-op otherwise
%
% Standardized save logic that replaces the repeated 8-line save block
% in every plot function. Delegates to pf2_base.plot.saveFigure.
%
% Syntax:
%   pf2_base.plot.handleSave(fig, opts)
%
% Inputs:
%   fig  - Figure handle
%   opts - Struct with optional fields:
%          .SavePath   - File path (empty = no-op)
%          .SaveWidth  - Width in pixels (default: 800)
%          .SaveHeight - Height in pixels (default: 500)
%          .SaveDPI    - Resolution (default: 150)
%
% See also: pf2_base.plot.saveFigure, pf2_base.plot.createFigure

    if ~isfield(opts, 'SavePath') || isempty(opts.SavePath)
        return;
    end

    w = 800;
    h = 500;
    d = 150;
    if isfield(opts, 'SaveWidth'),  w = opts.SaveWidth;  end
    if isfield(opts, 'SaveHeight'), h = opts.SaveHeight; end
    if isfield(opts, 'SaveDPI'),    d = opts.SaveDPI;    end

    pf2_base.plot.saveFigure(fig, opts.SavePath, w, h, d);
    fprintf('Saved: %s\n', opts.SavePath);
end
