classdef Explore3D < handle
% EXPLORE3D Interactive explorer for 3D cortical surface visualization
%
% Opens a live preview of pf2.probe.plot.interpolateValues3D with on-screen
% controls for the major rendering options (render style, matcap material,
% ambient-occlusion strength, camera view, colormap, interpolation, biomarker,
% time point and label toggles). Every change re-renders immediately, and the
% panel shows the exact equivalent command so it can be copied into a script.
% Useful both for dialling in a figure and as a guided tour of what the
% renderer can do.
%
% Syntax:
%   pf2.probe.plot.Explore3D(data)
%   app = pf2.probe.plot.Explore3D(data)
%   app = pf2.probe.plot.Explore3D(data, 'Visible', 'off')   % construct hidden
%
% Inputs:
%   data - Processed fNIRS struct containing at least one biomarker field
%          (HbO/HbR/HbTotal/HbDiff/CBSI) and a device with MNI coordinates.
%
% Name-Value Parameters:
%   'Visible' - 'on' (default) | 'off'. Build without showing (e.g. testing).
%
% Outputs:
%   app - The Explore3D handle (controls and current options are properties).
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   pf2.probe.plot.Explore3D(proc);
%
% See also: pf2.probe.plot.interpolateValues3D, pf2.probe.plot.topo,
%           pf2_base.plot.RenderStyle

    properties
        Data            % fNIRS data struct
        Fig             % figure handle
        Ax              % render axes
        Ctrl  = struct  % control handles
        Biomarkers      % available biomarker field names
    end

    properties (Constant, Access = private)
        STYLES   = {'showcase','publication'};
        MATCAPS  = {'clay','porcelain','matte','glossy','pewter','jade'};
        VIEWS    = {'auto','front','back','left','right','top','bottom', ...
                    'top-left','top-right','front-left','front-right'};
        CMAPS    = {'hotCropped','rdbu','viridis','cividis','actc','warm','hot','jet','parula'};
        INTERPS  = {'nearest','linear','quadratic','cubic','sensitivity'};
    end

    methods
        function self = Explore3D(data, varargin)
            ip = inputParser;
            ip.addRequired('data', @isstruct);
            ip.addParameter('Visible', 'on', @(x) any(strcmpi(x, {'on','off'})));
            ip.parse(data, varargin{:});
            self.Data = data;

            cand = {'HbO','HbR','HbTotal','HbDiff','CBSI'};
            self.Biomarkers = cand(isfield(data, cand));
            if isempty(self.Biomarkers)
                error('pf2:probe:plot:Explore3D:noBiomarker', ...
                    'data has no biomarker field (HbO/HbR/HbTotal/HbDiff/CBSI).');
            end

            self.buildUI(ip.Results.Visible);
            self.render();
        end
    end

    methods (Access = private)

        function buildUI(self, vis)
            self.Fig = figure('Name', 'pf2 · 3D Brain Explorer', ...
                'NumberTitle', 'off', 'Color', [1 1 1], ...
                'Units', 'pixels', 'Position', [80 80 1180 700], ...
                'Visible', vis, 'MenuBar', 'none', 'ToolBar', 'figure');

            self.Ax = axes('Parent', self.Fig, 'Units', 'normalized', ...
                'Position', [0.02 0.04 0.63 0.92]);

            pnl = uipanel('Parent', self.Fig, 'Units', 'normalized', ...
                'Position', [0.665 0.02 0.325 0.96], 'BackgroundColor', [0.96 0.96 0.97], ...
                'Title', 'Render options', 'FontWeight', 'bold');

            y = 0.955; dh = 0.052; gap = 0.004;
            % rows
            self.Ctrl.biomarker = self.rowPopup(pnl, y,        'Biomarker', self.Biomarkers); y = y - dh - gap;
            self.Ctrl.style     = self.rowPopup(pnl, y,        'Style',     self.STYLES);     y = y - dh - gap;
            self.Ctrl.matcap    = self.rowPopup(pnl, y,        'Matcap',    self.MATCAPS);    y = y - dh - gap;
            self.Ctrl.view      = self.rowPopup(pnl, y,        'View',      self.VIEWS);      y = y - dh - gap;
            self.Ctrl.cmap      = self.rowPopup(pnl, y,        'Colormap',  self.CMAPS);      y = y - dh - gap;
            self.Ctrl.interp    = self.rowPopup(pnl, y,        'Interp',    self.INTERPS);    y = y - dh - gap;

            % AO strength slider
            self.Ctrl.aoLabel = uicontrol(pnl, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.04], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', [0.96 0.96 0.97], 'String', 'Ambient occlusion: 0.38');
            y = y - 0.040;
            self.Ctrl.ao = uicontrol(pnl, 'Style', 'slider', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.035], 'Min', 0, 'Max', 0.8, 'Value', 0.38, ...
                'Callback', @(s,e) self.onChange());
            y = y - dh - gap;

            % Time mean checkbox + time slider
            self.Ctrl.timeMean = uicontrol(pnl, 'Style', 'checkbox', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.04], 'BackgroundColor', [0.96 0.96 0.97], ...
                'String', 'Time-average (whole record)', 'Value', 1, ...
                'Callback', @(s,e) self.onChange());
            y = y - 0.040;
            self.Ctrl.timeLabel = uicontrol(pnl, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.035], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', [0.96 0.96 0.97], 'String', 'Time: (mean)', 'Enable', 'off');
            y = y - 0.038;
            self.Ctrl.time = uicontrol(pnl, 'Style', 'slider', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.035], 'Min', 1, 'Max', max(2,size(self.biomarkerMatrix(),1)), ...
                'Value', 1, 'Enable', 'off', 'Callback', @(s,e) self.onChange());
            y = y - dh - gap;

            % Toggle checkboxes (two columns)
            self.Ctrl.chLabels = uicontrol(pnl, 'Style', 'checkbox', 'Units', 'normalized', ...
                'Position', [0.04 y 0.46 0.04], 'BackgroundColor', [0.96 0.96 0.97], ...
                'String', 'Channel #', 'Value', 0, 'Callback', @(s,e) self.onChange());
            self.Ctrl.sdLabels = uicontrol(pnl, 'Style', 'checkbox', 'Units', 'normalized', ...
                'Position', [0.52 y 0.46 0.04], 'BackgroundColor', [0.96 0.96 0.97], ...
                'String', 'S/D labels', 'Value', 0, 'Callback', @(s,e) self.onChange());
            y = y - 0.044;
            self.Ctrl.showAxes = uicontrol(pnl, 'Style', 'checkbox', 'Units', 'normalized', ...
                'Position', [0.04 y 0.46 0.04], 'BackgroundColor', [0.96 0.96 0.97], ...
                'String', 'Axes', 'Value', 0, 'Callback', @(s,e) self.onChange());
            self.Ctrl.colorbar = uicontrol(pnl, 'Style', 'checkbox', 'Units', 'normalized', ...
                'Position', [0.52 y 0.46 0.04], 'BackgroundColor', [0.96 0.96 0.97], ...
                'String', 'Colorbar', 'Value', 1, 'Callback', @(s,e) self.onChange());
            y = y - 0.05;

            % Command display
            uicontrol(pnl, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.03], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', [0.96 0.96 0.97], 'FontWeight', 'bold', ...
                'String', 'Equivalent command:');
            y = y - 0.155;
            self.Ctrl.cmd = uicontrol(pnl, 'Style', 'edit', 'Units', 'normalized', ...
                'Position', [0.04 y 0.92 0.15], 'Max', 6, 'Min', 0, ...
                'HorizontalAlignment', 'left', 'FontName', 'Menlo', 'FontSize', 9, ...
                'BackgroundColor', [1 1 1], 'String', '');
            y = y - 0.06;

            % Buttons
            uicontrol(pnl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.04 y 0.45 0.05], 'String', 'Copy command', ...
                'Callback', @(s,e) self.onCopy());
            uicontrol(pnl, 'Style', 'pushbutton', 'Units', 'normalized', ...
                'Position', [0.52 y 0.44 0.05], 'String', 'Save PNG…', ...
                'Callback', @(s,e) self.onSave());
        end

        function ctrl = rowPopup(self, pnl, y, lbl, items)
            uicontrol(pnl, 'Style', 'text', 'Units', 'normalized', ...
                'Position', [0.04 y 0.30 0.04], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', [0.96 0.96 0.97], 'String', lbl);
            ctrl = uicontrol(pnl, 'Style', 'popupmenu', 'Units', 'normalized', ...
                'Position', [0.35 y 0.61 0.045], 'String', items, ...
                'Callback', @(s,e) self.onChange());
        end

        function M = biomarkerMatrix(self)
            % Current biomarker [T x C] matrix (first available if none chosen).
            if isfield(self.Ctrl, 'biomarker') && isgraphics(self.Ctrl.biomarker)
                bio = self.Biomarkers{self.Ctrl.biomarker.Value};
            else
                bio = self.Biomarkers{1};
            end
            M = self.Data.(bio);
        end

        function onChange(self)
            % Enable/disable dependent controls then re-render.
            isShowcase = strcmp(self.STYLES{self.Ctrl.style.Value}, 'showcase');
            self.setEnable(self.Ctrl.matcap, isShowcase);
            useMean = self.Ctrl.timeMean.Value == 1;
            self.setEnable(self.Ctrl.time, ~useMean);
            self.setEnable(self.Ctrl.timeLabel, ~useMean);
            % Keep the time slider range valid for the chosen biomarker.
            T = size(self.biomarkerMatrix(), 1);
            self.Ctrl.time.Max = max(2, T);
            self.Ctrl.time.Value = min(self.Ctrl.time.Value, self.Ctrl.time.Max);
            self.render();
        end

        function [vals, timeStr, timeComment] = currentVals(self)
            bio = self.Biomarkers{self.Ctrl.biomarker.Value};
            M = self.Data.(bio);
            if self.Ctrl.timeMean.Value == 1
                vals = mean(M, 1, 'omitnan');
                timeStr = '(mean)';
                timeComment = sprintf('vals = mean(data.%s, 1, ''omitnan'');', bio);
            else
                idx = round(self.Ctrl.time.Value);
                idx = max(1, min(size(M,1), idx));
                vals = M(idx, :);
                if isfield(self.Data, 'time') && numel(self.Data.time) >= idx
                    tsec = self.Data.time(idx);
                    timeStr = sprintf('t = %.1f s (sample %d)', tsec, idx);
                else
                    timeStr = sprintf('sample %d', idx);
                end
                timeComment = sprintf('vals = data.%s(%d, :);   %% %s', bio, idx, timeStr);
            end
        end

        function s = currentStyle(self)
            name = self.STYLES{self.Ctrl.style.Value};
            s = pf2_base.plot.RenderStyle.get(name);
            s.aoStrength = self.Ctrl.ao.Value;
            if strcmp(name, 'showcase')
                s.matcapMaterial = self.MATCAPS{self.Ctrl.matcap.Value};
            end
        end

        function render(self)
            set(0, 'CurrentFigure', self.Fig);
            [vals, timeStr, ~] = self.currentVals();
            self.Ctrl.aoLabel.String = sprintf('Ambient occlusion: %.2f', self.Ctrl.ao.Value);
            self.Ctrl.timeLabel.String = ['Time: ' timeStr];

            cla(self.Ax, 'reset');
            try
                pf2.probe.plot.interpolateValues3D(vals, self.Data, ...
                    'ax', self.Ax, ...
                    'Style', self.currentStyle(), ...
                    'initCamPosition', self.VIEWS{self.Ctrl.view.Value}, ...
                    'cmap', self.CMAPS{self.Ctrl.cmap.Value}, ...
                    'interpolateType', self.INTERPS{self.Ctrl.interp.Value}, ...
                    'ChannelLabels', self.Ctrl.chLabels.Value == 1, ...
                    'SDLabels', self.Ctrl.sdLabels.Value == 1, ...
                    'ShowAxes', self.Ctrl.showAxes.Value == 1, ...
                    'showColorbar', self.Ctrl.colorbar.Value == 1);
            catch err
                title(self.Ax, ['Render error: ' err.message], 'Color', [0.7 0 0]);
            end
            self.Ctrl.cmd.String = self.commandString();
        end

        function str = commandString(self)
            [~, ~, timeComment] = self.currentVals();
            name = self.STYLES{self.Ctrl.style.Value};
            % Style: emit a plain name unless AO/matcap differ from the preset.
            preset = pf2_base.plot.RenderStyle.get(name);
            styleChanged = abs(self.Ctrl.ao.Value - preset.aoStrength) > 1e-6;
            if strcmp(name,'showcase')
                styleChanged = styleChanged || ~strcmp(self.MATCAPS{self.Ctrl.matcap.Value}, preset.matcapMaterial);
            end
            lines = {'data = ...;   % your processed fNIRS struct', timeComment};
            if styleChanged
                lines{end+1} = sprintf('sty = pf2_base.plot.RenderStyle.get(''%s'');', name);
                lines{end+1} = sprintf('sty.aoStrength = %.2f;', self.Ctrl.ao.Value);
                if strcmp(name,'showcase')
                    lines{end+1} = sprintf('sty.matcapMaterial = ''%s'';', self.MATCAPS{self.Ctrl.matcap.Value});
                end
                styleArg = 'sty';
            else
                styleArg = sprintf('''%s''', name);
            end
            call = sprintf(['pf2.probe.plot.interpolateValues3D(vals, data, ...\n' ...
                '    ''Style'', %s, ''initCamPosition'', ''%s'', ''cmap'', ''%s'', ...\n' ...
                '    ''interpolateType'', ''%s'', ''ChannelLabels'', %s, ''SDLabels'', %s, ...\n' ...
                '    ''ShowAxes'', %s, ''showColorbar'', %s);'], ...
                styleArg, self.VIEWS{self.Ctrl.view.Value}, self.CMAPS{self.Ctrl.cmap.Value}, ...
                self.INTERPS{self.Ctrl.interp.Value}, ...
                self.tf(self.Ctrl.chLabels.Value), self.tf(self.Ctrl.sdLabels.Value), ...
                self.tf(self.Ctrl.showAxes.Value), self.tf(self.Ctrl.colorbar.Value));
            lines{end+1} = call;
            str = strjoin(lines, newline);
        end

        function onCopy(self)
            clipboard('copy', self.commandString());
        end

        function onSave(self)
            [f, pth] = uiputfile({'*.png','PNG image'; '*.jpg','JPEG image'}, ...
                'Save brain render', 'brain.png');
            if isequal(f, 0), return; end
            outPath = fullfile(pth, f);
            [vals, ~, ~] = self.currentVals();
            tmpFig = figure('Visible', 'off', 'Color', [1 1 1], 'Position', [100 100 900 800]);
            cleanup = onCleanup(@() close(tmpFig)); %#ok<NASGU>
            tmpAx = axes('Parent', tmpFig);
            set(0, 'CurrentFigure', tmpFig);   % so the renderer's gca-based light setup targets this axes
            pf2.probe.plot.interpolateValues3D(vals, self.Data, ...
                'ax', tmpAx, ...
                'Style', self.currentStyle(), ...
                'initCamPosition', self.VIEWS{self.Ctrl.view.Value}, ...
                'cmap', self.CMAPS{self.Ctrl.cmap.Value}, ...
                'interpolateType', self.INTERPS{self.Ctrl.interp.Value}, ...
                'ChannelLabels', self.Ctrl.chLabels.Value == 1, ...
                'SDLabels', self.Ctrl.sdLabels.Value == 1, ...
                'ShowAxes', self.Ctrl.showAxes.Value == 1, ...
                'showColorbar', self.Ctrl.colorbar.Value == 1, ...
                'savePath', outPath);
        end

    end

    methods (Static, Access = private)
        function setEnable(h, tf)
            if tf, h.Enable = 'on'; else, h.Enable = 'off'; end
        end
        function s = tf(v)
            if v == 1, s = 'true'; else, s = 'false'; end
        end
    end
end
