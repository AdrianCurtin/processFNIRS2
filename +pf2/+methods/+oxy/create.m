function create(methodName, varargin)
% CREATE Create a new oxy processing method programmatically
%
% Creates a new oxy processing method without using the GUI. This enables
% scripted method creation for batch workflows and reproducible analysis
% setups.
%
% Syntax:
%   pf2.methods.oxy.create(methodName)
%   pf2.methods.oxy.create(methodName, functions)
%   pf2.methods.oxy.create(..., 'Replace', true)
%
% Inputs:
%   methodName - Name for the new method (will be sanitized for INI format)
%   functions  - (optional) Cell array of function definitions, where each
%                element is a struct with fields:
%                  .f       - Function name (e.g., 'pf2_takizawa')
%                  .args    - Cell array of argument names
%                  .argvals - Cell array of argument values
%                  .output  - Output variable ('x', 'fchMask', etc.)
%
% Options (Name-Value):
%   'Replace' - If true, replace existing method with same name (default: false)
%
% Example:
%   % Create empty method
%   pf2.methods.oxy.create('myOxyMethod');
%
%   % Create method with Takizawa rejection
%   funcs = {struct('f', 'pf2_takizawa', 'args', {{'x', 'fchMask', 'threshold'}}, ...
%                   'argvals', {{'x', 'fchMask', 0.75}}, 'output', 'fchMask')};
%   pf2.methods.oxy.create('myTakizawa', funcs);
%
%   % Replace existing method
%   pf2.methods.oxy.create('myMethod', funcs, 'Replace', true);
%
% See also: pf2.methods.oxy.addFunction, pf2.methods.oxy.list,
%           pf2.methods.oxy.setMethod, pf2.methods.raw.create

% Parse inputs
p = inputParser;
addRequired(p, 'methodName', @(x) ischar(x) || isstring(x));
addOptional(p, 'functions', {}, @iscell);
addParameter(p, 'Replace', false, @islogical);
parse(p, methodName, varargin{:});

functions = p.Results.functions;
replaceExisting = p.Results.Replace;

% Initialize PF2 if needed
global PF2
if isempty(PF2) || ~isfield(PF2, 'myOxyMethods')
    pf2_base.pf2_initialize();
end

% Sanitize method name
methodName = pf2_base.cleanNameForINI(methodName);

% Check for reserved name
if strcmpi(methodName, 'None')
    error('pf2:ReservedName', '''None'' is a reserved method name');
end

% Check if method already exists
methodExists = ismember(methodName, PF2.myOxyMethods.cfg.Sections);
if methodExists && ~replaceExisting
    error('pf2:MethodExists', ...
        'Method ''%s'' already exists. Use ''Replace'', true to overwrite.', ...
        methodName);
end

% Build method structure
method = struct();
method.name = methodName;
method.F = {};

% Add functions if provided
for i = 1:length(functions)
    func = functions{i};

    % Validate function struct
    if ~isfield(func, 'f')
        error('pf2:InvalidFunction', 'Function %d missing ''f'' field', i);
    end

    % Ensure required fields exist
    if ~isfield(func, 'args'), func.args = {}; end
    if ~isfield(func, 'argvals'), func.argvals = {}; end
    if ~isfield(func, 'default_argvals'), func.default_argvals = func.argvals; end
    if ~isfield(func, 'output'), func.output = 'x'; end

    % Store function
    method.F{end+1} = func;
end

% Remove existing method if replacing
if methodExists
    PF2.myOxyMethods.cfg.remove(methodName);
end

% Pack method for storage (convert F to S1, S2, etc.)
packedMethod = method;
packedMethod = rmfield(packedMethod, 'F');
for j = 1:length(method.F)
    packedMethod.(sprintf('S%d', j)) = method.F{j};
end

% Add to config
PF2.myOxyMethods.cfg.add(methodName, packedMethod);

% Save to disk
PF2.myOxyMethods.cfg.write();

% Reload methods to update F field
PF2.myOxyMethods = unpackMethodsLocal(PF2.myOxyMethods);

fprintf('Created oxy method: %s\n', methodName);
if ~isempty(functions)
    fprintf('  Functions: %d\n', length(functions));
end

end


function myMethods = unpackMethodsLocal(myMethods)
% Local copy of unpackMethods to avoid dependency on GUI
% Handles struct arrays created by INI round-tripping of cell array fields

for i = 1:length(myMethods.cfg.Sections)
    x = myMethods.cfg.(myMethods.cfg.Sections{i});
    if ~isstruct(x)
        continue;
    end

    x_fields = fieldnames(x);
    x.name = myMethods.cfg.Sections{i};
    x.F = {};

    for j = 1:length(x_fields)
        fieldName = sprintf('S%d', j);
        if isfield(x, fieldName)
            x.F{end+1} = x.(fieldName);
            x = rmfield(x, fieldName);
        end
    end

    % Handle struct arrays created by INI cell-array distribution
    for idx = 1:length(x.F)
        Fidx = x.F{idx};
        if isstruct(Fidx) && length(Fidx) > 1
            F_fixed.f = Fidx(1).f;
            F_fixed.args = cell(1, length(Fidx));
            F_fixed.argvals = cell(1, length(Fidx));
            F_fixed.default_argvals = cell(1, length(Fidx));
            F_fixed.output = cell(1, length(Fidx));
            for k = 1:length(Fidx)
                F_fixed.args{k} = Fidx(k).args;
                F_fixed.argvals{k} = Fidx(k).argvals;
                if isfield(Fidx, 'default_argvals')
                    F_fixed.default_argvals{k} = Fidx(k).default_argvals;
                else
                    F_fixed.default_argvals{k} = Fidx(k).argvals;
                end
                if isfield(Fidx, 'output')
                    F_fixed.output{k} = Fidx(k).output;
                else
                    F_fixed.output{k} = 'x';
                end
            end
            x.F{idx} = F_fixed;
        end
    end

    myMethods.cfg.(myMethods.cfg.Sections{i}) = x;
end

end
