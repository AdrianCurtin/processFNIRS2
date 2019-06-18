function outStr=Raw()

global PF2

methodListStr='';

%rawMethods=PF2.myRawMethods.cfg.Sections;
if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections')&&length(PF2.myRawMethods.cfg.Sections)>0)

    
    rawMethods=PF2.myRawMethods.cfg.Sections;

    methodListStr=sprintf('%sCurrently Loaded Oxy Methods:\n\n',methodListStr);
    methodListStr=sprintf('%sRaw Processing Methods (Light->OD):\n',methodListStr);

    for i=1:length(rawMethods)
        methodListStr=sprintf('%s%i. %s\n',methodListStr,i,rawMethods{i});
    end

    %methodListStr=sprintf('%s\n',methodListStr);

    %methodListStr=sprintf('%sOxy Processing Methods (Hb->Hb-Processed):\n',methodListStr);

    %for i=1:length(oxyMethods)
    %	methodListStr=sprintf('%s%i. %s\n',methodListStr,i,oxyMethods{i});
    %end

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