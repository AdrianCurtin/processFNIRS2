function [methodsLib, stage] = resolveMethodsLib(stage, context)
% RESOLVEMETHODSLIB Resolve method library struct for a pipeline stage
%
% Returns the method library (cfg struct) for 'raw' or 'oxy' processing.
% When a ProcessingContext is provided, reads from it. Otherwise falls back
% to the global PF2 variable, initializing if needed.
%
% Syntax:
%   [methodsLib, stage] = pf2_base.resolveMethodsLib('raw')
%   [methodsLib, stage] = pf2_base.resolveMethodsLib('oxy', ctx)
%
% Inputs:
%   stage   - 'raw' or 'oxy'
%   context - (optional) ProcessingContext or struct with myRawMethods/myOxyMethods
%
% Outputs:
%   methodsLib - Struct with .cfg field containing method definitions
%   stage      - Normalized stage string ('raw' or 'oxy')
%
% See also: pf2_base.ProcessingContext, pf2_base.pf2_initialize

if nargin < 2 || isempty(context)
    % Fall back to global PF2
    global PF2 %#ok<GVMIS>
    if strcmpi(stage, 'raw')
        if isempty(PF2) || ~isfield(PF2, 'myRawMethods')
            pf2_base.pf2_initialize();
        end
        methodsLib = PF2.myRawMethods;
    else
        if isempty(PF2) || ~isfield(PF2, 'myOxyMethods')
            pf2_base.pf2_initialize();
        end
        methodsLib = PF2.myOxyMethods;
    end
else
    % Read from context
    if strcmpi(stage, 'raw')
        if isfield(context, 'myRawMethods')
            methodsLib = context.myRawMethods;
        elseif isprop(context, 'myRawMethods')
            methodsLib = context.myRawMethods;
        else
            error('pf2:InvalidContext', 'Context does not contain myRawMethods');
        end
    else
        if isfield(context, 'myOxyMethods')
            methodsLib = context.myOxyMethods;
        elseif isprop(context, 'myOxyMethods')
            methodsLib = context.myOxyMethods;
        else
            error('pf2:InvalidContext', 'Context does not contain myOxyMethods');
        end
    end
end

end
