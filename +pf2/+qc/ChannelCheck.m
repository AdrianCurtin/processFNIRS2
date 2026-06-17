classdef ChannelCheck < matlab.apps.AppBase
% CHANNELCHECK App Designer channel quality review GUI
%
% Modern programmatic App Designer replacement for probeCheckGUI.
% Supports single-dataset and multi-dataset (cell array) modes with
% integrated QC metrics, undo/redo, bulk operations, and spatial
% probe-arranged mini-plot grid.
%
% Syntax:
%   app = pf2.qc.ChannelCheck(data)
%   app = pf2.qc.ChannelCheck(allData)
%   app = pf2.qc.ChannelCheck(data, 'CalledFromImport', true)
%   app = pf2.qc.ChannelCheck(data, 'SkipConfirmation', true)
%
% Name-Value Parameters:
%   CalledFromImport   - If true, saves _CH.mat on Save without
%                        confirmation dialog (default: false)
%   SkipConfirmation   - If true, suppresses all confirmation dialogs
%                        (default: false)
%
% After the window closes, read app.OutputData for the modified data.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   app = pf2.qc.ChannelCheck(data);
%   modifiedData = app.OutputData;
%   delete(app);
%
% See also: pf2.qc.pipeline.assess, pf2.qc.sci, pf2.qc.powerSpectrum

    properties (Access = public)
        UIFigure    matlab.ui.Figure
        OutputData  % Modified data (struct or cell array) returned to caller
    end

    properties (Access = private)
        % --- Mode & Data ---
        IsMultiFile     logical = false
        AllData         cell = {}
        Data            struct
        CurrentDataIndex double = 1
        CalledFromImport logical = false
        SkipConfirmation logical = false

        % --- Device / Layout ---
        Dev             % pf2.Device or []
        LayoutPositions cell = {}
        NumChannels     double = 0
        IsProcessed     logical = false
        ChannelColumns  cell = {}       % {ch} = raw column indices
        ChannelWavelengths cell = {}    % {ch} = wavelength (nm) per column, NaN if unknown
        DeviceWLOrder   double = []     % sorted unique non-zero wavelengths (short -> long)

        % --- Channel State ---
        FchMask         double = []
        OrigFchMask     double = []
        OrigFchMaskAll  cell = {}      % multi-file: per-dataset original mask
        OrigHadFchMask  logical = false(1,0)  % multi-file: dataset originally had fchMask
        MaskHistory     cell = {}
        MaskFuture      cell = {}
        SelectedChannel double = 1

        % --- QC ---
        QCReport
        QCComputed      logical = false
        QCRecommendations double = []
        QCSettings      struct    % thresholds + enabled flags, persisted via prefs

        % --- Cached Data ---
        MiniTime        double = []
        MiniData        cell = {}       % {ch} = [T x nSignals]
        MiniMaxPts      double = 150
        DetailMaxPts    double = 2000
        AmbientColumns  cell = {}
        AmbientData     cell = {}

        % --- Stats ---
        ChanStats       struct

        % --- Settings ---
        AutoScaleOn     logical = false  % false = global scale (default), true = per-channel
        IsDarkMode      logical = false
        ThemeFg         = [0, 0, 0]

        % --- Colors ---
        WL1Color    = [0.90, 0.55, 0.10]    % Amber  (730nm)
        WL2Color    = [0.10, 0.65, 0.60]    % Teal   (850nm)
        AmbientColor = [0.5, 0.5, 0.5]      % Gray (dark/ambient channel)
        HbOColor    = [0.85, 0.10, 0.10]
        HbRColor    = [0.10, 0.10, 0.85]
        GoodBg      = [1, 1, 1]
        NoisyBg     = [1, 0.95, 0.85]
        RejectBg    = [1, 0.88, 0.88]
        SelectColor = [0.20, 0.55, 1.00]

        % --- Global Y limits ---
        GlobalYLim  double = []     % [ymin, ymax] across all channels
        RawMax      double = []     % Device max raw intensity
        RawMin      double = []     % Device min (ambient) raw intensity

        % --- Markers ---
        ShowMarkers     logical = false
        SelectedMarkerCodes double = []  % empty = all codes
        UniqueMarkerCodes double = []

        % --- Detail Plot Cursor ---
        DetailPlotTime  double = []     % downsampled time vector on detail plot
        DetailPlotData  double = []     % [T x nSignals] downsampled data matrix
        DetailPlotLabels cell = {}      % signal names for tooltip
        CursorLine                      % vertical line handle
        CursorText                      % text annotation handle

        % --- UI: Left Panel ---
        LeftPanel
        DatasetLabel
        DatasetListBox
        DatasetPrevBtn
        DatasetNextBtn
        InfoLabel
        QCTitleLabel
        QCAxes
        QCInfoLabel

        % --- UI: Center Panel ---
        ProbeGridPanel
        MiniAxes        cell = {}
        MiniLines       cell = {}
        MiniAuxLines    cell = {}  % ambient, rawMin, marker lines per channel
        MiniContextMenus cell = {}
        QCPatches       cell = {}

        % --- UI: Right Panel ---
        RightPanel
        ChannelTitleLabel
        DetailAxes
        PSDAxes
        StatsTextArea
        StateLabel
        MarkGoodBtn
        MarkNoisyBtn
        MarkRejectBtn
        PrevChBtn
        NextChBtn

        % --- UI: Toolbar ---
        RunQCBtn
        QCSettingsBtn
        AcceptRecsBtn
        RejectNoisyBtn
        ResetAllBtn
        UndoBtn
        RedoBtn
        AutoScaleChk
        SummaryLabel
        ShowMarkersChk
        MarkerCodesBtn
        SaveBtn
        CancelBtn
    end

    %% ================================================================
    %%  PUBLIC METHODS
    %% ================================================================
    methods (Access = public)

        function app = ChannelCheck(dataOrCell, varargin)
        % Constructor. Accepts struct or cell array.
            if pf2_base.env.isOctave()
                error('pf2:gui:octaveUnsupported', ...
                    ['pf2.qc.ChannelCheck requires MATLAB (App Designer). ' ...
                     'Under Octave, use pf2.qc.pipeline.assess for headless QC.']);
            end
            p = inputParser;
            addRequired(p, 'dataOrCell');
            addParameter(p, 'CalledFromImport', false, @islogical);
            addParameter(p, 'SkipConfirmation', false, @islogical);
            parse(p, dataOrCell, varargin{:});

            app.CalledFromImport = p.Results.CalledFromImport;
            app.SkipConfirmation = p.Results.SkipConfirmation;

            % Theme detection
            app.IsDarkMode = pf2_base.plot.PlotStyle.isDarkMode();
            if app.IsDarkMode
                bg = get(groot, 'defaultAxesColor');
                if ~isnumeric(bg), bg = [0.18, 0.18, 0.18]; end
                app.GoodBg = bg;
                app.NoisyBg = min(bg + [0.07, 0.04, -0.03], 1);
                app.RejectBg = min(bg + [0.10, 0.00, 0.00], 1);
                app.ThemeFg = [1, 1, 1];
                app.AmbientColor = [0.85, 0.85, 0.85]; % white-ish in dark mode
            end

            % Load QC settings from persistent prefs
            app.QCSettings = loadQCSettings();

            if iscell(dataOrCell)
                if isempty(dataOrCell)
                    error('pf2:ChannelCheck:emptyInput', ...
                        'Cell array must contain at least one data struct.');
                end
                app.IsMultiFile = true;
                app.AllData = dataOrCell(:)';
                initialData = dataOrCell{1};

                % Snapshot original masks per dataset so Cancel can revert
                % edits made while navigating between datasets.
                n = numel(app.AllData);
                app.OrigFchMaskAll = cell(1, n);
                app.OrigHadFchMask = false(1, n);
                for i = 1:n
                    if isfield(app.AllData{i}, 'fchMask')
                        app.OrigFchMaskAll{i} = app.AllData{i}.fchMask;
                        app.OrigHadFchMask(i) = true;
                    end
                end
            elseif isstruct(dataOrCell)
                app.IsMultiFile = false;
                initialData = dataOrCell;
            else
                error('pf2:ChannelCheck:badInput', ...
                    'Input must be a data struct or cell array.');
            end

            try
                createComponents(app);
                loadData(app, initialData);
                buildMiniAxesGrid(app);
                plotAllMiniChannels(app);
                selectChannel(app, 1);
                updateSummaryBar(app);

                if app.IsMultiFile
                    buildDatasetLabels(app);
                    app.DatasetListBox.Value = app.CurrentDataIndex;
                end

                app.UIFigure.Visible = 'on';

                % Auto-run QC on raw data
                if ~app.IsProcessed
                    runQC(app);
                end
            catch ME
                delete(app);
                rethrow(ME);
            end

            uiwait(app.UIFigure);
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

    end

    %% ================================================================
    %%  PRIVATE METHODS
    %% ================================================================
    methods (Access = private)

        %% ---- UI Creation ------------------------------------------

        function createComponents(app)
            % Figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100, 100, 1400, 900];
            app.UIFigure.Name = 'Channel Check';
            app.UIFigure.CloseRequestFcn = @(~,~) closeApp(app, true);
            app.UIFigure.KeyPressFcn = @(~,evt) onKeyPress(app, evt);
            app.UIFigure.WindowButtonMotionFcn = @(~,~) onMouseMove(app);

            % Main grid: detail row + content row + toolbar row
            mainGrid = uigridlayout(app.UIFigure, [3, 1]);
            mainGrid.RowHeight = {280, '1x', 44};
            mainGrid.Padding = [0,0,0,0];
            mainGrid.RowSpacing = 0;

            createDetailRow(app, mainGrid);

            % Content: left | center | right
            contentGrid = uigridlayout(mainGrid, [1, 3]);
            contentGrid.Layout.Row = 2;
            contentGrid.Layout.Column = 1;
            contentGrid.ColumnWidth = {200, '1x', 300};
            contentGrid.Padding = [0,0,0,0];
            contentGrid.ColumnSpacing = 2;

            createLeftPanel(app, contentGrid);
            createCenterPanel(app, contentGrid);
            createRightPanel(app, contentGrid);
            createToolbar(app, mainGrid);
        end

        function createDetailRow(app, parent)
            detailPanel = uipanel(parent, 'Title', '');
            detailPanel.Layout.Row = 1;
            detailPanel.Layout.Column = 1;

            g = uigridlayout(detailPanel, [1, 2]);
            g.ColumnWidth = {'1x', 150};
            g.Padding = [4,4,4,4];
            g.ColumnSpacing = 4;

            % Right strip: channel info + state buttons + nav (vertically centered)
            ctrlGrid = uigridlayout(g, [7, 2]);
            ctrlGrid.Layout.Row = 1;
            ctrlGrid.Layout.Column = 2;
            ctrlGrid.RowHeight = {'1x', 22, 28, 28, 28, 28, '1x'};
            ctrlGrid.ColumnWidth = {'1x', '1x'};
            ctrlGrid.Padding = [2,2,2,2];
            ctrlGrid.RowSpacing = 3;
            ctrlGrid.ColumnSpacing = 4;

            % Channel title
            app.ChannelTitleLabel = uilabel(ctrlGrid);
            app.ChannelTitleLabel.Layout.Row = 2;
            app.ChannelTitleLabel.Layout.Column = 1;
            app.ChannelTitleLabel.Text = 'Ch 1 / 1';
            app.ChannelTitleLabel.FontWeight = 'bold';
            app.ChannelTitleLabel.FontSize = 12;

            app.StateLabel = uilabel(ctrlGrid);
            app.StateLabel.Layout.Row = 2;
            app.StateLabel.Layout.Column = 2;
            app.StateLabel.Text = 'Good';
            app.StateLabel.HorizontalAlignment = 'right';
            app.StateLabel.FontWeight = 'bold';
            app.StateLabel.FontColor = [0.2, 0.7, 0.2];

            % State buttons (always black text for readability on colored bg)
            app.MarkGoodBtn = uibutton(ctrlGrid, 'push');
            app.MarkGoodBtn.Layout.Row = 3;
            app.MarkGoodBtn.Layout.Column = [1, 2];
            app.MarkGoodBtn.Text = 'Good';
            app.MarkGoodBtn.BackgroundColor = [0.85, 1, 0.85];
            app.MarkGoodBtn.FontColor = [0, 0, 0];
            app.MarkGoodBtn.Tooltip = 'Mark selected channel Good (1).';
            app.MarkGoodBtn.ButtonPushedFcn = ...
                @(~,~) setChannelState(app, app.SelectedChannel, 1);

            app.MarkNoisyBtn = uibutton(ctrlGrid, 'push');
            app.MarkNoisyBtn.Layout.Row = 4;
            app.MarkNoisyBtn.Layout.Column = [1, 2];
            app.MarkNoisyBtn.Text = 'Noisy';
            app.MarkNoisyBtn.BackgroundColor = [1, 0.95, 0.80];
            app.MarkNoisyBtn.FontColor = [0, 0, 0];
            app.MarkNoisyBtn.Tooltip = 'Mark selected channel Noisy (2).';
            app.MarkNoisyBtn.ButtonPushedFcn = ...
                @(~,~) setChannelState(app, app.SelectedChannel, 0.5);

            app.MarkRejectBtn = uibutton(ctrlGrid, 'push');
            app.MarkRejectBtn.Layout.Row = 5;
            app.MarkRejectBtn.Layout.Column = [1, 2];
            app.MarkRejectBtn.Text = 'Reject';
            app.MarkRejectBtn.BackgroundColor = [1, 0.85, 0.85];
            app.MarkRejectBtn.FontColor = [0, 0, 0];
            app.MarkRejectBtn.Tooltip = 'Mark selected channel Rejected (3).';
            app.MarkRejectBtn.ButtonPushedFcn = ...
                @(~,~) setChannelState(app, app.SelectedChannel, 0);

            % Channel nav (fixed height row, not flex)
            app.PrevChBtn = uibutton(ctrlGrid, 'push');
            app.PrevChBtn.Layout.Row = 6;
            app.PrevChBtn.Layout.Column = 1;
            app.PrevChBtn.Text = '< Prev';
            app.PrevChBtn.Tooltip = 'Previous channel (Left arrow).';
            app.PrevChBtn.ButtonPushedFcn = @(~,~) navChannel(app, -1);

            app.NextChBtn = uibutton(ctrlGrid, 'push');
            app.NextChBtn.Layout.Row = 6;
            app.NextChBtn.Layout.Column = 2;
            app.NextChBtn.Text = 'Next >';
            app.NextChBtn.Tooltip = 'Next channel (Right arrow).';
            app.NextChBtn.ButtonPushedFcn = @(~,~) navChannel(app, 1);

            % Detail axes (main view)
            app.DetailAxes = uiaxes(g);
            app.DetailAxes.Layout.Row = 1;
            app.DetailAxes.Layout.Column = 1;
            app.DetailAxes.Box = 'on';
            app.DetailAxes.FontSize = 9;
            xlabel(app.DetailAxes, 'Time (s)');
            disableDefaultInteractivity(app.DetailAxes);
            app.DetailAxes.Toolbar.Visible = 'off';
        end

        function createLeftPanel(app, parent)
            app.LeftPanel = uipanel(parent, 'Title', '');
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            g = uigridlayout(app.LeftPanel, [8, 2]);
            % Dataset controls (rows 3-5) only make sense for multi-file
            % batch reviews; collapse those rows otherwise so QC takes
            % over the freed space.
            if app.IsMultiFile
                g.RowHeight = {90, 6, 22, '1x', 28, 22, '0.6x', 30};
            else
                g.RowHeight = {90, 6, 0, 0, 0, 22, '1x', 30};
            end
            g.ColumnWidth = {'1x', '1x'};
            g.Padding = [6,6,6,6];
            g.RowSpacing = 4;

            % Row 1: Info label (top)
            app.InfoLabel = uilabel(g);
            app.InfoLabel.Layout.Row = 1;
            app.InfoLabel.Layout.Column = [1, 2];
            app.InfoLabel.Text = '';
            app.InfoLabel.VerticalAlignment = 'top';
            app.InfoLabel.FontSize = 11;
            app.InfoLabel.WordWrap = 'on';

            % Row 2: spacer (visual separation)

            % Row 3: Dataset label
            app.DatasetLabel = uilabel(g);
            app.DatasetLabel.Layout.Row = 3;
            app.DatasetLabel.Layout.Column = [1, 2];
            app.DatasetLabel.Text = 'Files in batch';
            app.DatasetLabel.FontWeight = 'bold';
            app.DatasetLabel.Tooltip = 'When you launch ChannelCheck with a cell array of fNIRS structs, each appears here. Edits are remembered as you switch between them.';

            % Row 4: Dataset listbox
            app.DatasetListBox = uilistbox(g);
            app.DatasetListBox.Layout.Row = 4;
            app.DatasetListBox.Layout.Column = [1, 2];
            app.DatasetListBox.Items = {};
            app.DatasetListBox.Tooltip = 'Select a file to review. * marks files with edits; counts show rejected/noisy channels.';
            app.DatasetListBox.ValueChangedFcn = ...
                @(~,evt) onDatasetSelect(app, evt);

            % Row 5: Prev / Next
            app.DatasetPrevBtn = uibutton(g, 'push');
            app.DatasetPrevBtn.Layout.Row = 5;
            app.DatasetPrevBtn.Layout.Column = 1;
            app.DatasetPrevBtn.Text = '< Prev';
            app.DatasetPrevBtn.Tooltip = 'Previous file in batch.';
            app.DatasetPrevBtn.ButtonPushedFcn = ...
                @(~,~) navigateDataset(app, -1);

            app.DatasetNextBtn = uibutton(g, 'push');
            app.DatasetNextBtn.Layout.Row = 5;
            app.DatasetNextBtn.Layout.Column = 2;
            app.DatasetNextBtn.Text = 'Next >';
            app.DatasetNextBtn.Tooltip = 'Next file in batch.';
            app.DatasetNextBtn.ButtonPushedFcn = ...
                @(~,~) navigateDataset(app, 1);

            % Row 6: QC title
            app.QCTitleLabel = uilabel(g);
            app.QCTitleLabel.Layout.Row = 6;
            app.QCTitleLabel.Layout.Column = [1, 2];
            app.QCTitleLabel.Text = 'Quality';
            app.QCTitleLabel.FontWeight = 'bold';

            % Row 7: QC axes (bar chart / summary)
            app.QCAxes = uiaxes(g);
            app.QCAxes.Layout.Row = 7;
            app.QCAxes.Layout.Column = [1, 2];
            app.QCAxes.XTick = [];
            app.QCAxes.YTick = [];
            app.QCAxes.Box = 'on';
            disableDefaultInteractivity(app.QCAxes);
            app.QCAxes.Toolbar.Visible = 'off';
            title(app.QCAxes, '');

            % Row 8: QC info label
            app.QCInfoLabel = uilabel(g);
            app.QCInfoLabel.Layout.Row = 8;
            app.QCInfoLabel.Layout.Column = [1, 2];
            app.QCInfoLabel.Text = 'Click "Run QC" for quality check';
            app.QCInfoLabel.FontSize = 10;
            app.QCInfoLabel.FontColor = [0.5, 0.5, 0.5];
            app.QCInfoLabel.WordWrap = 'on';

            % Hide dataset controls in single-file mode
            if ~app.IsMultiFile
                app.DatasetLabel.Visible = 'off';
                app.DatasetListBox.Visible = 'off';
                app.DatasetPrevBtn.Visible = 'off';
                app.DatasetNextBtn.Visible = 'off';
            end
        end

        function createCenterPanel(app, parent)
            app.ProbeGridPanel = uipanel(parent, 'Title', '');
            app.ProbeGridPanel.Layout.Row = 1;
            app.ProbeGridPanel.Layout.Column = 2;
            % Don't let MATLAB shuffle children; we keep the probe
            % aspect ratio intact via SizeChangedFcn.
            app.ProbeGridPanel.AutoResizeChildren = 'off';
            app.ProbeGridPanel.SizeChangedFcn = ...
                @(~,~) relayoutMiniAxes(app);
        end

        function createRightPanel(app, parent)
            app.RightPanel = uipanel(parent, 'Title', '');
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;

            g = uigridlayout(app.RightPanel, [2, 1]);
            g.RowHeight = {'1x', '1x'};
            g.Padding = [6,6,6,6];
            g.RowSpacing = 4;

            % Row 1: PSD axes
            app.PSDAxes = uiaxes(g);
            app.PSDAxes.Layout.Row = 1;
            app.PSDAxes.Layout.Column = 1;
            app.PSDAxes.Box = 'on';
            app.PSDAxes.FontSize = 9;
            xlabel(app.PSDAxes, 'Freq (Hz)');
            ylabel(app.PSDAxes, 'PSD');
            title(app.PSDAxes, 'Power Spectrum');
            disableDefaultInteractivity(app.PSDAxes);
            app.PSDAxes.Toolbar.Visible = 'off';

            % Row 2: Stats text
            app.StatsTextArea = uitextarea(g);
            app.StatsTextArea.Layout.Row = 2;
            app.StatsTextArea.Layout.Column = 1;
            app.StatsTextArea.Editable = 'off';
            app.StatsTextArea.FontSize = 10;
            app.StatsTextArea.FontName = 'Courier';
            app.StatsTextArea.Value = {''};
        end

        function createToolbar(app, parent)
            toolPanel = uipanel(parent, 'Title', '');
            toolPanel.Layout.Row = 3;
            toolPanel.Layout.Column = 1;

            g = uigridlayout(toolPanel, [1, 14]);
            g.ColumnWidth = {75, 80, 105, 95, 68, 52, 52, 85, 68, 55, '1x', 22, 68, 68};
            g.Padding = [6,2,6,2];
            g.ColumnSpacing = 4;

            modKey = 'Ctrl/Cmd';

            app.RunQCBtn = uibutton(g, 'push');
            app.RunQCBtn.Layout.Row = 1;
            app.RunQCBtn.Layout.Column = 1;
            app.RunQCBtn.Text = 'Run QC';
            app.RunQCBtn.Tooltip = 'Run the QC pipeline (saturation, SCI, cardiac, CoV, Takizawa) and update recommendations.';
            app.RunQCBtn.ButtonPushedFcn = @(~,~) runQC(app);

            app.QCSettingsBtn = uibutton(g, 'push');
            app.QCSettingsBtn.Layout.Row = 1;
            app.QCSettingsBtn.Layout.Column = 2;
            app.QCSettingsBtn.Text = 'QC Setup';
            app.QCSettingsBtn.Tooltip = 'Edit QC thresholds (SCI, CoV, cardiac SNR, etc.).';
            app.QCSettingsBtn.ButtonPushedFcn = @(~,~) openQCSettings(app);

            app.AcceptRecsBtn = uibutton(g, 'push');
            app.AcceptRecsBtn.Layout.Row = 1;
            app.AcceptRecsBtn.Layout.Column = 3;
            app.AcceptRecsBtn.Text = 'Accept Recs';
            app.AcceptRecsBtn.Enable = 'off';
            app.AcceptRecsBtn.Tooltip = 'Replace the current mask with the QC pipeline''s recommendations. Confirms before overwriting manual edits.';
            app.AcceptRecsBtn.ButtonPushedFcn = ...
                @(~,~) applyQCRecommendations(app);

            app.RejectNoisyBtn = uibutton(g, 'push');
            app.RejectNoisyBtn.Layout.Row = 1;
            app.RejectNoisyBtn.Layout.Column = 4;
            app.RejectNoisyBtn.Text = 'Reject Noisy';
            app.RejectNoisyBtn.Tooltip = 'Promote all channels currently flagged "noisy" to "rejected".';
            app.RejectNoisyBtn.ButtonPushedFcn = @(~,~) bulkRejectNoisy(app);

            app.ResetAllBtn = uibutton(g, 'push');
            app.ResetAllBtn.Layout.Row = 1;
            app.ResetAllBtn.Layout.Column = 5;
            app.ResetAllBtn.Text = 'Reset All';
            app.ResetAllBtn.Tooltip = 'Mark every channel "good" (1).';
            app.ResetAllBtn.ButtonPushedFcn = @(~,~) bulkResetAll(app);

            app.UndoBtn = uibutton(g, 'push');
            app.UndoBtn.Layout.Row = 1;
            app.UndoBtn.Layout.Column = 6;
            app.UndoBtn.Text = 'Undo';
            app.UndoBtn.Enable = 'off';
            app.UndoBtn.Tooltip = sprintf('Undo last channel mask change (%s+Z).', modKey);
            app.UndoBtn.ButtonPushedFcn = @(~,~) undo(app);

            app.RedoBtn = uibutton(g, 'push');
            app.RedoBtn.Layout.Row = 1;
            app.RedoBtn.Layout.Column = 7;
            app.RedoBtn.Text = 'Redo';
            app.RedoBtn.Enable = 'off';
            app.RedoBtn.Tooltip = sprintf('Redo last undone change (%s+Shift+Z or %s+Y).', modKey, modKey);
            app.RedoBtn.ButtonPushedFcn = @(~,~) redo(app);

            app.AutoScaleChk = uicheckbox(g);
            app.AutoScaleChk.Layout.Row = 1;
            app.AutoScaleChk.Layout.Column = 8;
            app.AutoScaleChk.Text = 'Per-Ch Scale';
            app.AutoScaleChk.Value = false;
            app.AutoScaleChk.Tooltip = 'Off: shared Y-range across all mini-plots. On: each mini-plot autoscales independently.';
            app.AutoScaleChk.ValueChangedFcn = ...
                @(~,evt) onAutoScaleChange(app, evt);

            app.ShowMarkersChk = uicheckbox(g);
            app.ShowMarkersChk.Layout.Row = 1;
            app.ShowMarkersChk.Layout.Column = 9;
            app.ShowMarkersChk.Text = 'Markers';
            app.ShowMarkersChk.Value = false;
            app.ShowMarkersChk.Tooltip = 'Show event markers on time-series plots.';
            app.ShowMarkersChk.ValueChangedFcn = ...
                @(~,evt) onMarkersChange(app, evt);

            app.MarkerCodesBtn = uibutton(g, 'push');
            app.MarkerCodesBtn.Layout.Row = 1;
            app.MarkerCodesBtn.Layout.Column = 10;
            app.MarkerCodesBtn.Text = 'Codes...';
            app.MarkerCodesBtn.Tooltip = 'Choose which marker codes to display.';
            app.MarkerCodesBtn.ButtonPushedFcn = ...
                @(~,~) openMarkerSettings(app);

            app.SummaryLabel = uilabel(g);
            app.SummaryLabel.Layout.Row = 1;
            app.SummaryLabel.Layout.Column = 11;
            app.SummaryLabel.Text = '';
            app.SummaryLabel.HorizontalAlignment = 'center';
            app.SummaryLabel.FontSize = 11;

            % Spacer column 12 (22px)

            app.SaveBtn = uibutton(g, 'push');
            app.SaveBtn.Layout.Row = 1;
            app.SaveBtn.Layout.Column = 13;
            app.SaveBtn.Text = 'Save';
            app.SaveBtn.BackgroundColor = [0.75, 0.92, 0.75];
            app.SaveBtn.FontColor = [0, 0, 0];
            app.SaveBtn.Tooltip = sprintf('Apply mask edits and close (%s+S).', modKey);
            app.SaveBtn.ButtonPushedFcn = @(~,~) closeApp(app, false);

            app.CancelBtn = uibutton(g, 'push');
            app.CancelBtn.Layout.Row = 1;
            app.CancelBtn.Layout.Column = 14;
            app.CancelBtn.Text = 'Cancel';
            app.CancelBtn.Tooltip = 'Discard all edits and close (Esc).';
            app.CancelBtn.ButtonPushedFcn = @(~,~) closeApp(app, true);
        end

        %% ---- Data Loading -----------------------------------------

        function loadData(app, dataStruct)
            app.Data = dataStruct;
            % Treat as processed when hemoglobin output exists. Some
            % pipelines retain `raw` alongside `HbO` for debugging, so
            % positively detect via processingInfo / units rather than
            % requiring `raw` to be absent.
            app.IsProcessed = isfield(dataStruct, 'HbO') && ...
                              (isfield(dataStruct, 'processingInfo') || ...
                               isfield(dataStruct, 'units') || ...
                               ~isfield(dataStruct, 'raw'));

            % Resolve device
            app.Dev = [];
            try
                app.Dev = pf2_base.resolveDeviceFromData(dataStruct);
            catch
            end

            % Get RawMax/RawMin reference levels from device
            app.RawMax = [];
            app.RawMin = [];
            if ~isempty(app.Dev)
                try
                    if ~isnan(app.Dev.rawMax)
                        app.RawMax = app.Dev.rawMax;
                    end
                    if ~isnan(app.Dev.rawMin) && app.Dev.rawMin > 0
                        app.RawMin = app.Dev.rawMin;
                    end
                catch
                end
            end

            % Channel count (nChannels already includes short-sep)
            if app.IsProcessed
                app.NumChannels = size(dataStruct.HbO, 2);
            elseif ~isempty(app.Dev)
                app.NumChannels = app.Dev.nChannels;
            else
                nCols = size(dataStruct.raw, 2);
                app.NumChannels = nCols;
                for nWl = [3, 2]
                    if mod(nCols, nWl) == 0
                        app.NumChannels = nCols / nWl;
                        break;
                    end
                end
            end

            resolveChannelColumns(app);
            resolveLayout(app);

            % Initialize mask: prefer in-memory fchMask, otherwise try the
            % *_CH.mat sidecar next to the original recording, otherwise
            % default to all-good.
            sidecarMask = [];
            if ~isfield(dataStruct, 'fchMask') || isempty(dataStruct.fchMask)
                sidecarMask = tryLoadSidecarMask(dataStruct);
            end

            if isfield(dataStruct, 'fchMask') && ~isempty(dataStruct.fchMask)
                app.FchMask = dataStruct.fchMask(:)';
            elseif ~isempty(sidecarMask)
                app.FchMask = sidecarMask(:)';
                fprintf('Channel mask loaded from sidecar (%d rejected, %d noisy).\n', ...
                    sum(app.FchMask == 0), sum(app.FchMask == 0.5));
            else
                app.FchMask = ones(1, app.NumChannels);
            end

            % Pad or truncate to match NumChannels
            if numel(app.FchMask) < app.NumChannels
                app.FchMask(end+1:app.NumChannels) = 1;
            elseif numel(app.FchMask) > app.NumChannels
                app.FchMask = app.FchMask(1:app.NumChannels);
            end
            app.OrigFchMask = app.FchMask;
            app.MaskHistory = {};
            app.MaskFuture = {};

            % Discover unique marker codes
            app.UniqueMarkerCodes = [];
            if isfield(dataStruct, 'markers') && ~isempty(dataStruct.markers)
                mrkArr = pf2_base.markersToArray(dataStruct.markers);
                if size(mrkArr, 2) >= 2
                    codes = mrkArr(:, 2);
                    app.UniqueMarkerCodes = unique(codes(~isnan(codes)))';
                end
            end

            % Load marker display preferences
            app.ShowMarkers = getpref('pf2_ChannelCheck', 'ShowMarkers', false);
            app.SelectedMarkerCodes = getpref('pf2_ChannelCheck', 'SelectedMarkerCodes', []);
            if ~isempty(app.ShowMarkersChk)
                app.ShowMarkersChk.Value = app.ShowMarkers;
            end

            % Disable marker controls when no markers exist
            hasMarkers = ~isempty(app.UniqueMarkerCodes);
            if ~isempty(app.ShowMarkersChk)
                app.ShowMarkersChk.Enable = hasMarkers;
            end
            if ~isempty(app.MarkerCodesBtn)
                app.MarkerCodesBtn.Enable = hasMarkers;
            end

            computeStats(app);
            cacheDownsampledData(app);
            updateInfoDisplay(app);

            % Check if QC is feasible at this sample rate
            if ~app.IsProcessed && isfield(dataStruct, 'fs') && dataStruct.fs < 4
                app.QCInfoLabel.Text = sprintf( ...
                    'Fs=%.1f Hz (< 4 Hz). SCI and cardiac checks unavailable. CoV and Takizawa still available.', ...
                    dataStruct.fs);
            end
        end

        function resolveChannelColumns(app)
            app.ChannelColumns = {};
            app.AmbientColumns = {};
            app.ChannelWavelengths = {};
            app.DeviceWLOrder = [];
            if app.IsProcessed
                for ch = 1:app.NumChannels
                    app.ChannelColumns{ch} = ch;
                    app.AmbientColumns{ch} = [];
                    app.ChannelWavelengths{ch} = NaN;
                end
                return;
            end
            if ~isempty(app.Dev)
                chNums = app.Dev.channelNumbers();
                wls = app.Dev.wavelengths();
                app.DeviceWLOrder = sort(unique(wls(wls > 0 & ~isnan(wls))));
                for ch = 1:app.NumChannels
                    cols = find(chNums == ch & wls > 0);
                    if isempty(cols)
                        cols = find(chNums == ch);
                    end
                    app.ChannelColumns{ch} = cols;
                    app.ChannelWavelengths{ch} = wls(cols);
                    app.AmbientColumns{ch} = find(chNums == ch & wls == 0);
                end
            else
                nCols = size(app.Data.raw, 2);
                nWl = round(nCols / app.NumChannels);
                for ch = 1:app.NumChannels
                    app.ChannelColumns{ch} = (ch-1)*nWl + (1:nWl);
                    app.AmbientColumns{ch} = [];
                    app.ChannelWavelengths{ch} = nan(1, nWl);
                end
            end
        end

        function colors = miniSignalColors(app, ch, nSigs)
            % Per-signal colors for mini-plots: HbO/HbR for processed,
            % wavelength-aware coloring for raw.
            colors = cell(1, nSigs);
            if app.IsProcessed
                palette = {app.HbOColor, app.HbRColor};
                for s = 1:nSigs
                    cidx = min(s, numel(palette));
                    colors{s} = palette{cidx};
                end
                return;
            end
            wls = [];
            if ch <= numel(app.ChannelWavelengths)
                wls = app.ChannelWavelengths{ch};
            end
            for s = 1:nSigs
                if s <= numel(wls)
                    wlVal = wls(s);
                else
                    wlVal = NaN;
                end
                colors{s} = wavelengthColor(app, wlVal, s);
            end
        end

        function [clr, label] = wavelengthColor(app, wl, fallbackIdx)
            % Map a wavelength (nm) to the canonical WL1/WL2 color slot.
            % Falls back to position-based coloring when wl is NaN or the
            % device wavelength order is unknown.
            label = '';
            if ~isnan(wl) && ~isempty(app.DeviceWLOrder)
                pos = find(app.DeviceWLOrder == wl, 1);
                if ~isempty(pos)
                    if pos == 1
                        clr = app.WL1Color;
                    else
                        clr = app.WL2Color;
                    end
                    label = sprintf('%g nm', wl);
                    return;
                end
            end
            % Fallback: use signal index ordering
            palette = {app.WL1Color, app.WL2Color, app.AmbientColor};
            cidx = min(max(fallbackIdx, 1), numel(palette));
            clr = palette{cidx};
            if ~isnan(wl)
                label = sprintf('%g nm', wl);
            else
                label = sprintf('WL%d', fallbackIdx);
            end
        end

        function resolveLayout(app)
            app.LayoutPositions = {};
            if isempty(app.Dev), return; end

            % Prefer _ss layout (includes short-sep)
            try
                lay = app.Dev.layout2Dss();
                if iscell(lay) && ~all(cellfun(@isempty, lay))
                    app.LayoutPositions = lay;
                    return;
                end
            catch
            end

            % Fallback to standard layout
            lay = app.Dev.layout2D();
            if ~isempty(lay) && iscell(lay)
                app.LayoutPositions = lay;
            end
        end

        function computeStats(app)
            nCh = app.NumChannels;
            stats = struct('mean', {}, 'std', {}, 'cov', {}, 'isNoisy', {});
            for ch = 1:nCh
                if app.IsProcessed
                    sig = app.Data.HbO(:, ch);
                    m = mean(sig, 'omitnan');
                    s = std(sig, 'omitnan');
                    cv = abs(s / (m + eps));
                else
                    cols = app.ChannelColumns{ch};
                    sig = app.Data.raw(:, cols);
                    m = mean(sig, 1, 'omitnan');
                    s = std(sig, 0, 1, 'omitnan');
                    cv = abs(s ./ (m + eps));
                end
                stats(ch).mean = m;
                stats(ch).std = s;
                stats(ch).cov = cv;
                stats(ch).isNoisy = any(cv > app.QCSettings.CoVThreshold);
            end
            app.ChanStats = stats;
        end

        function cacheDownsampledData(app)
            nCh = app.NumChannels;
            app.MiniData = cell(1, nCh);

            if app.IsProcessed
                [app.MiniTime, hbo] = pf2.qc.ChannelCheck.smartDownsample( ...
                    app.Data.time, app.Data.HbO, app.MiniMaxPts);
                [~, hbr] = pf2.qc.ChannelCheck.smartDownsample( ...
                    app.Data.time, app.Data.HbR, app.MiniMaxPts);
                for ch = 1:nCh
                    app.MiniData{ch} = [hbo(:,ch), hbr(:,ch)];
                end
            else
                [app.MiniTime, rawDown] = pf2.qc.ChannelCheck.smartDownsample( ...
                    app.Data.time, app.Data.raw, app.MiniMaxPts);
                for ch = 1:nCh
                    cols = app.ChannelColumns{ch};
                    validCols = cols(cols <= size(rawDown, 2));
                    if isempty(validCols)
                        app.MiniData{ch} = zeros(size(rawDown, 1), 1);
                    else
                        app.MiniData{ch} = rawDown(:, validCols);
                    end
                end
            end

            % Cache ambient data (raw mode only)
            app.AmbientData = cell(1, nCh);
            if ~app.IsProcessed
                for ch = 1:nCh
                    if ch <= numel(app.AmbientColumns) && ~isempty(app.AmbientColumns{ch})
                        ambCols = app.AmbientColumns{ch};
                        ambCols = ambCols(ambCols <= size(app.Data.raw, 2));
                        if ~isempty(ambCols)
                            [~, ad] = pf2.qc.ChannelCheck.smartDownsample( ...
                                app.Data.time, app.Data.raw(:, ambCols(1)), app.MiniMaxPts);
                            app.AmbientData{ch} = ad;
                        end
                    end
                end
            end

            % Compute global Y range across all channels (always include 0)
            globalMax = -Inf;
            globalMin = Inf;
            for ch = 1:nCh
                d = app.MiniData{ch};
                if isempty(d), continue; end
                cMax = max(d(:), [], 'omitnan');
                cMin = min(d(:), [], 'omitnan');
                if cMax > globalMax, globalMax = cMax; end
                if cMin < globalMin, globalMin = cMin; end
            end
            % Always include 0, add 5% padding
            globalMin = min(globalMin, 0);
            globalMax = max(globalMax, 0);
            % Include RawMin in global range (shown on mini-plots as ref)
            if ~isempty(app.RawMin) && ~app.IsProcessed
                globalMin = min(globalMin, app.RawMin);
            end
            pad = (globalMax - globalMin) * 0.05;
            if pad == 0, pad = 1; end
            app.GlobalYLim = [globalMin - pad, globalMax + pad];
        end

        %% ---- Mini-Plot Grid ---------------------------------------

        function buildMiniAxesGrid(app)
            % Delete existing
            for i = 1:numel(app.MiniAxes)
                if ~isempty(app.MiniAxes{i}) && isvalid(app.MiniAxes{i})
                    delete(app.MiniAxes{i});
                end
            end
            for i = 1:numel(app.MiniContextMenus)
                if ~isempty(app.MiniContextMenus{i}) && isvalid(app.MiniContextMenus{i})
                    delete(app.MiniContextMenus{i});
                end
            end

            nCh = app.NumChannels;
            app.MiniAxes = cell(1, nCh);
            app.MiniLines = cell(1, nCh);
            app.MiniContextMenus = cell(1, nCh);
            app.QCPatches = cell(1, nCh);

            layout = app.LayoutPositions;

            % Fallback grid if no probe layout
            if isempty(layout) || numel(layout) < nCh || ...
                    all(cellfun(@isempty, layout(1:min(nCh, numel(layout)))))
                nCols = ceil(sqrt(nCh));
                nRows = ceil(nCh / nCols);
                w = 1 / nCols;
                h = 1 / nRows;
                layout = cell(nCh, 1);
                for ch = 1:nCh
                    row = ceil(ch / nCols);
                    col = ch - (row - 1) * nCols;
                    layout{ch} = [(col - 1) * w, (row - 1) * h, w, h];
                end
            end

            % Cache layout (possibly the synthetic fallback grid above)
            % so relayoutMiniAxes can find it.
            app.LayoutPositions = layout;

            for ch = 1:nCh
                if ch > numel(layout) || isempty(layout{ch})
                    continue;
                end

                ax = uiaxes(app.ProbeGridPanel);
                ax.Units = 'normalized';
                ax.Box = 'on';
                ax.XTick = [];
                ax.YTick = [];
                ax.FontSize = 7;
                ax.Title.String = sprintf('%d', ch);
                ax.Title.FontSize = 12;
                ax.Title.FontWeight = 'bold';
                if app.IsDarkMode
                    ax.Color = app.GoodBg;
                    ax.Title.Color = app.ThemeFg;
                    ax.XColor = [0.5, 0.5, 0.5];
                    ax.YColor = [0.5, 0.5, 0.5];
                end
                disableDefaultInteractivity(ax);
                ax.Toolbar.Visible = 'off';

                % Left-click handler
                ax.ButtonDownFcn = @(~,~) onMiniClick(app, ch);

                % Right-click context menu
                cm = uicontextmenu(app.UIFigure);
                uimenu(cm, 'Text', 'Mark Good', ...
                    'MenuSelectedFcn', @(~,~) setChannelState(app, ch, 1));
                uimenu(cm, 'Text', 'Mark Noisy', ...
                    'MenuSelectedFcn', @(~,~) setChannelState(app, ch, 0.5));
                uimenu(cm, 'Text', 'Mark Reject', ...
                    'MenuSelectedFcn', @(~,~) setChannelState(app, ch, 0));
                uimenu(cm, 'Separator', 'on', 'Text', 'Cycle State', ...
                    'MenuSelectedFcn', @(~,~) cycleChannelState(app, ch));
                ax.ContextMenu = cm;

                app.MiniAxes{ch} = ax;
                app.MiniContextMenus{ch} = cm;
            end

            % Position axes preserving probe aspect ratio
            relayoutMiniAxes(app);
        end

        function relayoutMiniAxes(app)
            % Re-position the mini-axes within ProbeGridPanel so that the
            % stored probe layout is fitted into the largest centered
            % rectangle whose pixel aspect matches the probe's natural
            % aspect ratio. Called on initial build and on every
            % SizeChangedFcn from ProbeGridPanel.
            if isempty(app.MiniAxes) || isempty(app.LayoutPositions)
                return;
            end
            layout = app.LayoutPositions;

            % Probe bounding box from non-empty layout entries
            valid = ~cellfun(@isempty, layout(1:min(end, app.NumChannels)));
            if ~any(valid), return; end
            pts = vertcat(layout{valid});
            xmin = min(pts(:,1));
            ymin = min(pts(:,2));
            xmax = max(pts(:,1) + pts(:,3));
            ymax = max(pts(:,2) + pts(:,4));
            pw = xmax - xmin;
            ph = ymax - ymin;
            if pw <= 0 || ph <= 0, return; end
            probeAspect = pw / ph;

            % Panel pixel size
            if isempty(app.ProbeGridPanel) || ~isvalid(app.ProbeGridPanel)
                return;
            end
            oldUnits = app.ProbeGridPanel.Units;
            app.ProbeGridPanel.Units = 'pixels';
            panelPos = app.ProbeGridPanel.Position;
            app.ProbeGridPanel.Units = oldUnits;
            panelW = panelPos(3);
            panelH = panelPos(4);
            if panelW <= 1 || panelH <= 1, return; end
            panelAspect = panelW / panelH;

            % Largest centered rectangle (in panel-normalized units) whose
            % pixel aspect matches the probe.
            outerMargin = 0.03;
            usableW = 1 - 2 * outerMargin;
            usableH = 1 - 2 * outerMargin;
            if probeAspect > panelAspect
                fitW = usableW;
                fitH = (panelAspect / probeAspect) * usableW;
            else
                fitH = usableH;
                fitW = (probeAspect / panelAspect) * usableH;
            end
            fitX = (1 - fitW) / 2;
            fitY = (1 - fitH) / 2;

            % Per-channel inner margin so axes don't touch
            innerSc = 0.92;
            innerMg = (1 - innerSc) / 2;

            for ch = 1:app.NumChannels
                if ch > numel(layout) || isempty(layout{ch}), continue; end
                if ch > numel(app.MiniAxes), continue; end
                ax = app.MiniAxes{ch};
                if isempty(ax) || ~isvalid(ax), continue; end

                p = layout{ch};
                nx = (p(1) - xmin) / pw;
                ny = (p(2) - ymin) / ph;
                nw = p(3) / pw;
                nh = p(4) / ph;

                % Y-flip: layout y=0 at top, MATLAB y=0 at bottom
                cellX = fitX + nx * fitW;
                cellY = fitY + (1 - ny - nh) * fitH;
                cellW = nw * fitW;
                cellH = nh * fitH;

                ax.Units = 'normalized';
                ax.Position = [cellX + cellW * innerMg, ...
                               cellY + cellH * innerMg, ...
                               cellW * innerSc, ...
                               cellH * innerSc];
            end
        end

        function plotAllMiniChannels(app)
            for ch = 1:app.NumChannels
                plotMiniChannel(app, ch);
            end
            drawnow limitrate;
        end

        function plotMiniChannel(app, ch)
            ax = app.MiniAxes{ch};
            if isempty(ax) || ~isvalid(ax), return; end

            t = app.MiniTime;
            d = app.MiniData{ch};
            nSigs = size(d, 2);

            % Per-signal colors
            sigColors = miniSignalColors(app, ch, nSigs);

            % Plot (create lines or update)
            if isempty(app.MiniLines{ch}) || ...
                    numel(app.MiniLines{ch}) ~= nSigs || ...
                    ~all(arrayfun(@isvalid, app.MiniLines{ch}))
                cla(ax);
                hold(ax, 'on');
                lines = gobjects(1, nSigs);
                for s = 1:nSigs
                    lines(s) = plot(ax, t, d(:, s), ...
                        'Color', sigColors{s}, 'LineWidth', 0.8, ...
                        'HitTest', 'off', 'PickableParts', 'none');
                end
                hold(ax, 'off');
                app.MiniLines{ch} = lines;
            else
                for s = 1:nSigs
                    set(app.MiniLines{ch}(s), 'XData', t, 'YData', d(:, s), ...
                        'Color', sigColors{s});
                end
            end

            % Clear previous auxiliary lines (ambient, rawMin, markers)
            if ch <= numel(app.MiniAuxLines) && ~isempty(app.MiniAuxLines{ch})
                delete(app.MiniAuxLines{ch}(isvalid(app.MiniAuxLines{ch})));
            end
            auxHandles = gobjects(0);

            % Ambient channel on mini-plot (raw mode only)
            if ~app.IsProcessed && ch <= numel(app.AmbientData) ...
                    && ~isempty(app.AmbientData{ch})
                hold(ax, 'on');
                h = plot(ax, t, app.AmbientData{ch}, '-', ...
                    'Color', app.AmbientColor, 'LineWidth', 0.7, ...
                    'HitTest', 'off', 'PickableParts', 'none');
                auxHandles(end+1) = h; %#ok<AGROW>
                hold(ax, 'off');
            end

            % RawMin reference line (ambient baseline)
            if ~app.IsProcessed && ~isempty(app.RawMin)
                hold(ax, 'on');
                h = plot(ax, [t(1), t(end)], [app.RawMin, app.RawMin], '--', ...
                    'Color', app.AmbientColor, 'LineWidth', 0.4, ...
                    'HitTest', 'off', 'PickableParts', 'none');
                auxHandles(end+1) = h; %#ok<AGROW>
                hold(ax, 'off');
            end

            % Markers on mini-plot
            mrkArr = [];
            if isfield(app.Data, 'markers') && ~isempty(app.Data.markers)
                mrkArr = pf2_base.markersToArray(app.Data.markers);
            end
            if app.ShowMarkers && ~isempty(mrkArr) && size(mrkArr, 2) >= 2
                mTimes = mrkArr(:, 1);
                mCodes = mrkArr(:, 2);
                if ~isempty(app.SelectedMarkerCodes)
                    keep = ismember(mCodes, app.SelectedMarkerCodes);
                    mTimes = mTimes(keep);
                end
                tRange = [t(1), t(end)];
                mTimes = mTimes(mTimes >= tRange(1) & mTimes <= tRange(2));
                if numel(mTimes) > 50
                    mTimes = mTimes(1:50);
                end
                if ~isempty(mTimes)
                    yl = ylim(ax);
                    hold(ax, 'on');
                    for mi = 1:numel(mTimes)
                        h = plot(ax, [mTimes(mi), mTimes(mi)], yl, ...
                            'Color', [0.4, 0.8, 0.4, 0.4], 'LineWidth', 0.3, ...
                            'HitTest', 'off', 'PickableParts', 'none');
                        auxHandles(end+1) = h; %#ok<AGROW>
                    end
                    hold(ax, 'off');
                end
            end

            % Store aux handles for cleanup on next redraw
            if ch > numel(app.MiniAuxLines)
                app.MiniAuxLines{ch} = auxHandles;
            else
                app.MiniAuxLines{ch} = auxHandles;
            end

            % Tight X-range: start..end of the displayed segment
            if numel(t) >= 2
                xlim(ax, [t(1), t(end)]);
            end
            if app.AutoScaleOn
                % Per-channel autoscale
                ax.YLimMode = 'auto';
            elseif ~isempty(app.GlobalYLim)
                % Global scale: device max, always includes 0
                ylim(ax, app.GlobalYLim);
            end

            % Update mask overlay (background color)
            updateMaskOverlay(app, ch);
        end

        function updateMaskOverlay(app, ch)
            ax = app.MiniAxes{ch};
            if isempty(ax) || ~isvalid(ax), return; end

            % State glyph: ✅ good, ⚠ noisy, ❌ rejected.
            state = app.FchMask(ch);
            if state == 0
                ax.Color = app.RejectBg;
                stateGlyph = char(10060);    % ❌
                ax.Title.Color = [0.8, 0.1, 0.1];
            elseif state == 0.5
                ax.Color = app.NoisyBg;
                stateGlyph = char(9888);     % ⚠
                ax.Title.Color = [0.8, 0.5, 0.0];
            else
                ax.Color = app.GoodBg;
                stateGlyph = char(9989);     % ✅
                ax.Title.Color = [0.2, 0.6, 0.2];
            end
            ax.Title.String = sprintf('%d - %s', ch, stateGlyph);

            % QC recommendation indicator (overlays a flag glyph)
            if app.QCComputed && ch <= numel(app.QCRecommendations)
                rec = app.QCRecommendations(ch);
                if rec == 0
                    ax.Title.String = [ax.Title.String, ' !'];
                elseif rec == 0.5
                    ax.Title.String = [ax.Title.String, ' ?'];
                end

                % Draw colored QC dot in top-right corner
                if numel(app.QCPatches) >= ch && ~isempty(app.QCPatches{ch}) ...
                        && isvalid(app.QCPatches{ch})
                    delete(app.QCPatches{ch});
                end
                if rec == 1
                    dotClr = [0.2, 0.8, 0.2];
                elseif rec == 0.5
                    dotClr = [1, 0.7, 0.1];
                else
                    dotClr = [0.9, 0.1, 0.1];
                end
                xl = xlim(ax); yl = ylim(ax);
                dx = (xl(2) - xl(1)) * 0.06;
                dy = (yl(2) - yl(1)) * 0.08;
                rx = xl(2) - dx * 2;
                ry = yl(2) - dy * 2;
                hold(ax, 'on');
                app.QCPatches{ch} = fill(ax, ...
                    rx + dx * [-1, 1, 1, -1], ry + dy * [-1, -1, 1, 1], ...
                    dotClr, 'EdgeColor', 'none', ...
                    'HitTest', 'off', 'PickableParts', 'none');
                hold(ax, 'off');

                % Build QC tooltip for this channel. UIAxes only exposes
                % a Tooltip property on some MATLAB releases — guard.
                if isprop(ax, 'Tooltip')
                    try
                        ax.Tooltip = buildQCTooltip(app, ch);
                    catch
                    end
                end
            end
        end

        %% ---- Detail Panel -----------------------------------------

        function selectChannel(app, ch)
            ch = max(1, min(app.NumChannels, ch));
            oldCh = app.SelectedChannel;
            app.SelectedChannel = ch;

            % Remove old highlight
            if oldCh >= 1 && oldCh <= numel(app.MiniAxes) && ...
                    ~isempty(app.MiniAxes{oldCh}) && isvalid(app.MiniAxes{oldCh})
                if app.IsDarkMode
                    axClr = [0.55, 0.55, 0.55];
                else
                    axClr = [0.15, 0.15, 0.15];
                end
                app.MiniAxes{oldCh}.XColor = axClr;
                app.MiniAxes{oldCh}.YColor = axClr;
                app.MiniAxes{oldCh}.LineWidth = 0.5;
            end

            % Add new highlight
            if ch >= 1 && ch <= numel(app.MiniAxes) && ...
                    ~isempty(app.MiniAxes{ch}) && isvalid(app.MiniAxes{ch})
                app.MiniAxes{ch}.XColor = app.SelectColor;
                app.MiniAxes{ch}.YColor = app.SelectColor;
                app.MiniAxes{ch}.LineWidth = 2;
            end

            plotDetailChannel(app, ch);
            plotPSD(app, ch);
            updateStatsDisplay(app, ch);
            updateStateDisplay(app, ch);

            app.ChannelTitleLabel.Text = sprintf( ...
                'Ch %d / %d', ch, app.NumChannels);
        end

        function plotDetailChannel(app, ch)
            cla(app.DetailAxes);

            timeVec = app.Data.time;
            maxPts = app.DetailMaxPts;

            if app.IsProcessed
                [t, hbo] = pf2.qc.ChannelCheck.smartDownsample( ...
                    timeVec, app.Data.HbO(:, ch), maxPts);
                [~, hbr] = pf2.qc.ChannelCheck.smartDownsample( ...
                    timeVec, app.Data.HbR(:, ch), maxPts);
                hold(app.DetailAxes, 'on');
                plot(app.DetailAxes, t, hbo, ...
                    'Color', app.HbOColor, 'LineWidth', 1.2, ...
                    'DisplayName', 'HbO');
                plot(app.DetailAxes, t, hbr, ...
                    'Color', app.HbRColor, 'LineWidth', 1.2, ...
                    'DisplayName', 'HbR');
                hold(app.DetailAxes, 'off');
                ylabel(app.DetailAxes, 'Hb');
            else
                cols = app.ChannelColumns{ch};
                raw = app.Data.raw(:, cols);
                [t, rd] = pf2.qc.ChannelCheck.smartDownsample( ...
                    timeVec, raw, maxPts);
                wls = [];
                if ch <= numel(app.ChannelWavelengths)
                    wls = app.ChannelWavelengths{ch};
                end
                hold(app.DetailAxes, 'on');
                for s = 1:size(rd, 2)
                    if s <= numel(wls)
                        wlVal = wls(s);
                    else
                        wlVal = NaN;
                    end
                    [clr, lbl] = wavelengthColor(app, wlVal, s);
                    plot(app.DetailAxes, t, rd(:, s), ...
                        'Color', clr, 'LineWidth', 1, ...
                        'DisplayName', lbl);
                end
                % Ambient channel
                if ch <= numel(app.AmbientColumns) && ~isempty(app.AmbientColumns{ch})
                    ambCols = app.AmbientColumns{ch};
                    ambCols = ambCols(ambCols <= size(app.Data.raw, 2));
                    if ~isempty(ambCols)
                        [~, ambD] = pf2.qc.ChannelCheck.smartDownsample( ...
                            timeVec, app.Data.raw(:, ambCols(1)), maxPts);
                        plot(app.DetailAxes, t, ambD, '-', ...
                            'Color', app.AmbientColor, 'LineWidth', 1.0, ...
                            'DisplayName', 'Ambient');
                    end
                end
                % RawMax / RawMin reference lines
                if ~isempty(app.RawMax)
                    plot(app.DetailAxes, [t(1), t(end)], ...
                        [app.RawMax, app.RawMax], '--', ...
                        'Color', [0.7, 0.2, 0.2], 'LineWidth', 0.8, ...
                        'DisplayName', 'Max');
                end
                if ~isempty(app.RawMin)
                    plot(app.DetailAxes, [t(1), t(end)], ...
                        [app.RawMin, app.RawMin], '--', ...
                        'Color', [0.2, 0.2, 0.7], 'LineWidth', 0.8, ...
                        'DisplayName', 'Min');
                end
                hold(app.DetailAxes, 'off');
                ylabel(app.DetailAxes, 'Raw Intensity');
            end

            % Plot markers (filtered by code selection)
            markers = [];
            if isfield(app.Data, 'markers') && ~isempty(app.Data.markers)
                markers = pf2_base.markersToArray(app.Data.markers);
            end
            if app.ShowMarkers && ~isempty(markers) && size(markers, 2) >= 2
                mTimes = markers(:, 1);
                mCodes = markers(:, 2);
                if ~isempty(app.SelectedMarkerCodes)
                    keep = ismember(mCodes, app.SelectedMarkerCodes);
                    mTimes = mTimes(keep);
                    mCodes = mCodes(keep);
                end
                tRange = [t(1), t(end)];
                visible = mTimes >= tRange(1) & mTimes <= tRange(2);
                mTimes = mTimes(visible);
                mCodes = mCodes(visible);
                if numel(mTimes) > 200
                    mTimes = mTimes(1:200);
                    mCodes = mCodes(1:200);
                end
                hold(app.DetailAxes, 'on');
                yl = ylim(app.DetailAxes);
                for i = 1:numel(mTimes)
                    plot(app.DetailAxes, [mTimes(i), mTimes(i)], yl, ...
                        'Color', [0.4, 0.8, 0.4, 0.6], 'LineWidth', 0.5, ...
                        'HandleVisibility', 'off');
                end
                % Code labels at top (one per unique code per visible set)
                seenCodes = [];
                for i = 1:numel(mTimes)
                    if ~ismember(mCodes(i), seenCodes)
                        text(app.DetailAxes, mTimes(i), yl(2), ...
                            sprintf(' %g', mCodes(i)), 'FontSize', 7, ...
                            'VerticalAlignment', 'top', ...
                            'Color', [0.3, 0.6, 0.3], ...
                            'HandleVisibility', 'off');
                        seenCodes(end+1) = mCodes(i); %#ok<AGROW>
                    end
                end
                hold(app.DetailAxes, 'off');
            end

            % Y-axis: global scale (default) or per-channel autoscale
            if app.AutoScaleOn
                app.DetailAxes.YLimMode = 'auto';
            elseif ~isempty(app.GlobalYLim)
                detailYLim = app.GlobalYLim;
                if ~app.IsProcessed && ~isempty(app.RawMax)
                    detailYLim(2) = max(detailYLim(2), app.RawMax * 1.05);
                end
                ylim(app.DetailAxes, detailYLim);
            end

            xlabel(app.DetailAxes, 'Time (s)');
            title(app.DetailAxes, sprintf('Channel %d', ch));

            % Tight X-range: start..end of the displayed segment
            if numel(t) >= 2
                xlim(app.DetailAxes, [t(1), t(end)]);
            end

            % Store data for cursor tooltip
            if app.IsProcessed
                app.DetailPlotTime = t;
                app.DetailPlotData = [hbo, hbr];
                app.DetailPlotLabels = {'HbO', 'HbR'};
            else
                dataMat = rd;
                labels = cell(1, size(rd, 2));
                for s = 1:size(rd, 2)
                    labels{s} = sprintf('WL%d', s);
                end
                if exist('ambD', 'var') && ~isempty(ambD)
                    dataMat = [dataMat, ambD];
                    labels{end+1} = 'Amb';
                end
                app.DetailPlotTime = t;
                app.DetailPlotData = dataMat;
                app.DetailPlotLabels = labels;
            end

            % Create cursor objects (hidden until mouse enters)
            hold(app.DetailAxes, 'on');
            yl = ylim(app.DetailAxes);
            cursorClr = [app.ThemeFg, 0.4];
            app.CursorLine = plot(app.DetailAxes, [NaN, NaN], yl, ...
                ':', 'Color', cursorClr, 'LineWidth', 0.8, ...
                'HandleVisibility', 'off', 'Visible', 'off');
            app.CursorText = text(app.DetailAxes, NaN, NaN, '', ...
                'FontSize', 8, 'Color', [0, 0, 0], ...
                'BackgroundColor', [1, 1, 0.9, 0.85], ...
                'EdgeColor', [0.6, 0.6, 0.6], 'Margin', 2, ...
                'VerticalAlignment', 'bottom', ...
                'HandleVisibility', 'off', 'Visible', 'off');
            hold(app.DetailAxes, 'off');
        end

        function plotPSD(app, ch)
            cla(app.PSDAxes);
            if ~isfield(app.Data, 'fs') || app.Data.fs <= 0
                return;
            end

            fs = app.Data.fs;

            % Get signal
            if app.IsProcessed
                sig = app.Data.HbO(:, ch);
            else
                if ch > numel(app.ChannelColumns) || isempty(app.ChannelColumns{ch})
                    return;
                end
                cols = app.ChannelColumns{ch};
                sig = app.Data.raw(:, cols(1));
            end
            sig = sig(~isnan(sig));
            if numel(sig) < 32, return; end

            % Compute PSD (simple periodogram, no toolbox required)
            N = numel(sig);
            nfft = min(N, 1024);
            % Hann window
            w = 0.5 * (1 - cos(2 * pi * (0:nfft-1)' / (nfft - 1)));
            nSegs = floor(N / nfft);
            if nSegs < 1, nSegs = 1; end
            pxx = zeros(floor(nfft/2) + 1, 1);
            for seg = 1:nSegs
                idx = (seg - 1) * nfft + (1:nfft);
                if idx(end) > N, break; end
                chunk = sig(idx) - mean(sig(idx));
                Y = fft(chunk .* w);
                P = (1 / (fs * nfft)) * abs(Y(1:floor(nfft/2) + 1)).^2;
                P(2:end-1) = 2 * P(2:end-1);
                pxx = pxx + P;
            end
            pxx = pxx / max(nSegs, 1);
            f = (0:floor(nfft/2))' * (fs / nfft);

            % Plot
            semilogy(app.PSDAxes, f, pxx, 'b', 'LineWidth', 1);
            hold(app.PSDAxes, 'on');

            % Shade physiological bands (only those within Nyquist)
            bands = struct( ...
                'name', {'Mayer', 'Respiratory', 'Cardiac'}, ...
                'range', {[0.05, 0.15], [0.15, 0.4], [0.5, 2.5]}, ...
                'color', {[0.7, 0.7, 1], [0.7, 1, 0.7], [1, 0.7, 0.7]});
            yl = ylim(app.PSDAxes);
            for b = 1:numel(bands)
                r = bands(b).range;
                if r(1) >= fs/2, continue; end
                r(2) = min(r(2), fs/2 - 0.01);
                fill(app.PSDAxes, ...
                    [r(1), r(2), r(2), r(1)], ...
                    [yl(1), yl(1), yl(2), yl(2)], ...
                    bands(b).color, ...
                    'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                    'HitTest', 'off', 'PickableParts', 'none');
            end

            hold(app.PSDAxes, 'off');
            maxFreq = min(fs / 2, 5);
            if maxFreq > 0
                xlim(app.PSDAxes, [0, maxFreq]);
            end
            xlabel(app.PSDAxes, 'Freq (Hz)');
            ylabel(app.PSDAxes, 'PSD');

            % Show Nyquist warning for low Fs
            if fs < 4
                title(app.PSDAxes, sprintf( ...
                    'Power Spectrum (Fs=%.1f Hz, cardiac band unavailable)', fs));
            else
                title(app.PSDAxes, 'Power Spectrum');
            end
        end

        function updateStatsDisplay(app, ch)
            if ch < 1 || ch > numel(app.ChanStats)
                app.StatsTextArea.Value = {''};
                return;
            end
            s = app.ChanStats(ch);
            lines = {};
            if numel(s.mean) == 1
                lines{end+1} = sprintf('Mean: %.4g  Std: %.4g  CoV: %.4f', ...
                    s.mean, s.std, s.cov);
            else
                for w = 1:numel(s.mean)
                    lines{end+1} = sprintf('WL%d  Mean: %.4g  Std: %.4g  CoV: %.4f', ...
                        w, s.mean(w), s.std(w), s.cov(w)); %#ok<AGROW>
                end
            end
            if s.isNoisy
                lines{end+1} = sprintf('CoV > %.2f: NOISY', app.QCSettings.CoVThreshold);
            end

            % QC details if available — show per-check results
            if app.QCComputed
                r = app.QCReport;
                lines{end+1} = '--- QC ---';
                if isfield(r, 'pass') && ch <= numel(r.pass)
                    lines{end+1} = sprintf('Overall: %s', ...
                        iff(r.pass(ch), 'PASS', 'FAIL'));
                end
                if isfield(r, 'saturation') && ~r.saturation.skipped ...
                        && ch <= numel(r.saturation.pass)
                    pct = r.saturation.totalPct(ch) * 100;
                    lines{end+1} = sprintf('Saturation: %.1f%% %s', ...
                        pct, iff(r.saturation.pass(ch), 'PASS', 'FAIL'));
                end
                if isfield(r, 'sci') && ~r.sci.skipped ...
                        && ch <= numel(r.sci.values)
                    lines{end+1} = sprintf('SCI: %.3f (>%.2f) %s', ...
                        r.sci.values(ch), r.sci.threshold, ...
                        iff(r.sci.pass(ch), 'PASS', 'FAIL'));
                end
                if isfield(r, 'cardiac')
                    if r.cardiac.skipped
                        lines{end+1} = 'Cardiac: skipped (low Fs)';
                    elseif ch <= numel(r.cardiac.snr)
                        lines{end+1} = sprintf('Cardiac SNR: %.1f (>%.0f) %s', ...
                            r.cardiac.snr(ch), r.cardiac.threshold, ...
                            iff(r.cardiac.pass(ch), 'PASS', 'FAIL'));
                    end
                end
                if isfield(r, 'cov') && ch <= numel(r.cov.values)
                    lines{end+1} = sprintf('CoV: %.4f (<%.2f) %s', ...
                        r.cov.values(ch), r.cov.threshold, ...
                        iff(r.cov.pass(ch), 'PASS', 'FAIL'));
                end
                if isfield(r, 'takizawa') && ch <= numel(r.takizawa.pass)
                    if r.takizawa.pass(ch)
                        lines{end+1} = 'Takizawa: PASS';
                    else
                        failedRules = find(~r.takizawa.rules(:, ch));
                        rNames = r.takizawa.ruleNames;
                        failStr = strjoin(rNames(failedRules), ', ');
                        lines{end+1} = sprintf('Takizawa: FAIL (%s)', failStr);
                    end
                end
            end
            app.StatsTextArea.Value = lines;
        end

        function updateStateDisplay(app, ch)
            state = app.FchMask(ch);
            if state == 1
                app.StateLabel.Text = 'Good';
                app.StateLabel.FontColor = [0.2, 0.7, 0.2];
            elseif state == 0.5
                app.StateLabel.Text = 'Noisy';
                app.StateLabel.FontColor = [0.8, 0.5, 0.0];
            else
                app.StateLabel.Text = 'Rejected';
                app.StateLabel.FontColor = [0.8, 0.1, 0.1];
            end
            % Highlight the button that matches the current state, dim
            % the others, and disable the active one so it can't be
            % pressed redundantly.
            highlightStateButton(app, state);
        end

        function highlightStateButton(app, state)
            % Selected button: saturated bg + white text + bold + bullet
            % prefix so it reads as the active radio choice. Inactive
            % buttons keep a subtle state-color tint so they still look
            % like clickable buttons (not greyed-out or disabled).
            activeGood   = [0.30, 0.65, 0.30];
            inactiveGood = [0.86, 0.95, 0.86];
            activeNoisy  = [0.92, 0.62, 0.20];
            inactiveNoisy = [0.99, 0.93, 0.80];
            activeReject = [0.82, 0.28, 0.28];
            inactiveReject = [0.99, 0.86, 0.86];

            inactiveGoodFg = [0.10, 0.35, 0.10];
            inactiveNoisyFg = [0.50, 0.35, 0.05];
            inactiveRejectFg = [0.55, 0.10, 0.10];

            isGood = (state == 1);
            isNoisy = (state == 0.5);
            isReject = (state == 0);

            bullet = char(9679);  % ●

            styleStateBtn(app.MarkGoodBtn, isGood, ...
                activeGood, inactiveGood, inactiveGoodFg, 'Good', bullet);
            styleStateBtn(app.MarkNoisyBtn, isNoisy, ...
                activeNoisy, inactiveNoisy, inactiveNoisyFg, 'Noisy', bullet);
            styleStateBtn(app.MarkRejectBtn, isReject, ...
                activeReject, inactiveReject, inactiveRejectFg, 'Reject', bullet);

            function styleStateBtn(btn, isActive, activeBg, inactiveBg, inactiveFg, label, mark)
                if isempty(btn) || ~isvalid(btn), return; end
                btn.Enable = 'on';
                if isActive
                    btn.BackgroundColor = activeBg;
                    btn.FontColor = [1, 1, 1];
                    btn.FontWeight = 'bold';
                    btn.Text = sprintf('%s %s', mark, label);
                else
                    btn.BackgroundColor = inactiveBg;
                    btn.FontColor = inactiveFg;
                    btn.FontWeight = 'normal';
                    btn.Text = label;
                end
            end
        end

        %% ---- Channel State ----------------------------------------

        function setChannelState(app, ch, state)
            pushUndo(app);
            app.FchMask(ch) = state;
            app.Data.fchMask = app.FchMask;
            updateMaskOverlay(app, ch);
            updateSummaryBar(app);
            if ch == app.SelectedChannel
                updateStateDisplay(app, ch);
            end
        end

        function cycleChannelState(app, ch)
            cur = app.FchMask(ch);
            if cur == 1
                nxt = 0;
            elseif cur == 0
                nxt = 0.5;
            else
                nxt = 1;
            end
            setChannelState(app, ch, nxt);
        end

        function pushUndo(app)
            app.MaskHistory{end+1} = app.FchMask;
            app.MaskFuture = {};
            app.UndoBtn.Enable = 'on';
            app.RedoBtn.Enable = 'off';
            % Cap history size
            if numel(app.MaskHistory) > 50
                app.MaskHistory(1) = [];
            end
        end

        function undo(app)
            if isempty(app.MaskHistory), return; end
            app.MaskFuture{end+1} = app.FchMask;
            app.FchMask = app.MaskHistory{end};
            app.MaskHistory(end) = [];
            app.Data.fchMask = app.FchMask;
            refreshAllVisuals(app);
            app.UndoBtn.Enable = pf2.qc.ChannelCheck.onOff(~isempty(app.MaskHistory));
            app.RedoBtn.Enable = 'on';
        end

        function redo(app)
            if isempty(app.MaskFuture), return; end
            app.MaskHistory{end+1} = app.FchMask;
            app.FchMask = app.MaskFuture{end};
            app.MaskFuture(end) = [];
            app.Data.fchMask = app.FchMask;
            refreshAllVisuals(app);
            app.UndoBtn.Enable = 'on';
            app.RedoBtn.Enable = pf2.qc.ChannelCheck.onOff(~isempty(app.MaskFuture));
        end

        function refreshAllVisuals(app)
            for ch = 1:app.NumChannels
                updateMaskOverlay(app, ch);
            end
            updateSummaryBar(app);
            updateStateDisplay(app, app.SelectedChannel);
        end

        function updateSummaryBar(app)
            nGood = sum(app.FchMask == 1);
            nNoisy = sum(app.FchMask == 0.5);
            nRej = sum(app.FchMask == 0);
            app.SummaryLabel.Text = sprintf( ...
                '%d good, %d noisy, %d rejected', nGood, nNoisy, nRej);

            % Mirror the current-dataset status into the multi-file list.
            if app.IsMultiFile && ~isempty(app.DatasetListBox) && ...
                    isvalid(app.DatasetListBox) && ...
                    ~isempty(app.DatasetListBox.Items)
                buildDatasetLabels(app);
            end
        end

        function bulkRejectNoisy(app)
            pushUndo(app);
            app.FchMask(app.FchMask == 0.5) = 0;
            app.Data.fchMask = app.FchMask;
            refreshAllVisuals(app);
        end

        function bulkResetAll(app)
            pushUndo(app);
            app.FchMask = ones(1, app.NumChannels);
            app.Data.fchMask = app.FchMask;
            refreshAllVisuals(app);
        end

        %% ---- QC Integration ---------------------------------------

        function runQC(app)
            if app.IsProcessed
                uialert(app.UIFigure, ...
                    'QC assessment requires raw data. This dataset appears to be already processed.', ...
                    'QC Not Available');
                return;
            end

            app.RunQCBtn.Enable = 'off';
            app.RunQCBtn.Text = 'Running...';
            drawnow;

            try
                s = app.QCSettings;
                % Build enabled checks list
                allChecks = {'saturation', 'sci', 'cardiac', 'cov', 'takizawa'};
                enabledFields = {'enableSaturation', 'enableSCI', ...
                    'enableCardiac', 'enableCoV', 'enableTakizawa'};
                checks = {};
                for ci = 1:numel(allChecks)
                    if s.(enabledFields{ci})
                        checks{end+1} = allChecks{ci}; %#ok<AGROW>
                    end
                end
                % Also skip sci/cardiac at low sample rates
                fs = app.Data.fs;
                if fs < 4
                    checks = setdiff(checks, {'sci', 'cardiac'}, 'stable');
                end

                assessArgs = {'Checks', checks, ...
                    'SaturationThreshold', s.SaturationThreshold, ...
                    'SCIThreshold', s.SCIThreshold, ...
                    'CardiacSNR', s.CardiacSNR, ...
                    'CoVThreshold', s.CoVThreshold, ...
                    'TakizawaStrict', s.TakizawaStrict};

                app.QCReport = pf2.qc.pipeline.assess(app.Data, ...
                    assessArgs{:});
                app.QCComputed = true;

                % Build recommendations
                app.QCRecommendations = ones(1, app.NumChannels);
                if isfield(app.QCReport, 'pass')
                    nPR = min(numel(app.QCReport.pass), app.NumChannels);
                    app.QCRecommendations(1:nPR) = ...
                        double(app.QCReport.pass(1:nPR));
                    % Mark marginal channels (some checks pass, some fail)
                    if isfield(app.QCReport, 'summary') && istable(app.QCReport.summary)
                        nChecks = size(app.QCReport.summary, 2);
                        sumMatrix = table2array(app.QCReport.summary);
                        nPassed = sum(double(sumMatrix), 2)';
                        for i = 1:min(nPR, numel(nPassed))
                            if nPassed(i) > 0 && nPassed(i) < nChecks && ~app.QCReport.pass(i)
                                app.QCRecommendations(i) = 0.5;
                            end
                        end
                    end
                end

                updateQCSummary(app);
                refreshAllVisuals(app);
                updateStatsDisplay(app, app.SelectedChannel);
                app.AcceptRecsBtn.Enable = 'on';

                % Summary text with per-check failure counts
                nPass = sum(app.QCReport.pass);
                nTotal = numel(app.QCReport.pass);
                checkNames = app.QCReport.checkNames;
                parts = {sprintf('%d/%d pass.', nPass, nTotal)};
                for ci = 1:numel(checkNames)
                    cn = checkNames{ci};
                    if isfield(app.QCReport, cn) && isfield(app.QCReport.(cn), 'pass')
                        if isfield(app.QCReport.(cn), 'skipped') && app.QCReport.(cn).skipped
                            parts{end+1} = sprintf('%s: skipped', cn); %#ok<AGROW>
                        else
                            nFail = sum(~app.QCReport.(cn).pass);
                            if nFail > 0
                                parts{end+1} = sprintf('%s: %d fail', cn, nFail); %#ok<AGROW>
                            end
                        end
                    end
                end
                app.QCInfoLabel.Text = strjoin(parts, '  ');

            catch ex
                errMsg = sprintf('QC failed: %s\n', ex.message);
                if ~isempty(ex.stack)
                    errMsg = sprintf('%sIn %s (line %d)', ...
                        errMsg, ex.stack(1).name, ex.stack(1).line);
                end
                uialert(app.UIFigure, errMsg, 'Error');
            end

            app.RunQCBtn.Text = 'Run QC';
            app.RunQCBtn.Enable = 'on';
        end

        function openQCSettings(app)
        % Show dialog for configuring QC thresholds and enabled checks
            s = app.QCSettings;

            % Build dialog
            dlg = uifigure('Name', 'QC Settings', ...
                'Position', [100, 100, 360, 380], ...
                'WindowStyle', 'modal', 'Resize', 'off');
            dlg.CloseRequestFcn = @(~,~) delete(dlg);

            g = uigridlayout(dlg, [8, 3]);
            g.RowHeight = {28, 28, 28, 28, 28, 28, 10, 32};
            g.ColumnWidth = {22, '1x', 90};
            g.Padding = [12, 12, 12, 12];
            g.RowSpacing = 6;

            % --- Saturation ---
            chkSat = uicheckbox(g, 'Text', '', 'Value', s.enableSaturation);
            chkSat.Layout.Row = 1; chkSat.Layout.Column = 1;
            lbl = uilabel(g, 'Text', 'Saturation threshold (%)');
            lbl.Layout.Row = 1; lbl.Layout.Column = 2;
            fldSat = uieditfield(g, 'numeric', 'Value', s.SaturationThreshold * 100, ...
                'Limits', [0, 100]);
            fldSat.Layout.Row = 1; fldSat.Layout.Column = 3;

            % --- SCI ---
            chkSCI = uicheckbox(g, 'Text', '', 'Value', s.enableSCI);
            chkSCI.Layout.Row = 2; chkSCI.Layout.Column = 1;
            lbl = uilabel(g, 'Text', 'SCI threshold');
            lbl.Layout.Row = 2; lbl.Layout.Column = 2;
            fldSCI = uieditfield(g, 'numeric', 'Value', s.SCIThreshold, ...
                'Limits', [0, 1]);
            fldSCI.Layout.Row = 2; fldSCI.Layout.Column = 3;

            % --- Cardiac ---
            chkCard = uicheckbox(g, 'Text', '', 'Value', s.enableCardiac);
            chkCard.Layout.Row = 3; chkCard.Layout.Column = 1;
            lbl = uilabel(g, 'Text', 'Cardiac SNR threshold');
            lbl.Layout.Row = 3; lbl.Layout.Column = 2;
            fldCard = uieditfield(g, 'numeric', 'Value', s.CardiacSNR, ...
                'Limits', [0, Inf]);
            fldCard.Layout.Row = 3; fldCard.Layout.Column = 3;

            % --- CoV ---
            chkCoV = uicheckbox(g, 'Text', '', 'Value', s.enableCoV);
            chkCoV.Layout.Row = 4; chkCoV.Layout.Column = 1;
            lbl = uilabel(g, 'Text', 'CoV threshold (%)');
            lbl.Layout.Row = 4; lbl.Layout.Column = 2;
            fldCoV = uieditfield(g, 'numeric', 'Value', s.CoVThreshold * 100, ...
                'Limits', [0, 1000]);
            fldCoV.Layout.Row = 4; fldCoV.Layout.Column = 3;

            % --- Takizawa ---
            chkTak = uicheckbox(g, 'Text', '', 'Value', s.enableTakizawa);
            chkTak.Layout.Row = 5; chkTak.Layout.Column = 1;
            lbl = uilabel(g, 'Text', 'Takizawa (Hb rules)');
            lbl.Layout.Row = 5; lbl.Layout.Column = 2;
            if s.TakizawaStrict
                takVal = 'Strict (OR)';
            else
                takVal = 'Lenient (AND)';
            end
            ddTak = uidropdown(g, 'Items', {'Lenient (AND)', 'Strict (OR)'}, ...
                'Value', takVal);
            ddTak.Layout.Row = 5; ddTak.Layout.Column = 3;

            % --- Reset to defaults ---
            resetBtn = uibutton(g, 'push', 'Text', 'Reset Defaults');
            resetBtn.Layout.Row = 6; resetBtn.Layout.Column = [1, 3];
            resetBtn.ButtonPushedFcn = @(~,~) resetFields();

            % Row 7: spacer

            % --- OK / Cancel ---
            okBtn = uibutton(g, 'push', 'Text', 'OK');
            okBtn.Layout.Row = 8; okBtn.Layout.Column = 2;
            okBtn.ButtonPushedFcn = @(~,~) applyAndClose();

            cancelBtn = uibutton(g, 'push', 'Text', 'Cancel');
            cancelBtn.Layout.Row = 8; cancelBtn.Layout.Column = 3;
            cancelBtn.ButtonPushedFcn = @(~,~) delete(dlg);

            function resetFields()
                d = defaultQCSettings();
                chkSat.Value = d.enableSaturation;
                fldSat.Value = d.SaturationThreshold * 100;
                chkSCI.Value = d.enableSCI;
                fldSCI.Value = d.SCIThreshold;
                chkCard.Value = d.enableCardiac;
                fldCard.Value = d.CardiacSNR;
                chkCoV.Value = d.enableCoV;
                fldCoV.Value = d.CoVThreshold * 100;
                chkTak.Value = d.enableTakizawa;
                ddTak.Value = 'Lenient (AND)';
            end

            function applyAndClose()
                newS = struct();
                newS.enableSaturation = chkSat.Value;
                newS.SaturationThreshold = fldSat.Value / 100;
                newS.enableSCI = chkSCI.Value;
                newS.SCIThreshold = fldSCI.Value;
                newS.enableCardiac = chkCard.Value;
                newS.CardiacSNR = fldCard.Value;
                newS.enableCoV = chkCoV.Value;
                newS.CoVThreshold = fldCoV.Value / 100;
                newS.enableTakizawa = chkTak.Value;
                newS.TakizawaStrict = strcmp(ddTak.Value, 'Strict (OR)');

                app.QCSettings = newS;
                saveQCSettings(newS);
                delete(dlg);

                % Recompute the noisy flag in stats since CoVThreshold may
                % have changed, then refresh the visible detail stats.
                computeStats(app);
                if ~isempty(app.SelectedChannel) && app.SelectedChannel >= 1
                    updateStatsDisplay(app, app.SelectedChannel);
                end

                % Re-run QC with new settings
                if ~app.IsProcessed
                    runQC(app);
                end
            end
        end

        function applyQCRecommendations(app)
            if ~app.QCComputed, return; end

            % If the user has made manual edits since this dataset was
            % loaded, confirm before overwriting them.
            hasManualEdits = ~isempty(app.OrigFchMask) && ...
                             numel(app.FchMask) == numel(app.OrigFchMask) && ...
                             any(app.FchMask ~= app.OrigFchMask);
            if hasManualEdits && ~app.SkipConfirmation
                nDiff = sum(app.FchMask ~= app.OrigFchMask);
                answer = uiconfirm(app.UIFigure, ...
                    sprintf(['You have %d manual channel edit(s) on this dataset.\n\n', ...
                            'Accepting recommendations will replace those edits ' , ...
                            'with the QC pipeline''s suggestions.\n\n', ...
                            'Continue? (Undo with Ctrl/Cmd+Z if needed.)'], nDiff), ...
                    'Overwrite Manual Edits?', ...
                    'Options', {'Replace with Recommendations', 'Cancel'}, ...
                    'DefaultOption', 'Cancel', ...
                    'CancelOption', 'Cancel', ...
                    'Icon', 'warning');
                if ~strcmp(answer, 'Replace with Recommendations')
                    return;
                end
            end

            pushUndo(app);
            app.FchMask = app.QCRecommendations;
            app.Data.fchMask = app.FchMask;
            refreshAllVisuals(app);
        end

        function tip = buildQCTooltip(app, ch)
        % Build a multi-line QC breakdown string for channel tooltip
            r = app.QCReport;
            parts = {sprintf('Ch %d QC:', ch)};

            checks = {'saturation', 'sci', 'cardiac', 'cov', 'takizawa'};
            labels = {'Sat', 'SCI', 'Cardiac', 'CoV', 'Takizawa'};

            for ci = 1:numel(checks)
                cn = checks{ci};
                if ~isfield(r, cn), continue; end
                s = r.(cn);
                if isfield(s, 'skipped') && s.skipped
                    parts{end+1} = sprintf('  %s: skipped', labels{ci}); %#ok<AGROW>
                    continue;
                end
                if ~isfield(s, 'pass') || ch > numel(s.pass), continue; end
                if s.pass(ch)
                    tag = 'PASS';
                else
                    tag = 'FAIL';
                end
                % Add value detail where available
                switch cn
                    case 'saturation'
                        if isfield(s, 'totalPct') && ch <= numel(s.totalPct)
                            parts{end+1} = sprintf('  %s: %s (%.1f%%)', ...
                                labels{ci}, tag, s.totalPct(ch) * 100); %#ok<AGROW>
                        else
                            parts{end+1} = sprintf('  %s: %s', labels{ci}, tag); %#ok<AGROW>
                        end
                    case 'sci'
                        if isfield(s, 'values') && ch <= numel(s.values)
                            parts{end+1} = sprintf('  %s: %s (%.2f)', ...
                                labels{ci}, tag, s.values(ch)); %#ok<AGROW>
                        else
                            parts{end+1} = sprintf('  %s: %s', labels{ci}, tag); %#ok<AGROW>
                        end
                    case 'cardiac'
                        if isfield(s, 'snr') && ch <= numel(s.snr)
                            parts{end+1} = sprintf('  %s: %s (SNR %.1f)', ...
                                labels{ci}, tag, s.snr(ch)); %#ok<AGROW>
                        else
                            parts{end+1} = sprintf('  %s: %s', labels{ci}, tag); %#ok<AGROW>
                        end
                    case 'cov'
                        if isfield(s, 'values') && ch <= numel(s.values)
                            parts{end+1} = sprintf('  %s: %s (%.1f%%)', ...
                                labels{ci}, tag, s.values(ch) * 100); %#ok<AGROW>
                        else
                            parts{end+1} = sprintf('  %s: %s', labels{ci}, tag); %#ok<AGROW>
                        end
                    otherwise
                        parts{end+1} = sprintf('  %s: %s', labels{ci}, tag); %#ok<AGROW>
                end
            end
            tip = strjoin(parts, newline);
        end

        function updateQCSummary(app)
            if ~app.QCComputed, return; end
            cla(app.QCAxes);

            nCh = min(app.NumChannels, numel(app.QCRecommendations));
            layout = app.LayoutPositions;
            useSpatial = ~isempty(layout) && numel(layout) >= nCh && ...
                ~all(cellfun(@isempty, layout(1:min(nCh, numel(layout)))));

            hold(app.QCAxes, 'on');

            if useSpatial
                % Probe-arranged QC map. Use the same bounding box +
                % axis-equal trick as the mini-axes grid so the probe is
                % drawn at its natural aspect ratio.
                pts = vertcat(layout{1:nCh});
                xmin = min(pts(:,1));
                ymin = min(pts(:,2));
                xmax = max(pts(:,1) + pts(:,3));
                ymax = max(pts(:,2) + pts(:,4));
                pad = 0.04 * max(xmax - xmin, ymax - ymin);

                for ch = 1:nCh
                    if ch > numel(layout) || isempty(layout{ch}), continue; end
                    pos = layout{ch};  % [x, y, w, h] normalized
                    rec = app.QCRecommendations(ch);
                    clr = qcColor(rec);
                    cx = pos(1) + pos(3) / 2;
                    cy = (ymin + ymax) - (pos(2) + pos(4) / 2);  % Y-flip
                    hw = pos(3) * 0.45;
                    hh = pos(4) * 0.45;
                    fill(app.QCAxes, ...
                        cx + hw * [-1, 1, 1, -1], ...
                        cy + hh * [-1, -1, 1, 1], ...
                        clr, 'EdgeColor', 'none');
                    text(app.QCAxes, cx, cy, sprintf('%d', ch), ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 6, 'Color', [1, 1, 1]);
                end
                xlim(app.QCAxes, [xmin - pad, xmax + pad]);
                ylim(app.QCAxes, [ymin - pad, ymax + pad]);
                app.QCAxes.DataAspectRatioMode = 'manual';
                app.QCAxes.DataAspectRatio = [1, 1, 1];
            else
                % Fallback grid
                nGridCols = ceil(sqrt(nCh));
                nGridRows = ceil(nCh / nGridCols);
                for ch = 1:nCh
                    row = ceil(ch / nGridCols);
                    col = ch - (row - 1) * nGridCols;
                    rec = app.QCRecommendations(ch);
                    clr = qcColor(rec);
                    fill(app.QCAxes, ...
                        col + [-0.4, 0.4, 0.4, -0.4], ...
                        (nGridRows - row + 1) + [-0.4, -0.4, 0.4, 0.4], ...
                        clr, 'EdgeColor', 'none');
                    text(app.QCAxes, col, nGridRows - row + 1, ...
                        sprintf('%d', ch), ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 7, 'Color', [1, 1, 1]);
                end
                xlim(app.QCAxes, [0, nGridCols + 1]);
                ylim(app.QCAxes, [0, nGridRows + 1]);
                app.QCAxes.DataAspectRatioMode = 'manual';
                app.QCAxes.DataAspectRatio = [1, 1, 1];
            end

            hold(app.QCAxes, 'off');
            app.QCAxes.XTick = [];
            app.QCAxes.YTick = [];
            title(app.QCAxes, 'QC Map');
        end

        %% ---- Multi-File Navigation --------------------------------

        function navigateDataset(app, direction)
            if ~app.IsMultiFile, return; end
            saveCurrentMaskToCell(app);

            newIdx = app.CurrentDataIndex + direction;
            newIdx = max(1, min(numel(app.AllData), newIdx));
            if newIdx == app.CurrentDataIndex, return; end

            app.CurrentDataIndex = newIdx;

            % Tear down old mini-axes
            for i = 1:numel(app.MiniAxes)
                if ~isempty(app.MiniAxes{i}) && isvalid(app.MiniAxes{i})
                    delete(app.MiniAxes{i});
                end
            end
            for i = 1:numel(app.MiniContextMenus)
                if ~isempty(app.MiniContextMenus{i}) && isvalid(app.MiniContextMenus{i})
                    delete(app.MiniContextMenus{i});
                end
            end

            loadData(app, app.AllData{newIdx});
            buildMiniAxesGrid(app);
            plotAllMiniChannels(app);
            selectChannel(app, 1);
            updateSummaryBar(app);

            % Rebuild labels so previously-edited datasets show their
            % rejection counts and the current selection moves with us.
            buildDatasetLabels(app);
            app.DatasetListBox.Value = app.CurrentDataIndex;

            % Reset QC state for new dataset
            app.QCComputed = false;
            app.QCRecommendations = [];
            app.AcceptRecsBtn.Enable = 'off';
            cla(app.QCAxes);
            app.QCInfoLabel.Text = 'Click "Run QC" for quality check';
        end

        function saveCurrentMaskToCell(app)
            if app.IsMultiFile
                app.AllData{app.CurrentDataIndex}.fchMask = app.FchMask;
            end
        end

        function buildDatasetLabels(app)
            n = numel(app.AllData);
            labels = cell(1, n);
            for i = 1:n
                d = app.AllData{i};

                % Current dataset uses the live mask in memory; others
                % reflect what was committed to AllData via navigation.
                if i == app.CurrentDataIndex && ~isempty(app.FchMask)
                    mask = app.FchMask;
                elseif isfield(d, 'fchMask')
                    mask = d.fchMask;
                else
                    mask = [];
                end

                lbl = sprintf('%d', i);
                if isfield(d, 'info')
                    if isfield(d.info, 'SubjectID') && ~isempty(d.info.SubjectID)
                        lbl = sprintf('%s | %s', lbl, string(d.info.SubjectID));
                    end
                    if isfield(d.info, 'Group') && ~isempty(d.info.Group)
                        lbl = sprintf('%s | %s', lbl, string(d.info.Group));
                    end
                    if isfield(d.info, 'Session') && ~isempty(d.info.Session)
                        lbl = sprintf('%s | S%s', lbl, string(d.info.Session));
                    end
                end

                % Append review status: rejection/noisy counts plus an
                % edited-vs-original marker.
                if ~isempty(mask)
                    nRej = sum(mask == 0);
                    nNoisy = sum(mask == 0.5);
                    if i <= numel(app.OrigFchMaskAll)
                        orig = app.OrigFchMaskAll{i};
                    else
                        orig = [];
                    end
                    if isempty(orig)
                        isEdited = any(mask ~= 1);
                    elseif numel(mask) == numel(orig)
                        isEdited = any(mask ~= orig);
                    else
                        isEdited = true;
                    end
                    statusBits = {};
                    if nRej > 0
                        statusBits{end+1} = sprintf('%d rej', nRej); %#ok<AGROW>
                    end
                    if nNoisy > 0
                        statusBits{end+1} = sprintf('%d noisy', nNoisy); %#ok<AGROW>
                    end
                    if isEdited && ~(nRej > 0 || nNoisy > 0)
                        statusBits{end+1} = 'edited'; %#ok<AGROW>
                    end
                    if ~isempty(statusBits)
                        lbl = sprintf('%s  [%s]', lbl, strjoin(statusBits, ', '));
                    end
                    if isEdited
                        lbl = ['* ', lbl];
                    end
                end

                labels{i} = lbl;
            end

            % Preserve selection across rebuilds (ItemsData is the index)
            prevValue = [];
            if ~isempty(app.DatasetListBox.Items) && ...
                    ~isempty(app.DatasetListBox.Value)
                prevValue = app.DatasetListBox.Value;
            end
            app.DatasetListBox.Items = labels;
            app.DatasetListBox.ItemsData = 1:n;
            if ~isempty(prevValue) && isnumeric(prevValue) && ...
                    prevValue >= 1 && prevValue <= n
                app.DatasetListBox.Value = prevValue;
            elseif n >= 1
                app.DatasetListBox.Value = app.CurrentDataIndex;
            end
        end

        %% ---- Save / Close -----------------------------------------

        function saveMask(app)
            filepath = '';
            if isfield(app.Data, 'info') && isfield(app.Data.info, 'filename')
                filepath = app.Data.info.filename;
            end
            if isempty(filepath), return; end

            [pathstr, name, ~] = fileparts(filepath);
            if ~isempty(pathstr)
                filestr = fullfile(pathstr, [name, '_CH.mat']);
            else
                filestr = [name, '_CH.mat'];
            end
            fmask = app.FchMask; %#ok<PROPLC>
            save(filestr, 'fmask');
            fprintf('Channel mask saved to: %s\n', filestr);
        end

        function closeApp(app, cancelled)
            if ~isvalid(app.UIFigure), return; end

            if cancelled
                % Restore original mask for the visible dataset
                app.Data.fchMask = app.OrigFchMask;

                % Multi-file: also revert edits that were committed into
                % AllData by saveCurrentMaskToCell during navigation.
                if app.IsMultiFile
                    for i = 1:numel(app.AllData)
                        if app.OrigHadFchMask(i)
                            app.AllData{i}.fchMask = app.OrigFchMaskAll{i};
                        elseif isfield(app.AllData{i}, 'fchMask')
                            app.AllData{i} = rmfield(app.AllData{i}, 'fchMask');
                        end
                    end
                end
            else
                % Save
                app.Data.fchMask = app.FchMask;

                hasFilepath = isfield(app.Data, 'info') && ...
                              isfield(app.Data.info, 'filename') && ...
                              ~isempty(app.Data.info.filename);

                if app.CalledFromImport && hasFilepath
                    % During import: save silently
                    saveMask(app);
                elseif hasFilepath && ~app.SkipConfirmation
                    % Outside import: ask for confirmation
                    answer = uiconfirm(app.UIFigure, ...
                        sprintf('Save channel mask to file?\n\nTip: use ''SkipConfirmation'', true to skip this dialog.'), ...
                        'Save Mask File', ...
                        'Options', {'Save to File', 'Update Data Only', 'Cancel'}, ...
                        'DefaultOption', 'Update Data Only', ...
                        'CancelOption', 'Cancel');
                    switch answer
                        case 'Save to File'
                            saveMask(app);
                        case 'Cancel'
                            return;  % Don't close
                        % 'Update Data Only' => just update fchMask
                    end
                end
                % If no filepath, or SkipConfirmation, just update fchMask
            end

            if app.IsMultiFile
                if ~cancelled
                    saveCurrentMaskToCell(app);
                end
                app.OutputData = app.AllData;
            else
                app.OutputData = app.Data;
            end

            uiresume(app.UIFigure);
            app.UIFigure.Visible = 'off';
        end

        %% ---- Callbacks --------------------------------------------

        function onMiniClick(app, ch)
            selectChannel(app, ch);
        end

        function onKeyPress(app, evt)
            switch evt.Key
                case 'rightarrow'
                    navChannel(app, 1);
                case 'leftarrow'
                    navChannel(app, -1);
                case '1'
                    setChannelState(app, app.SelectedChannel, 1);
                case '2'
                    setChannelState(app, app.SelectedChannel, 0.5);
                case '3'
                    setChannelState(app, app.SelectedChannel, 0);
                case 'z'
                    if hasModifier(evt, 'control') || hasModifier(evt, 'command')
                        if hasModifier(evt, 'shift')
                            redo(app);
                        else
                            undo(app);
                        end
                    end
                case 'y'
                    if hasModifier(evt, 'control') || hasModifier(evt, 'command')
                        redo(app);
                    end
                case 's'
                    if hasModifier(evt, 'control') || hasModifier(evt, 'command')
                        closeApp(app, false);
                    end
                case 'escape'
                    closeApp(app, true);
            end
        end

        function navChannel(app, direction)
            newCh = app.SelectedChannel + direction;
            newCh = max(1, min(app.NumChannels, newCh));
            if newCh ~= app.SelectedChannel
                selectChannel(app, newCh);
            end
        end

        function onDatasetSelect(app, evt)
            if ~app.IsMultiFile, return; end
            idx = evt.Value;
            if isnumeric(idx)
                direction = idx - app.CurrentDataIndex;
                if direction ~= 0
                    navigateDataset(app, direction);
                end
            end
        end

        function onAutoScaleChange(app, evt)
            app.AutoScaleOn = evt.Value;
            plotAllMiniChannels(app);
            plotDetailChannel(app, app.SelectedChannel);
        end

        function onMouseMove(app)
            % Cursor tooltip on detail axes
            if isempty(app.DetailPlotTime) || isempty(app.CursorLine) ...
                    || ~isvalid(app.CursorLine)
                return;
            end

            cp = app.DetailAxes.CurrentPoint;
            xl = xlim(app.DetailAxes);
            yl = ylim(app.DetailAxes);
            mx = cp(1, 1);
            my = cp(1, 2);

            % Check if mouse is within detail axes bounds
            if mx < xl(1) || mx > xl(2) || my < yl(1) || my > yl(2)
                app.CursorLine.Visible = 'off';
                app.CursorText.Visible = 'off';
                return;
            end

            % Find nearest time index
            [~, idx] = min(abs(app.DetailPlotTime - mx));
            tx = app.DetailPlotTime(idx);

            % Build tooltip string
            parts = {sprintf('t=%.2fs', tx)};
            for si = 1:size(app.DetailPlotData, 2)
                val = app.DetailPlotData(idx, si);
                lbl = '';
                if si <= numel(app.DetailPlotLabels)
                    lbl = app.DetailPlotLabels{si};
                end
                if app.IsProcessed
                    parts{end+1} = sprintf('%s: %.4g', lbl, val); %#ok<AGROW>
                else
                    parts{end+1} = sprintf('%s: %.0f', lbl, val); %#ok<AGROW>
                end
            end

            % Update cursor line and text
            app.CursorLine.XData = [tx, tx];
            app.CursorLine.YData = yl;
            app.CursorLine.Visible = 'on';

            app.CursorText.Position = [tx, yl(2)];
            app.CursorText.String = strjoin(parts, '  ');
            app.CursorText.Visible = 'on';
        end

        function onMarkersChange(app, evt)
            app.ShowMarkers = evt.Value;
            setpref('pf2_ChannelCheck', 'ShowMarkers', app.ShowMarkers);
            plotAllMiniChannels(app);
            plotDetailChannel(app, app.SelectedChannel);
        end

        function openMarkerSettings(app)
            codes = app.UniqueMarkerCodes;
            if isempty(codes)
                uialert(app.UIFigure, 'No markers found in data.', 'Markers');
                return;
            end

            % Build display strings with labels if available
            codeStrs = cell(1, numel(codes));
            hasLabels = isfield(app.Data, 'info') && ...
                isfield(app.Data.info, 'eventTypes') && ...
                ~isempty(app.Data.info.eventTypes);
            for i = 1:numel(codes)
                codeStrs{i} = sprintf('%g', codes(i));
                if hasLabels
                    et = app.Data.info.eventTypes;
                    etCodes = cell2mat(et(:, 1));
                    idx = find(etCodes == codes(i), 1);
                    if ~isempty(idx)
                        codeStrs{i} = sprintf('%g - %s', codes(i), et{idx, 2});
                    end
                end
            end

            % Pre-select
            if isempty(app.SelectedMarkerCodes)
                initSel = 1:numel(codes);
            else
                initSel = find(ismember(codes, app.SelectedMarkerCodes));
                if isempty(initSel), initSel = 1:numel(codes); end
            end

            [sel, ok] = listdlg('ListString', codeStrs, ...
                'SelectionMode', 'multiple', ...
                'InitialValue', initSel, ...
                'Name', 'Select Marker Codes', ...
                'PromptString', 'Show markers for:', ...
                'ListSize', [220, 300]);

            if ok
                if numel(sel) == numel(codes)
                    app.SelectedMarkerCodes = [];  % all
                else
                    app.SelectedMarkerCodes = codes(sel);
                end
                setpref('pf2_ChannelCheck', 'SelectedMarkerCodes', app.SelectedMarkerCodes);
                if app.ShowMarkers
                    plotAllMiniChannels(app);
                    plotDetailChannel(app, app.SelectedChannel);
                end
            end
        end

        function updateInfoDisplay(app)
            lines = {};
            if isfield(app.Data, 'info')
                info = app.Data.info;
                if isfield(info, 'filename') && ~isempty(info.filename)
                    [~, name, ext] = fileparts(info.filename);
                    lines{end+1} = sprintf('File: %s%s', name, ext);
                end
                if isfield(info, 'SubjectID') && ~isempty(info.SubjectID)
                    lines{end+1} = sprintf('Subject: %s', string(info.SubjectID));
                end
                if isfield(info, 'Group') && ~isempty(info.Group)
                    lines{end+1} = sprintf('Group: %s', string(info.Group));
                end
            end
            if ~isempty(app.Dev)
                lines{end+1} = sprintf('Device: %s', app.Dev.model);
            end
            lines{end+1} = sprintf('Channels: %d', app.NumChannels);
            if isfield(app.Data, 'time') && ~isempty(app.Data.time)
                dur = app.Data.time(end) - app.Data.time(1);
                lines{end+1} = sprintf('Duration: %.0fs', dur);
            end
            if isfield(app.Data, 'fs')
                lines{end+1} = sprintf('Fs: %.1f Hz', app.Data.fs);
            end
            app.InfoLabel.Text = strjoin(lines, newline);
        end

    end

    %% ================================================================
    %%  STATIC METHODS
    %% ================================================================
    methods (Static, Access = private)

        function [tOut, dOut] = smartDownsample(tIn, dIn, maxPts)
        % Stride-based downsampling for display purposes
            n = size(dIn, 1);
            if n <= maxPts
                tOut = tIn;
                dOut = dIn;
                return;
            end
            stride = floor(n / maxPts);
            idx = 1:stride:n;
            tOut = tIn(idx);
            dOut = dIn(idx, :);
        end

        function s = onOff(tf)
        % Convert logical to 'on'/'off' string
            if tf, s = 'on'; else, s = 'off'; end
        end

    end

end

%% ---- Local Helper Functions ----------------------------------------

function tf = hasModifier(evt, mod)
% Check if a modifier key is pressed
    tf = any(strcmp(evt.Modifier, mod));
end

function s = iff(cond, trueStr, falseStr)
% Inline if for string selection
    if cond, s = trueStr; else, s = falseStr; end
end

function clr = qcColor(rec)
% Map QC recommendation value to display color
    if rec == 1
        clr = [0.2, 0.8, 0.2];
    elseif rec == 0.5
        clr = [1, 0.7, 0.1];
    else
        clr = [0.9, 0.1, 0.1];
    end
end

function s = defaultQCSettings()
% Default QC thresholds and enabled flags
    s.enableSaturation = true;
    s.SaturationThreshold = 0.1;     % 10%
    s.enableSCI = true;
    s.SCIThreshold = 0.75;
    s.enableCardiac = true;
    s.CardiacSNR = 3;
    s.enableCoV = true;
    s.CoVThreshold = 0.2;            % 20% (raw intensity runs higher CoV than Hb)
    s.enableTakizawa = true;
    s.TakizawaStrict = false;
end

function s = loadQCSettings()
% Load QC settings from MATLAB prefs, falling back to defaults
    s = defaultQCSettings();
    if ispref('pf2_ChannelCheck', 'QCSettings')
        saved = getpref('pf2_ChannelCheck', 'QCSettings');
        % Merge saved fields into defaults (handles added fields gracefully)
        flds = fieldnames(s);
        for i = 1:numel(flds)
            if isfield(saved, flds{i})
                s.(flds{i}) = saved.(flds{i});
            end
        end
    end
end

function saveQCSettings(s)
% Persist QC settings to MATLAB prefs
    setpref('pf2_ChannelCheck', 'QCSettings', s);
end

function mask = tryLoadSidecarMask(dataStruct)
% Look for a *_CH.mat sidecar next to dataStruct.info.filename and return
% the first numeric field whose name contains 'mask'. Returns [] if no
% filename, no sidecar, or no mask field found.
    mask = [];
    if ~isfield(dataStruct, 'info') || ~isfield(dataStruct.info, 'filename')
        return;
    end
    fn = dataStruct.info.filename;
    if isempty(fn) || ~(ischar(fn) || isstring(fn))
        return;
    end
    [pathstr, name, ~] = fileparts(char(fn));
    if isempty(pathstr)
        sidecar = [name, '_CH.mat'];
    else
        sidecar = fullfile(pathstr, [name, '_CH.mat']);
    end
    if exist(sidecar, 'file') ~= 2
        return;
    end
    try
        s = load(sidecar);
    catch
        return;
    end
    flds = fieldnames(s);
    hits = find(contains(lower(flds), 'mask'));
    for i = 1:numel(hits)
        v = s.(flds{hits(i)});
        if isnumeric(v)
            mask = v;
            return;
        end
    end
end
