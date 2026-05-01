function exportMethod(methodName, filePath, ctx)
% EXPORTMETHOD Export an oxy processing method to a JSON file
%
% Saves an oxy processing method as a portable JSON file that can be
% shared with collaborators or imported into other installations.
%
% Syntax:
%   pf2.methods.oxy.exportMethod(methodName, filePath)
%
% Inputs:
%   methodName - Name of the method to export
%   filePath   - Output file path (should end in .json)
%
% Example:
%   pf2.methods.oxy.exportMethod('takizawa_easy', '/path/to/method.json');
%
% See also: pf2.methods.oxy.importMethod, pf2.methods.raw.exportMethod,
%           pf2.methods.oxy.describeMethod

% Validate inputs
validateattributes(methodName, {'char', 'string'}, {'scalartext'});
validateattributes(filePath, {'char', 'string'}, {'scalartext'});
methodName = pf2_base.cleanNameForINI(methodName);

if nargin < 3, ctx = []; end

% Resolve methods library (uses Context if provided, otherwise global PF2)
methodsLib = pf2_base.resolveMethodsLib('oxy', ctx);

% Check method exists
if ~ismember(methodName, methodsLib.cfg.Sections)
    error('pf2:MethodNotFound', ...
        'Method ''%s'' not found. Use pf2.methods.oxy.list() to see available methods.', ...
        methodName);
end

% Get method
method = methodsLib.cfg.(methodName);

% Build JSON structure
jsonStruct = struct();
jsonStruct.name = methodName;
jsonStruct.version = '1.0';
jsonStruct.type = 'oxy';
jsonStruct.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
jsonStruct.functions = {};

if isfield(method, 'F')
    for i = 1:length(method.F)
        func = method.F{i};
        if isa(func, 'pf2_base.PipelineFunction')
            func = func.toStruct();
        end
        funcStruct = struct();
        funcStruct.f = func.f;
        funcStruct.args = func.args;
        funcStruct.argvals = func.argvals;
        if isfield(func, 'output')
            funcStruct.output = func.output;
        else
            funcStruct.output = 'x';
        end
        jsonStruct.functions{end+1} = funcStruct;
    end
end

% Write JSON
jsonText = jsonencode(jsonStruct, 'PrettyPrint', true);
fid = fopen(filePath, 'w');
if fid == -1
    error('pf2:FileWriteError', 'Cannot open file for writing: %s', filePath);
end
fwrite(fid, jsonText, 'char');
fclose(fid);

fprintf('Exported oxy method ''%s'' to %s\n', methodName, filePath);

end
