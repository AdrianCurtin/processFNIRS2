function storeMethodsLib(stage, methodsLib, context)
% STOREMETHODSLIB Write method library struct back to global PF2 or context
%
% After modifying a method library (adding/removing/editing methods),
% call this to persist the changes. Falls back to global PF2 when no
% context is provided.
%
% Syntax:
%   pf2_base.storeMethodsLib('raw', methodsLib)
%   pf2_base.storeMethodsLib('oxy', methodsLib, ctx)
%
% Inputs:
%   stage      - 'raw' or 'oxy'
%   methodsLib - Updated methods library struct
%   context    - (optional) ProcessingContext or struct
%
% See also: pf2_base.resolveMethodsLib

if nargin < 3 || isempty(context)
    global PF2 %#ok<GVMIS>
    if strcmpi(stage, 'raw')
        PF2.myRawMethods = methodsLib;
    else
        PF2.myOxyMethods = methodsLib;
    end
else
    if isstruct(context)
        warning('pf2:storeMethodsLib:structContext', ...
            'Context is a plain struct; mutations will not persist. Use a ProcessingContext handle object.');
    end
    if strcmpi(stage, 'raw')
        context.myRawMethods = methodsLib;
    else
        context.myOxyMethods = methodsLib;
    end
end

end
