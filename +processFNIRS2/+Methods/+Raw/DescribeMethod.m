function [descrip,functions]=DescribeMethod(rawMethod)

global PF2

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end

if(nargin<1)
   rawMethod=processFNIRS2.Methods.Raw(true); 
   getByIndex=false;
elseif(isnumeric(rawMethod))
    getByIndex=true;
else
    getByIndex=false;
end

    
if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections')&&~isempty(PF2.myRawMethods.cfg.Sections))
    rawMethods=PF2.myRawMethods.cfg.Sections;
    
    if(getByIndex)
        if(rawMethodIndex>0&&rawMethodIndex<=length(rawMethods))
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
end

