function removeFunction(methodName, position)
% REMOVEFUNCTION Remove a processing function from an oxy method by position
%
% Removes the function at the specified position from an existing oxy
% processing method pipeline.
%
% Syntax:
%   pf2.methods.oxy.removeFunction(methodName, position)
%
% Inputs:
%   methodName - Name of the existing method to modify
%   position   - Position of the function to remove (1-based index)
%
% Example:
%   % Remove the first function from a method
%   pf2.methods.oxy.removeFunction('myMethod', 1);
%
%   % View method, then remove last function
%   pf2.methods.oxy.describeMethod('myMethod');
%   pf2.methods.oxy.removeFunction('myMethod', 2);
%
% See also: pf2.methods.oxy.addFunction, pf2.methods.oxy.delete,
%           pf2.methods.oxy.describeMethod, pf2.methods.raw.removeFunction

% Validate inputs
validateattributes(methodName, {'char', 'string'}, {'scalartext'});
validateattributes(position, {'numeric'}, {'scalar', 'positive', 'integer'});
methodName = pf2_base.cleanNameForINI(methodName);

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
PF2.myOxyMethods.cfg.remove(methodName);
PF2.myOxyMethods.cfg.add(methodName, packedMethod);

% Save to disk
PF2.myOxyMethods.cfg.write();

% Reload methods
PF2.myOxyMethods = unpackMethodsLocal(PF2.myOxyMethods);

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
