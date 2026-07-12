function [descrip,functions]=describeMethod(oxyMethod, ctx)
% DESCRIBEMETHOD Display detailed information about an oxy processing method
%
% Shows the complete configuration of an oxy (hemoglobin) processing method,
% including all processing functions in the pipeline, their arguments, and
% output assignments. Useful for understanding what a method does before
% applying it to data, or for debugging processing issues.
%
% Syntax:
%   pf2.methods.oxy.describeMethod()
%   pf2.methods.oxy.describeMethod(oxyMethod)
%   pf2.methods.oxy.describeMethod(methodIndex)
%   [descrip, functions] = pf2.methods.oxy.describeMethod(...)
%
% Inputs:
%   oxyMethod - Method identifier (optional), one of:
%               - String/char: Method name (e.g., 'takizawa_easy_lpf')
%               - Numeric: Method index from the available methods list
%               If omitted, prompts for interactive selection.
%
% Outputs:
%   descrip   - String containing the formatted method description
%               If not requested, description prints to console.
%   functions - Cell array of function configuration structs containing:
%               .f       - Function name
%               .args    - Argument names
%               .argvals - Argument values
%               .output  - Output variable assignment
%
% Example:
%   % Display current method details to console
%   pf2.methods.oxy.describeMethod();
%
%   % Describe a specific method by name
%   pf2.methods.oxy.describeMethod('takizawa_easy_lpf');
%
%   % Get method details as variables for programmatic use
%   [desc, funcs] = pf2.methods.oxy.describeMethod('medfilt_car');
%   fprintf('Method has %d processing functions\n', length(funcs));
%
%   % Describe method by index
%   pf2.methods.oxy.describeMethod(3);
%
% See also: pf2.methods.oxy.list, pf2.methods.oxy.setMethod,
%           pf2.methods.raw.describeMethod, pf2.methods.describeCurrentMethods

if nargin < 2, ctx = []; end

% Resolve methods library (uses Context if provided, otherwise global PF2)
methodsLib = pf2_base.resolveMethodsLib('oxy', ctx);

if(nargin<1)
   oxyMethod=pf2.methods.oxy(true);
   getByIndex=false;
elseif(isnumeric(oxyMethod))
    getByIndex=true;
else
    getByIndex=false;
end

% No current method selected (e.g. fresh install): report gracefully
% rather than failing the cfg lookup below.
if(~getByIndex && (isempty(oxyMethod) || (ischar(oxyMethod) && isempty(strtrim(oxyMethod)))))
    msg=sprintf(['No current Oxy Method selected.\n' ...
        'Use pf2.methods.oxy.setMethod(...) to select one, ' ...
        'or pf2.methods.oxy.list() to see available methods.\n']);
    if(nargout>0)
        descrip=msg;
        functions={};
    else
        fprintf(2,'%s',msg);
    end
    return;
end

    
% methodsLib.cfg may be a struct or a pf2_base.external.INI object; the
% latter exposes Sections as a property (isfield is false for objects), so
% probe with a struct-or-object safe check before reading it.
cfgHasSections = isfield(methodsLib,'cfg') && ...
    ((isstruct(methodsLib.cfg) && isfield(methodsLib.cfg,'Sections')) || ...
     (isobject(methodsLib.cfg) && isprop(methodsLib.cfg,'Sections')));
if(cfgHasSections&&~isempty(methodsLib.cfg.Sections))
    oxyMethods=methodsLib.cfg.Sections;
    
    if(getByIndex)
        if(oxyMethod>0&&oxyMethod<=length(oxyMethods))
            oxyMethod=oxyMethods{oxyMethod};
        else
            error('pf2:methods:oxy:describeMethod:badIndex', 'Unable to find Oxy Method at Index %i',oxyMethod);
        end
    end
    
    if(ismember(oxyMethod,oxyMethods)&&~isempty(methodsLib.cfg.(oxyMethod)))
        oxyMethodCfg=methodsLib.cfg.(oxyMethod);
    else
       error('pf2:methods:oxy:describeMethod:methodNotFound', 'Unable to find current Oxy Method name %s',oxyMethod);
    end
    
    
    funcs=oxyMethodCfg.F;
    
    descripStr=sprintf('Oxy Method: %s\n',oxyMethod);
    for f=1:length(funcs)
        curFunc=funcs{f};
        % Function entries may be plain structs or PipelineFunction objects;
        % normalize to the struct shape (.f/.args/.argvals/.output) below.
        if(isa(curFunc,'pf2_base.PipelineFunction'))
            curFunc=curFunc.toStruct();
        end
        funcDescripStr=sprintf('%i. Function: %s\n',f,curFunc.f);
        for a=1:length(curFunc.args)
            if(~iscell(curFunc.args))
                arg=curFunc.args;
            else
                arg=curFunc.args{a};
            end
            if(~iscell(curFunc.argvals))
                argVal=curFunc.argvals;
            else
                argVal=curFunc.argvals{a};
            end

            funcDescripStr=sprintf('%s\targ%i: \t%s\t%s\n',funcDescripStr,a,arg,num2strOrNot(argVal));      
        end
        
        if(iscell(curFunc.output))
           output=curFunc.output{1}; 
        else
           output=curFunc.output; 
        end
        
        funcDescripStr=sprintf('%s\toutput:\t%s\n',funcDescripStr,output);
        descripStr=sprintf('%s%s',descripStr,funcDescripStr);
    end
    
    if(nargout>0)
        descrip=descripStr;
        functions=funcs;
    else
        fprintf(descripStr);
    end
else
    % No methods library / Sections available: report gracefully rather than
    % returning with unassigned outputs.
    msg=sprintf('No Oxy Methods available to describe.\n');
    if(nargout>0)
        descrip=msg;
        functions={};
    else
        fprintf(2,'%s',msg);
    end
end

end

function possibleStr=num2strOrNot(possibleStr)
    if(iscell(possibleStr))
        for i=1:length(possibleStr)
           if(~ischar(possibleStr{i})&&isnumeric(possibleStr{i}))
                possibleStr{i}=num2str(possibleStr{i}); 
           end
        end
    elseif(~ischar(possibleStr)&&islogical(possibleStr))
        if(possibleStr)
            possibleStr='true';
        else
            possibleStr='false';
        end
    elseif(~ischar(possibleStr)&&isnumeric(possibleStr))
        possibleStr=num2str(possibleStr);

    end
end

