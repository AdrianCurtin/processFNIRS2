function [descrip,functions]=describeMethod(rawMethod, ctx)
% DESCRIBEMETHOD Display detailed information about a raw processing method
%
% Shows the complete configuration of a raw processing method, including
% all processing functions in the pipeline, their arguments, and output
% assignments. Useful for understanding what a method does before applying
% it to data, or for debugging processing issues.
%
% Syntax:
%   pf2.methods.raw.describeMethod()
%   pf2.methods.raw.describeMethod(rawMethod)
%   pf2.methods.raw.describeMethod(methodIndex)
%   [descrip, functions] = pf2.methods.raw.describeMethod(...)
%
% Inputs:
%   rawMethod - Method identifier (optional), one of:
%               - String/char: Method name (e.g., 'x2_lpf_smar')
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
%   pf2.methods.raw.describeMethod();
%
%   % Describe a specific method by name
%   pf2.methods.raw.describeMethod('x2_lpf_smar');
%
%   % Get method details as variables for programmatic use
%   [desc, funcs] = pf2.methods.raw.describeMethod('x5_TDDR');
%   fprintf('Method has %d processing functions\n', length(funcs));
%
%   % Describe method by index
%   pf2.methods.raw.describeMethod(3);
%
% See also: pf2.methods.raw.list, pf2.methods.raw.setMethod,
%           pf2.methods.oxy.describeMethod, pf2.methods.describeCurrentMethods

if nargin < 2, ctx = []; end
methodsLib = pf2_base.resolveMethodsLib('raw', ctx);

if(nargin<1)
   rawMethod=pf2.methods.raw(true);
   getByIndex=false;
elseif(isnumeric(rawMethod))
    getByIndex=true;
else
    getByIndex=false;
end

% No current method selected (e.g. fresh install): report gracefully
% rather than failing the cfg lookup below.
if(~getByIndex && (isempty(rawMethod) || (ischar(rawMethod) && isempty(strtrim(rawMethod)))))
    msg=sprintf(['No current Raw Method selected.\n' ...
        'Use pf2.methods.raw.setMethod(...) to select one, ' ...
        'or pf2.methods.raw.list() to see available methods.\n']);
    if(nargout>0)
        descrip=msg;
        functions={};
    else
        fprintf(2,'%s',msg);
    end
    return;
end

    
if(isfield(methodsLib,'cfg')&&isfield(methodsLib.cfg,'Sections')&&~isempty(methodsLib.cfg.Sections))
    rawMethods=methodsLib.cfg.Sections;
    
    if(getByIndex)
        if(rawMethod>0&&rawMethod<=length(rawMethods))
            rawMethod=rawMethods{rawMethod};
        else
            error('Unable to find Raw Method at Index %i',rawMethod);
        end
    end
    
    if(ismember(rawMethod,rawMethods)&&~isempty(methodsLib.cfg.(rawMethod)))
        rawMethodCfg=methodsLib.cfg.(rawMethod);
    else
       error('Unable to find current Raw Method name %s',rawMethod); 
    end
    
    
    funcs=rawMethodCfg.F;
    
    descripStr=sprintf('Raw Method: %s\n',rawMethod);
    for f=1:length(funcs)
        curFunc=funcs{f};
        funcDescripStr=sprintf('%i. Function: %s\n',f,curFunc.f);
        for a=1:length(curFunc.args)
            if(iscell(curFunc.args))
                arg=curFunc.args{a};
                argVal=curFunc.argvals{a};
            else
                arg=curFunc.args;
                argVal=curFunc.argvals;
            end

            funcDescripStr=sprintf('%s\targ%i: \t%s\t%s\n',funcDescripStr,a,arg,num2strOrNot(argVal));      
        end

        
        if(isfield(curFunc,'output'))
            if(iscell(curFunc.output(1)))
                curFunc.output=curFunc.output{1}; 
            end
            funcDescripStr=sprintf('%s\toutput:\t%s\n',funcDescripStr,curFunc.output(1));
        
        end
        descripStr=sprintf('%s%s',descripStr,funcDescripStr);
    end
    
    if(nargout>0)
        descrip=descripStr;
        functions=funcs;
    else
        fprintf(descripStr);
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
    
    if(iscell(possibleStr)&&length(possibleStr)==1)
       possibleStr=possibleStr{1}; 
    end
end

