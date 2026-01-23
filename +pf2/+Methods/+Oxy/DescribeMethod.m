function [descrip,functions]=DescribeMethod(oxyMethod)
% DESCRIBEMETHOD Display detailed information about an oxy processing method
%
% Shows the complete configuration of an oxy (hemoglobin) processing method,
% including all processing functions in the pipeline, their arguments, and
% output assignments. Useful for understanding what a method does before
% applying it to data, or for debugging processing issues.
%
% Syntax:
%   pf2.Methods.Oxy.DescribeMethod()
%   pf2.Methods.Oxy.DescribeMethod(oxyMethod)
%   pf2.Methods.Oxy.DescribeMethod(methodIndex)
%   [descrip, functions] = pf2.Methods.Oxy.DescribeMethod(...)
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
%   pf2.Methods.Oxy.DescribeMethod();
%
%   % Describe a specific method by name
%   pf2.Methods.Oxy.DescribeMethod('takizawa_easy_lpf');
%
%   % Get method details as variables for programmatic use
%   [desc, funcs] = pf2.Methods.Oxy.DescribeMethod('medfilt_car');
%   fprintf('Method has %d processing functions\n', length(funcs));
%
%   % Describe method by index
%   pf2.Methods.Oxy.DescribeMethod(3);
%
% See also: pf2.Methods.Oxy.List, pf2.Methods.Oxy.SetMethod,
%           pf2.Methods.Raw.DescribeMethod, pf2.Methods.DescribeCurrentMethods

global PF2

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end

if(nargin<1)
   oxyMethod=pf2.Methods.Oxy(true); 
   getByIndex=false;
elseif(isnumeric(oxyMethod))
    getByIndex=true;
else
    getByIndex=false;
end

    
if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections')&&~isempty(PF2.myOxyMethods.cfg.Sections))
    oxyMethods=PF2.myOxyMethods.cfg.Sections;
    
    if(getByIndex)
        if(oxyMethod>0&&oxyMethod<=length(oxyMethods))
            oxyMethod=oxyMethods{oxyMethod};
        else
            error('Unable to find Oxy Method at Index %i',oxyMethod);
        end
    end
    
    if(ismember(oxyMethod,oxyMethods)&&~isempty(PF2.myOxyMethods.cfg.(oxyMethod)))
        oxyMethodCfg=PF2.myOxyMethods.cfg.(oxyMethod);
    else
       error('Unable to find current Oxy Method name %s',oxyMethod); 
    end
    
    
    funcs=oxyMethodCfg.F;
    
    descripStr=sprintf('Oxy Method: %s\n',oxyMethod);
    for f=1:length(funcs)
        curFunc=funcs{f};
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

