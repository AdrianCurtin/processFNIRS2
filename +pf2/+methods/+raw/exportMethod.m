function exportMethod(methodName, filePath, ctx)
% EXPORTMETHOD Export a raw processing method to a JSON file
%
% Saves a raw processing method as a portable JSON file that can be
% shared with collaborators or imported into other installations.
%
% Syntax:
%   pf2.methods.raw.exportMethod(methodName, filePath)
%
% Inputs:
%   methodName - Name of the method to export
%   filePath   - Output file path (should end in .json)
%
% Example:
%   pf2.methods.raw.exportMethod('x2_lpf_smar', '/path/to/method.json');
%
% See also: pf2.methods.raw.importMethod, pf2.methods.oxy.exportMethod,
%           pf2.methods.raw.describeMethod

% Validate inputs
validateattributes(methodName, {'char', 'string'}, {'scalartext'});
validateattributes(filePath, {'char', 'string'}, {'scalartext'});
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

% Get method
method = methodsLib.cfg.(methodName);

% Build JSON structure
jsonStruct = struct();
jsonStruct.name = methodName;
jsonStruct.version = '1.0';
jsonStruct.type = 'raw';
jsonStruct.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
jsonStruct.functions = {};

if isfield(method, 'F')
    for i = 1:length(method.F)
        func = method.F{i};
        % In-memory cfg holds PipelineFunction objects (cfg gets re-set
        % to the unpacked form by pf2.methods.raw.create); convert.
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

fprintf('Exported raw method ''%s'' to %s\n', methodName, filePath);

end
