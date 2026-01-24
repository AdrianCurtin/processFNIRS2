function addFunction(methodName, funcName, varargin)
% ADDFUNCTION Add a processing function to an existing raw method
%
% Appends a function to the processing pipeline of an existing raw method.
% The function is added at the end of the current pipeline.
%
% Syntax:
%   pf2.methods.raw.addFunction(methodName, funcName)
%   pf2.methods.raw.addFunction(methodName, funcName, args, argvals)
%   pf2.methods.raw.addFunction(..., 'Output', outputVar)
%   pf2.methods.raw.addFunction(..., 'Position', pos)
%
% Inputs:
%   methodName - Name of the existing method to modify
%   funcName   - MATLAB function name to add (e.g., 'pf2_TDDR')
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
%   % Add TDDR to an existing method
%   pf2.methods.raw.addFunction('myMethod', 'pf2_TDDR', ...
%       {'x', 'fs'}, {'x', 'fs'});
%
%   % Add a filter with numeric parameter
%   pf2.methods.raw.addFunction('myMethod', 'pf2_lpf', ...
%       {'x', 'fs', 'cutoff'}, {'x', 'fs', 0.5});
%
%   % Add function at the beginning
%   pf2.methods.raw.addFunction('myMethod', 'pf2_Intensity2OD', ...
%       {'x'}, {'x'}, 'Position', 1);
%
%   % Add function that modifies channel mask
%   pf2.methods.raw.addFunction('myMethod', 'pf2_checkIntensity', ...
%       {'x', 'fchMask'}, {'x', 'fchMask'}, 'Output', 'fchMask');
%
% See also: pf2.methods.raw.create, pf2.methods.raw.describeMethod,
%           pf2.methods.oxy.addFunction, pf2_base.ArgumentType

% Parse inputs
p = inputParser;
addRequired(p, 'methodName', @(x) ischar(x) || isstring(x));
addRequired(p, 'funcName', @(x) ischar(x) || isstring(x));
addOptional(p, 'args', {}, @iscell);
addOptional(p, 'argvals', {}, @iscell);
addParameter(p, 'Output', 'x', @(x) ischar(x) || isstring(x));
addParameter(p, 'Position', 0, @(x) isnumeric(x) || strcmpi(x, 'end'));
parse(p, methodName, funcName, varargin{:});

args = p.Results.args;
argvals = p.Results.argvals;
outputVar = p.Results.Output;
position = p.Results.Position;

% Handle 'end' position
if ischar(position) && strcmpi(position, 'end')
    position = 0;
end

% Initialize PF2 if needed
global PF2
if isempty(PF2) || ~isfield(PF2, 'myRawMethods')
    pf2_base.pf2_initialize();
end

% Check method exists
if ~ismember(methodName, PF2.myRawMethods.cfg.Sections)
    error('pf2:MethodNotFound', ...
        'Method ''%s'' not found. Use pf2.methods.raw.create() first.', ...
        methodName);
end

% Get current method
method = PF2.myRawMethods.cfg.(methodName);
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
PF2.myRawMethods.cfg.remove(methodName);
PF2.myRawMethods.cfg.add(methodName, packedMethod);

% Save to disk
PF2.myRawMethods.cfg.write();

% Reload methods
PF2.myRawMethods = unpackMethodsLocal(PF2.myRawMethods);

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
