function fig = plotWcoherence(result, varargin)
% PLOTWCOHERENCE Time-frequency wavelet coherence visualization
%
% Renders wavelet coherence as a time-frequency heatmap with cone of
% influence overlay and optional phase arrow display. The standard
% visualization for wavelet coherence analysis.
%
% Syntax:
%   fig = exploreFNIRS.coupling.plotWcoherence(result)
%   fig = exploreFNIRS.coupling.plotWcoherence(result, 'ShowPhase', true)
%   fig = exploreFNIRS.coupling.plotWcoherence(result, 'FreqRange', [0.01 0.1])
%
% Inputs:
%   result - Struct from exploreFNIRS.coupling.wcoherence with fields:
%            .wcoh, .freqs, .times, .coi, .freqRange
%            Optionally .phase for phase arrow display
%
% Name-Value Parameters:
%   FreqRange   - [fLow fHigh] frequency limits for display (default: from result)
%   CLim        - Color limits [cmin cmax] (default: [0 1])
%   Colormap    - Colormap name or matrix (default: 'jet')
%   ShowCOI     - Show cone of influence overlay (default: true)
%   ShowPhase   - Show phase arrows (default: false, requires .phase)
%   PhaseStep   - Spacing of phase arrows in [freq, time] indices (default: [4, 8])
%   ShowBand    - Show frequency band boundaries as dashed lines (default: true)
%   LogFreq     - Use log scale for frequency axis (default: true)
%   Title       - Figure title (default: auto)
%   Visible     - 'on' (default) or 'off'
%   SavePath    - File path to save figure
%   SaveWidth   - Width in pixels (default: 800)
%   SaveHeight  - Height in pixels (default: 400)
%   SaveDPI     - Resolution (default: 150)
%
% Outputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.coupling.wcoherence, exploreFNIRS.connectivity.plotMatrix

    p = inputParser;
    addRequired(p, 'result', @isstruct);
    addParameter(p, 'FreqRange', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2));
    addParameter(p, 'CLim', [0, 1], @(v) isnumeric(v) && length(v) == 2);
    addParameter(p, 'Colormap', 'jet', @(v) ischar(v) || isnumeric(v));
    addParameter(p, 'ShowCOI', true, @islogical);
    addParameter(p, 'ShowPhase', false, @islogical);
    addParameter(p, 'PhaseStep', [4, 8], @(v) isnumeric(v) && numel(v) == 2);
    addParameter(p, 'ShowBand', true, @islogical);
    addParameter(p, 'LogFreq', true, @islogical);
    addParameter(p, 'Title', '', @ischar);
    addParameter(p, 'Visible', 'on', @ischar);
    addParameter(p, 'SavePath', '', @ischar);
    addParameter(p, 'SaveWidth', 800, @isnumeric);
    addParameter(p, 'SaveHeight', 400, @isnumeric);
    addParameter(p, 'SaveDPI', 150, @isnumeric);
    parse(p, result, varargin{:});
    opts = p.Results;

    if ~isempty(opts.SavePath)
        opts.Visible = 'off';
    end

    wcoh = result.wcoh;
    freqs = result.freqs;
    times = result.times;
    coi = result.coi(:)';

    % Frequency range for display
    if isempty(opts.FreqRange) && isfield(result, 'freqRange')
        dispRange = result.freqRange;
    elseif ~isempty(opts.FreqRange)
        dispRange = opts.FreqRange;
    else
        dispRange = [min(freqs), max(freqs)];
    end

    fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
        'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
        'SavePath', opts.SavePath);
    sty = pf2_base.plot.PlotStyle.getDefault();
    ax = axes('Parent', fig);

    % Plot coherence
    if opts.LogFreq && all(freqs > 0)
        surf(ax, times, freqs, wcoh, 'EdgeColor', 'none');
        view(ax, 0, 90);
        set(ax, 'YScale', 'log');
        set(ax, 'YDir', 'normal');
    else
        imagesc(ax, times, freqs, wcoh);
        set(ax, 'YDir', 'normal');
    end

    caxis(ax, opts.CLim);

    % Colormap
    if ischar(opts.Colormap)
        colormap(ax, opts.Colormap);
    else
        colormap(ax, opts.Colormap);
    end
    cb = colorbar(ax);
    cb.Label.String = 'Wavelet Coherence';

    % Frequency axis limits
    ylim(ax, dispRange);
    xlim(ax, [min(times), max(times)]);

    % Cone of influence overlay
    if opts.ShowCOI
        hold(ax, 'on');
        % Fill below COI boundary with semi-transparent gray
        coiFreqs = min(coi, max(freqs));
        fillX = [times(:)', fliplr(times(:)')];
        fillY = [coiFreqs, ones(1, length(times)) * min(freqs)];
        fill(ax, fillX, fillY, [0.5, 0.5, 0.5], ...
            'FaceAlpha', 0.4, 'EdgeColor', 'none');
        hold(ax, 'off');
    end

    % Frequency band boundaries
    if opts.ShowBand && isfield(result, 'freqRange')
        hold(ax, 'on');
        tRange = xlim(ax);
        plot(ax, tRange, [result.freqRange(1), result.freqRange(1)], ...
            '--w', 'LineWidth', 1);
        plot(ax, tRange, [result.freqRange(2), result.freqRange(2)], ...
            '--w', 'LineWidth', 1);
        hold(ax, 'off');
    end

    % Phase arrows
    if opts.ShowPhase && isfield(result, 'phase')
        hold(ax, 'on');
        phase = result.phase;
        fStep = opts.PhaseStep(1);
        tStep = opts.PhaseStep(2);

        fIdx = 1:fStep:length(freqs);
        tIdx = 1:tStep:length(times);

        for fi = fIdx
            for ti = tIdx
                if wcoh(fi, ti) > 0.5  % Only show arrows where coherence is notable
                    ang = phase(fi, ti);
                    dx = cos(ang) * (times(min(ti+1,end)) - times(ti)) * tStep * 0.3;
                    dy = sin(ang) * freqs(fi) * 0.1;
                    quiver(ax, times(ti), freqs(fi), dx, dy, 0, ...
                        'k', 'MaxHeadSize', 0.8, 'LineWidth', 0.5);
                end
            end
        end
        hold(ax, 'off');
    end

    % Labels
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Frequency (Hz)');

    if ~isempty(opts.Title)
        title(ax, opts.Title);
    else
        title(ax, sprintf('Wavelet Coherence (mean = %.3f)', result.value));
    end

    sty.applyToAxes(ax);

    pf2_base.plot.handleSave(fig, opts);

end
