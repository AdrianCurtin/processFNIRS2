function outStr=Oxy()

global PF2

methodListStr='';

    
if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections')&&length(PF2.myOxyMethods.cfg.Sections)>0)
    oxyMethods=PF2.myOxyMethods.cfg.Sections;

    methodListStr=sprintf('%s\nCurrently Loaded Oxy Methods:\n',methodListStr);

    methodListStr=sprintf('%sOxy Processing Methods (Hb->Hb-Processed):\n',methodListStr);

    for i=1:length(oxyMethods)
        if(strcmpi(PF2.stageRawMethod.name,oxyMethods{i}))
            methodListStr=sprintf('%s%i. %s <strong>(Current Method)</strong>\n',methodListStr,i,oxyMethods{i});
        else
            methodListStr=sprintf('%s%i. %s\n',methodListStr,i,oxyMethods{i});
        end
    end

    if(nargout==0)
        fprintf('%s',methodListStr);
        return;
    else
        outStr=methodListStr;
    end
else
   methodListStr=sprintf('No Oxy Processing Methods Loaded\nPlease import or configure methods first\n'); 
   
   
    if(nargout==0)
        fprintf(2,'%s',methodListStr);
        return;
    else
        outStr=methodListStr;
    end
end