function delete(methodName)
% DELETE Delete an entire oxy processing method permanently
%
% Removes an oxy processing method from the configuration file. This
% action cannot be undone.
%
% Syntax:
%   pf2.methods.oxy.delete(methodName)
%
% Inputs:
%   methodName - Name of the method to delete
%
% Example:
%   % Delete a method
%   pf2.methods.oxy.delete('myMethod');
%
%   % Verify deletion
%   pf2.methods.oxy.list();
%
% See also: pf2.methods.oxy.create, pf2.methods.oxy.removeFunction,
%           pf2.methods.oxy.list, pf2.methods.raw.delete

% Validate inputs
validateattributes(methodName, {'char', 'string'}, {'scalartext'});
methodName = pf2_base.cleanNameForINI(methodName);

% Reject reserved name
if strcmpi(methodName, 'None')
    error('pf2:ReservedName', '''None'' is a reserved method and cannot be deleted.');
end

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

% Remove from config
PF2.myOxyMethods.cfg.remove(methodName);

% Save to disk
PF2.myOxyMethods.cfg.write();

% Reload methods
PF2.myOxyMethods = unpackMethodsLocal(PF2.myOxyMethods);

fprintf('Deleted oxy method: %s\n', methodName);

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
