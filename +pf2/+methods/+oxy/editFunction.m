function editFunction(methodName, position, varargin)
% EDITFUNCTION Modify a processing function in an oxy method by position
%
% Modifies properties of an existing function in an oxy processing method
% pipeline without removing and re-adding it.
%
% Syntax:
%   pf2.methods.oxy.editFunction(methodName, position, 'Property', value)
%
% Inputs:
%   methodName - Name of the existing method to modify
%   position   - Position of the function to edit (1-based index)
%
% Options (Name-Value):
%   'funcName'  - Replace the function name (e.g., 'pf2_lpf')
%   'args'      - Replace argument names (cell array)
%   'argvals'   - Replace argument values (cell array)
%   'Output'    - Replace output variable name
%
% Example:
%   % Change argument values
%   pf2.methods.oxy.editFunction('myMethod', 2, 'argvals', {'x', 'fs', 0.1});
%
%   % Change output variable
%   pf2.methods.oxy.editFunction('myMethod', 2, 'Output', 'fchMask');
%
%   % Replace the function entirely
%   pf2.methods.oxy.editFunction('myMethod', 2, 'funcName', 'pf2_lpf', ...
%       'args', {'x','fs','cutoff'}, 'argvals', {'x','fs',0.1});
%
% See also: pf2.methods.oxy.addFunction, pf2.methods.oxy.removeFunction,
%           pf2.methods.oxy.describeMethod, pf2.methods.raw.editFunction

% Parse inputs
p = inputParser;
addRequired(p, 'methodName', @(x) ischar(x) || isstring(x));
addRequired(p, 'position', @(x) isnumeric(x) && isscalar(x) && x > 0 && x == floor(x));
addParameter(p, 'funcName', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'args', {}, @iscell);
addParameter(p, 'argvals', {}, @iscell);
addParameter(p, 'Output', '', @(x) ischar(x) || isstring(x));
parse(p, methodName, position, varargin{:});

methodName = pf2_base.cleanNameForINI(p.Results.methodName);
position = p.Results.position;

% Initialize PF2 if needed
global PF2
if isempty(PF2) || ~isfield(PF2, 'myOxyMethods')
    pf2_base.pf2_initialize();
end

% Check method exists
if ~ismember(methodName, PF2.myOxyMethods.cfg.Sections)
    error('pf2:MethodNotFound', ...
        'Method ''%s'' not found. Use pf2.methods.oxy.list() to see available methods.', ...
        methodName);
end

% Get current method
method = PF2.myOxyMethods.cfg.(methodName);
if ~isfield(method, 'F') || isempty(method.F)
    error('pf2:EmptyMethod', 'Method ''%s'' has no functions to edit.', methodName);
end

% Validate position
numFuncs = length(method.F);
if position > numFuncs
    error('pf2:InvalidPosition', ...
        'Position %d is out of range. Method ''%s'' has %d function(s).', ...
        position, methodName, numFuncs);
end

% Apply edits
curFunc = method.F{position};
changes = {};

if ~isempty(p.Results.funcName)
    curFunc.f = p.Results.funcName;
    changes{end+1} = 'funcName';
end

if ~ismember('args', p.UsingDefaults)
    curFunc.args = p.Results.args;
    changes{end+1} = 'args';
end

if ~ismember('argvals', p.UsingDefaults)
    curFunc.argvals = p.Results.argvals;
    changes{end+1} = 'argvals';
end

if ~isempty(p.Results.Output)
    curFunc.output = p.Results.Output;
    changes{end+1} = 'Output';
end

if isempty(changes)
    fprintf('No changes specified for %s position %d\n', methodName, position);
    return;
end

% Update function
method.F{position} = curFunc;

% Repack method for storage
packedMethod = struct();
packedMethod.name = methodName;
for j = 1:length(method.F)
    packedMethod.(sprintf('S%d', j)) = method.F{j};
end

% Update config
PF2.myOxyMethods.cfg.remove(methodName);
PF2.myOxyMethods.cfg.add(methodName, packedMethod);

% Save to disk
PF2.myOxyMethods.cfg.write();

% Reload methods
PF2.myOxyMethods = unpackMethodsLocal(PF2.myOxyMethods);

fprintf('Edited %s position %d: changed %s\n', methodName, position, strjoin(changes, ', '));

end


function myMethods = unpackMethodsLocal(myMethods)
% Local copy of unpackMethods

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

    myMethods.cfg.(myMethods.cfg.Sections{i}) = x;
end

end
