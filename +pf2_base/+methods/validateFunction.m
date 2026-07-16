function validateFunction(funcName, args, argvals, varargin)
% VALIDATEFUNCTION Validate a processing function configuration
%
% Checks that a function configuration is valid before adding it to a
% processing method pipeline. Validates function existence, argument
% consistency, and output variable names.
%
% Syntax:
%   pf2_base.methods.validateFunction(funcName, args, argvals)
%   pf2_base.methods.validateFunction(funcName, args, argvals, 'Output', outputVar)
%
% Inputs:
%   funcName - Name of the MATLAB function (e.g., 'pf2_TDDR')
%   args     - Cell array of argument names
%   argvals  - Cell array of argument values
%
% Options (Name-Value):
%   'Output' - Output variable name (default: 'x')
%
% Example:
%   % Validate a valid function
%   pf2_base.methods.validateFunction('pf2_TDDR', {'x','fs'}, {'x','fs'});
%
%   % Validate with output specification
%   pf2_base.methods.validateFunction('pf2_TakizawaRejection', ...
%       {'x','fchMask','threshold'}, {'x','fchMask',0.75}, ...
%       'Output', 'fchMask');
%
%   % This will error - function does not exist
%   pf2_base.methods.validateFunction('nonexistent_func', {'x'}, {'x'});
%
% See also: pf2.methods.raw.addFunction, pf2.methods.oxy.addFunction,
%           pf2.methods.raw.editFunction, pf2.methods.oxy.editFunction

% Parse inputs
p = inputParser;
addRequired(p, 'funcName', @(x) ischar(x) || isstring(x));
addRequired(p, 'args', @iscell);
addRequired(p, 'argvals', @iscell);
addParameter(p, 'Output', 'x', @(x) ischar(x) || isstring(x));
parse(p, funcName, args, argvals, varargin{:});

outputVar = p.Results.Output;

% 1. Check function exists on MATLAB path
if exist(funcName, 'file') ~= 2 && exist(funcName, 'builtin') ~= 5
    error('pf2:FunctionNotFound', ...
        'Function ''%s'' not found on MATLAB path.', funcName);
end

% 2. Check args and argvals have matching lengths
if length(args) ~= length(argvals)
    error('pf2:ArgLengthMismatch', ...
        'args has %d elements but argvals has %d elements. They must match.', ...
        length(args), length(argvals));
end

% 3. Check reserved argument names use correct values in argvals
reservedArgs = {'x', 'fs', 'fchMask', 'ftimeChMask'};
for i = 1:length(args)
    argName = args{i};
    if ischar(argName) && ismember(argName, reservedArgs)
        argVal = argvals{i};
        if ischar(argVal) && ~strcmp(argVal, argName)
            warning('pf2:ReservedArgMismatch', ...
                'Argument ''%s'' is a reserved name and typically has argval ''%s'', but got ''%s''.', ...
                argName, argName, argVal);
        end
    end
end

% 4. Check output variable is valid
validOutputs = {'x', 'fchMask', 'ftimeChMask', 'ROI'};
if ~ismember(outputVar, validOutputs)
    error('pf2:InvalidOutput', ...
        'Output ''%s'' is not valid. Must be one of: %s', ...
        outputVar, strjoin(validOutputs, ', '));
end

end
