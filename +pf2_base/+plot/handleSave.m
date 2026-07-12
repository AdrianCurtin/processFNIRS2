function handleSave(fig, opts)
% HANDLESAVE Apply layout options and save figure if SavePath is non-empty
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
%          .TightLayout - Apply tight layout to reduce whitespace (default: false)
%          .SavePath    - File path (empty = no-op)
%          .SaveWidth   - Width in pixels (default: 800)
%          .SaveHeight  - Height in pixels (default: 500)
%          .SaveDPI     - Resolution (default: 150)
%
% See also: pf2_base.plot.saveFigure, pf2_base.plot.createFigure,
%           pf2_base.plot.applyTightLayout

    % Apply tight layout before saving (or for on-screen display)
    if isfield(opts, 'TightLayout') && opts.TightLayout
        pf2_base.plot.applyTightLayout(fig);
    end

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
