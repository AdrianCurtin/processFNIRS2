classdef Experiment < handle
% EXPERIMENT Scriptable container for multi-subject fNIRS group analysis
%
% The Experiment class provides a CLI-friendly interface to exploreFNIRS
% group analysis operations. It wraps data organization, filtering,
% grouping, hierarchical averaging, and export into a chainable API
% that doesn't require the GUI.
%
% Syntax:
%   ex = exploreFNIRS.core.Experiment(data)
%   ex = exploreFNIRS.core.Experiment(data, 'Hierarchy', {'SubjectID','Session'})
%   ex2 = exploreFNIRS.core.Experiment(ex)   % copy data, settings, hierarchy
%
% Inputs:
%   data      - Cell array of processed fNIRS structs (from processFNIRS2),
%               or another Experiment object (copies data, settings, hierarchy)
%
% Name-Value Parameters:
%   Hierarchy - Cell array of hierarchy level names (default:
%               {'SubjectID','Session','Condition','Trial','Block'})
%               Column 1 = highest level (Subject), last = lowest (Trial).
%               Used for within-subject averaging to prevent pseudoreplication.
%
% Example:
%   % Load processed data
%   files = dir('processed/*.mat');
%   data = cell(length(files), 1);
%   for i = 1:length(files)
%       tmp = load(fullfile(files(i).folder, files(i).name));
%       data{i} = tmp.processed;
%   end
%
%   % Create experiment and run analysis
%   ex = exploreFNIRS.core.Experiment(data);
%   ex.select('Group', 'Control', 'Condition', {'Natural','Synthetic'});
%   ex.groupby({'Group', 'Condition'});
%   ex.aggregate();
%
%   % View results
%   ex.summary();
%
%   % Export
%   T = ex.toLongTable({'HbO','HbR'});
%   writetable(T, 'results.csv');
%
% See also: exploreFNIRS, processFNIRS2, grandAvgFNIRS

    properties
        % Cell array of processed fNIRS structs (immutable source data)
        data

        % Metadata table built from data.info fields
        dataTable

        % Hierarchy levels for within-subject averaging
        % Default: {'SubjectID','Session','Condition','Trial','Block'}
        hierarchy

        % Analysis settings
        settings

        % Hierarchical color scheme for plots (optional)
        % See also: exploreFNIRS.core.ColorScheme
        colorScheme

        % Named color scheme presets (struct of ColorScheme objects)
        % Use addColorScheme/useColorScheme to manage.
        % See also: exploreFNIRS.core.ColorScheme
        colorSchemes
    end

    properties (SetAccess = private)
        % Logical index into data for current selection
        selectedIdx

        % Variable names used for current grouping
        groupByVars

        % Struct array of grouped data (matches ExFNIRS.gby format)
        groups

        % State flags
        isGrouped
        isAggregated

        % Transient state snapshot (used by PlotProxy for save/restore)
        stateSnapshot
    end

    properties (Dependent, SetAccess = private)
        % PlotProxy for grammar-of-graphics style plotting
        plot
    end

    methods

        function obj = Experiment(data, varargin)
        % EXPERIMENT Create a new Experiment from processed fNIRS data
        %
        %   ex = Experiment(data)
        %   ex = Experiment(data, 'Hierarchy', {'SubjectID','Condition'})
        %   ex2 = Experiment(ex)   % copy data, settings, hierarchy

            % Copy from another Experiment (source hierarchy as default,
            % caller's varargin appended last so it takes priority)
            if isa(data, 'exploreFNIRS.core.Experiment')
                src = data;
                data = src.data;
                varargin = [{'Hierarchy', src.hierarchy}, varargin];
            end

            if ~iscell(data) || isempty(data)
                error('exploreFNIRS:core:Experiment', ...
                    'Input must be a non-empty cell array of fNIRS structs');
            end

            % Force column cell array
            obj.data = data(:);

            % Build metadata table
            obj.dataTable = exploreFNIRS.dataset.buildSegmentInfoTable(obj.data);

            % Add missingFNIRS column (required by export functions)
            % All data passed to Experiment is assumed valid
            obj.dataTable.missingFNIRS = zeros(height(obj.dataTable), 1);

            % Parse options
            p = inputParser;
            addParameter(p, 'Hierarchy', ...
                {'SubjectID','Session','Condition','Trial','Block'}, @iscell);
            parse(p, varargin{:});
            obj.hierarchy = p.Results.Hierarchy;

            % Default settings
            obj.settings = struct( ...
                'baseline',     [-5, 0], ...     % [start, end] seconds for baseline window
                'taskStart',    0, ...           % task onset time (for bin alignment)
                'taskEnd',      Inf, ...         % task end time (Inf = use full segment)
                'resampleRate', 0.5, ...         % seconds per bin for temporal (0 = no resample)
                'barBinSize',   0, ...           % seconds per bin for bar (0 = full task window, 1 bar)
                'useBaseline',  true, ...        % apply baseline correction
                'avgMode',      'hierarchy', ... % 'hierarchy', 'flat', or 'none'
                'rawMethod',    '', ...          % Raw processing method name ('' = no reprocessing)
                'oxyMethod',    '' ...           % Oxy processing method name ('' = no reprocessing)
            );

            % Copy settings from source Experiment
            if exist('src', 'var')
                obj.settings = src.settings;
            end

            % Initialize color schemes
            obj.colorSchemes = struct();

            % Initialize state
            obj.selectedIdx = true(length(obj.data), 1);
            obj.groupByVars = {};
            obj.groups = [];
            obj.isGrouped = false;
            obj.isAggregated = false;
        end


        function proxy = get.plot(obj)
        % GET.PLOT Return a PlotProxy linked to this Experiment
        %
        %   fig = ex.plot.bar('X', 'Condition', 'Color', 'Group', 'Channels', 5)
        %   fig = ex.plot.temporal('Color', 'Group', 'Channels', 1:5)
        %
        % See also: exploreFNIRS.core.PlotProxy
            proxy = exploreFNIRS.core.PlotProxy(obj);
        end


        function obj = addColorScheme(obj, name, cs)
        % ADDCOLORSCHEME Register a named color scheme preset
        %
        %   ex.addColorScheme('byGroup', csGroup)
        %   ex.addColorScheme('byCondition', csCond)
        %
        % Stores the ColorScheme under the given name for later use with
        % useColorScheme() or per-plot 'ColorScheme' parameter.
        %
        % See also: useColorScheme, removeColorScheme, ColorScheme

            if ~isvarname(name)
                error('exploreFNIRS:core:Experiment:addColorScheme', ...
                    'Name "%s" is not a valid MATLAB identifier.', name);
            end
            if ~isa(cs, 'exploreFNIRS.core.ColorScheme')
                error('exploreFNIRS:core:Experiment:addColorScheme', ...
                    'Value must be an exploreFNIRS.core.ColorScheme object.');
            end
            obj.colorSchemes.(name) = cs;
        end


        function obj = removeColorScheme(obj, name)
        % REMOVECOLORSCHEME Remove a named color scheme preset
        %
        %   ex.removeColorScheme('byGroup')
        %
        % See also: addColorScheme, useColorScheme

            if ~isfield(obj.colorSchemes, name)
                error('exploreFNIRS:core:Experiment:removeColorScheme', ...
                    'Color scheme "%s" not found.', name);
            end
            obj.colorSchemes = rmfield(obj.colorSchemes, name);
        end


        function obj = useColorScheme(obj, name)
        % USECOLORSCHEME Set the active color scheme from a named preset
        %
        %   ex.useColorScheme('byGroup')
        %
        % Looks up the named preset and assigns it to ex.colorScheme.
        %
        % See also: addColorScheme, removeColorScheme

            if ~isfield(obj.colorSchemes, name)
                error('exploreFNIRS:core:Experiment:useColorScheme', ...
                    'Color scheme "%s" not found. Available: %s', ...
                    name, strjoin(fieldnames(obj.colorSchemes), ', '));
            end
            obj.colorScheme = obj.colorSchemes.(name);
        end


        function obj = select(obj, varargin)
        % SELECT Filter data by metadata criteria
        %
        %   ex.select('VarName', value, 'VarName2', value2, ...)
        %
        % Values can be:
        %   - String/char:   exact match (e.g., 'Group', 'Control')
        %   - Cell/string array: match any (e.g., 'Condition', {'A','B'})
        %   - Numeric scalar: exact match
        %   - Numeric vector: match any
        %
        % Calling select() again narrows the current selection (AND logic).
        % Use reset() first to start fresh.
        %
        % Example:
        %   ex.select('Group', 'Control', 'Condition', {'Task1','Task2'});

            if mod(length(varargin), 2) ~= 0
                error('exploreFNIRS:core:Experiment:select', ...
                    'Arguments must be name-value pairs');
            end

            idx = obj.selectedIdx;

            for i = 1:2:length(varargin)
                varName = varargin{i};
                varVal  = varargin{i+1};

                if ~ismember(varName, obj.dataTable.Properties.VariableNames)
                    error('exploreFNIRS:core:Experiment:select', ...
                        'Variable "%s" not found in dataTable. Available: %s', ...
                        varName, strjoin(obj.dataTable.Properties.VariableNames, ', '));
                end

                col = obj.dataTable.(varName);

                if ischar(varVal)
                    varVal = string(varVal);
                end

                if isstring(varVal) || iscell(varVal)
                    % String matching
                    varVal = string(varVal);
                    if isstring(col) || iscategorical(col) || iscell(col)
                        idx = idx & ismember(string(col), varVal);
                    else
                        idx = idx & ismember(col, varVal);
                    end
                elseif isnumeric(varVal)
                    idx = idx & ismember(col, varVal);
                else
                    error('exploreFNIRS:core:Experiment:select', ...
                        'Unsupported value type for "%s"', varName);
                end
            end

            obj.selectedIdx = idx;
            obj.isGrouped = false;
            obj.isAggregated = false;
            obj.groups = [];

            nSel = sum(idx);
            nTot = length(idx);
            fprintf('Selected %d of %d segments\n', nSel, nTot);
        end


        function obj = reset(obj)
        % RESET Clear selection and grouping, return to full dataset
        %
        %   ex.reset();

            obj.selectedIdx = true(length(obj.data), 1);
            obj.groupByVars = {};
            obj.groups = [];
            obj.isGrouped = false;
            obj.isAggregated = false;
        end


        function selData = getSelectedData(obj)
        % GETSELECTEDDATA Return cell array of currently selected fNIRS structs
            selData = obj.data(obj.selectedIdx);
        end


        function selTable = getSelectedTable(obj)
        % GETSELECTEDTABLE Return metadata table for current selection
            selTable = obj.dataTable(obj.selectedIdx, :);
        end


        function obj = groupby(obj, vars)
        % GROUPBY Group selected data by metadata variables
        %
        %   ex.groupby({'Group', 'Condition'})
        %   ex.groupby('Group')
        %
        % Creates groups based on unique combinations of the specified
        % variables. Must be called after select() (or on full dataset).
        % Must be called before aggregate().

            if ischar(vars) || isstring(vars)
                vars = cellstr(vars);
            end

            % Validate variable names exist
            selTable = obj.getSelectedTable();
            for i = 1:length(vars)
                if ~ismember(vars{i}, selTable.Properties.VariableNames)
                    error('exploreFNIRS:core:Experiment:groupby', ...
                        'Variable "%s" not found. Available: %s', ...
                        vars{i}, strjoin(selTable.Properties.VariableNames, ', '));
                end
            end

            obj.groupByVars = vars;
            selData = obj.getSelectedData();

            [groupRows, ~, gbyIdx] = unique(selTable(:, vars), 'rows');
            nGroups = max(gbyIdx);

            obj.groups = [];
            for g = 1:nGroups
                mask = gbyIdx == g;
                obj.groups(g).gbyTables = selTable(mask, :);
                obj.groups(g).gbyFNIRS  = selData(mask);
                obj.groups(g).gbyGrand  = [];
                obj.groups(g).gbyGrandBarFlat = [];
                obj.groups(g).gbyFNIRS_pp = {};
                obj.groups(g).cache = struct('ppData', {{}}, 'barData', {{}}, 'ppKey', '');

                % Build human-readable label
                rowVals = cell(1, length(vars));
                for v = 1:length(vars)
                    val = groupRows.(vars{v})(g);
                    if isnumeric(val)
                        rowVals{v} = num2str(val);
                    else
                        rowVals{v} = char(string(val));
                    end
                end
                obj.groups(g).label = strjoin(rowVals, ' | ');
            end

            obj.isGrouped = true;
            obj.isAggregated = false;

            fprintf('Created %d groups:\n', nGroups);
            for g = 1:nGroups
                fprintf('  [%d] %s  (%d segments)\n', ...
                    g, obj.groups(g).label, size(obj.groups(g).gbyTables, 1));
            end
        end


        function obj = aggregate(obj, mode)
        % AGGREGATE Preprocess segments and compute grand averages
        %
        %   ex.aggregate()              % Uses settings.avgMode (default: 'hierarchy')
        %   ex.aggregate('hierarchy')   % Full hierarchical averaging
        %   ex.aggregate('flat')        % Average within subject only
        %   ex.aggregate('none')        % No within-subject averaging
        %
        % Preprocessing (controlled by settings):
        %   If settings.resampleRate > 0, each segment is resampled to that
        %   bin size (in seconds). If settings.useBaseline is true, the
        %   baseline window (settings.baseline) is extracted and subtracted.
        %
        % Averaging Modes:
        %   'hierarchy' - Averages bottom-up through hierarchy levels
        %                 (Trial -> Condition -> Session -> Subject)
        %                 Prevents pseudoreplication.
        %   'flat'      - Average all observations per subject (one value each)
        %   'none'      - Each observation treated independently
        %
        % Also computes a flat (SubjectID-only) grand average for each group,
        % stored in groups(i).gbyGrandBarFlat, which is used by export
        % functions and LME models.

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:aggregate', ...
                    'Call groupby() before aggregate()');
            end

            if nargin < 2
                mode = obj.settings.avgMode;
            end

            s = obj.settings;
            doResample = s.resampleRate > 0;
            doBaseline = s.useBaseline && ~isempty(s.baseline);

            % Find which hierarchy columns actually exist in the data
            availableVars = obj.dataTable.Properties.VariableNames;
            validHierarchy = intersect(obj.hierarchy, availableVars, 'stable');

            if doResample || doBaseline
                if isfinite(s.taskEnd)
                    fprintf('Preprocessing: resample=%.2fs, baseline=[%.1f, %.1f]s, task=[%.1f, %.1f]s\n', ...
                        s.resampleRate, s.baseline(1), s.baseline(2), s.taskStart, s.taskEnd);
                else
                    fprintf('Preprocessing: resample=%.2fs, baseline=[%.1f, %.1f]s, taskStart=%.1fs\n', ...
                        s.resampleRate, s.baseline(1), s.baseline(2), s.taskStart);
                end
            end
            fprintf('Aggregating %d groups (mode: %s)...\n', length(obj.groups), mode);

            % --- Build reprocessing args if methods are specified ---
            hasMethodSet = ~isempty(s.rawMethod) || ~isempty(s.oxyMethod);
            reprocessArgs = {};
            if hasMethodSet
                if ~isempty(s.rawMethod) && ~isempty(s.oxyMethod)
                    reprocessArgs = {s.rawMethod, s.oxyMethod};
                elseif ~isempty(s.rawMethod)
                    reprocessArgs = {s.rawMethod};
                elseif ~isempty(s.oxyMethod)
                    % Only oxyMethod set: must pass both positional args
                    % to avoid oxyMethod being interpreted as rawMethod.
                    % Look up current rawMethod from the first segment.
                    curRaw = 'None';
                    firstData = obj.groups(1).gbyFNIRS;
                    if ~isempty(firstData) && isfield(firstData{1}, 'processingInfo') ...
                            && isfield(firstData{1}.processingInfo, 'rawMethod')
                        curRaw = firstData{1}.processingInfo.rawMethod;
                    end
                    reprocessArgs = {curRaw, s.oxyMethod};
                end
            end

            for g = 1:length(obj.groups)
                curData  = obj.groups(g).gbyFNIRS;
                curTable = obj.groups(g).gbyTables;

                % Skip empty groups
                if isempty(curData)
                    warning('Group %d (%s) is empty, skipping', g, obj.groups(g).label);
                    continue;
                end

                % --- Reprocess only if methods changed since last aggregate ---
                if hasMethodSet
                    cachedRaw = '';
                    cachedOxy = '';
                    if isfield(obj.groups(g), 'cache') && ~isempty(obj.groups(g).cache)
                        if isfield(obj.groups(g).cache, 'rawMethod')
                            cachedRaw = obj.groups(g).cache.rawMethod;
                        end
                        if isfield(obj.groups(g).cache, 'oxyMethod')
                            cachedOxy = obj.groups(g).cache.oxyMethod;
                        end
                    end

                    methodChanged = ~strcmp(cachedRaw, s.rawMethod) || ...
                                    ~strcmp(cachedOxy, s.oxyMethod);

                    if methodChanged
                        curData = processFNIRS2(curData, reprocessArgs{:});
                        obj.groups(g).gbyFNIRS = curData;  % persist reprocessed data
                        obj.groups(g).cache.rawMethod = s.rawMethod;
                        obj.groups(g).cache.oxyMethod = s.oxyMethod;
                        obj.groups(g).cache.ppKey = '';  % invalidate preprocessing cache
                        fprintf('  [%d] %s: reprocessed %d segments (raw=%s, oxy=%s)\n', ...
                            g, obj.groups(g).label, length(curData), s.rawMethod, s.oxyMethod);
                    end
                end

                % --- Stage A: Preprocessing (cached) ---
                ppKey = buildPPKey(s);
                hasCachedPP = isfield(obj.groups(g), 'cache') && ...
                              ~isempty(obj.groups(g).cache) && ...
                              isfield(obj.groups(g).cache, 'ppKey') && ...
                              strcmp(obj.groups(g).cache.ppKey, ppKey) && ...
                              ~isempty(obj.groups(g).cache.ppData);

                if hasCachedPP
                    ppData = obj.groups(g).cache.ppData;
                    barData = obj.groups(g).cache.barData;
                    fprintf('  [%d] %s: using cached preprocessing\n', g, obj.groups(g).label);
                else
                    [ppData, barData] = preprocessGroup(curData, s, doResample, doBaseline);
                    obj.groups(g).cache.ppData = ppData;
                    obj.groups(g).cache.barData = barData;
                    obj.groups(g).cache.ppKey = ppKey;
                end

                % --- Stage B: Grand averaging (always re-run) ---
                hVars = buildHierarchyVars(curTable, validHierarchy, mode);

                % Temporal resolution grand average
                obj.groups(g).gbyGrand = grandAvgFNIRS( ...
                    ppData, false, [], false, hVars, false, true);

                % Flat grand average for export/LME (bar chart resolution)
                flatH = buildHierarchyVars(curTable, validHierarchy, 'flat');
                barBin = computeBarBin(s, curData);
                obj.groups(g).gbyGrandBarFlat = grandAvgFNIRS( ...
                    barData, false, barBin, false, flatH, false, true);

                % Store preprocessed segments for potential direct access
                obj.groups(g).gbyFNIRS_pp = ppData;

                if ~hasCachedPP
                    fprintf('  [%d] %s: %d segments -> grand average\n', ...
                        g, obj.groups(g).label, length(curData));
                else
                    fprintf('  [%d] %s: re-averaged (%s mode)\n', ...
                        g, obj.groups(g).label, mode);
                end
            end

            obj.isAggregated = true;
            fprintf('Done.\n');
        end


        function T = toLongTable(obj, bioMarkers, channels, times, varargin)
        % TOLONGTABLE Export grouped data to long format table
        %
        %   T = ex.toLongTable()
        %   T = ex.toLongTable({'HbO','HbR'})
        %   T = ex.toLongTable({'HbO'}, 1:10, [0 5 10])
        %   T = ex.toLongTable({'HbO'}, 1:5, [], 'IncludeAux', true)
        %   T = ex.toLongTable({'HbO'}, [], [], 'IncludeROI', true)
        %
        % Name-Value Parameters:
        %   IncludeAux - Include auxiliary data columns (default: false)
        %   IncludeROI - Include ROI-averaged data columns (default: false)
        %
        % See also: mergeGbyTablesLong

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:toLongTable', ...
                    'Call aggregate() before exporting');
            end
            if nargin < 2, bioMarkers = {'HbO','HbR','HbDiff','HbTotal','CBSI'}; end
            if nargin < 3, channels = []; end
            if nargin < 4, times = []; end

            ip = inputParser;
            addParameter(ip, 'IncludeAux', false, @islogical);
            addParameter(ip, 'IncludeROI', false, @islogical);
            parse(ip, varargin{:});

            % Build channel labels as cell array
            if ~isempty(channels)
                chLabels = cellstr(num2str(channels(:)));
            else
                chLabels = {};
            end

            T = exploreFNIRS.export.mergeGbyTablesLong( ...
                obj.groups, bioMarkers, channels, times, ...
                ip.Results.IncludeAux, ip.Results.IncludeROI, chLabels);
        end


        function T = toWideTable(obj, bioMarkers, channels, times, varargin)
        % TOWIDETABLE Export grouped data to wide format table
        %
        %   T = ex.toWideTable()
        %   T = ex.toWideTable({'HbO','HbR'})
        %   T = ex.toWideTable({'HbO'}, 1:10, [0 5 10])
        %   T = ex.toWideTable({'HbO'}, 1:5, [], 'IncludeAux', true)
        %   T = ex.toWideTable({'HbO'}, [], [], 'IncludeROI', true)
        %
        % Name-Value Parameters:
        %   IncludeAux - Include auxiliary data columns (default: false)
        %   IncludeROI - Include ROI-averaged data columns (default: false)
        %
        % See also: mergeGbyTablesWide

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:toWideTable', ...
                    'Call aggregate() before exporting');
            end
            if nargin < 2, bioMarkers = {'HbO','HbR','HbDiff','HbTotal','CBSI'}; end
            if nargin < 3, channels = []; end
            if nargin < 4, times = []; end

            ip = inputParser;
            addParameter(ip, 'IncludeAux', false, @islogical);
            addParameter(ip, 'IncludeROI', false, @islogical);
            parse(ip, varargin{:});

            % Build channel labels as cell array
            if ~isempty(channels)
                chLabels = cellstr(num2str(channels(:)));
            else
                chLabels = {};
            end

            T = exploreFNIRS.export.mergeGbyTablesWide( ...
                obj.groups, bioMarkers, channels, times, ...
                ip.Results.IncludeAux, ip.Results.IncludeROI, chLabels);
        end


        function T = writeCSV(obj, filepath, varargin)
        % WRITECSV Export aggregated data to a CSV file
        %
        %   ex.writeCSV('results.csv')
        %   ex.writeCSV('results.csv', 'Biomarkers', {'HbO','HbR'})
        %   ex.writeCSV('results.csv', 'Format', 'wide')
        %   T = ex.writeCSV('results.csv')   % also returns the table
        %
        % Name-Value Parameters:
        %   Format     - 'long' (default) or 'wide'
        %   Biomarkers - Cell array of biomarker names (default: all)
        %   Channels   - Channel indices (default: all)
        %   Times      - Time points (default: all)
        %   IncludeAux - Include auxiliary data (default: false)
        %   IncludeROI - Include ROI-averaged data (default: false)
        %
        % See also: toLongTable, toWideTable

            ip = inputParser;
            addRequired(ip, 'filepath', @ischar);
            addParameter(ip, 'Format', 'long', @ischar);
            addParameter(ip, 'Biomarkers', {'HbO','HbR','HbDiff','HbTotal','CBSI'}, @iscell);
            addParameter(ip, 'Channels', [], @isnumeric);
            addParameter(ip, 'Times', [], @isnumeric);
            addParameter(ip, 'IncludeAux', false, @islogical);
            addParameter(ip, 'IncludeROI', false, @islogical);
            parse(ip, filepath, varargin{:});
            opts = ip.Results;

            if strcmpi(opts.Format, 'wide')
                T = obj.toWideTable(opts.Biomarkers, opts.Channels, opts.Times, ...
                    'IncludeAux', opts.IncludeAux, 'IncludeROI', opts.IncludeROI);
            else
                T = obj.toLongTable(opts.Biomarkers, opts.Channels, opts.Times, ...
                    'IncludeAux', opts.IncludeAux, 'IncludeROI', opts.IncludeROI);
            end

            writetable(T, filepath);
            fprintf('Wrote %d rows x %d columns to %s\n', ...
                height(T), width(T), filepath);
        end


        function fig = plotExperimentTimeline(obj, varargin)
        % PLOTEXPERIMENTTIMELINE Visualize experiment time settings as a diagram
        %
        %   fig = ex.plotExperimentTimeline()
        %   fig = ex.plotExperimentTimeline('SavePath', 'timeline.png')
        %
        % Shows baseline, task block, temporal resample, and bar resample
        % settings. Does not require aggregate(). Useful for verifying
        % configuration before processing.
        %
        % See also: exploreFNIRS.core.plotExperimentTimeline

            % Infer data time range from first selected segment
            selData = obj.data(obj.selectedIdx);
            if ~isempty(selData)
                seg = selData{1};
                dataRange = [min(seg.time), max(seg.time)];
            else
                dataRange = [];
            end
            fig = exploreFNIRS.core.plotExperimentTimeline(obj.settings, ...
                'DataRange', dataRange, varargin{:});
        end


        function fig = plotTemporal(obj, varargin)
        % PLOTTEMPORAL Headless temporal (time-series) plot
        %
        %   fig = ex.plotTemporal()
        %   fig = ex.plotTemporal('Biomarkers', {'HbO'}, 'Channels', 1:5)
        %   ex.plotTemporal('SavePath', 'temporal.png')
        %
        % All name-value arguments are forwarded to
        % exploreFNIRS.core.plotTemporal. See help for that function.
        %
        % See also: exploreFNIRS.core.plotTemporal

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotTemporal', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotTemporal(obj.groups, varargin{:});
        end


        function fig = plotBar(obj, varargin)
        % PLOTBAR Headless bar chart plot
        %
        %   fig = ex.plotBar()
        %   fig = ex.plotBar('Biomarker', 'HbO', 'Channels', 1:5)
        %   ex.plotBar('TimeWindow', [5, 20], 'SavePath', 'bar.png')
        %
        % All name-value arguments are forwarded to
        % exploreFNIRS.core.plotBar. See help for that function.
        %
        % See also: exploreFNIRS.core.plotBar

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotBar', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotBar(obj.groups, ...
                'GroupByVars', obj.groupByVars, varargin{:});
        end


        function fig = plotAux(obj, auxField, varargin)
        % PLOTAUX Plot auxiliary signal timeseries by group
        %
        %   fig = ex.plotAux('accelerometer')
        %   fig = ex.plotAux('heartRate', 'AuxChannels', 1)
        %   fig = ex.plotAux('accelerometer', 'Layout', 'grid', 'SavePath', 'accel.png')
        %
        % Plots multichannel auxiliary data (accelerometer, heart rate,
        % respiration, etc.) as time-series with error bands per group.
        % Requires aggregate() to have been called first.
        %
        % Use ex.auxFields() to see available Aux fields.
        %
        % See also: exploreFNIRS.core.plotAux, auxFields

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotAux', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotAux(obj.groups, auxField, varargin{:});
        end


        function fig = plotAuxBar(obj, auxField, varargin)
        % PLOTAUXBAR Bar chart for auxiliary signal data by group
        %
        %   fig = ex.plotAuxBar('heartRate')
        %   fig = ex.plotAuxBar('accelerometer', 'TimeWindow', [5, 20])
        %   fig = ex.plotAuxBar('heartRate', 'ShowIndividual', true, 'SavePath', 'hr.png')
        %
        % Plots mean auxiliary variable values per group as bar charts.
        % Each aux channel gets its own subplot. Requires aggregate() first.
        %
        % Use ex.auxFields() to see available Aux fields.
        %
        % See also: exploreFNIRS.core.plotAuxBar, plotAux, auxFields

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotAuxBar', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotAuxBar(obj.groups, auxField, ...
                'GroupByVars', obj.groupByVars, varargin{:});
        end


        function [fig, stats] = plotAuxScatter(obj, auxField, infoVar, varargin)
        % PLOTAUXSCATTER Scatter plot correlating info variable vs auxiliary data
        %
        %   [fig, stats] = ex.plotAuxScatter('heartRate', 'Age')
        %   [fig, stats] = ex.plotAuxScatter('heartRate', 'reactionTime', ...
        %       'AuxChannels', 1, 'FitLine', true)
        %
        % Correlates an info/behavioral variable (X) with auxiliary signal
        % channel data (Y). Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotAuxScatter, plotAuxBar, auxFields

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotAuxScatter', ...
                    'Call aggregate() before plotAuxScatter()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, stats] = exploreFNIRS.core.plotAuxScatter(obj.groups, ...
                auxField, 'InfoVar', infoVar, varargin{:});
        end


        function flds = auxFields(obj)
        % AUXFIELDS List available auxiliary data fields after aggregation
        %
        %   flds = ex.auxFields()
        %
        % Returns a cell array of Aux field names from the first group's
        % grand average. These names can be passed to plotAux().

            if ~obj.isAggregated || isempty(obj.groups)
                flds = {};
                fprintf('No aggregated data. Call aggregate() first.\n');
                return;
            end

            ga = obj.groups(1).gbyGrand;
            if ~isfield(ga, 'Aux') || ~isstruct(ga.Aux)
                flds = {};
                fprintf('No Aux data in aggregated results.\n');
                return;
            end

            % Get clean field names (handles flattened _data/_time/_unit suffixes)
            allFlds = fieldnames(ga.Aux);
            allFlds = allFlds(~ismember(allFlds, {'flattened'}));

            % Deduplicate: strip _data/_time/_unit, keep only fields with .Mean
            baseNames = {};
            for i = 1:length(allFlds)
                f = allFlds{i};
                base = regexprep(f, '_(data|time|unit)$', '');
                if ~ismember(base, baseNames)
                    % Check if this or _data version has .Mean
                    resolved = f;
                    if isfield(ga.Aux, [base '_data'])
                        resolved = [base '_data'];
                    end
                    if isstruct(ga.Aux.(resolved)) && isfield(ga.Aux.(resolved), 'Mean')
                        baseNames{end+1} = base; %#ok<AGROW>
                    end
                end
            end
            flds = unique(baseNames, 'stable');

            if nargout == 0
                % Print to console
                fprintf('Available Aux fields:\n');
                for i = 1:length(flds)
                    % Resolve to actual field name
                    if isfield(ga.Aux, flds{i})
                        actualField = flds{i};
                    elseif isfield(ga.Aux, [flds{i} '_data'])
                        actualField = [flds{i} '_data'];
                    else
                        continue;
                    end
                    auxData = ga.Aux.(actualField);
                    if isfield(auxData, 'Mean')
                        nCh = size(auxData.Mean, 2);
                        unitStr = '';
                        if isfield(auxData, 'unit')
                            unitStr = sprintf(' (%s)', auxData.unit);
                        end
                        nameStr = '';
                        if isfield(auxData, 'varNames') && ~isempty(auxData.varNames)
                            nameStr = sprintf(' [%s]', strjoin(auxData.varNames, ', '));
                        end
                        fprintf('  %s: %d channels%s%s\n', flds{i}, nCh, unitStr, nameStr);
                    else
                        fprintf('  %s\n', flds{i});
                    end
                end
                clear flds;
            end
        end


        function fig = plotInfoBar(obj, varName, varargin)
        % PLOTINFOBAR Plot a numeric info variable grouped by current groupby
        %
        %   fig = ex.plotInfoBar('reactionTime')
        %   fig = ex.plotInfoBar('accuracy', 'ErrorType', 'SD')
        %   fig = ex.plotInfoBar('Age', 'SavePath', 'age_by_group.png')
        %
        % Plots a bar chart of any numeric variable from the metadata table,
        % grouped by the current groupby variables. Does NOT require
        % aggregate() - works directly from the dataTable.
        %
        % Requires groupby() to have been called first.
        %
        % Name-Value Parameters:
        %   ErrorType      - 'SEM' (default), 'SD', or 'none'
        %   ShowIndividual - Show individual data points (default: true)
        %   Title          - Figure title (default: auto)
        %   YLabel         - Y-axis label (default: varName)
        %   Visible        - 'on' (default) or 'off'
        %   SavePath       - File path to save figure
        %   SaveWidth      - Width in pixels (default: 600)
        %   SaveHeight     - Height in pixels (default: 400)
        %   SaveDPI        - Resolution (default: 150)
        %
        % See also: plotBar, plotTemporal

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:plotInfoBar', ...
                    'Call groupby() before plotInfoBar()');
            end

            p = inputParser;
            addRequired(p, 'varName', @ischar);
            addParameter(p, 'ErrorType', 'SEM', @ischar);
            addParameter(p, 'ShowIndividual', true, @islogical);
            addParameter(p, 'Title', '', @ischar);
            addParameter(p, 'YLabel', '', @ischar);
            addParameter(p, 'Visible', 'on', @ischar);
            addParameter(p, 'SavePath', '', @ischar);
            addParameter(p, 'SaveWidth', 600, @isnumeric);
            addParameter(p, 'SaveHeight', 400, @isnumeric);
            addParameter(p, 'SaveDPI', 150, @isnumeric);
            addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
            addParameter(p, 'ColorScheme', [], @(x) isempty(x) || ischar(x) || isstring(x) || isa(x, 'exploreFNIRS.core.ColorScheme'));
            parse(p, varName, varargin{:});
            opts = p.Results;

            % Resolve named ColorScheme
            if ~isempty(opts.ColorScheme)
                csVal = opts.ColorScheme;
                if ischar(csVal) || isstring(csVal)
                    name = char(csVal);
                    if ~isfield(obj.colorSchemes, name)
                        error('exploreFNIRS:core:Experiment:plotInfoBar', ...
                            'Unknown color scheme: "%s". Available: %s', ...
                            name, strjoin(fieldnames(obj.colorSchemes), ', '));
                    end
                    csVal = obj.colorSchemes.(name);
                end
                if isempty(opts.Colors)
                    opts.Colors = csVal;
                end
            end

            % Auto-inject colorScheme if not explicitly set
            if isempty(opts.Colors) && ~isempty(obj.colorScheme)
                opts.Colors = obj.colorScheme;
            end

            if ~isempty(opts.SavePath)
                opts.Visible = 'off';
            end

            % Validate variable exists and is numeric
            selTable = obj.getSelectedTable();
            if ~ismember(varName, selTable.Properties.VariableNames)
                error('exploreFNIRS:core:Experiment:plotInfoBar', ...
                    'Variable "%s" not found. Available: %s', ...
                    varName, strjoin(selTable.Properties.VariableNames, ', '));
            end

            testCol = selTable.(varName);
            if ~isnumeric(testCol)
                error('exploreFNIRS:core:Experiment:plotInfoBar', ...
                    'Variable "%s" must be numeric (got %s)', varName, class(testCol));
            end

            nGroups = length(obj.groups);
            groupMeans = nan(1, nGroups);
            groupErrors = nan(1, nGroups);
            groupN = nan(1, nGroups);
            groupLabels = cell(1, nGroups);
            individualData = cell(1, nGroups);

            for g = 1:nGroups
                vals = obj.groups(g).gbyTables.(varName);
                vals = vals(~isnan(vals));
                individualData{g} = vals;
                groupN(g) = length(vals);
                groupMeans(g) = mean(vals, 'omitnan');
                groupLabels{g} = obj.groups(g).label;

                switch upper(opts.ErrorType)
                    case 'SEM'
                        groupErrors(g) = std(vals, 'omitnan') / sqrt(groupN(g));
                    case 'SD'
                        groupErrors(g) = std(vals, 'omitnan');
                    case 'NONE'
                        groupErrors(g) = 0;
                end
            end

            % Colors
            if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                colors = opts.Colors.resolve(obj.groups);
            else
                colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
            end

            fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
                'Width', opts.SaveWidth, 'Height', opts.SaveHeight, ...
                'SavePath', opts.SavePath);
            sty = pf2_base.plot.PlotStyle.getDefault();
            ax = axes('Parent', fig);
            hold(ax, 'on');

            % Build barweb inputs
            meanMatrix = groupMeans(:);   % [nGroups x 1]
            if strcmpi(opts.ErrorType, 'none')
                errInput = [];
            else
                errInput = groupErrors(:);
            end

            if ~isempty(opts.YLabel)
                ylabelStr = opts.YLabel;
            else
                ylabelStr = varName;
            end

            barwebArgs = {'Axes', ax, ...
                'ColorMap', colors(1,:), ...
                'YLabel', ylabelStr};

            if opts.ShowIndividual
                indivData = cell(nGroups, 1);
                for g = 1:nGroups
                    indivData{g, 1} = individualData{g};
                end
                barwebArgs = [barwebArgs, {'DataPoints', indivData}];
            end

            bwHandles = pf2_base.external.barweb(meanMatrix, errInput, ...
                1, groupLabels, barwebArgs{:});
            hold(ax, 'on');

            % Color each bar individually
            if ~isempty(bwHandles.bars)
                bwHandles.bars(1).FaceColor = 'flat';
                bwHandles.bars(1).CData = colors(1:nGroups, :);
            end

            % Add x-axis margin so bars don't touch the edges
            xlim(ax, [0.25, nGroups + 0.75]);

            % Legend identifies bars — replace tick labels with xlabel
            set(ax, 'XTickLabel', {});
            xlabel(ax, strjoin(obj.groupByVars, ' x '));

            % Legend with colored patches
            lh = gobjects(nGroups, 1);
            for g = 1:nGroups
                lh(g) = patch(ax, NaN, NaN, colors(g,:), ...
                    'EdgeColor', 'k', 'LineWidth', 2);
            end
            lg = legend(ax, lh, groupLabels, 'Location', 'best');
            lg.TextColor = 'k';
            lg.Color = 'w';
            lg.EdgeColor = [0.5 0.5 0.5];

            % N labels
            for g = 1:nGroups
                if ~isnan(groupN(g))
                    yPos = groupMeans(g) + groupErrors(g);
                    if isnan(yPos), yPos = groupMeans(g); end
                    text(ax, g, yPos, sprintf('n=%d', groupN(g)), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end

            if ~isempty(opts.Title)
                title(ax, opts.Title);
            else
                title(ax, sprintf('%s by %s', varName, strjoin(obj.groupByVars, ', ')));
            end

            box(ax, 'on');
            grid(ax, 'on');

            sty.applyToFigure(fig);
            pf2_base.plot.handleSave(fig, opts);
        end


        function fig = plotInfoScatter(obj, xVar, yVar, varargin)
        % PLOTINFOSCATTER Scatter plot of two info variables, colored by group
        %
        %   fig = ex.plotInfoScatter('Age', 'reactionTime')
        %   fig = ex.plotInfoScatter('taskLoad', 'accuracy', 'FitLine', true)
        %
        % Plots xVar vs yVar from the metadata table. If groupby() has been
        % called, points are colored by group. Does NOT require aggregate().
        %
        % Name-Value Parameters:
        %   FitLine    - Add linear fit per group (default: false)
        %   Title      - Figure title (default: auto)
        %   XLabel     - X-axis label (default: xVar)
        %   YLabel     - Y-axis label (default: yVar)
        %   MarkerSize - Point size (default: 40)
        %   Visible    - 'on' (default) or 'off'
        %   SavePath   - File path to save figure
        %   SaveWidth  - Width in pixels (default: 600)
        %   SaveHeight - Height in pixels (default: 400)
        %   SaveDPI    - Resolution (default: 150)
        %
        % See also: plotInfoBar, plotBar

            p = inputParser;
            addRequired(p, 'xVar', @ischar);
            addRequired(p, 'yVar', @ischar);
            addParameter(p, 'FitLine', false, @islogical);
            addParameter(p, 'ErrorBand', false, @islogical);
            addParameter(p, 'Title', '', @ischar);
            addParameter(p, 'XLabel', '', @ischar);
            addParameter(p, 'YLabel', '', @ischar);
            addParameter(p, 'MarkerSize', 40, @isnumeric);
            addParameter(p, 'Visible', 'on', @ischar);
            addParameter(p, 'SavePath', '', @ischar);
            addParameter(p, 'SaveWidth', 600, @isnumeric);
            addParameter(p, 'SaveHeight', 400, @isnumeric);
            addParameter(p, 'SaveDPI', 150, @isnumeric);
            addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || isa(x, 'function_handle') || isa(x, 'exploreFNIRS.core.ColorScheme'));
            addParameter(p, 'ColorScheme', [], @(x) isempty(x) || ischar(x) || isstring(x) || isa(x, 'exploreFNIRS.core.ColorScheme'));
            parse(p, xVar, yVar, varargin{:});
            opts = p.Results;

            % Resolve named ColorScheme
            if ~isempty(opts.ColorScheme)
                csVal = opts.ColorScheme;
                if ischar(csVal) || isstring(csVal)
                    name = char(csVal);
                    if ~isfield(obj.colorSchemes, name)
                        error('exploreFNIRS:core:Experiment:plotInfoScatter', ...
                            'Unknown color scheme: "%s". Available: %s', ...
                            name, strjoin(fieldnames(obj.colorSchemes), ', '));
                    end
                    csVal = obj.colorSchemes.(name);
                end
                if isempty(opts.Colors)
                    opts.Colors = csVal;
                end
            end

            % Auto-inject colorScheme if not explicitly set
            if isempty(opts.Colors) && ~isempty(obj.colorScheme)
                opts.Colors = obj.colorScheme;
            end

            if ~isempty(opts.SavePath)
                opts.Visible = 'off';
            end

            selTable = obj.getSelectedTable();

            % Validate variables
            for v = {xVar, yVar}
                vn = v{1};
                if ~ismember(vn, selTable.Properties.VariableNames)
                    error('exploreFNIRS:core:Experiment:plotInfoScatter', ...
                        'Variable "%s" not found. Available: %s', ...
                        vn, strjoin(selTable.Properties.VariableNames, ', '));
                end
                if ~isnumeric(selTable.(vn))
                    error('exploreFNIRS:core:Experiment:plotInfoScatter', ...
                        'Variable "%s" must be numeric (got %s)', vn, class(selTable.(vn)));
                end
            end

            xData = selTable.(xVar);
            yData = selTable.(yVar);

            fig = figure('Visible', opts.Visible, ...
                'Position', [100, 100, opts.SaveWidth, opts.SaveHeight], ...
                'Color', 'w');
            ax = axes('Parent', fig);
            hold(ax, 'on');

            if obj.isGrouped && ~isempty(obj.groups)
                nGroups = length(obj.groups);
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    colors = opts.Colors.resolve(obj.groups);
                else
                    colors = exploreFNIRS.core.getGroupColors(nGroups, opts.Colors);
                end

                legendHandles = gobjects(nGroups, 1);
                legendLabels = cell(nGroups, 1);

                for g = 1:nGroups
                    gTable = obj.groups(g).gbyTables;
                    gx = gTable.(xVar);
                    gy = gTable.(yVar);
                    valid = ~isnan(gx) & ~isnan(gy);
                    gx = gx(valid);
                    gy = gy(valid);

                    legendHandles(g) = scatter(ax, gx, gy, opts.MarkerSize, ...
                        colors(g,:), 'filled', 'MarkerFaceAlpha', 0.7);
                    legendLabels{g} = sprintf('%s (n=%d)', obj.groups(g).label, sum(valid));

                    if opts.FitLine && sum(valid) >= 2
                        coeffs = polyfit(gx, gy, 1);
                        xFit = linspace(min(gx), max(gx), 50);
                        yFit = polyval(coeffs, xFit);
                        plot(ax, xFit, yFit, '-', 'Color', colors(g,:), ...
                            'LineWidth', 1.5, 'HandleVisibility', 'off');

                        if opts.ErrorBand && sum(valid) >= 3
                            yResid = gy - polyval(coeffs, gx);
                            se = std(yResid) * sqrt(1/sum(valid) + ...
                                (xFit - mean(gx)).^2 / sum((gx - mean(gx)).^2));
                            fill(ax, [xFit, fliplr(xFit)], ...
                                [yFit + 1.96*se, fliplr(yFit - 1.96*se)], ...
                                colors(g,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                                'HandleVisibility', 'off');
                        end
                    end
                end

                lg = legend(ax, legendHandles, legendLabels, 'Location', 'best');
                lg.TextColor = 'k';
                lg.Color = 'w';
                lg.EdgeColor = [0.5 0.5 0.5];
            else
                % No grouping - single color
                if isa(opts.Colors, 'exploreFNIRS.core.ColorScheme')
                    singleColor = exploreFNIRS.core.getGroupColors(1);
                else
                    singleColor = exploreFNIRS.core.getGroupColors(1, opts.Colors);
                end
                valid = ~isnan(xData) & ~isnan(yData);
                scatter(ax, xData(valid), yData(valid), opts.MarkerSize, ...
                    singleColor, 'filled', 'MarkerFaceAlpha', 0.7);

                if opts.FitLine && sum(valid) >= 2
                    xv = xData(valid);
                    yv = yData(valid);
                    coeffs = polyfit(xv, yv, 1);
                    xFit = linspace(min(xv), max(xv), 50);
                    yFit = polyval(coeffs, xFit);
                    plot(ax, xFit, yFit, '-', 'Color', singleColor, ...
                        'LineWidth', 1.5, 'HandleVisibility', 'off');

                    if opts.ErrorBand && sum(valid) >= 3
                        yResid = yv - polyval(coeffs, xv);
                        se = std(yResid) * sqrt(1/sum(valid) + ...
                            (xFit - mean(xv)).^2 / sum((xv - mean(xv)).^2));
                        fill(ax, [xFit, fliplr(xFit)], ...
                            [yFit + 1.96*se, fliplr(yFit - 1.96*se)], ...
                            singleColor, 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                            'HandleVisibility', 'off');
                    end
                end
            end

            if ~isempty(opts.XLabel), xlabel(ax, opts.XLabel);
            else, xlabel(ax, xVar); end
            if ~isempty(opts.YLabel), ylabel(ax, opts.YLabel);
            else, ylabel(ax, yVar); end

            if ~isempty(opts.Title)
                title(ax, opts.Title);
            else
                title(ax, sprintf('%s vs %s', yVar, xVar));
            end

            box(ax, 'on');
            grid(ax, 'on');

            if ~isempty(opts.SavePath)
                if ~isempty(which('pf2_base.plot.saveFigure'))
                    pf2_base.plot.saveFigure(fig, opts.SavePath, ...
                        opts.SaveWidth, opts.SaveHeight, opts.SaveDPI);
                else
                    set(fig, 'PaperPositionMode', 'auto');
                    print(fig, opts.SavePath, '-dpng', sprintf('-r%d', opts.SaveDPI));
                end
                fprintf('Saved: %s\n', opts.SavePath);
            end
        end


        function [fig, stats] = plotScatter(obj, infoVar, varargin)
        % PLOTSCATTER Scatter plot correlating info variable vs fNIRS biomarker
        %
        %   [fig, stats] = ex.plotScatter('reactionTime')
        %   [fig, stats] = ex.plotScatter('Age', 'Biomarkers', {'HbO'}, ...
        %       'Channels', 5, 'FitLine', true)
        %   [fig, stats] = ex.plotScatter('Age', 'PlotTopo', true)
        %
        % Correlates an info/behavioral variable (X) with fNIRS biomarker
        % channel data (Y). Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotScatter

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotScatter', ...
                    'Call aggregate() before plotScatter()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, stats] = exploreFNIRS.core.plotScatter(obj.groups, ...
                'InfoVar', infoVar, varargin{:});
        end


        function [fig, results] = plotLME(obj, varargin)
        % PLOTLME Linear Mixed Effects analysis with bar chart and topo
        %
        %   [fig, results] = ex.plotLME()
        %   [fig, results] = ex.plotLME('Biomarkers', {'HbO'}, 'Channels', 1:5)
        %   [fig, results] = ex.plotLME('ShowTopo', true)
        %
        % Fits LME models per channel using the current groupby variables
        % as fixed effects. Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotLME', ...
                    'Call aggregate() before plotLME()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, results] = exploreFNIRS.core.plotLME(obj.groups, ...
                obj.groupByVars, varargin{:});
        end


        function [fig, results] = plotAuxLME(obj, auxField, varargin)
        % PLOTAUXLME LME analysis with bar chart for auxiliary data
        %
        %   [fig, results] = ex.plotAuxLME('heartRate')
        %   [fig, results] = ex.plotAuxLME('accelerometer', 'Channels', 1:2)
        %
        % Convenience wrapper for plotLME with DataType='Aux'.
        % Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotLME, statsAuxLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotAuxLME', ...
                    'Call aggregate() before plotAuxLME()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, results] = exploreFNIRS.core.plotLME(obj.groups, ...
                obj.groupByVars, 'DataType', 'Aux', 'AuxField', auxField, ...
                varargin{:});
        end


        function [fig, results] = plotInfoLME(obj, infoVar, varargin)
        % PLOTINFOLME LME analysis with bar chart for info/behavioral variables
        %
        %   [fig, results] = ex.plotInfoLME('reactionTime')
        %   [fig, results] = ex.plotInfoLME('accuracy', 'AllInteractions', true)
        %
        % Fits a single LME model for the specified info variable and
        % renders a bar chart of F-statistics per ANOVA term.
        % Requires groupby() first (does NOT require aggregate).
        %
        % See also: exploreFNIRS.core.plotInfoLME, statsInfoLME

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:plotInfoLME', ...
                    'Call groupby() before plotInfoLME()');
            end
            selTable = obj.getSelectedTable();
            varargin = obj.injectColorScheme(varargin);
            [fig, results] = exploreFNIRS.core.plotInfoLME(selTable, ...
                infoVar, obj.groupByVars, varargin{:});
        end


        function [fig, results] = plotTopoLME(obj, varargin)
        % PLOTTOPOLME 3D brain topo of LME ANOVA F-statistics
        %
        %   [fig, results] = ex.plotTopoLME()
        %   [fig, results] = ex.plotTopoLME('SigType', 'q', 'Biomarkers', {'HbO'})
        %
        % Renders significant F-statistics from LME ANOVA onto the 3D
        % brain surface. One subplot per term; non-significant channels
        % are NaN-masked. Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotTopoLME, plotLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotTopoLME', ...
                    'Call aggregate() before plotTopoLME()');
            end
            [fig, results] = exploreFNIRS.core.plotTopoLME(obj.groups, ...
                obj.groupByVars, varargin{:});
        end


        function [fig, results] = plotTopoROILME(obj, varargin)
        % PLOTTOPOROILME 3D brain topo of ROI-level LME F-statistics
        %
        %   [fig, results] = ex.plotTopoROILME()
        %   [fig, results] = ex.plotTopoROILME('Biomarkers', {'HbO'})
        %
        % Convenience wrapper for plotTopoLME with DataType='ROI'.
        % Broadcasts each ROI's F-statistic to all its constituent
        % channels for 3D visualization. Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotTopoLME, plotLME, statsROILME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotTopoROILME', ...
                    'Call aggregate() before plotTopoROILME()');
            end
            varargin = obj.injectColorScheme(varargin);
            [fig, results] = exploreFNIRS.core.plotTopoLME(obj.groups, ...
                obj.groupByVars, 'DataType', 'ROI', varargin{:});
        end


        function results = statsFitLME(obj, varargin)
        % STATSFITLME Fit LME models (statistics only, no visualization)
        %
        %   results = ex.statsFitLME()
        %   results = ex.statsFitLME('Biomarkers', {'HbO'}, 'Channels', 1:5)
        %
        % Fits LME models per channel using the current groupby variables
        % as fixed effects. Returns statistical results without any plots.
        % Requires aggregate() first.
        %
        % For combined analysis + visualization, use plotLME() instead.
        %
        % See also: exploreFNIRS.stats.fitLME, plotLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:statsFitLME', ...
                    'Call aggregate() before statsFitLME()');
            end
            results = exploreFNIRS.stats.fitLME(obj.groups, ...
                obj.groupByVars, varargin{:});
        end


        function results = statsInfoLME(obj, infoVar, varargin)
        % STATSINFOLME Fit LME model for an info/behavioral variable
        %
        %   results = ex.statsInfoLME('reactionTime')
        %   results = ex.statsInfoLME('accuracy', 'AllInteractions', true)
        %
        % Fits a single LME model using the specified info variable as the
        % response and the current groupby variables as fixed effects.
        % Does NOT require aggregate() - works directly from the dataTable.
        % Requires groupby() first.
        %
        % Results are compatible with statsRunContrasts() and statsSummarize().
        %
        % See also: exploreFNIRS.stats.fitInfoLME, statsFitLME

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:statsInfoLME', ...
                    'Call groupby() before statsInfoLME()');
            end
            selTable = obj.getSelectedTable();
            results = exploreFNIRS.stats.fitInfoLME(selTable, infoVar, ...
                obj.groupByVars, varargin{:});
        end


        function results = statsAuxLME(obj, auxField, varargin)
        % STATSAUXLME Fit LME models for auxiliary data channels
        %
        %   results = ex.statsAuxLME('heartRate')
        %   results = ex.statsAuxLME('accelerometer', 'Channels', 1:2)
        %
        % Convenience wrapper for statsFitLME with DataType='Aux'.
        % Fits LME models per aux channel using the current groupby
        % variables as fixed effects. Requires aggregate() first.
        %
        % Results are compatible with statsRunContrasts() and statsSummarize().
        %
        % See also: exploreFNIRS.stats.fitLME, statsFitLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:statsAuxLME', ...
                    'Call aggregate() before statsAuxLME()');
            end
            results = exploreFNIRS.stats.fitLME(obj.groups, ...
                obj.groupByVars, 'DataType', 'Aux', 'AuxField', auxField, ...
                varargin{:});
        end


        function results = statsROILME(obj, varargin)
        % STATSROILME Fit LME models for ROI-level data
        %
        %   results = ex.statsROILME()
        %   results = ex.statsROILME('Biomarkers', {'HbO'}, 'Channels', 1:3)
        %
        % Convenience wrapper for statsFitLME with DataType='ROI'.
        % Fits LME models per ROI using the current groupby variables
        % as fixed effects. Requires aggregate() first. Use 'Channels'
        % to select specific ROI indices.
        %
        % See also: exploreFNIRS.stats.fitLME, statsFitLME

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:statsROILME', ...
                    'Call aggregate() before statsROILME()');
            end
            results = exploreFNIRS.stats.fitLME(obj.groups, ...
                obj.groupByVars, 'DataType', 'ROI', varargin{:});
        end


        function contrastResults = statsRunContrasts(obj, lmeResults, varargin)
        % STATSRUNCONTRASTS Post-hoc contrasts with FDR correction
        %
        %   results = ex.statsFitLME('Biomarkers', {'HbO'});
        %   cr = ex.statsRunContrasts(results);
        %   cr = ex.statsRunContrasts(results, 'FDRThreshold', 0.01)
        %
        % Takes output from statsFitLME and runs post-hoc contrasts per
        % channel, then applies FDR correction across channels.
        %
        % See also: exploreFNIRS.stats.runContrasts, statsFitLME

            contrastResults = exploreFNIRS.stats.runContrasts( ...
                lmeResults, varargin{:});
        end


        function T = statsSummarize(obj, lmeResults, varargin) %#ok<INUSL>
        % STATSSUMMARIZE Publication-ready summary table from LME results
        %
        %   results = ex.statsFitLME('Biomarkers', {'HbO'});
        %   T = ex.statsSummarize(results)
        %   T = ex.statsSummarize(results, 'Type', 'anova', 'Format', 'apa')
        %   T = ex.statsSummarize(results, 'Type', 'contrasts')
        %   T = ex.statsSummarize(results, 'Type', 'fit')
        %
        % Formats LME results into publication-ready tables.
        %
        % See also: exploreFNIRS.stats.summarize, statsFitLME

            T = exploreFNIRS.stats.summarize(lmeResults, varargin{:});
        end


        function T = infoTable(obj)
        % INFOTABLE Return the selected metadata as a plain table
        %
        %   T = ex.infoTable()
        %
        % Useful for behavioral analysis, summary statistics, or exporting
        % metadata without running the fNIRS aggregation pipeline.

            T = obj.getSelectedTable();
        end


        function summary(obj)
        % SUMMARY Display experiment overview
        %
        %   ex.summary()

            fprintf('\n=== Experiment Summary ===\n');
            fprintf('Total segments: %d\n', length(obj.data));
            fprintf('Selected: %d\n', sum(obj.selectedIdx));

            % Show available metadata variables
            vars = obj.dataTable.Properties.VariableNames;
            fprintf('Metadata variables: %s\n', strjoin(vars, ', '));

            % Show unique values for key variables
            keyVars = intersect({'SubjectID','Group','Condition','Session'}, vars, 'stable');
            for i = 1:length(keyVars)
                v = keyVars{i};
                vals = unique(obj.dataTable.(v)(obj.selectedIdx));
                if isnumeric(vals)
                    valStr = strjoin(arrayfun(@num2str, vals, 'UniformOutput', false), ', ');
                else
                    valStr = strjoin(string(vals), ', ');
                end
                fprintf('  %s: [%s] (%d unique)\n', v, valStr, length(vals));
            end

            % Show hierarchy
            validH = intersect(obj.hierarchy, vars, 'stable');
            fprintf('Hierarchy: %s\n', strjoin(validH, ' > '));

            % Show preprocessing settings
            s = obj.settings;
            fprintf('Settings:\n');
            fprintf('  Baseline: [%.1f, %.1f]s (enabled: %s)\n', ...
                s.baseline(1), s.baseline(2), mat2str(s.useBaseline));
            fprintf('  Resample: %.2fs bins, task start: %.1fs\n', ...
                s.resampleRate, s.taskStart);

            % Show grouping state
            if obj.isGrouped
                fprintf('Grouped by: %s (%d groups)\n', ...
                    strjoin(obj.groupByVars, ', '), length(obj.groups));
                for g = 1:length(obj.groups)
                    nSeg = size(obj.groups(g).gbyTables, 1);
                    aggStr = '';
                    if obj.isAggregated && ~isempty(obj.groups(g).gbyGrand)
                        nObs = size(obj.groups(g).gbyGrand.HbO.data, 3);
                        aggStr = sprintf(' -> %d observations after averaging', nObs);
                    end
                    fprintf('  [%d] %s: %d segments%s\n', ...
                        g, obj.groups(g).label, nSeg, aggStr);
                end
            else
                fprintf('Not grouped (call groupby() to define groups)\n');
            end

            if obj.isAggregated
                fprintf('Status: Aggregated\n');
            elseif obj.isGrouped
                fprintf('Status: Grouped (call aggregate() to compute averages)\n');
            else
                fprintf('Status: Ready (call select() and/or groupby())\n');
            end
            fprintf('\n');
        end


        function result = connectivity(obj, varargin)
        % CONNECTIVITY Compute within-subject connectivity matrices per group
        %
        %   result = ex.connectivity()
        %   result = ex.connectivity('Method', 'pearson', 'Biomarker', 'HbO')
        %   result = ex.connectivity('TimeWindow', [5, 25], 'Channels', 1:16)
        %   result = ex.connectivity('Blocks', blocks)
        %   result = ex.connectivity('Align', 'union')
        %
        % For each group, computes a connectivity matrix per subject, then
        % averages across subjects. Requires groupby() first but does NOT
        % require aggregate() (works directly on selected fNIRS data).
        %
        % When 'Blocks' is provided, computes connectivity for each block's
        % time window and returns a struct array with one element per block.
        %
        % Name-Value Parameters:
        %   Method       - 'pearson' (default), 'spearman', 'xcorr', 'coherence', 'wcoherence'
        %   Biomarker    - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
        %   Channels     - Channel indices (default: all good channels)
        %   TimeWindow   - [start, end] seconds (default: full range)
        %   CouplingArgs - Extra args for coupling function (default: {})
        %   UseROI       - Use ROI-level data instead of channels (default: false)
        %   Blocks       - Block definition struct array from pf2.data.defineBlocks
        %                  When provided, computes connectivity per block.
        %   Align        - Channel alignment mode for group aggregation:
        %                  'union' (default) - all channels, NaN where missing
        %                  'intersection' - only channels in all subjects
        %                  numeric 0-1 - channels in >= threshold fraction
        %
        % Outputs (without Blocks):
        %   result - Struct array (one per group) with fields:
        %     .Mean      - [C x C] mean connectivity matrix
        %     .SD        - [C x C] standard deviation
        %     .SEM       - [C x C] standard error
        %     .N         - Number of subjects
        %     .matrices  - {N x 1} cell of individual matrices
        %     .label     - Group label
        %     .method    - Coupling method
        %     .biomarker - Biomarker used
        %     .channels  - Channel indices
        %
        % Outputs (with Blocks):
        %   result - Struct array (one per block) with fields:
        %     .blockNumber - Block index
        %     .startTime   - Block start time
        %     .endTime     - Block end time
        %     .blockInfo   - Block .info struct
        %     .groups      - Per-group struct array (same format as above)
        %
        % See also: exploreFNIRS.connectivity.computeMatrix,
        %   exploreFNIRS.connectivity.plotMatrix, pf2.data.defineBlocks

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:connectivity', ...
                    'Call groupby() before connectivity()');
            end

            % Extract Blocks and Align parameters (not forwarded to computeMatrix)
            [blocks, fwdArgs] = extractBlocksArg(varargin);
            [align, fwdArgs] = extractAlignArg(fwdArgs);

            if isempty(blocks)
                % Standard: compute for full time range
                result = computeConnectivityGroups(obj.groups, fwdArgs, align);
            else
                % Block-wise: compute per block
                nBlocks = length(blocks);
                result = struct([]);
                for b = 1:nBlocks
                    tw = [blocks(b).startTime, blocks(b).endTime];
                    blockArgs = [fwdArgs, 'TimeWindow', tw];

                    result(b).blockNumber = b;
                    result(b).startTime = blocks(b).startTime;
                    result(b).endTime = blocks(b).endTime;
                    result(b).blockInfo = blocks(b).info;
                    result(b).groups = computeConnectivityGroups( ...
                        obj.groups, blockArgs, align);
                end
                fprintf('Computed connectivity for %d blocks across %d groups.\n', ...
                    nBlocks, length(obj.groups));
            end
        end


        function result = hyperscanning(obj, varargin)
        % HYPERSCANNING Inter-brain synchrony analysis across paired subjects
        %
        %   result = ex.hyperscanning()
        %   result = ex.hyperscanning('Method', 'pearson', 'Permutations', 500)
        %   result = ex.hyperscanning('ManualPairs', {{1,2},{3,4}})
        %   result = ex.hyperscanning('Blocks', blocks)
        %
        % Pairs subjects using .info.DyadID metadata, computes cross-brain
        % coupling for each dyad, and aggregates into group statistics.
        % Operates on selected data directly (no aggregate needed).
        %
        % When 'Blocks' is provided, computes hyperscanning for each block's
        % time window and returns a struct array with one element per block.
        %
        % Name-Value Parameters:
        %   Method          - 'pearson' (default), 'spearman', 'xcorr', 'coherence', 'wcoherence'
        %   Biomarker       - 'HbO' (default), 'HbR', 'HbTotal', 'HbDiff', 'CBSI'
        %   ChannelPairing  - 'same' (default) or 'all'
        %   Channels        - Channel indices (default: intersection of good channels)
        %   TimeWindow      - [start, end] seconds
        %   Permutations    - Number of permutations for significance (default: 0, none)
        %   PThreshold      - Significance threshold (default: 0.05)
        %   ManualPairs     - Manual pairing override (see pairSubjects)
        %   DyadField       - Info field for dyad ID (default: 'DyadID')
        %   RoleField       - Info field for role (default: 'Role')
        %   CouplingArgs    - Extra args for coupling function (default: {})
        %   Blocks          - Block definition struct array from pf2.data.defineBlocks
        %                     When provided, computes hyperscanning per block.
        %   Align           - Channel alignment mode for group aggregation:
        %                     'union' (default) - all channels, NaN where missing
        %                     'intersection' - only channels in all subjects
        %                     numeric 0-1 - channels in >= threshold fraction
        %
        % Outputs (without Blocks):
        %   result - Struct with fields from computeGroup, plus:
        %     .pairs       - Pairs struct from pairSubjects
        %     .permutation - Permutation test result (if Permutations > 0)
        %
        % Outputs (with Blocks):
        %   result - Struct array (one per block) with fields:
        %     .blockNumber - Block index
        %     .startTime   - Block start time
        %     .endTime     - Block end time
        %     .blockInfo   - Block .info struct
        %     .coupling    - Hyperscanning result (same format as above)
        %
        % See also: exploreFNIRS.hyperscanning.pairSubjects,
        %   exploreFNIRS.hyperscanning.computeGroup,
        %   exploreFNIRS.hyperscanning.permutationTest, pf2.data.defineBlocks

            ip = inputParser;
            addParameter(ip, 'Method', 'pearson', @ischar);
            addParameter(ip, 'Biomarker', 'HbO', @ischar);
            addParameter(ip, 'ChannelPairing', 'same', @ischar);
            addParameter(ip, 'Channels', [], @isnumeric);
            addParameter(ip, 'TimeWindow', [], @(v) isnumeric(v) && (isempty(v) || length(v) == 2));
            addParameter(ip, 'Permutations', 0, @(v) isnumeric(v) && isscalar(v));
            addParameter(ip, 'PThreshold', 0.05, @isnumeric);
            addParameter(ip, 'ManualPairs', {}, @iscell);
            addParameter(ip, 'DyadField', 'DyadID', @ischar);
            addParameter(ip, 'RoleField', 'Role', @ischar);
            addParameter(ip, 'CouplingArgs', {}, @iscell);
            addParameter(ip, 'UseROI', false, @islogical);
            addParameter(ip, 'Blocks', [], @(x) isempty(x) || isstruct(x));
            addParameter(ip, 'Align', 'union', @(x) (ischar(x) || isstring(x)) || (isnumeric(x) && isscalar(x)));
            parse(ip, varargin{:});
            opts = ip.Results;

            selData = obj.getSelectedData();

            % Pair subjects (same pairs for all blocks)
            pairArgs = {};
            if ~isempty(opts.ManualPairs)
                pairArgs = [pairArgs, 'ManualPairs', {opts.ManualPairs}];
            end
            pairArgs = [pairArgs, 'DyadField', opts.DyadField, 'RoleField', opts.RoleField];

            pairs = exploreFNIRS.hyperscanning.pairSubjects(selData, pairArgs{:});

            if isempty(pairs)
                error('exploreFNIRS:core:Experiment:hyperscanning', ...
                    'No valid pairs found. Check .info.%s or use ManualPairs.', opts.DyadField);
            end

            % Build base args for computeGroup/computeDyad
            groupArgs = {'Method', opts.Method, 'Biomarker', opts.Biomarker, ...
                'ChannelPairing', opts.ChannelPairing};
            if ~isempty(opts.Channels)
                groupArgs = [groupArgs, 'Channels', opts.Channels];
            end
            if ~isempty(opts.CouplingArgs)
                groupArgs = [groupArgs, 'CouplingArgs', {opts.CouplingArgs}];
            end
            if opts.UseROI
                groupArgs = [groupArgs, 'UseROI', true];
            end

            alignMode = opts.Align;

            if isempty(opts.Blocks)
                % Standard: single time window
                coreArgs = groupArgs;
                if ~isempty(opts.TimeWindow)
                    coreArgs = [coreArgs, 'TimeWindow', opts.TimeWindow];
                end
                result = computeHyperscanningCore(selData, pairs, coreArgs, ...
                    opts.Permutations, opts.PThreshold, alignMode);
            else
                % Block-wise: iterate over blocks
                blocks = opts.Blocks;
                nBlocks = length(blocks);
                result = struct([]);
                for b = 1:nBlocks
                    tw = [blocks(b).startTime, blocks(b).endTime];
                    coreArgs = [groupArgs, 'TimeWindow', tw];

                    result(b).blockNumber = b;
                    result(b).startTime = blocks(b).startTime;
                    result(b).endTime = blocks(b).endTime;
                    result(b).blockInfo = blocks(b).info;
                    result(b).coupling = computeHyperscanningCore( ...
                        selData, pairs, coreArgs, ...
                        opts.Permutations, opts.PThreshold, alignMode);
                end
                fprintf('Computed hyperscanning for %d blocks across %d dyads.\n', ...
                    nBlocks, length(pairs));
            end
        end


        function fig = plotTopo(obj, varargin)
        % PLOTTOPO Group-level 2D topographic map
        %
        %   fig = ex.plotTopo()
        %   fig = ex.plotTopo('Biomarker', 'HbO', 'Time', 10)
        %   fig = ex.plotTopo('Layout', 'pergroup', 'SavePath', 'topo.png')
        %
        % See also: exploreFNIRS.core.plotTopo

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotTopo', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotTopo(obj.groups, varargin{:});
        end


        function fig = plotHeatmap(obj, varargin)
        % PLOTHEATMAP Channel x time heatmap
        %
        %   fig = ex.plotHeatmap()
        %   fig = ex.plotHeatmap('Biomarker', 'HbO', 'SortChannels', 'amplitude')
        %   fig = ex.plotHeatmap('SavePath', 'heatmap.png')
        %
        % See also: exploreFNIRS.core.plotHeatmap

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotHeatmap', ...
                    'Call aggregate() before plotting');
            end
            varargin = obj.injectColorScheme(varargin);
            fig = exploreFNIRS.core.plotHeatmap(obj.groups, varargin{:});
        end


        function fig = plotComposite(obj, panels, varargin)
        % PLOTCOMPOSITE Multi-panel publication figure
        %
        %   panels = {struct('type','temporal','args',{{'Biomarkers',{'HbO'}}}), ...
        %             struct('type','bar','args',{{'Biomarker','HbO'}})};
        %   fig = ex.plotComposite(panels, 'Layout', [1,2])
        %
        % See also: exploreFNIRS.core.plotComposite

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotComposite', ...
                    'Call aggregate() before plotting');
            end
            fig = exploreFNIRS.core.plotComposite(obj.groups, panels, varargin{:});
        end


        function result = intraROI(obj, varargin)
        % INTRAROI Within-ROI connectivity analysis per group
        %
        %   result = ex.intraROI()
        %   result = ex.intraROI('Method', 'pearson', 'Biomarker', 'HbO')
        %
        % For each group, computes pairwise coupling between channels within
        % each ROI and summarizes. Requires groupby() and ROI definitions.
        %
        % See also: exploreFNIRS.connectivity.computeIntraROI

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:intraROI', ...
                    'Call groupby() before intraROI()');
            end

            nGroups = length(obj.groups);
            result = struct([]);

            for g = 1:nGroups
                curData = obj.groups(g).gbyFNIRS;
                nSubjects = length(curData);

                fprintf('Group [%d] %s: computing intra-ROI for %d subjects...\n', ...
                    g, obj.groups(g).label, nSubjects);

                subResults = cell(nSubjects, 1);
                for s = 1:nSubjects
                    subResults{s} = exploreFNIRS.connectivity.computeIntraROI( ...
                        curData{s}, varargin{:});
                end

                result(g).subjectResults = subResults;
                result(g).label = obj.groups(g).label;
                result(g).N = nSubjects;

                % Aggregate across subjects
                nROIs = length(subResults{1}.roiMetrics);
                roiMetrics = subResults{1}.roiMetrics;
                for r = 1:nROIs
                    allMean = zeros(nSubjects, 1);
                    for s = 1:nSubjects
                        allMean(s) = subResults{s}.roiMetrics(r).meanCoupling;
                    end
                    roiMetrics(r).groupMean = mean(allMean, 'omitnan');
                    roiMetrics(r).groupSEM = std(allMean, 'omitnan') / sqrt(nSubjects);
                    roiMetrics(r).groupSD = std(allMean, 'omitnan');
                end
                result(g).roiMetrics = roiMetrics;
                result(g).method = subResults{1}.method;
            end
        end


        function result = interROI(obj, varargin)
        % INTERROI Between-ROI connectivity analysis per group
        %
        %   result = ex.interROI()
        %   result = ex.interROI('Method', 'pearson', 'Biomarker', 'HbO')
        %   result = ex.interROI('Align', 'intersection')
        %
        % For each group, computes connectivity between ROI pairs using
        % ROI-level data. Requires groupby() and ROI definitions.
        %
        % Name-Value Parameters:
        %   Align - Channel alignment mode (default: 'union')
        %
        % See also: exploreFNIRS.connectivity.computeMatrix

            if ~obj.isGrouped
                error('exploreFNIRS:core:Experiment:interROI', ...
                    'Call groupby() before interROI()');
            end

            [align, fwdArgs] = extractAlignArg(varargin);
            result = computeConnectivityGroups(obj.groups, ...
                [{'UseROI', true}, fwdArgs], align);
        end

    end

    methods (Hidden)
        % These methods support PlotProxy's transactional state management.
        % They are Hidden so they don't clutter tab-completion, but are
        % accessible from PlotProxy (same package).

        function saveState(obj)
        % SAVESTATE Snapshot lightweight state for later restore
        %
        %   ex.saveState()  % called by PlotProxy before modifying state

            obj.stateSnapshot = struct( ...
                'selectedIdx', obj.selectedIdx, ...
                'groupByVars', {obj.groupByVars}, ...
                'groups', obj.groups, ...
                'isGrouped', obj.isGrouped, ...
                'isAggregated', obj.isAggregated, ...
                'settings', obj.settings);
        end


        function restoreState(obj)
        % RESTORESTATE Restore state from snapshot
        %
        %   ex.restoreState()  % called by PlotProxy after rendering

            if isempty(obj.stateSnapshot), return; end

            s = obj.stateSnapshot;
            obj.selectedIdx = s.selectedIdx;
            obj.groupByVars = s.groupByVars;
            obj.groups = s.groups;
            obj.isGrouped = s.isGrouped;
            obj.isAggregated = s.isAggregated;
            obj.settings = s.settings;
            obj.stateSnapshot = [];
        end


        function narrowSelection(obj, logicalIdx)
        % NARROWSELECTION AND a logical index with current selection
        %
        %   ex.narrowSelection(idx)  % called by PlotProxy for filter

            obj.selectedIdx = obj.selectedIdx & logicalIdx(:);
        end


        function g = getGroups(obj)
        % GETGROUPS Return current groups struct array
            g = obj.groups;
        end


        function tf = getIsAggregated(obj)
        % GETISAGGREGATED Check if experiment is aggregated
            tf = obj.isAggregated;
        end


        function vars = getGroupByVars(obj)
        % GETGROUPBYVARS Return current groupby variable names
            vars = obj.groupByVars;
        end


        function args = injectColorScheme(obj, args)
        % INJECTCOLORSCHEME Auto-inject colorScheme as Colors if not set
        %
        % Priority: explicit 'ColorScheme' param > explicit 'Colors' > default

            keys = args(1:2:end);

            % Check for explicit 'ColorScheme' param
            csIdx = find(strcmpi(keys, 'ColorScheme'), 1);
            if ~isempty(csIdx)
                valIdx = csIdx * 2;
                csVal = args{valIdx};
                % Resolve name to object
                if ischar(csVal) || isstring(csVal)
                    name = char(csVal);
                    if ~isfield(obj.colorSchemes, name)
                        error('exploreFNIRS:core:Experiment:injectColorScheme', ...
                            'Unknown color scheme: "%s". Available: %s', ...
                            name, strjoin(fieldnames(obj.colorSchemes), ', '));
                    end
                    csVal = obj.colorSchemes.(name);
                end
                % Remove 'ColorScheme' pair, inject as 'Colors'
                args([csIdx * 2 - 1, valIdx]) = [];
                % Only inject if no explicit Colors already
                if ~any(strcmpi(args(1:2:end), 'Colors'))
                    args = [args, {'Colors', csVal}];
                end
                return;
            end

            % Fallback: inject default colorScheme if no Colors set
            if isempty(obj.colorScheme), return; end
            if ~any(strcmpi(keys, 'Colors'))
                args = [args, {'Colors', obj.colorScheme}];
            end
        end
    end
end


%% Local helper functions

function [ppData, barData] = preprocessGroup(curData, s, doResample, doBaseline)
% PREPROCESSGROUP Preprocess segments: baseline extraction + resampling
%
% Extracted from aggregate() to enable caching.

if doResample || doBaseline
    ppData = cell(size(curData));
    barData = cell(size(curData));

    % Determine effective task end
    if isfinite(s.taskEnd)
        effectiveTaskEnd = s.taskEnd;
    else
        effectiveTaskEnd = max(curData{1}.time);
    end
    taskDuration = effectiveTaskEnd - s.taskStart;
    if taskDuration <= 0
        taskDuration = max(curData{1}.time) - s.taskStart;
    end

    % Determine bar bin size: 0 = full task window (1 bar)
    barBin = s.barBinSize;
    if barBin <= 0
        barBin = taskDuration;
    end

    for i = 1:length(curData)
        seg = curData{i};

        if doBaseline
            bl = pf2.data.split(seg, s.baseline(1), s.baseline(2));

            if doResample
                ppData{i} = pf2.data.resample(seg, s.resampleRate, ...
                    'centerOnTime', s.taskStart, ...
                    'timeOutMode', 'start', ...
                    'blfNIR', bl, ...
                    'averageAux', true, 'flattenAux', true, 'trimAux', false);
                ppData{i}.time = ppData{i}.time + s.taskStart;

                barData{i} = pf2.data.resample(seg, barBin, ...
                    'centerOnTime', s.taskStart, ...
                    'timeOutMode', 'start', ...
                    'blfNIR', bl, ...
                    'averageAux', true, 'flattenAux', true, 'trimAux', false);
            else
                ppData{i} = pf2.data.split(seg, s.baseline(2), inf, ...
                    'blfNIR', bl);
                barData{i} = ppData{i};
            end
        else
            ppData{i} = pf2.data.resample(seg, s.resampleRate, ...
                'centerOnTime', s.taskStart, ...
                'timeOutMode', 'start', ...
                'averageAux', true, 'flattenAux', true, 'trimAux', false);
            ppData{i}.time = ppData{i}.time + s.taskStart;
            barData{i} = pf2.data.resample(seg, barBin, ...
                'centerOnTime', s.taskStart, ...
                'timeOutMode', 'start', ...
                'averageAux', true, 'flattenAux', true, 'trimAux', false);
        end

        % Trim barData to task window (times are relative to taskStart)
        barData{i} = trimToTaskWindow(barData{i}, 0, taskDuration);

        % Trim ppData to task window if taskEnd is explicitly set
        if isfinite(s.taskEnd)
            ppData{i} = trimToTaskWindow(ppData{i}, s.taskStart, effectiveTaskEnd);
        end
    end
else
    ppData = curData;
    barData = curData;
end

end


function barBin = computeBarBin(s, curData)
% COMPUTEBARBIN Compute bar bin size for grandAvgFNIRS
%
% When barBinSize=0 (single bar), each segment has one time point after
% resampling. grandAvgFNIRS cannot auto-detect sample rate from
% single-point data (median(diff([])) = NaN), so we pass it explicitly.

barBin = s.barBinSize;
if barBin <= 0
    if isfinite(s.taskEnd)
        barBin = s.taskEnd - s.taskStart;
    else
        barBin = max(curData{1}.time) - s.taskStart;
    end
    if barBin <= 0
        barBin = max(curData{1}.time);
    end
end

end


function ppKey = buildPPKey(s)
% BUILDPPKEY Build a string key from preprocessing settings for cache lookup
%
% The key encodes settings that affect Stage A (preprocessing). Changing
% any of these values produces a different key, invalidating the cache.

ppKey = sprintf('bl=[%.4f,%.4f]_rs=%.4f_bb=%.4f_ts=%.4f_te=%.4f_ub=%d_rm=%s_om=%s', ...
    s.baseline(1), s.baseline(2), ...
    s.resampleRate, s.barBinSize, ...
    s.taskStart, s.taskEnd, s.useBaseline, ...
    s.rawMethod, s.oxyMethod);

end


function data = trimToTaskWindow(data, tStart, tEnd)
% TRIMTOTASKWINDOW Remove time points outside the task window [tStart, tEnd)

if ~isfield(data, 'time'), return; end
t = data.time;
keep = t >= tStart & t < tEnd;
if all(keep), return; end

nT = length(t);
data.time = t(keep);

% Trim biomarker arrays
bioFields = {'HbO','HbR','HbTotal','HbDiff','CBSI','raw','od'};
for f = 1:length(bioFields)
    fn = bioFields{f};
    if isfield(data, fn) && isnumeric(data.(fn)) && size(data.(fn),1) == nT
        data.(fn) = data.(fn)(keep, :);
    end
end

% Trim aux data (tables from flattenAux or structs)
if isfield(data, 'Aux') && isstruct(data.Aux)
    auxFields = fieldnames(data.Aux);
    for f = 1:length(auxFields)
        af = data.Aux.(auxFields{f});
        if istable(af) && height(af) == nT
            data.Aux.(auxFields{f}) = af(keep, :);
        elseif isstruct(af) && isfield(af, 'data') && size(af.data,1) == nT
            data.Aux.(auxFields{f}).data = af.data(keep, :);
            if isfield(af, 'time') && length(af.time) == nT
                data.Aux.(auxFields{f}).time = af.time(keep);
            end
        end
    end
end

end


function hVars = buildHierarchyVars(curTable, validHierarchy, mode)
% Build the hierarchy argument for grandAvgFNIRS based on averaging mode

    switch lower(mode)
        case 'hierarchy'
            tableVars = curTable.Properties.VariableNames;
            useVars = intersect(validHierarchy, tableVars, 'stable');
            if ~isempty(useVars)
                hVars = curTable(:, useVars);
            else
                hVars = (1:size(curTable, 1))';
            end

        case 'flat'
            if ismember('SubjectID', curTable.Properties.VariableNames)
                hVars = curTable(:, 'SubjectID');
            else
                hVars = (1:size(curTable, 1))';
            end

        case 'none'
            hVars = (1:size(curTable, 1))';

        otherwise
            error('Unknown averaging mode: %s. Use ''hierarchy'', ''flat'', or ''none''.', mode);
    end
end


function [blocks, fwdArgs] = extractBlocksArg(args)
% EXTRACTBLOCKSARG Extract 'Blocks' parameter from name-value argument list
%
% Returns the blocks struct array and the remaining args without 'Blocks'.

blocks = [];
fwdArgs = args;

for k = 1:2:length(args)-1
    if ischar(args{k}) && strcmpi(args{k}, 'Blocks')
        blocks = args{k+1};
        fwdArgs = [args(1:k-1), args(k+2:end)];
        return;
    end
end

end


function [align, fwdArgs] = extractAlignArg(args)
% EXTRACTALIGNARG Extract 'Align' parameter from name-value argument list
%
% Returns the alignment mode and the remaining args without 'Align'.

align = 'union';
fwdArgs = args;

for k = 1:2:length(args)-1
    if ischar(args{k}) && strcmpi(args{k}, 'Align')
        align = args{k+1};
        fwdArgs = [args(1:k-1), args(k+2:end)];
        return;
    end
end

end


function result = computeConnectivityGroups(groups, args, align)
% COMPUTECONNECTIVITYGROUPS Core connectivity computation across groups
%
% Computes per-subject connectivity matrices for each group and aggregates.
% Uses alignMatrices to handle subjects with different valid channels.

if nargin < 3
    align = 'union';
end

nGroups = length(groups);
result = struct([]);

for g = 1:nGroups
    curData = groups(g).gbyFNIRS;
    nSubjects = length(curData);

    fprintf('Group [%d] %s: computing connectivity for %d subjects...\n', ...
        g, groups(g).label, nSubjects);

    subResults = cell(nSubjects, 1);
    for s = 1:nSubjects
        subResults{s} = exploreFNIRS.connectivity.computeMatrix(curData{s}, args{:});
    end

    % Align and aggregate using channel-identity-aware stacking
    [allMat, masterCh, masterLabels, nValidMat] = ...
        exploreFNIRS.connectivity.alignMatrices(subResults, align);

    result(g).Mean = mean(allMat, 3, 'omitnan');
    result(g).SD = std(allMat, 0, 3, 'omitnan');
    result(g).SEM = result(g).SD ./ sqrt(max(nValidMat, 1));
    result(g).nValid = nValidMat;
    result(g).N = nSubjects;
    result(g).matrices = cellfun(@(r) r.matrix, subResults, 'UniformOutput', false);
    result(g).label = groups(g).label;
    result(g).method = subResults{1}.method;
    result(g).biomarker = subResults{1}.biomarker;
    result(g).channels = masterCh;
    result(g).labels = masterLabels;
    result(g).useROI = subResults{1}.useROI;

    mask = triu(true(size(result(g).Mean)), 1);
    result(g).globalMean = mean(result(g).Mean(mask), 'omitnan');
end

end


function result = computeHyperscanningCore(selData, pairs, groupArgs, nPerms, pThreshold, align)
% COMPUTEHYPERSCANNINGCORE Core hyperscanning computation
%
% Computes group coupling and optional permutation test.

if nargin < 6
    align = 'union';
end

result = exploreFNIRS.hyperscanning.computeGroup(selData, pairs, ...
    'Align', align, groupArgs{:});
result.pairs = pairs;

if nPerms > 0
    fprintf('Running permutation test (%d iterations)...\n', nPerms);
    result.permutation = exploreFNIRS.hyperscanning.permutationTest( ...
        selData, pairs, ...
        'Permutations', nPerms, ...
        'PThreshold', pThreshold, ...
        'Align', align, ...
        groupArgs{:});
end

end
