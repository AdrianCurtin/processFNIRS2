function outStr=pf2_describeMethod(methodName,isRaw)
% pf2_describeMethod will take the method with the given name and in text,
% illustrate the procesing pipeline

if(nargin<2)
    methodName='lpf';
    isRaw=false;
end

global PF2
mdescrip='';

if(isRaw)
    if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections'))
        if(isfield(PF2.myRawMethods.cfg,methodName))
            rawMethod=pf2_base.pf2_unpackMethod(PF2.myRawMethods.cfg.(rawMethodStr));
        else
           fprintf(2,'\nDescribe Method Failed: Unable to find function name %s\n\n',methodName); 
        end
    end
else
    if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections'))
        if(isfield(PF2.myOxyMethods.cfg,methodName))
            oxyMethod=pf2_base.pf2_unpackMethod(PF2.myOxyMethods.cfg.(rawMethodStr));
        else
           fprintf(2,'\nDescribe Method Failed: Unable to find function name %s\n\n',methodName); 
        end
    end
end



if(nargout==0)
    fprintf(mdescrip);
    return;
else    
    outStr=mdescrip;
end

end