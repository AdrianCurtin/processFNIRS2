classdef ColorScheme
% COLORSCHEME Hierarchical color rules for multi-factor experiment plots
%
% Defines per-value colors and effects that resolve hierarchically across
% factors. Assign base colors to one factor (e.g., Group) and modifier
% effects to another (e.g., Condition) to get distinct, meaningful colors
% for every group combination.
%
% Syntax:
%   cs = exploreFNIRS.core.ColorScheme()
%   cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2])
%   cs = cs.set('Condition', 'Easy', 'lighten', 0.25)
%   colors = cs.resolve(groups)
%
% Methods:
%   set         - Define color and/or effect for a factor value
%   setBase     - Set a global base color (all factors become modifiers)
%   setPriority - Override factor priority order
%   resolve     - Resolve to [nGroups x 3] RGB for a groups struct array
%   preview     - Visualize resolved colors for all factor combinations
%
% Example:
%   cs = exploreFNIRS.core.ColorScheme();
%   cs = cs.set('Group', 'Patient', [0.85, 0.2, 0.2]);
%   cs = cs.set('Group', 'Healthy', [0.2, 0.65, 0.3]);
%   cs = cs.set('Condition', 'Easy', 'lighten', 0.25);
%   cs = cs.set('Condition', 'Hard', 'darken', 0.15);
%
%   % Assign to Experiment
%   ex.colorScheme = cs;
%   fig = ex.plotBar('Biomarker', 'HbO', 'TimeWindow', [5, 20]);
%   % Patient|Easy = lighter red, Patient|Hard = darker red
%   % Healthy|Easy = lighter green, Healthy|Hard = darker green
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.getGroupColors

    properties
        % Struct array: factor, value, color ([1x3] or []), effect, amount
        rules = struct('factor', {}, 'value', {}, 'color', {}, ...
                       'effect', {}, 'amount', {})

        % Cell array of factor names in priority order
        % First factor with a color rule = base color source
        % Remaining factors = modifiers
        priority = {}

        % Global base color [1x3] RGB (optional)
        % When set, all factor rules act as modifiers on this base
        baseColor = []
    end

    properties (Access = private)
        % Track factor order from set() calls for auto-priority
        factorOrder = {}
    end

    methods

        function obj = set(obj, factor, value, varargin)
        % SET Define color and/or effect for a factor-value pair
        %
        %   cs = cs.set(factor, value, color)
        %   cs = cs.set(factor, value, effectName, amount)
        %   cs = cs.set(factor, value, color, effectName, amount)
        %
        % Inputs:
        %   factor     - Factor name (e.g., 'Group', 'Condition')
        %   value      - Factor value (e.g., 'Patient', 'Easy')
        %   color      - [1x3] RGB vector (optional)
        %   effectName - 'lighten', 'darken', 'saturate', 'desaturate'
        %   amount     - Effect strength 0-1

            color = [];
            effect = '';
            amount = 0;

            if ~isempty(varargin)
                idx = 1;
                % First optional arg: color or effect name
                if isnumeric(varargin{idx}) && numel(varargin{idx}) == 3
                    color = varargin{idx}(:)';
                    idx = idx + 1;
                end
                % Next: effect name + amount
                if idx <= length(varargin) && ischar(varargin{idx})
                    effect = lower(varargin{idx});
                    idx = idx + 1;
                    if idx <= length(varargin) && isnumeric(varargin{idx})
                        amount = varargin{idx};
                    end
                end
            end

            % Validate
            if ~isempty(color)
                validateattributes(color, {'numeric'}, {'size', [1, 3], '>=', 0, '<=', 1});
            end
            if ~isempty(effect)
                validEffects = {'lighten', 'darken', 'saturate', 'desaturate'};
                if ~ismember(effect, validEffects)
                    error('exploreFNIRS:core:ColorScheme:set', ...
                        'Effect must be one of: %s', strjoin(validEffects, ', '));
                end
            end

            % Track factor order for auto-priority
            if ~ismember(factor, obj.factorOrder)
                obj.factorOrder{end+1} = factor;
            end

            % Check for existing rule with same factor+value
            found = false;
            for i = 1:length(obj.rules)
                if strcmp(obj.rules(i).factor, factor) && ...
                        strcmp(obj.rules(i).value, char(string(value)))
                    if ~isempty(color)
                        obj.rules(i).color = color;
                    end
                    if ~isempty(effect)
                        obj.rules(i).effect = effect;
                        obj.rules(i).amount = amount;
                    end
                    found = true;
                    break;
                end
            end

            if ~found
                newRule = struct('factor', factor, ...
                    'value', char(string(value)), ...
                    'color', color, ...
                    'effect', effect, ...
                    'amount', amount);
                if isempty(obj.rules)
                    obj.rules = newRule;
                else
                    obj.rules(end+1) = newRule;
                end
            end
        end


        function obj = setPriority(obj, factorList)
        % SETPRIORITY Override the factor priority order
        %
        %   cs = cs.setPriority({'Group', 'Condition'})
        %
        % First factor = base color source; rest = modifiers.

            if ~iscell(factorList) || isempty(factorList)
                error('exploreFNIRS:core:ColorScheme:setPriority', ...
                    'factorList must be a non-empty cell array of factor names');
            end
            obj.priority = factorList;
        end


        function obj = setBase(obj, color)
        % SETBASE Set a global base color
        %
        %   cs = cs.setBase([0.5, 0.5, 0.5])
        %
        % When set, all factors act as modifiers on this base color.

            validateattributes(color, {'numeric'}, {'size', [1, 3], '>=', 0, '<=', 1});
            obj.baseColor = color;
        end


        function colors = resolve(obj, groups)
        % RESOLVE Resolve color scheme to [nGroups x 3] RGB matrix
        %
        %   colors = cs.resolve(groups)
        %
        % For each group, extracts factor values from gbyTables, then:
        %   1. Walks priority list to find base color
        %   2. Applies modifier effects from remaining factors
        %   3. Falls back to default palette for unmatched groups

            nGroups = length(groups);
            colors = nan(nGroups, 3);

            % Determine priority order
            prio = obj.priority;
            if isempty(prio)
                prio = obj.factorOrder;
            end

            defaultPalette = exploreFNIRS.core.getGroupColors(nGroups);

            for g = 1:nGroups
                T = groups(g).gbyTables;

                % Step 1: find base color
                clr = obj.baseColor;

                for pi = 1:length(prio)
                    factor = prio{pi};
                    val = getFactorValue(T, factor);
                    if isempty(val), continue; end

                    rule = findRule(obj.rules, factor, val);
                    if ~isempty(rule) && ~isempty(rule.color)
                        clr = rule.color;
                        break;
                    end
                end

                % Fallback to default palette
                if isempty(clr) || any(isnan(clr))
                    clr = defaultPalette(g, :);
                end

                % Step 2: apply modifier effects from all factors
                for pi = 1:length(prio)
                    factor = prio{pi};
                    val = getFactorValue(T, factor);
                    if isempty(val), continue; end

                    rule = findRule(obj.rules, factor, val);
                    if ~isempty(rule) && ~isempty(rule.effect)
                        clr = applyEffect(clr, rule.effect, rule.amount);
                    end
                end

                colors(g, :) = clr;
            end
        end


        function fig = preview(obj, varargin)
        % PREVIEW Visualize the resolved colors for all factor combinations
        %
        %   fig = cs.preview()
        %   fig = cs.preview('Visible', 'off', 'SavePath', 'scheme.png')
        %
        % Builds synthetic groups from the rules, resolves colors, and
        % renders a horizontal bar chart showing each factor combination
        % with its resolved color.
        %
        % Name-Value Parameters:
        %   Visible    - 'on' (default) or 'off'
        %   SavePath   - File path to save (default: '')
        %   SaveWidth  - Width in pixels (default: 600)
        %   SaveHeight - Height in pixels (default: 400)
        %   SaveDPI    - Resolution (default: 150)

            p = inputParser;
            addParameter(p, 'Visible', 'on', @ischar);
            addParameter(p, 'SavePath', '', @ischar);
            addParameter(p, 'SaveWidth', 600, @isnumeric);
            addParameter(p, 'SaveHeight', 400, @isnumeric);
            addParameter(p, 'SaveDPI', 150, @isnumeric);
            addParameter(p, 'TightLayout', false, @islogical);
            parse(p, varargin{:});
            opts = p.Results;

            % Build synthetic groups from rules
            prio = obj.priority;
            if isempty(prio)
                prio = obj.factorOrder;
            end
            [groups, labels] = buildSyntheticGroups(obj.rules, prio);

            if isempty(groups)
                fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
                    'SavePath', opts.SavePath, 'Width', opts.SaveWidth, ...
                    'Height', max(200, opts.SaveHeight));
                ax = axes(fig);
                text(ax, 0.5, 0.5, 'No rules defined', ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 12, 'Units', 'normalized');
                axis(ax, 'off');
                pf2_base.plot.handleSave(fig, opts);
                return;
            end

            % Resolve colors
            colors = obj.resolve(groups);

            nGroups = length(groups);
            figH = max(200, 40 * nGroups + 80);
            if isempty(opts.SavePath)
                figH = max(figH, opts.SaveHeight);
            end

            fig = pf2_base.plot.createFigure('Visible', opts.Visible, ...
                'SavePath', opts.SavePath, 'Width', opts.SaveWidth, ...
                'Height', figH);
            ax = axes(fig);

            barh(ax, 1:nGroups, ones(nGroups, 1), 'FaceColor', 'flat');
            bObj = ax.Children(1);
            bObj.CData = colors;

            set(ax, 'YTick', 1:nGroups, 'YTickLabel', pf2_base.plot.escapeTeX(labels), ...
                'YDir', 'reverse', 'XTick', []);
            xlim(ax, [0, 1.05]);
            xlabel(ax, '');

            % Annotate hex color on each bar
            for i = 1:nGroups
                hexStr = sprintf('#%02X%02X%02X', ...
                    round(colors(i,1)*255), round(colors(i,2)*255), round(colors(i,3)*255));
                % Choose text color for readability
                lum = 0.299*colors(i,1) + 0.587*colors(i,2) + 0.114*colors(i,3);
                if lum > 0.5
                    txtClr = [0, 0, 0];
                else
                    txtClr = [1, 1, 1];
                end
                text(ax, 0.5, i, hexStr, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 9, 'Color', txtClr, 'FontWeight', 'bold');
            end

            title(ax, 'ColorScheme Preview');
            box(ax, 'off');

            pf2_base.plot.handleSave(fig, opts);
        end

    end
end


%% Local helpers

function val = getFactorValue(T, factor)
% Extract string value of a factor from a gbyTables row
    val = '';
    if ~istable(T), return; end
    if ~ismember(factor, T.Properties.VariableNames), return; end
    v = T.(factor)(1);
    if isnumeric(v)
        val = num2str(v);
    else
        val = char(string(v));
    end
end


function rule = findRule(rules, factor, value)
% Find a rule matching factor + value
    rule = [];
    for i = 1:length(rules)
        if strcmp(rules(i).factor, factor) && strcmp(rules(i).value, value)
            rule = rules(i);
            return;
        end
    end
end


function clr = applyEffect(clr, effect, amount)
% Apply a color modifier effect
    switch effect
        case 'lighten'
            clr = clr + (1 - clr) * amount;
        case 'darken'
            clr = clr * (1 - amount);
        case 'saturate'
            hsv = rgb2hsv(clr);
            hsv(2) = min(1, hsv(2) + amount * (1 - hsv(2)));
            clr = hsv2rgb(hsv);
        case 'desaturate'
            hsv = rgb2hsv(clr);
            hsv(2) = hsv(2) * (1 - amount);
            clr = hsv2rgb(hsv);
    end
    clr = max(0, min(1, clr));
end


function [groups, labels] = buildSyntheticGroups(rules, prio)
% Build synthetic groups struct from ColorScheme rules for preview
    if isempty(rules)
        groups = [];
        labels = {};
        return;
    end

    if isempty(prio)
        % Fallback: extract from rules
        prio = unique({rules.factor}, 'stable');
    end

    factorValues = cell(length(prio), 1);
    for f = 1:length(prio)
        vals = {};
        for r = 1:length(rules)
            if strcmp(rules(r).factor, prio{f})
                if ~ismember(rules(r).value, vals)
                    vals{end+1} = rules(r).value; %#ok<AGROW>
                end
            end
        end
        factorValues{f} = vals;
    end

    % Remove factors with no values
    hasValues = ~cellfun(@isempty, factorValues);
    prio = prio(hasValues);
    factorValues = factorValues(hasValues);

    if isempty(prio)
        groups = [];
        labels = {};
        return;
    end

    % Cartesian product of all factor values
    nFactors = length(prio);
    nValues = cellfun(@length, factorValues);
    nCombinations = prod(nValues);

    groups = struct('gbyTables', cell(1, nCombinations));
    labels = cell(nCombinations, 1);

    for c = 1:nCombinations
        % Compute indices into each factor's values
        idx = c - 1;
        T = table();
        parts = cell(nFactors, 1);
        for f = nFactors:-1:1
            fi = mod(idx, nValues(f)) + 1;
            idx = floor(idx / nValues(f));
            T.(prio{f}) = categorical({factorValues{f}{fi}});
            parts{f} = factorValues{f}{fi};
        end
        groups(c).gbyTables = T;
        labels{c} = strjoin(parts, ' | ');
    end
end
