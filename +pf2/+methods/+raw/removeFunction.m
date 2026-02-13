function removeFunction(methodName, position, ctx)
% REMOVEFUNCTION Remove a processing function from a raw method by position
%
% Removes the function at the specified position from an existing raw
% processing method pipeline.
%
% Syntax:
%   pf2.methods.raw.removeFunction(methodName, position)
%
% Inputs:
%   methodName - Name of the existing method to modify
%   position   - Position of the function to remove (1-based index)
%
% Example:
%   % Remove the first function from a method
%   pf2.methods.raw.removeFunction('myMethod', 1);
%
%   % View method, then remove last function
%   pf2.methods.raw.describeMethod('myMethod');
%   pf2.methods.raw.removeFunction('myMethod', 2);
%
% See also: pf2.methods.raw.addFunction, pf2.methods.raw.delete,
%           pf2.methods.raw.describeMethod, pf2.methods.oxy.removeFunction

% Validate inputs
validateattributes(methodName, {'char', 'string'}, {'scalartext'});
validateattributes(position, {'numeric'}, {'scalar', 'positive', 'integer'});
methodName = pf2_base.cleanNameForINI(methodName);
if nargin < 3, ctx = []; end

% Resolve methods library
methodsLib = pf2_base.resolveMethodsLib('raw', ctx);

% Check method exists
if ~ismember(methodName, methodsLib.cfg.Sections)
    error('pf2:MethodNotFound', ...
        'Method ''%s'' not found. Use pf2.methods.raw.list() to see available methods.', ...
        methodName);
end

% Get current method
method = methodsLib.cfg.(methodName);
if ~isfield(method, 'F') || isempty(method.F)
    error('pf2:EmptyMethod', 'Method ''%s'' has no functions to remove.', methodName);
end

% Validate position
numFuncs = length(method.F);
if position > numFuncs
    error('pf2:InvalidPosition', ...
        'Position %d is out of range. Method ''%s'' has %d function(s).', ...
        position, methodName, numFuncs);
end

% Get function name for display
removedName = method.F{position}.f;

% Remove function at position
method.F(position) = [];

% Repack method for storage
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
pf2_base.storeMethodsLib('raw', methodsLib, ctx);

fprintf('Removed %s from %s (was at position %d)\n', removedName, methodName, position);

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
