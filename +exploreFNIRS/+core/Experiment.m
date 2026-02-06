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
%
% Inputs:
%   data      - Cell array of processed fNIRS structs (from processFNIRS2)
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
    end

    methods

        function obj = Experiment(data, varargin)
        % EXPERIMENT Create a new Experiment from processed fNIRS data
        %
        %   ex = Experiment(data)
        %   ex = Experiment(data, 'Hierarchy', {'SubjectID','Condition'})

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
                'resampleRate', 0.5, ...         % seconds per bin for temporal (0 = no resample)
                'barBinSize',   0, ...           % seconds per bin for bar export (0 = use resampleRate)
                'useBaseline',  true, ...        % apply baseline correction
                'avgMode',      'hierarchy' ...  % 'hierarchy', 'flat', or 'none'
            );

            % Initialize state
            obj.selectedIdx = true(length(obj.data), 1);
            obj.groupByVars = {};
            obj.groups = [];
            obj.isGrouped = false;
            obj.isAggregated = false;
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
                fprintf('Preprocessing: resample=%.2fs, baseline=[%.1f, %.1f]s, taskStart=%.1fs\n', ...
                    s.resampleRate, s.baseline(1), s.baseline(2), s.taskStart);
            end
            fprintf('Aggregating %d groups (mode: %s)...\n', length(obj.groups), mode);

            for g = 1:length(obj.groups)
                curData  = obj.groups(g).gbyFNIRS;
                curTable = obj.groups(g).gbyTables;

                % Skip empty groups
                if isempty(curData)
                    warning('Group %d (%s) is empty, skipping', g, obj.groups(g).label);
                    continue;
                end

                % --- Preprocess each segment ---
                if doResample || doBaseline
                    ppData = cell(size(curData));
                    barData = cell(size(curData));
                    barBin = s.barBinSize;
                    if barBin <= 0
                        barBin = s.resampleRate;  % same resolution if not specified
                    end

                    for i = 1:length(curData)
                        seg = curData{i};

                        if doBaseline
                            % Extract baseline window
                            bl = pf2.data.split(seg, s.baseline(1), s.baseline(2));

                            % Resample for temporal with baseline subtraction
                            if doResample
                                ppData{i} = pf2.data.resample(seg, s.resampleRate, ...
                                    'centerOnTime', s.taskStart, ...
                                    'timeOutMode', 'start', ...
                                    'blfNIR', bl, ...
                                    'averageAux', true, 'flattenAux', true, 'trimAux', false);
                                ppData{i}.time = ppData{i}.time + s.taskStart;

                                % Resample for bar charts (coarser bins)
                                barData{i} = pf2.data.resample(seg, barBin, ...
                                    'centerOnTime', s.taskStart, ...
                                    'timeOutMode', 'start', ...
                                    'blfNIR', bl, ...
                                    'averageAux', true, 'flattenAux', true, 'trimAux', false);
                            else
                                % Baseline only, no resample
                                ppData{i} = pf2.data.split(seg, s.baseline(2), inf, ...
                                    'blfNIR', bl);
                                barData{i} = ppData{i};
                            end
                        else
                            % Resample without baseline
                            ppData{i} = pf2.data.resample(seg, s.resampleRate, ...
                                'centerOnTime', s.taskStart, ...
                                'timeOutMode', 'start', ...
                                'averageAux', true, 'flattenAux', true, 'trimAux', false);
                            barData{i} = pf2.data.resample(seg, barBin, ...
                                'centerOnTime', s.taskStart, ...
                                'timeOutMode', 'start', ...
                                'averageAux', true, 'flattenAux', true, 'trimAux', false);
                        end
                    end
                else
                    % No preprocessing - use raw data
                    ppData = curData;
                    barData = curData;
                end

                % --- Grand average ---
                hVars = buildHierarchyVars(curTable, validHierarchy, mode);

                % Temporal resolution grand average
                obj.groups(g).gbyGrand = grandAvgFNIRS( ...
                    ppData, false, [], false, hVars, false, true);

                % Flat grand average for export/LME (bar chart resolution)
                flatH = buildHierarchyVars(curTable, validHierarchy, 'flat');
                obj.groups(g).gbyGrandBarFlat = grandAvgFNIRS( ...
                    barData, false, [], false, flatH, false, true);

                % Store preprocessed segments for potential direct access
                obj.groups(g).gbyFNIRS_pp = ppData;

                fprintf('  [%d] %s: %d segments -> grand average\n', ...
                    g, obj.groups(g).label, length(curData));
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
        %
        % Name-Value Parameters:
        %   IncludeAux - Include auxiliary data columns (default: false)
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
            parse(ip, varargin{:});

            % Build channel labels as cell array
            if ~isempty(channels)
                chLabels = cellstr(num2str(channels(:)));
            else
                chLabels = {};
            end

            T = exploreFNIRS.export.mergeGbyTablesLong( ...
                obj.groups, bioMarkers, channels, times, ...
                ip.Results.IncludeAux, false, chLabels);
        end


        function T = toWideTable(obj, bioMarkers, channels, times, varargin)
        % TOWIDETABLE Export grouped data to wide format table
        %
        %   T = ex.toWideTable()
        %   T = ex.toWideTable({'HbO','HbR'})
        %   T = ex.toWideTable({'HbO'}, 1:10, [0 5 10])
        %   T = ex.toWideTable({'HbO'}, 1:5, [], 'IncludeAux', true)
        %
        % Name-Value Parameters:
        %   IncludeAux - Include auxiliary data columns (default: false)
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
            parse(ip, varargin{:});

            % Build channel labels as cell array
            if ~isempty(channels)
                chLabels = cellstr(num2str(channels(:)));
            else
                chLabels = {};
            end

            T = exploreFNIRS.export.mergeGbyTablesWide( ...
                obj.groups, bioMarkers, channels, times, ...
                ip.Results.IncludeAux, false, chLabels);
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
            fig = exploreFNIRS.core.plotBar(obj.groups, varargin{:});
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
            fig = exploreFNIRS.core.plotAux(obj.groups, auxField, varargin{:});
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


        function fig = plotInfoVar(obj, varName, varargin)
        % PLOTINFOVAR Plot a numeric info variable grouped by current groupby
        %
        %   fig = ex.plotInfoVar('reactionTime')
        %   fig = ex.plotInfoVar('accuracy', 'ErrorType', 'SD')
        %   fig = ex.plotInfoVar('Age', 'SavePath', 'age_by_group.png')
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
                error('exploreFNIRS:core:Experiment:plotInfoVar', ...
                    'Call groupby() before plotInfoVar()');
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
            parse(p, varName, varargin{:});
            opts = p.Results;

            if ~isempty(opts.SavePath)
                opts.Visible = 'off';
            end

            % Validate variable exists and is numeric
            selTable = obj.getSelectedTable();
            if ~ismember(varName, selTable.Properties.VariableNames)
                error('exploreFNIRS:core:Experiment:plotInfoVar', ...
                    'Variable "%s" not found. Available: %s', ...
                    varName, strjoin(selTable.Properties.VariableNames, ', '));
            end

            testCol = selTable.(varName);
            if ~isnumeric(testCol)
                error('exploreFNIRS:core:Experiment:plotInfoVar', ...
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
            colors = exploreFNIRS.core.getGroupColors(nGroups);

            fig = figure('Visible', opts.Visible, ...
                'Position', [100, 100, opts.SaveWidth, opts.SaveHeight], ...
                'Color', 'w');
            ax = axes('Parent', fig);
            hold(ax, 'on');

            barX = 1:nGroups;
            for g = 1:nGroups
                bar(ax, barX(g), groupMeans(g), 0.6, ...
                    'FaceColor', colors(g,:), 'EdgeColor', 'k', 'FaceAlpha', 0.7);
            end

            if ~strcmpi(opts.ErrorType, 'none')
                errorbar(ax, barX, groupMeans, groupErrors, 'k.', ...
                    'LineWidth', 1.2, 'CapSize', 8);
            end

            if opts.ShowIndividual
                for g = 1:nGroups
                    if ~isempty(individualData{g})
                        jitter = (rand(size(individualData{g})) - 0.5) * 0.25;
                        scatter(ax, barX(g) + jitter, individualData{g}, 20, ...
                            colors(g,:), 'filled', 'MarkerFaceAlpha', 0.5, ...
                            'HandleVisibility', 'off');
                    end
                end
            end

            set(ax, 'XTick', barX, 'XTickLabel', groupLabels, 'XTickLabelRotation', 30);

            if ~isempty(opts.YLabel)
                ylabel(ax, opts.YLabel);
            else
                ylabel(ax, varName);
            end

            for g = 1:nGroups
                if ~isnan(groupN(g))
                    yPos = groupMeans(g) + groupErrors(g);
                    if isnan(yPos), yPos = groupMeans(g); end
                    text(ax, barX(g), yPos, sprintf('n=%d', groupN(g)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                        'FontSize', 8);
                end
            end

            if ~isempty(opts.Title)
                title(ax, opts.Title);
            else
                title(ax, sprintf('%s by %s', varName, strjoin(obj.groupByVars, ', ')));
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


        function fig = plotScatter(obj, xVar, yVar, varargin)
        % PLOTSCATTER Scatter plot of two info variables, colored by group
        %
        %   fig = ex.plotScatter('Age', 'reactionTime')
        %   fig = ex.plotScatter('taskLoad', 'accuracy', 'FitLine', true)
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
        % See also: plotInfoVar, plotBar

            p = inputParser;
            addRequired(p, 'xVar', @ischar);
            addRequired(p, 'yVar', @ischar);
            addParameter(p, 'FitLine', false, @islogical);
            addParameter(p, 'Title', '', @ischar);
            addParameter(p, 'XLabel', '', @ischar);
            addParameter(p, 'YLabel', '', @ischar);
            addParameter(p, 'MarkerSize', 40, @isnumeric);
            addParameter(p, 'Visible', 'on', @ischar);
            addParameter(p, 'SavePath', '', @ischar);
            addParameter(p, 'SaveWidth', 600, @isnumeric);
            addParameter(p, 'SaveHeight', 400, @isnumeric);
            addParameter(p, 'SaveDPI', 150, @isnumeric);
            parse(p, xVar, yVar, varargin{:});
            opts = p.Results;

            if ~isempty(opts.SavePath)
                opts.Visible = 'off';
            end

            selTable = obj.getSelectedTable();

            % Validate variables
            for v = {xVar, yVar}
                vn = v{1};
                if ~ismember(vn, selTable.Properties.VariableNames)
                    error('exploreFNIRS:core:Experiment:plotScatter', ...
                        'Variable "%s" not found. Available: %s', ...
                        vn, strjoin(selTable.Properties.VariableNames, ', '));
                end
                if ~isnumeric(selTable.(vn))
                    error('exploreFNIRS:core:Experiment:plotScatter', ...
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
                colors = exploreFNIRS.core.getGroupColors(nGroups);

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
                    end
                end

                legend(ax, legendHandles, legendLabels, 'Location', 'best');
            else
                % No grouping - single color
                singleColor = exploreFNIRS.core.getGroupColors(1);
                valid = ~isnan(xData) & ~isnan(yData);
                scatter(ax, xData(valid), yData(valid), opts.MarkerSize, ...
                    singleColor, 'filled', 'MarkerFaceAlpha', 0.7);

                if opts.FitLine && sum(valid) >= 2
                    coeffs = polyfit(xData(valid), yData(valid), 1);
                    xFit = linspace(min(xData(valid)), max(xData(valid)), 50);
                    yFit = polyval(coeffs, xFit);
                    plot(ax, xFit, yFit, '-', 'Color', singleColor, ...
                        'LineWidth', 1.5, 'HandleVisibility', 'off');
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


        function [fig, stats] = plotScatterFNIRS(obj, infoVar, varargin)
        % PLOTSCATTERFNIRS Scatter plot correlating info variable vs fNIRS biomarker
        %
        %   [fig, stats] = ex.plotScatterFNIRS('reactionTime')
        %   [fig, stats] = ex.plotScatterFNIRS('Age', 'Biomarkers', {'HbO'}, ...
        %       'Channels', 5, 'FitLine', true)
        %   [fig, stats] = ex.plotScatterFNIRS('Age', 'PlotTopo', true)
        %
        % Correlates an info/behavioral variable (X) with fNIRS biomarker
        % channel data (Y). Requires aggregate() first.
        %
        % See also: exploreFNIRS.core.plotScatterFNIRS

            if ~obj.isAggregated
                error('exploreFNIRS:core:Experiment:plotScatterFNIRS', ...
                    'Call aggregate() before plotScatterFNIRS()');
            end
            [fig, stats] = exploreFNIRS.core.plotScatterFNIRS(obj.groups, ...
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
            [fig, results] = exploreFNIRS.core.plotLME(obj.groups, ...
                obj.groupByVars, varargin{:});
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

            % Extract Blocks parameter (not forwarded to computeMatrix)
            [blocks, fwdArgs] = extractBlocksArg(varargin);

            if isempty(blocks)
                % Standard: compute for full time range
                result = computeConnectivityGroups(obj.groups, fwdArgs);
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
                        obj.groups, blockArgs);
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

            if isempty(opts.Blocks)
                % Standard: single time window
                coreArgs = groupArgs;
                if ~isempty(opts.TimeWindow)
                    coreArgs = [coreArgs, 'TimeWindow', opts.TimeWindow];
                end
                result = computeHyperscanningCore(selData, pairs, coreArgs, ...
                    opts.Permutations, opts.PThreshold);
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
                        opts.Permutations, opts.PThreshold);
                end
                fprintf('Computed hyperscanning for %d blocks across %d dyads.\n', ...
                    nBlocks, length(pairs));
            end
        end

    end
end


%% Local helper functions

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


function result = computeConnectivityGroups(groups, args)
% COMPUTECONNECTIVITYGROUPS Core connectivity computation across groups
%
% Computes per-subject connectivity matrices for each group and aggregates.

nGroups = length(groups);
result = struct([]);

for g = 1:nGroups
    curData = groups(g).gbyFNIRS;
    nSubjects = length(curData);

    fprintf('Group [%d] %s: computing connectivity for %d subjects...\n', ...
        g, groups(g).label, nSubjects);

    matrices = cell(nSubjects, 1);
    for s = 1:nSubjects
        res = exploreFNIRS.connectivity.computeMatrix(curData{s}, args{:});
        matrices{s} = res.matrix;
    end

    % Stack and aggregate
    refSize = size(matrices{1});
    allMat = nan([refSize, nSubjects]);
    for s = 1:nSubjects
        m = matrices{s};
        sz = min(size(m), refSize);
        allMat(1:sz(1), 1:sz(2), s) = m(1:sz(1), 1:sz(2));
    end

    result(g).Mean = mean(allMat, 3, 'omitnan');
    result(g).SD = std(allMat, 0, 3, 'omitnan');
    nValid = sum(~isnan(allMat), 3);
    result(g).SEM = result(g).SD ./ sqrt(max(nValid, 1));
    result(g).N = nSubjects;
    result(g).matrices = matrices;
    result(g).label = groups(g).label;
    result(g).method = res.method;
    result(g).biomarker = res.biomarker;
    result(g).channels = res.channels;
    result(g).labels = res.labels;
    result(g).useROI = res.useROI;
end

end


function result = computeHyperscanningCore(selData, pairs, groupArgs, nPerms, pThreshold)
% COMPUTEHYPERSCANNINGCORE Core hyperscanning computation
%
% Computes group coupling and optional permutation test.

result = exploreFNIRS.hyperscanning.computeGroup(selData, pairs, groupArgs{:});
result.pairs = pairs;

if nPerms > 0
    fprintf('Running permutation test (%d iterations)...\n', nPerms);
    result.permutation = exploreFNIRS.hyperscanning.permutationTest( ...
        selData, pairs, ...
        'Permutations', nPerms, ...
        'PThreshold', pThreshold, ...
        groupArgs{:});
end

end
