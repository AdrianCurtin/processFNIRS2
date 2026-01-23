function [descrip,functions]=DescribeMethod(rawMethod)
% DESCRIBEMETHOD Display detailed information about a raw processing method
%
% Shows the complete configuration of a raw processing method, including
% all processing functions in the pipeline, their arguments, and output
% assignments. Useful for understanding what a method does before applying
% it to data, or for debugging processing issues.
%
% Syntax:
%   pf2.Methods.Raw.DescribeMethod()
%   pf2.Methods.Raw.DescribeMethod(rawMethod)
%   pf2.Methods.Raw.DescribeMethod(methodIndex)
%   [descrip, functions] = pf2.Methods.Raw.DescribeMethod(...)
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
%   pf2.Methods.Raw.DescribeMethod();
%
%   % Describe a specific method by name
%   pf2.Methods.Raw.DescribeMethod('x2_lpf_smar');
%
%   % Get method details as variables for programmatic use
%   [desc, funcs] = pf2.Methods.Raw.DescribeMethod('x5_TDDR');
%   fprintf('Method has %d processing functions\n', length(funcs));
%
%   % Describe method by index
%   pf2.Methods.Raw.DescribeMethod(3);
%
% See also: pf2.Methods.Raw.List, pf2.Methods.Raw.SetMethod,
%           pf2.Methods.Oxy.DescribeMethod, pf2.Methods.DescribeCurrentMethods

global PF2

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end

if(nargin<1)
   rawMethod=pf2.Methods.Raw(true); 
   getByIndex=false;
elseif(isnumeric(rawMethod))
    getByIndex=true;
else
    getByIndex=false;
end

    
if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections')&&~isempty(PF2.myRawMethods.cfg.Sections))
    rawMethods=PF2.myRawMethods.cfg.Sections;
    
    if(getByIndex)
        if(rawMethod>0&&rawMethod<=length(rawMethods))
            rawMethod=rawMethods{rawMethod};
        else
            error('Unable to find Raw Method at Index %i',rawMethod);
        end
    end
    
    if(ismember(rawMethod,rawMethods)&&~isempty(PF2.myRawMethods.cfg.(rawMethod)))
        rawMethodCfg=PF2.myRawMethods.cfg.(rawMethod);
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

