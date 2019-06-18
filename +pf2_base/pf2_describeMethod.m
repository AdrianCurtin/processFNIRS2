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
            
        else
           fprintf(2,'\nUnable to find function name %s',methodName); 
        end
    end
else
    if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections'))
        if(isfield(PF2.myOxyMethods.cfg,methodName))
            
        else
           fprintf(2,'\nUnable to find function name %s',methodName); 
        end
    end
end



if(varargou==0)
    fprintf(mdescrip);
    return;
else    
    outStr=mdescrip;
end

end