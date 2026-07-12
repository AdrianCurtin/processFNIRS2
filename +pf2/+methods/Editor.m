classdef Editor < matlab.apps.AppBase
% EDITOR AppDesigner-based editor for pf2 raw / oxy processing methods.
%
% Three-pane uifigure built on the Pipeline foundation (PipelineModel,
% per-arg metadata, role tags, validate, listAvailable):
%
%   ┌────────────────────────────────────────────────────────────┐
%   │ [Stage: Raw ▾] [New] [Duplicate] [Delete]  [Save] [Save As]│
%   │                                       [Undo] [Redo] [Run]  │
%   ├──────────────┬───────────────────────┬─────────────────────┤
%   │ METHODS      │ STEPS                 │ STEP PROPERTIES     │
%   │ (saved)      │ (current method)      │ (type-aware widgets │
%   │              │ ▲ ▼ + −  Add Step     │  built from arg     │
%   │              │                       │  metadata)          │
%   ├──────────────┴───────────────────────┴─────────────────────┤
%   │ Validation: <messages>                                     │
%   └────────────────────────────────────────────────────────────┘
%
% Syntax:
%   app = pf2.methods.Editor()              % default raw stage
%   app = pf2.methods.Editor('Stage','oxy')
%
% See also: pf2_base.PipelineModel, pf2_base.RawPipeline,
%           pf2_base.OxyPipeline, pf2_base.PipelineFunction

    % ====================================================================
    % UI components
    % ====================================================================
    properties (Access = public)
        UIFigure                matlab.ui.Figure
    end

    properties (Access = private)
        % Top-level layout
        MainGrid                matlab.ui.container.GridLayout
        Toolbar                 matlab.ui.container.GridLayout
        StageDropDown           matlab.ui.control.DropDown
        NewButton               matlab.ui.control.Button
        DuplicateButton         matlab.ui.control.Button
        DeleteButton            matlab.ui.control.Button
        SaveButton              matlab.ui.control.Button
        SaveAsButton            matlab.ui.control.Button
        UndoButton              matlab.ui.control.Button
        RedoButton              matlab.ui.control.Button
        SeedButton              matlab.ui.control.Button
        ImportButton            matlab.ui.control.Button
        ExportButton            matlab.ui.control.Button
        FunctionsButton         matlab.ui.control.Button

        % Three-pane content row
        ContentGrid             matlab.ui.container.GridLayout
        MethodsPanel            matlab.ui.container.Panel
        MethodsListBox          matlab.ui.control.ListBox

        StepsPanel              matlab.ui.container.Panel
        StepsGrid               matlab.ui.container.GridLayout
        StepsListBox            matlab.ui.control.ListBox
        StepsButtonsGrid        matlab.ui.container.GridLayout
        AddStepDropDown         matlab.ui.control.DropDown
        AddStepButton           matlab.ui.control.Button
        RemoveStepButton        matlab.ui.control.Button
        MoveUpButton            matlab.ui.control.Button
        MoveDownButton          matlab.ui.control.Button

        PropsPanel              matlab.ui.container.Panel
        PropsScroll             matlab.ui.container.Panel
        PropsGrid               matlab.ui.container.GridLayout

        % Validation row (bottom)
        ValidationLabel         matlab.ui.control.Label
    end

    % ====================================================================
    % State
    % ====================================================================
    properties (Access = private)
        Stage                   char  = 'raw'   % 'raw' | 'oxy'
        Model                                   % pf2_base.PipelineModel | empty
        ModelChangedListener    event.listener
        CurrentMethodName       char  = ''
        IsDirty (1,1) logical   = false  % unsaved edits to current method
        SuppressCallbacks (1,1) logical = false  % when programmatically updating widgets
    end

    % ====================================================================
    % Construction & destruction
    % ====================================================================
    methods (Access = public)
        function app = Editor(varargin)
            if pf2_base.env.isOctave()
                error('pf2:gui:octaveUnsupported', ...
                    ['pf2.methods.Editor requires MATLAB (App Designer). ' ...
                     'Under Octave, edit methods via the Pipeline API.']);
            end
            ip = inputParser;
            ip.addParameter('Stage', 'raw', @(x) ismember(lower(char(x)), {'raw','oxy'}));
            ip.parse(varargin{:});
            app.Stage = lower(char(ip.Results.Stage));

            % Ensure pf2 is initialized so PF2.myRawMethods / myOxyMethods exist.
            try, pf2_base.pf2_initialize(); end %#ok<TRYNC>

            createComponents(app);
            registerApp(app, app.UIFigure);

            refreshMethodsList(app);
            % Auto-load the first non-None method if any
            sel = pickInitialMethod(app);
            if ~isempty(sel)
                app.MethodsListBox.Value = sel;
                onMethodSelected(app);
            else
                onNew(app);
            end

            if nargout == 0, clear app; end
        end

        function delete(app)
            try
                if ~isempty(app.ModelChangedListener) && isvalid(app.ModelChangedListener)
                    delete(app.ModelChangedListener);
                end
            catch
            end
            try
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    delete(app.UIFigure);
                end
            catch
            end
        end
    end

    % ====================================================================
    % UI construction
    % ====================================================================
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name', 'pf2 Methods Editor', ...
                'Position', [120 120 1100 640], ...
                'CloseRequestFcn', @(~,~) delete(app));

            app.MainGrid = uigridlayout(app.UIFigure, [3 1]);
            app.MainGrid.RowHeight   = {44, '1x', 28};
            app.MainGrid.ColumnWidth = {'1x'};
            app.MainGrid.Padding     = [6 6 6 6];
            app.MainGrid.RowSpacing  = 4;

            % --- Toolbar ---
            app.Toolbar = uigridlayout(app.MainGrid, [1 10]);
            app.Toolbar.Layout.Row    = 1;
            app.Toolbar.Layout.Column = 1;
            app.Toolbar.RowHeight     = {'1x'};
            app.Toolbar.ColumnWidth   = {110, 80, 100, 80, 130, 75, 75, 95, '1x', 80, 90, 60, 60};
            app.Toolbar.Padding       = [0 0 0 0];
            app.Toolbar.ColumnSpacing = 4;

            app.StageDropDown = uidropdown(app.Toolbar, ...
                'Items', {'Raw stage', 'Oxy stage'}, ...
                'ItemsData', {'raw','oxy'}, ...
                'Value', app.Stage, ...
                'ValueChangedFcn', @(s,e) onStageChanged(app));
            app.StageDropDown.Layout.Column = 1;

            app.NewButton = uibutton(app.Toolbar, 'Text', 'New', ...
                'ButtonPushedFcn', @(s,e) onNew(app));
            app.NewButton.Layout.Column = 2;

            app.DuplicateButton = uibutton(app.Toolbar, 'Text', 'Duplicate', ...
                'ButtonPushedFcn', @(s,e) onDuplicate(app));
            app.DuplicateButton.Layout.Column = 3;

            app.DeleteButton = uibutton(app.Toolbar, 'Text', 'Delete', ...
                'ButtonPushedFcn', @(s,e) onDelete(app));
            app.DeleteButton.Layout.Column = 4;

            app.SeedButton = uibutton(app.Toolbar, 'Text', 'Reset defaults', ...
                'Tooltip', 'Install repo-shipped seed methods (OD_TDDR, LPF, ...)', ...
                'ButtonPushedFcn', @(s,e) onSeedDefaults(app));
            app.SeedButton.Layout.Column = 5;

            app.ImportButton = uibutton(app.Toolbar, 'Text', 'Import…', ...
                'Tooltip', 'Import a method from a JSON file', ...
                'ButtonPushedFcn', @(s,e) onImport(app));
            app.ImportButton.Layout.Column = 6;

            app.ExportButton = uibutton(app.Toolbar, 'Text', 'Export…', ...
                'Tooltip', 'Export current method to a JSON file', ...
                'ButtonPushedFcn', @(s,e) onExport(app));
            app.ExportButton.Layout.Column = 7;

            app.FunctionsButton = uibutton(app.Toolbar, 'Text', 'Functions…', ...
                'Tooltip', 'Register a new processing function from a .m file', ...
                'ButtonPushedFcn', @(s,e) onRegisterFunction(app));
            app.FunctionsButton.Layout.Column = 8;

            app.SaveButton = uibutton(app.Toolbar, 'Text', 'Save', ...
                'ButtonPushedFcn', @(s,e) onSave(app));
            app.SaveButton.Layout.Column = 10;

            app.SaveAsButton = uibutton(app.Toolbar, 'Text', 'Save As…', ...
                'ButtonPushedFcn', @(s,e) onSaveAs(app));
            app.SaveAsButton.Layout.Column = 11;

            app.UndoButton = uibutton(app.Toolbar, 'Text', 'Undo', ...
                'ButtonPushedFcn', @(s,e) onUndo(app));
            app.UndoButton.Layout.Column = 12;

            app.RedoButton = uibutton(app.Toolbar, 'Text', 'Redo', ...
                'ButtonPushedFcn', @(s,e) onRedo(app));
            app.RedoButton.Layout.Column = 13;

            % --- Three-pane content ---
            app.ContentGrid = uigridlayout(app.MainGrid, [1 3]);
            app.ContentGrid.Layout.Row    = 2;
            app.ContentGrid.Layout.Column = 1;
            app.ContentGrid.ColumnWidth   = {220, 320, '1x'};
            app.ContentGrid.RowHeight     = {'1x'};
            app.ContentGrid.Padding       = [0 0 0 0];
            app.ContentGrid.ColumnSpacing = 6;

            % Methods (left)
            app.MethodsPanel = uipanel(app.ContentGrid, 'Title', 'Methods');
            app.MethodsPanel.Layout.Column = 1;
            mGrid = uigridlayout(app.MethodsPanel, [1 1]);
            mGrid.Padding = [4 4 4 4];
            app.MethodsListBox = uilistbox(mGrid, ...
                'Items', {}, ...
                'ValueChangedFcn', @(s,e) onMethodSelected(app));

            % Steps (center)
            app.StepsPanel = uipanel(app.ContentGrid, 'Title', 'Pipeline steps');
            app.StepsPanel.Layout.Column = 2;
            app.StepsGrid = uigridlayout(app.StepsPanel, [2 1]);
            app.StepsGrid.RowHeight = {'1x', 70};
            app.StepsGrid.Padding = [4 4 4 4];
            app.StepsGrid.RowSpacing = 4;

            app.StepsListBox = uilistbox(app.StepsGrid, ...
                'Items', {}, ...
                'ValueChangedFcn', @(s,e) refreshStepProperties(app));
            app.StepsListBox.Layout.Row = 1;

            app.StepsButtonsGrid = uigridlayout(app.StepsGrid, [2 4]);
            app.StepsButtonsGrid.Layout.Row = 2;
            app.StepsButtonsGrid.RowHeight  = {'1x','1x'};
            app.StepsButtonsGrid.ColumnWidth = {'1x', 30, 30, '1x'};
            app.StepsButtonsGrid.Padding    = [0 0 0 0];

            app.AddStepDropDown = uidropdown(app.StepsButtonsGrid, ...
                'Items', {'(load library...)'}, ...
                'ItemsData', {''}, ...
                'Tooltip', 'Pick a function to add as a step');
            app.AddStepDropDown.Layout.Row    = 1;
            app.AddStepDropDown.Layout.Column = [1 3];

            app.AddStepButton = uibutton(app.StepsButtonsGrid, 'Text', 'Add', ...
                'ButtonPushedFcn', @(s,e) onAddStep(app));
            app.AddStepButton.Layout.Row    = 1;
            app.AddStepButton.Layout.Column = 4;

            app.RemoveStepButton = uibutton(app.StepsButtonsGrid, 'Text', 'Remove', ...
                'ButtonPushedFcn', @(s,e) onRemoveStep(app));
            app.RemoveStepButton.Layout.Row    = 2;
            app.RemoveStepButton.Layout.Column = 1;

            app.MoveUpButton = uibutton(app.StepsButtonsGrid, 'Text', '▲', ...
                'ButtonPushedFcn', @(s,e) onMoveUp(app));
            app.MoveUpButton.Layout.Row    = 2;
            app.MoveUpButton.Layout.Column = 2;

            app.MoveDownButton = uibutton(app.StepsButtonsGrid, 'Text', '▼', ...
                'ButtonPushedFcn', @(s,e) onMoveDown(app));
            app.MoveDownButton.Layout.Row    = 2;
            app.MoveDownButton.Layout.Column = 3;

            % Properties (right)
            app.PropsPanel = uipanel(app.ContentGrid, 'Title', 'Step properties');
            app.PropsPanel.Layout.Column = 3;
            outerPropsGrid = uigridlayout(app.PropsPanel, [1 1]);
            outerPropsGrid.Padding = [4 4 4 4];
            app.PropsScroll = uipanel(outerPropsGrid, 'BorderType', 'none', ...
                'Scrollable', 'on');
            app.PropsGrid = uigridlayout(app.PropsScroll, [1 1]);
            app.PropsGrid.RowHeight   = {'fit'};
            app.PropsGrid.ColumnWidth = {'1x'};
            app.PropsGrid.Padding     = [0 0 0 0];
            app.PropsGrid.RowSpacing  = 4;

            % Validation strip
            app.ValidationLabel = uilabel(app.MainGrid, ...
                'Text', '', ...
                'FontColor', [0.4 0.4 0.4]);
            app.ValidationLabel.Layout.Row    = 3;
            app.ValidationLabel.Layout.Column = 1;

            refreshAddStepLibrary(app);
        end

        function refreshAddStepLibrary(app)
            try
                T = pf2_base.PipelineFunction.listAvailable(app.Stage);
            catch
                T = table();
            end
            if isempty(T) || height(T) == 0
                app.AddStepDropDown.Items     = {'(no functions)'};
                app.AddStepDropDown.ItemsData = {''};
                return
            end
            items = strings(height(T)+1, 1);
            data  = strings(height(T)+1, 1);
            items(1) = "(pick a function)";
            data(1)  = "";
            for k = 1:height(T)
                lbl = T.funcName(k);
                if strlength(T.displayName(k)) > 0
                    lbl = T.funcName(k) + " — " + T.displayName(k);
                end
                items(k+1) = lbl;
                data(k+1)  = T.funcName(k);
            end
            app.AddStepDropDown.Items     = cellstr(items);
            app.AddStepDropDown.ItemsData = cellstr(data);
            app.AddStepDropDown.Value     = '';
        end
    end

    % ====================================================================
    % Refresh helpers (UI <- state)
    % ====================================================================
    methods (Access = private)
        function refreshAll(app)
            refreshMethodsList(app);
            refreshStepsList(app);
            refreshStepProperties(app);
            refreshValidation(app);
            refreshUndoRedoState(app);
            refreshTitle(app);
        end

        function refreshMethodsList(app)
            cfg = methodCfg(app);
            items = {};
            if ~isempty(cfg)
                try
                    items = cfg.Sections;
                catch
                    items = {};
                end
            end
            if isempty(items), items = {}; end
            app.MethodsListBox.Items = items;
            if ~isempty(app.CurrentMethodName) && ismember(app.CurrentMethodName, items)
                app.MethodsListBox.Value = app.CurrentMethodName;
            elseif ~isempty(items)
                app.MethodsListBox.Value = items{1};
            end
        end

        function refreshStepsList(app)
            if isempty(app.Model) || isempty(app.Model.Pipeline)
                app.StepsListBox.Items = {};
                app.StepsListBox.ItemsData = {};
                return
            end
            steps = app.Model.Pipeline.steps;
            n = numel(steps);
            items = strings(n,1);
            for k = 1:n
                pf = steps{k};
                roleSuffix = '';
                if ~isempty(pf.role), roleSuffix = sprintf(' [%s]', pf.role); end
                items(k) = sprintf('%d. %s%s', k, pf.funcName, roleSuffix);
            end
            app.StepsListBox.Items     = cellstr(items);
            app.StepsListBox.ItemsData = num2cell(1:n);
            % Preserve / clamp selection. Programmatic Value changes don't
            % fire ValueChangedFcn, so refreshAll calls refreshStepProperties
            % explicitly after this — no extra trigger needed here.
            if n == 0
                app.StepsListBox.Value = {};
            else
                cur = app.StepsListBox.Value;
                if isempty(cur) || (isnumeric(cur) && cur > n)
                    app.StepsListBox.Value = 1;
                end
            end
        end

        function refreshStepProperties(app)
            % Wipe existing widgets in the props grid
            children = app.PropsGrid.Children;
            for k = numel(children):-1:1
                delete(children(k));
            end
            app.PropsGrid.RowHeight = {'fit'};

            stepIdx = app.StepsListBox.Value;
            if isempty(stepIdx) || isempty(app.Model)
                % Helpful hint when nothing's selected.
                if ~isempty(app.Model) && app.Model.Pipeline.numSteps() == 0
                    hint = uilabel(app.PropsGrid, ...
                        'Text', sprintf(['This method has no steps yet.\n' ...
                          'Pick a function in the dropdown below the steps panel ' ...
                          'and click Add. Or click "Reset defaults" in the toolbar ' ...
                          'to install the shipped seed methods (OD_TDDR, LPF, ...).']), ...
                        'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4]);
                    hint.Layout.Row = 1; hint.Layout.Column = 1;
                end
                return
            end
            step = app.Model.Pipeline.getStep(stepIdx);

            customNames = step.customNames;
            % Header row: function name + description
            row = 1;
            app.PropsGrid.RowHeight = repmat({'fit'}, 1, max(1, numel(customNames)*2 + 2));

            hdr = uilabel(app.PropsGrid, ...
                'Text', step.funcName, ...
                'FontWeight', 'bold');
            hdr.Layout.Row = row; hdr.Layout.Column = 1;
            row = row + 1;
            if ~isempty(step.description)
                desc = uilabel(app.PropsGrid, ...
                    'Text', sanitizeMultiline(step.description), ...
                    'WordWrap','on', 'FontColor', [0.4 0.4 0.4]);
                desc.Layout.Row = row; desc.Layout.Column = 1;
                row = row + 1;
            end

            % One row per custom param: label + editor widget
            for k = 1:numel(customNames)
                argName = customNames{k};
                meta = step.argMeta(argName);
                ctrlContainer = uigridlayout(app.PropsGrid, [1 2]);
                ctrlContainer.ColumnWidth = {140, '1x'};
                ctrlContainer.Padding = [0 0 0 0];
                ctrlContainer.RowSpacing = 0;
                ctrlContainer.Layout.Row = row;

                lblText = argName;
                if ~isempty(meta.unit), lblText = sprintf('%s (%s)', argName, meta.unit); end
                lbl = uilabel(ctrlContainer, 'Text', lblText, ...
                    'Tooltip', meta.description);
                lbl.Layout.Column = 1;

                buildParamWidget(app, ctrlContainer, stepIdx, argName, meta);
                row = row + 1;
            end
        end

        function buildParamWidget(app, parent, stepIdx, argName, meta)
            val = meta.default;
            switch lower(meta.type)
                case {'int','double'}
                    w = uieditfield(parent, 'numeric', ...
                        'Value', toNumOrNaN(val), ...
                        'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    if ~isempty(meta.range)
                        w.Limits = meta.range;
                    end
                    if strcmpi(meta.type, 'int')
                        w.RoundFractionalValues = 'on';
                    end
                case 'logical'
                    w = uicheckbox(parent, ...
                        'Text', '', ...
                        'Value', logical(coerceLogical(val)), ...
                        'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                case {'enum'}
                    items = meta.choices;
                    if isempty(items)
                        w = uieditfield(parent, 'text', ...
                            'Value', toStr(val), ...
                            'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    else
                        items = ensureChoiceCells(items);
                        labels = cellfun(@toStr, items, 'UniformOutput', false);
                        w = uidropdown(parent, ...
                            'Items', labels, ...
                            'ItemsData', items, ...
                            'Value', matchChoice(items, val), ...
                            'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    end
                case 'string'
                    w = uieditfield(parent, 'text', ...
                        'Value', toStr(val), ...
                        'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                otherwise
                    % 'auto' / unknown: try to infer from current value class
                    if islogical(val) || (isnumeric(val) && isscalar(val) && (val==0 || val==1))
                        w = uicheckbox(parent, 'Text','', ...
                            'Value', logical(coerceLogical(val)), ...
                            'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    elseif isnumeric(val)
                        w = uieditfield(parent, 'numeric', ...
                            'Value', toNumOrNaN(val), ...
                            'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    else
                        w = uieditfield(parent, 'text', ...
                            'Value', toStr(val), ...
                            'ValueChangedFcn', @(s,e) onParamChanged(app, stepIdx, argName, s.Value));
                    end
            end
            w.Layout.Column = 2;
        end

        function refreshValidation(app)
            if isempty(app.Model) || isempty(app.Model.Pipeline)
                app.ValidationLabel.Text     = '';
                app.ValidationLabel.FontColor = [0.4 0.4 0.4];
                return
            end
            issues = app.Model.Pipeline.validate();
            if isempty(issues)
                app.ValidationLabel.Text     = '✓ Pipeline valid';
                app.ValidationLabel.FontColor = [0 0.5 0];
                return
            end
            msgs = strings(1, numel(issues));
            for k = 1:numel(issues)
                msgs(k) = sprintf('step %d (%s): %s', ...
                    issues(k).step, issues(k).funcName, issues(k).message);
            end
            app.ValidationLabel.Text     = char(strjoin(msgs, ' | '));
            app.ValidationLabel.FontColor = [0.7 0 0];
        end

        function refreshUndoRedoState(app)
            if isempty(app.Model)
                app.UndoButton.Enable = 'off';
                app.RedoButton.Enable = 'off';
                return
            end
            app.UndoButton.Enable = matlab.lang.OnOffSwitchState(app.Model.canUndo());
            app.RedoButton.Enable = matlab.lang.OnOffSwitchState(app.Model.canRedo());
        end

        function refreshTitle(app)
            star = ''; if app.IsDirty, star = '*'; end
            stageStr = sprintf('%s stage', app.Stage);
            mname = app.CurrentMethodName;
            if isempty(mname), mname = '<unsaved>'; end
            app.UIFigure.Name = sprintf('pf2 Methods Editor — %s — %s%s', stageStr, mname, star);
        end
    end

    % ====================================================================
    % Callbacks
    % ====================================================================
    methods (Access = private)
        function onStageChanged(app)
            app.Stage = app.StageDropDown.Value;
            app.CurrentMethodName = '';
            app.IsDirty = false;
            refreshAddStepLibrary(app);
            refreshMethodsList(app);
            sel = pickInitialMethod(app);
            if ~isempty(sel)
                app.MethodsListBox.Value = sel;
                onMethodSelected(app);
            else
                onNew(app);
            end
        end

        function onMethodSelected(app)
            name = app.MethodsListBox.Value;
            if isempty(name), return; end
            try
                if strcmp(app.Stage, 'raw')
                    p = pf2_base.RawPipeline.fromMethod(name);
                else
                    p = pf2_base.OxyPipeline.fromMethod(name);
                end
            catch ME
                % Fall back to a fresh empty pipeline of the right subclass
                % so the editor stays usable when a saved method has empty F.
                if strcmp(app.Stage, 'raw')
                    p = pf2_base.RawPipeline(name);
                else
                    p = pf2_base.OxyPipeline(name);
                end
                warning('pf2:methods:Editor:loadFallback', ...
                    'Method ''%s'' could not be loaded (%s); starting empty.', ...
                    name, ME.message);
            end
            attachModel(app, p);
            app.CurrentMethodName = name;
            app.IsDirty = false;
            refreshAll(app);
        end

        function onNew(app)
            if strcmp(app.Stage, 'raw')
                p = pf2_base.RawPipeline('untitled');
            else
                p = pf2_base.OxyPipeline('untitled');
            end
            attachModel(app, p);
            app.CurrentMethodName = '';
            app.IsDirty = true;
            refreshAll(app);
        end

        function onDuplicate(app)
            if isempty(app.Model), return; end
            base = app.CurrentMethodName;
            if isempty(base), base = 'untitled'; end
            ans_ = inputdlg('New method name:', 'Duplicate', 1, {[base '_copy']});
            if isempty(ans_), return; end
            newName = strtrim(ans_{1});
            if isempty(newName), return; end
            if strcmp(app.Stage, 'raw')
                np = pf2_base.RawPipeline(newName);
            else
                np = pf2_base.OxyPipeline(newName);
            end
            for k = 1:app.Model.Pipeline.numSteps()
                np = np.add(app.Model.Pipeline.getStep(k));
            end
            attachModel(app, np);
            app.CurrentMethodName = newName;
            app.IsDirty = true;
            refreshAll(app);
        end

        function onDelete(app)
            global PF2 %#ok<GVMIS>
            name = app.CurrentMethodName;
            if isempty(name)
                uialert(app.UIFigure, 'No saved method selected.', 'Delete');
                return
            end
            sel = uiconfirm(app.UIFigure, ...
                sprintf('Delete saved method "%s"? This cannot be undone.', name), ...
                'Confirm Delete', 'Options', {'Delete','Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(sel, 'Delete'), return; end
            cfg = methodCfg(app);
            if ~isempty(cfg) && ismember(name, cfg.Sections)
                cfg.remove(name);
                cfg.write();
            end
            app.CurrentMethodName = '';
            refreshMethodsList(app);
            sel = pickInitialMethod(app);
            if ~isempty(sel)
                app.MethodsListBox.Value = sel;
                onMethodSelected(app);
            else
                onNew(app);
            end
        end

        function onSave(app)
            if isempty(app.Model), return; end
            name = app.CurrentMethodName;
            if isempty(name) || strcmp(name, 'untitled')
                onSaveAs(app);
                return
            end
            try
                app.Model.Pipeline.save(app.Stage, 'Replace', true);
                app.IsDirty = false;
                refreshMethodsList(app);
                refreshTitle(app);
            catch ME
                uialert(app.UIFigure, sprintf('Save failed: %s', ME.message), 'Save');
            end
        end

        function onSaveAs(app)
            if isempty(app.Model), return; end
            base = app.CurrentMethodName;
            if isempty(base), base = 'untitled'; end
            ans_ = inputdlg('Save method as:', 'Save As', 1, {base});
            if isempty(ans_), return; end
            newName = strtrim(ans_{1});
            if isempty(newName), return; end
            % Rebuild pipeline with the new name
            if strcmp(app.Stage, 'raw')
                np = pf2_base.RawPipeline(newName);
            else
                np = pf2_base.OxyPipeline(newName);
            end
            for k = 1:app.Model.Pipeline.numSteps()
                np = np.add(app.Model.Pipeline.getStep(k));
            end
            try
                np.save(app.Stage, 'Replace', true);
                app.CurrentMethodName = newName;
                attachModel(app, np);
                app.IsDirty = false;
                refreshAll(app);
            catch ME
                uialert(app.UIFigure, sprintf('Save As failed: %s', ME.message), 'Save As');
            end
        end

        function onAddStep(app)
            if isempty(app.Model), return; end
            funcName = app.AddStepDropDown.Value;
            if isempty(funcName)
                uialert(app.UIFigure, 'Pick a function from the dropdown first.', 'Add step');
                return
            end
            try
                app.Model.addStep(funcName);
            catch ME
                uialert(app.UIFigure, sprintf('Add failed: %s', ME.message), 'Add step');
            end
        end

        function onRemoveStep(app)
            if isempty(app.Model), return; end
            idx = app.StepsListBox.Value;
            if isempty(idx), return; end
            app.Model.removeStep(idx);
        end

        function onMoveUp(app)
            if isempty(app.Model), return; end
            idx = app.StepsListBox.Value;
            if isempty(idx) || idx <= 1, return; end
            app.Model.moveStep(idx, idx-1);
            app.StepsListBox.Value = idx-1;
        end

        function onMoveDown(app)
            if isempty(app.Model), return; end
            idx = app.StepsListBox.Value;
            n = app.Model.Pipeline.numSteps();
            if isempty(idx) || idx >= n, return; end
            app.Model.moveStep(idx, idx+1);
            app.StepsListBox.Value = idx+1;
        end

        function onImport(app)
            [file, path] = uigetfile({'*.json','JSON method files (*.json)'}, ...
                'Import method', '');
            figure(app.UIFigure);  % bring main back to front
            if isequal(file, 0), return; end
            fp = fullfile(path, file);
            try
                if strcmp(app.Stage, 'raw')
                    pf2.methods.raw.importMethod(fp, 'Replace', true);
                else
                    pf2.methods.oxy.importMethod(fp, 'Replace', true);
                end
                refreshMethodsList(app);
                % Try to select the imported method (its name = file base).
                [~, name] = fileparts(file);
                cleaned = pf2_base.cleanNameForINI(name);
                if ismember(cleaned, app.MethodsListBox.Items)
                    app.MethodsListBox.Value = cleaned;
                    onMethodSelected(app);
                end
                uialert(app.UIFigure, ...
                    sprintf('Imported method from %s', file), 'Import', ...
                    'Icon', 'success');
            catch ME
                uialert(app.UIFigure, sprintf('Import failed: %s', ME.message), ...
                    'Import');
            end
        end

        function onExport(app)
            if isempty(app.CurrentMethodName)
                uialert(app.UIFigure, 'Save the current method before exporting.', ...
                    'Export');
                return
            end
            if app.IsDirty
                sel = uiconfirm(app.UIFigure, ...
                    'You have unsaved changes. Save before export?', ...
                    'Export', 'Options', {'Save and export','Export anyway','Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 3);
                if strcmp(sel, 'Cancel'), return; end
                if strcmp(sel, 'Save and export'), onSave(app); end
            end
            defaultName = sprintf('%s.json', app.CurrentMethodName);
            [file, path] = uiputfile({'*.json','JSON method files (*.json)'}, ...
                'Export method', defaultName);
            figure(app.UIFigure);
            if isequal(file, 0), return; end
            fp = fullfile(path, file);
            try
                if strcmp(app.Stage, 'raw')
                    pf2.methods.raw.exportMethod(app.CurrentMethodName, fp);
                else
                    pf2.methods.oxy.exportMethod(app.CurrentMethodName, fp);
                end
                uialert(app.UIFigure, ...
                    sprintf('Exported %s to %s', app.CurrentMethodName, file), ...
                    'Export', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, sprintf('Export failed: %s', ME.message), ...
                    'Export');
            end
        end

        function onRegisterFunction(app)
        % Register a new processing function from a .m file. Auto-detects
        % the signature; user fills in display name, description, and role.
            [file, path] = uigetfile({'*.m','MATLAB function files (*.m)'}, ...
                'Pick a function .m file to register', '');
            figure(app.UIFigure);
            if isequal(file, 0), return; end
            [~, funcName] = fileparts(file);

            % Auto-detect signature
            try
                pf = pf2_base.PipelineFunction.detect(funcName);
            catch ME
                uialert(app.UIFigure, sprintf('Detect failed: %s', ME.message), ...
                    'Register function');
                return
            end

            % Prompt for display fields. uifigure-style modal via uiconfirm
            % is too restrictive; fall back to a sequence of inputdlg.
            answer = inputdlg( ...
                {'Display name:', 'Description:', ...
                 'Role (none|intensity2od|motion|filter|rejection|roi|transform):', ...
                 'Valid stages (1=raw, 2=oxy, "[1,2]" for both):', ...
                 'Requires OD input? (true/false)'}, ...
                sprintf('Register %s', funcName), 1, ...
                {pf.name, pf.description, pf.role, mat2str(pf.validStages), ...
                 mat2str(pf.requiresOD)});
            if isempty(answer), return; end

            % Build PipelineFunction with the user-supplied metadata and persist.
            try
                stages = str2num(answer{4}); %#ok<ST2NM>
                if isempty(stages), stages = pf.validStages; end
                reqOD = strcmpi(strtrim(answer{5}), 'true');
                pfNew = pf2_base.PipelineFunction(funcName, pf.argNames, ...
                    pf.argDefaults, pf.outputNames, ...
                    'Name',        answer{1}, ...
                    'Description', answer{2}, ...
                    'Role',        answer{3}, ...
                    'ValidStages', stages, ...
                    'RequiresOD',  reqOD);
                pf2_base.PipelineFunction.register(pfNew);
                refreshAddStepLibrary(app);
                uialert(app.UIFigure, ...
                    sprintf('Registered %s', funcName), 'Functions', ...
                    'Icon', 'success');
            catch ME
                uialert(app.UIFigure, sprintf('Register failed: %s', ME.message), ...
                    'Functions');
            end
        end

        function onSeedDefaults(app)
        % Install repo seeds for the current stage. Existing methods of the
        % same name are overwritten; other user methods are kept.
            sel = uiconfirm(app.UIFigure, ...
                sprintf(['Install repo seed methods for the %s stage? ' ...
                        'This will overwrite any existing methods with the ' ...
                        'same names (OD_TDDR, OD_TDDR_lpf for raw; ' ...
                        'LPF, LPF_ROI for oxy). Other user methods are kept.'], ...
                        app.Stage), ...
                'Install seed methods', ...
                'Options', {'Install', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 2);
            if ~strcmp(sel, 'Install'), return; end
            try
                seeds = pf2.methods.seeds.list(app.Stage);
                for k = 1:numel(seeds)
                    s = seeds(k);
                    factory = ['pf2.methods.seeds.' s.stage '.' s.name];
                    p = feval(factory);
                    p.save(s.stage, 'Replace', true);
                end
                refreshMethodsList(app);
                refreshAddStepLibrary(app);
                first = pickInitialMethod(app);
                if ~isempty(first)
                    app.MethodsListBox.Value = first;
                    onMethodSelected(app);
                end
                uialert(app.UIFigure, ...
                    sprintf('Installed %d seed methods.', numel(seeds)), ...
                    'Done', 'Icon','success');
            catch ME
                uialert(app.UIFigure, sprintf('Seed install failed: %s', ME.message), ...
                    'Reset defaults');
            end
        end

        function onUndo(app)
            if ~isempty(app.Model), app.Model.undo(); end
        end

        function onRedo(app)
            if ~isempty(app.Model), app.Model.redo(); end
        end

        function onParamChanged(app, stepIdx, argName, value)
            if isempty(app.Model) || app.SuppressCallbacks, return; end
            try
                app.Model.setParam(stepIdx, argName, value);
            catch ME
                uialert(app.UIFigure, sprintf('Set %s failed: %s', argName, ME.message), ...
                    'Parameter');
            end
        end

        function onModelChanged(app, ~, ~)
            % Listener target — fired by PipelineModel after every mutation.
            app.IsDirty = true;
            refreshStepsList(app);
            refreshStepProperties(app);
            refreshValidation(app);
            refreshUndoRedoState(app);
            refreshTitle(app);
        end
    end

    % ====================================================================
    % Internal helpers
    % ====================================================================
    methods (Access = private)
        function attachModel(app, pipeline)
            if ~isempty(app.ModelChangedListener) && isvalid(app.ModelChangedListener)
                delete(app.ModelChangedListener);
            end
            app.Model = pf2_base.PipelineModel(pipeline);
            app.ModelChangedListener = listener(app.Model, ...
                'PipelineChanged', @(s,e) onModelChanged(app, s, e));
        end

        function name = pickInitialMethod(app)
        % Pick the most useful method to show on load: prefer a non-'None'
        % method whose F has at least one step. Fall back to the first
        % non-'None', then the first section.
            cfg = methodCfg(app);
            name = '';
            if isempty(cfg), return; end
            try
                sections = cfg.Sections;
            catch
                return
            end
            if isempty(sections), return; end
            nonNone = sections(~strcmp(sections, 'None'));
            if isempty(nonNone)
                name = sections{1};
                return
            end
            % First, prefer a method that actually has steps.
            for k = 1:numel(nonNone)
                try
                    sec = cfg.(nonNone{k});
                    if isfield(sec,'F') && iscell(sec.F) && ~isempty(sec.F)
                        name = nonNone{k};
                        return
                    end
                catch
                end
            end
            name = nonNone{1};
        end

        function cfg = methodCfg(app)
            global PF2 %#ok<GVMIS>
            cfg = [];
            if isempty(PF2), return; end
            try
                if strcmp(app.Stage, 'raw') && isfield(PF2,'myRawMethods')
                    cfg = PF2.myRawMethods.cfg;
                elseif strcmp(app.Stage, 'oxy') && isfield(PF2,'myOxyMethods')
                    cfg = PF2.myOxyMethods.cfg;
                end
            catch
                cfg = [];
            end
        end
    end
end

% ====================================================================
% Local helpers (file-private functions)
% ====================================================================
function out = toNumOrNaN(v)
    if isempty(v)
        out = NaN;
    elseif isnumeric(v) && isscalar(v)
        out = double(v);
    elseif ischar(v) || isstring(v)
        out = str2double(v);
    else
        out = NaN;
    end
end

function out = coerceLogical(v)
    if isempty(v), out = false; return; end
    if islogical(v), out = v; return; end
    if isnumeric(v) && isscalar(v), out = v ~= 0; return; end
    if ischar(v) || isstring(v)
        s = lower(strtrim(char(v)));
        out = ismember(s, {'1','true','yes','on'});
        return
    end
    out = false;
end

function s = toStr(v)
    if isempty(v), s = ''; return; end
    if ischar(v), s = v; return; end
    if isstring(v), s = char(v); return; end
    if isnumeric(v) && isscalar(v), s = num2str(v); return; end
    s = char(string(v));
end

function out = ensureChoiceCells(c)
    if iscell(c)
        out = c;
    else
        out = num2cell(c);
    end
end

function v = matchChoice(items, value)
    v = items{1};
    for k = 1:numel(items)
        if isequal(items{k}, value)
            v = items{k}; return
        end
        if (ischar(items{k})||isstring(items{k})) && (ischar(value)||isstring(value)) ...
                && strcmp(char(items{k}), char(value))
            v = items{k}; return
        end
    end
end

function s = sanitizeMultiline(s)
    s = strrep(char(s), '\n', newline);
end
