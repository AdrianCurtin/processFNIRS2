function paths = saveFigureSet(figures, basePath, varargin)
% SAVEFIGURESET Batch-save struct of figure handles with consistent naming
%
% Saves all figures in a struct using field names as file suffixes.
% Delegates to pf2_base.plot.saveFigure for each figure.
%
% Syntax:
%   paths = exploreFNIRS.report.saveFigureSet(figures, basePath)
%   paths = exploreFNIRS.report.saveFigureSet(figures, basePath, 'DPI', 300)
%
% Inputs:
%   figures  - Struct with figure handles (field names become suffixes)
%              e.g., struct('temporal', fig1, 'bar', fig2, 'topo', fig3)
%   basePath - Base file path (e.g., 'output/study1')
%              Files saved as: 'output/study1_temporal.png', etc.
%
% Name-Value Parameters:
%   Format - File extension (default: 'png')
%   Width  - Width in pixels (default: 800)
%   Height - Height in pixels (default: 500)
%   DPI    - Resolution (default: 300)
%   Style  - 'default', 'publication', or 'presentation' (default: 'publication')
%
% Outputs:
%   paths - Struct with same field names, containing saved file paths
%
% Example:
%   figs.temporal = ex.plotTemporal('Visible', 'off');
%   figs.bar = ex.plotBar('Visible', 'off');
%   paths = exploreFNIRS.report.saveFigureSet(figs, 'results/group1', ...
%       'DPI', 300, 'Style', 'publication');
%
% See also: pf2_base.plot.saveFigure, pf2_base.plot.PlotStyle

    ip = inputParser;
    addRequired(ip, 'figures', @isstruct);
    addRequired(ip, 'basePath', @ischar);
    addParameter(ip, 'Format', 'png', @ischar);
    addParameter(ip, 'Width', 800, @isnumeric);
    addParameter(ip, 'Height', 500, @isnumeric);
    addParameter(ip, 'DPI', 300, @isnumeric);
    addParameter(ip, 'Style', 'publication', @ischar);
    parse(ip, figures, basePath, varargin{:});
    opts = ip.Results;

    % Ensure output directory exists
    [outDir, ~, ~] = fileparts(basePath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end

    % Apply style to all figures
    switch lower(opts.Style)
        case 'publication'
            sty = pf2_base.plot.PlotStyle.getPublication();
        case 'presentation'
            sty = pf2_base.plot.PlotStyle.getPresentation();
        otherwise
            sty = pf2_base.plot.PlotStyle.getDefault();
    end

    flds = fieldnames(figures);
    paths = struct();

    for i = 1:length(flds)
        name = flds{i};
        fig = figures.(name);

        if ~isvalid(fig)
            warning('Figure "%s" is invalid, skipping.', name);
            continue;
        end

        % Force white background and light-mode styling
        set(fig, 'Color', 'w');
        sty.applyToFigure(fig);
        exploreFNIRS.report.forceWhiteMode(fig);

        savePath = sprintf('%s_%s.%s', basePath, name, opts.Format);
        pf2_base.plot.saveFigure(fig, savePath, opts.Width, opts.Height, opts.DPI);
        paths.(name) = savePath;
        fprintf('Saved: %s\n', savePath);
    end
end
