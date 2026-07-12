function importMethod(filePath, varargin)
% IMPORTMETHOD Import a raw processing method from a JSON file
%
% Loads a raw processing method from a portable JSON file exported by
% exportMethod. Creates the method in the current installation.
%
% Syntax:
%   pf2.methods.raw.importMethod(filePath)
%   pf2.methods.raw.importMethod(filePath, 'Replace', true)
%
% Inputs:
%   filePath - Path to the JSON method file
%
% Options (Name-Value):
%   'Replace' - If true, replace existing method with same name (default: false)
%
% Example:
%   pf2.methods.raw.importMethod('/path/to/method.json');
%   pf2.methods.raw.importMethod('/path/to/method.json', 'Replace', true);
%
% See also: pf2.methods.raw.exportMethod, pf2.methods.oxy.importMethod,
%           pf2.methods.raw.create

% Parse inputs
p = inputParser;
addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
addParameter(p, 'Replace', false, @islogical);
parse(p, filePath, varargin{:});

replaceExisting = p.Results.Replace;

% Read JSON file
if ~isfile(filePath)
    error('pf2:FileNotFound', 'File not found: %s', filePath);
end

fid = fopen(filePath, 'r');
if fid == -1
    error('pf2:FileReadError', 'Cannot open file for reading: %s', filePath);
end
jsonText = fread(fid, '*char')';
fclose(fid);

% Parse JSON
jsonStruct = jsondecode(jsonText);

% Validate type
if isfield(jsonStruct, 'type') && ~strcmp(jsonStruct.type, 'raw')
    error('pf2:TypeMismatch', ...
        'Method type is ''%s'', expected ''raw''. Use pf2.methods.oxy.importMethod for oxy methods.', ...
        jsonStruct.type);
end

% Validate required fields
if ~isfield(jsonStruct, 'name')
    error('pf2:InvalidFormat', 'JSON file missing required ''name'' field.');
end

methodName = jsonStruct.name;

% Convert functions from JSON format to cell array of structs
functions = {};
if isfield(jsonStruct, 'functions')
    funcs = jsonStruct.functions;
    if isstruct(funcs)
        % jsondecode converts arrays of objects to struct arrays
        for i = 1:length(funcs)
            func = struct();
            func.f = funcs(i).f;
            func.args = convertToCell(funcs(i).args);
            func.argvals = convertArgvals(funcs(i).argvals);
            if isfield(funcs(i), 'output')
                func.output = funcs(i).output;
            else
                func.output = 'x';
            end
            functions{end+1} = func; %#ok<AGROW>
        end
    elseif iscell(funcs)
        for i = 1:length(funcs)
            f = funcs{i};
            func = struct();
            func.f = f.f;
            func.args = convertToCell(f.args);
            func.argvals = convertArgvals(f.argvals);
            if isfield(f, 'output')
                func.output = f.output;
            else
                func.output = 'x';
            end
            functions{end+1} = func; %#ok<AGROW>
        end
    end
end

% Create method using existing create function
pf2.methods.raw.create(methodName, functions, 'Replace', replaceExisting);

fprintf('Imported raw method ''%s'' from %s (%d functions)\n', ...
    methodName, filePath, length(functions));

end


function out = convertToCell(val)
% Convert jsondecode output to cell array of strings
if ischar(val) || isstring(val)
    out = {char(val)};
elseif iscell(val)
    out = cellfun(@char, val, 'UniformOutput', false);
elseif isstring(val) && ~isscalar(val)
    out = cellstr(val);
else
    out = {val};
end
end


function out = convertArgvals(val)
% Convert argvals, preserving numeric values
if ischar(val) || (isstring(val) && isscalar(val))
    out = {char(val)};
elseif iscell(val)
    out = cell(size(val));
    for i = 1:numel(val)
        v = val{i};
        if ischar(v) || isstring(v)
            out{i} = char(v);
        else
            out{i} = v;
        end
    end
elseif isnumeric(val)
    out = num2cell(val);
elseif isstring(val) && ~isscalar(val)
    out = cellstr(val);
else
    out = {val};
end
end
