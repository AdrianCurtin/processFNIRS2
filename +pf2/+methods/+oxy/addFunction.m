function addFunction(methodName, funcName, varargin)
% ADDFUNCTION Add a processing function to an existing oxy method
%
% Appends a function to the processing pipeline of an existing oxy method.
% The function is added at the end of the current pipeline.
%
% Syntax:
%   pf2.methods.oxy.addFunction(methodName, funcName)
%   pf2.methods.oxy.addFunction(methodName, funcName, args, argvals)
%   pf2.methods.oxy.addFunction(..., 'Output', outputVar)
%   pf2.methods.oxy.addFunction(..., 'Position', pos)
%
% Inputs:
%   methodName - Name of the existing method to modify
%   funcName   - MATLAB function name to add (e.g., 'pf2_takizawa')
%   args       - (optional) Cell array of argument names
%   argvals    - (optional) Cell array of argument values
%
% Options (Name-Value):
%   'Output'   - Output variable name (default: 'x')
%                Options: 'x', 'fchMask', 'ftimeChMask', 'ROI'
%   'Position' - Position to insert (default: end)
%                Use 0 or 'end' for end, 1 for beginning
%
% Example:
%   % Add Takizawa rejection to an existing method
%   pf2.methods.oxy.addFunction('myMethod', 'pf2_takizawa', ...
%       {'x', 'fchMask', 'threshold'}, {'x', 'fchMask', 0.75}, ...
%       'Output', 'fchMask');
%
%   % Add a filter with numeric parameter
%   pf2.methods.oxy.addFunction('myMethod', 'pf2_lpf', ...
%       {'x', 'fs', 'cutoff'}, {'x', 'fs', 0.1});
%
%   % Add function at the beginning
%   pf2.methods.oxy.addFunction('myMethod', 'pf2_baselineCorrect', ...
%       {'x', 'baseline'}, {'x', 10}, 'Position', 1);
%
% See also: pf2.methods.oxy.create, pf2.methods.oxy.describeMethod,
%           pf2.methods.raw.addFunction, pf2_base.ArgumentType

% Parse inputs
p = inputParser;
addRequired(p, 'methodName', @(x) ischar(x) || isstring(x));
addRequired(p, 'funcName', @(x) ischar(x) || isstring(x));
addOptional(p, 'args', {}, @iscell);
addOptional(p, 'argvals', {}, @iscell);
addParameter(p, 'Output', 'x', @(x) ischar(x) || isstring(x));
addParameter(p, 'Position', 0, @isValidPosition);
addParameter(p, 'Context', [], @(x) isempty(x) || isstruct(x) || isobject(x));
parse(p, methodName, funcName, varargin{:});

args = p.Results.args;
argvals = p.Results.argvals;
outputVar = p.Results.Output;
position = p.Results.Position;
ctx = p.Results.Context;

% Handle 'end' position (char or string); 0 means append at end
if (ischar(position) || isstring(position)) && strcmpi(position, 'end')
    position = 0;
end

% Resolve methods library (uses Context if provided, otherwise global PF2)
methodsLib = pf2_base.resolveMethodsLib('oxy', ctx);

% Sanitize method name for INI lookup
methodName = pf2_base.cleanNameForINI(methodName);

% Check method exists
if ~ismember(methodName, methodsLib.cfg.Sections)
    error('pf2:MethodNotFound', ...
        'Method ''%s'' not found. Use pf2.methods.oxy.create() first.', ...
        methodName);
end

% Get current method
method = methodsLib.cfg.(methodName);
if ~isfield(method, 'F')
    method.F = {};
end

% Create function struct
newFunc = struct();
newFunc.f = funcName;
newFunc.args = args;
newFunc.argvals = argvals;
newFunc.output = outputVar;

% Add at position
if position == 0 || position > length(method.F)
    method.F{end+1} = newFunc;
    insertPos = length(method.F);
else
    method.F = [method.F(1:position-1), {newFunc}, method.F(position:end)];
    insertPos = position;
end

% Pack method for storage
packedMethod = struct();
packedMethod.name = methodName;
for j = 1:length(method.F)
    packedMethod.(sprintf('S%d', j)) = method.F{j};
end

% Update config
methodsLib.cfg.remove(methodName);
methodsLib.cfg.add(methodName, packedMethod);

% Save to disk
methodsLib.cfg.write();

% Reload methods
methodsLib = unpackMethodsLocal(methodsLib);

% Persist updated methods library back to context or global
pf2_base.storeMethodsLib('oxy', methodsLib, ctx);

fprintf('Added %s to %s at position %d\n', funcName, methodName, insertPos);

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


function tf = isValidPosition(x)
% Position must be 'end' (char/string) or a nonnegative integer scalar
% (0 means append at end). Rejects negative or fractional values that
% would otherwise break cell indexing downstream.

if (ischar(x) || isstring(x)) && isscalar(string(x)) && strcmpi(x, 'end')
    tf = true;
elseif isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x == floor(x)
    tf = true;
else
    tf = false;
end

end
