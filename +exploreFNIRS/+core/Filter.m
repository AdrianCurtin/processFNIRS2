classdef Filter
% FILTER Immutable, combinable data filter for Experiment queries
%
% Value class for building up selection criteria that can be applied to
% an Experiment's dataTable. Filters are immutable — each method returns
% a new Filter with the criterion added.
%
% Syntax:
%   f = exploreFNIRS.core.Filter()
%   f = f.include('Group', 'Control')
%   f = f.include('Condition', {'Task1','Task2'})
%   f = f.exclude('SubjectID', 'S003')
%   f = f.ch([1, 5, 10])
%   f = f.bio({'HbO'})
%   f = f.time([5, 20])
%   f = f.mask(logicalVector)
%   f3 = f1.and(f2)
%   idx = f.apply(dataTable)
%
% Example:
%   f = exploreFNIRS.core.Filter();
%   f = f.include('Group', 'Control').include('Condition', {'Task1','Task2'});
%   f = f.ch(1:10).bio({'HbO','HbR'}).time([5, 20]);
%
%   % Apply to experiment's dataTable
%   idx = f.apply(ex.dataTable);
%
%   % Combine filters
%   f1 = exploreFNIRS.core.Filter().include('Group', 'Control');
%   f2 = exploreFNIRS.core.Filter().exclude('SubjectID', 'S003');
%   f3 = f1.and(f2);
%
% See also: exploreFNIRS.core.Experiment, exploreFNIRS.core.PlotProxy

    properties (SetAccess = private)
        % Cell array of include criteria: each is {varName, values}
        includes = {}

        % Cell array of exclude criteria: each is {varName, values}
        excludes = {}

        % Channel indices (empty = all)
        channels = []

        % Biomarker names (empty = default)
        biomarkers = {}

        % Time window [start, end] in seconds (empty = full range)
        timeWindow = []

        % Arbitrary logical mask (empty = no mask)
        logicalMask = []
    end

    methods

        function obj = Filter()
        % FILTER Create empty filter
        end


        function obj = include(obj, varName, values)
        % INCLUDE Keep only rows where varName matches values
        %
        %   f = f.include('Group', 'Control')
        %   f = f.include('Condition', {'Task1','Task2'})

            validateattributes(varName, {'char','string'}, {'scalartext'});
            if ischar(values), values = {values}; end
            if isstring(values), values = cellstr(values); end
            obj.includes{end+1} = {char(varName), values};
        end


        function obj = exclude(obj, varName, values)
        % EXCLUDE Remove rows where varName matches values
        %
        %   f = f.exclude('SubjectID', 'S003')
        %   f = f.exclude('Condition', {'Rest'})

            validateattributes(varName, {'char','string'}, {'scalartext'});
            if ischar(values), values = {values}; end
            if isstring(values), values = cellstr(values); end
            obj.excludes{end+1} = {char(varName), values};
        end


        function obj = ch(obj, chIdx)
        % CH Select specific channels
        %
        %   f = f.ch([1, 5, 10])

            validateattributes(chIdx, {'numeric'}, {'vector','positive','integer'});
            obj.channels = chIdx(:)';
        end


        function obj = bio(obj, bioNames)
        % BIO Select specific biomarkers
        %
        %   f = f.bio({'HbO'})
        %   f = f.bio({'HbO','HbR'})

            if ischar(bioNames), bioNames = {bioNames}; end
            if isstring(bioNames), bioNames = cellstr(bioNames); end
            obj.biomarkers = bioNames;
        end


        function obj = time(obj, tw)
        % TIME Set time window [start, end] in seconds
        %
        %   f = f.time([5, 20])

            validateattributes(tw, {'numeric'}, {'vector','numel',2});
            obj.timeWindow = sort(tw(:)');
        end


        function obj = mask(obj, logMask)
        % MASK Apply arbitrary logical mask
        %
        %   f = f.mask(logicalVector)

            validateattributes(logMask, {'logical'}, {'vector'});
            obj.logicalMask = logMask(:);
        end


        function obj = and(obj, other)
        % AND Combine two filters (intersection)
        %
        %   f3 = f1.and(f2)

            if ~isa(other, 'exploreFNIRS.core.Filter')
                error('exploreFNIRS:core:Filter:and', ...
                    'Argument must be a Filter object');
            end

            % Merge includes
            obj.includes = [obj.includes, other.includes];

            % Merge excludes
            obj.excludes = [obj.excludes, other.excludes];

            % Channels: intersect if both specified
            if ~isempty(other.channels)
                if isempty(obj.channels)
                    obj.channels = other.channels;
                else
                    obj.channels = intersect(obj.channels, other.channels);
                end
            end

            % Biomarkers: intersect if both specified
            if ~isempty(other.biomarkers)
                if isempty(obj.biomarkers)
                    obj.biomarkers = other.biomarkers;
                else
                    obj.biomarkers = intersect(obj.biomarkers, other.biomarkers);
                end
            end

            % Time window: intersect (max start, min end)
            if ~isempty(other.timeWindow)
                if isempty(obj.timeWindow)
                    obj.timeWindow = other.timeWindow;
                else
                    obj.timeWindow = [max(obj.timeWindow(1), other.timeWindow(1)), ...
                                      min(obj.timeWindow(2), other.timeWindow(2))];
                end
            end

            % Logical mask: AND
            if ~isempty(other.logicalMask)
                if isempty(obj.logicalMask)
                    obj.logicalMask = other.logicalMask;
                else
                    n = min(length(obj.logicalMask), length(other.logicalMask));
                    obj.logicalMask = obj.logicalMask(1:n) & other.logicalMask(1:n);
                end
            end
        end


        function idx = apply(obj, dataTable)
        % APPLY Return logical index into dataTable matching all criteria
        %
        %   idx = f.apply(dataTable)

            n = height(dataTable);
            idx = true(n, 1);

            % Apply includes
            for i = 1:length(obj.includes)
                varName = obj.includes{i}{1};
                values = obj.includes{i}{2};
                if ~ismember(varName, dataTable.Properties.VariableNames)
                    warning('exploreFNIRS:core:Filter:apply', ...
                        'Variable "%s" not found in dataTable, skipping', varName);
                    continue;
                end
                col = dataTable.(varName);
                idx = idx & matchColumn(col, values);
            end

            % Apply excludes
            for i = 1:length(obj.excludes)
                varName = obj.excludes{i}{1};
                values = obj.excludes{i}{2};
                if ~ismember(varName, dataTable.Properties.VariableNames)
                    continue;
                end
                col = dataTable.(varName);
                idx = idx & ~matchColumn(col, values);
            end

            % Apply logical mask
            if ~isempty(obj.logicalMask)
                maskLen = length(obj.logicalMask);
                if maskLen >= n
                    idx = idx & obj.logicalMask(1:n);
                else
                    % Pad with false
                    padded = false(n, 1);
                    padded(1:maskLen) = obj.logicalMask;
                    idx = idx & padded;
                end
            end
        end


        function tf = hasChannels(obj)
        % HASCHANNELS True if channels are specified
            tf = ~isempty(obj.channels);
        end

        function tf = hasBiomarkers(obj)
        % HASBIOMARKERS True if biomarkers are specified
            tf = ~isempty(obj.biomarkers);
        end

        function tf = hasTimeWindow(obj)
        % HASTIMEWINDOW True if time window is specified
            tf = ~isempty(obj.timeWindow);
        end

        function tf = isEmpty(obj)
        % ISEMPTY True if no criteria are set
            tf = isempty(obj.includes) && isempty(obj.excludes) && ...
                 isempty(obj.channels) && isempty(obj.biomarkers) && ...
                 isempty(obj.timeWindow) && isempty(obj.logicalMask);
        end

    end
end


function idx = matchColumn(col, values)
% Match column values against a set of target values
    if iscell(values) || isstring(values)
        values = string(values);
        if isstring(col) || iscategorical(col) || iscell(col)
            idx = ismember(string(col), values);
        else
            idx = ismember(col, double(values));
        end
    elseif isnumeric(values)
        idx = ismember(col, values);
    else
        idx = true(size(col, 1), 1);
    end
end
