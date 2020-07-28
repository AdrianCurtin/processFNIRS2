function [OxyMethodsList,isCurrent]=Oxy(onlyCurrentMethod)

if(nargin<1)
    onlyCurrentMethod=false;
end


global PF2

methodListStr='';

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end


    
if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections')&&~isempty(PF2.myOxyMethods.cfg.Sections))
    oxyMethods=PF2.myOxyMethods.cfg.Sections;
    
    oxyMethodsCellStr=cell(length(oxyMethods),1);
    isCurrent=false(size(oxyMethodsCellStr));

    methodListStr=sprintf('%s\nCurrently Loaded Oxy Methods:\n',methodListStr);

    methodListStr=sprintf('%sOxy Processing Methods (Hb->Hb-Processed):\n',methodListStr);

    for i=1:length(oxyMethods)
        if(isfield(PF2,'stageOxyMethod')&&strcmpi(PF2.stageOxyMethod.name,oxyMethods{i}))
            methodListStr=sprintf('%s%i. %s <strong>(Current Method)</strong>\n',methodListStr,i,oxyMethods{i});
            isCurrent(i)=1;
        else
            methodListStr=sprintf('%s%i. %s\n',methodListStr,i,oxyMethods{i});
        end
        
        oxyMethodsCellStr{i}=oxyMethods{i};
    end

    if(nargout==0)
        fprintf('%s',methodListStr);
        return;
    else
        if(onlyCurrentMethod)
            OxyMethodsList=oxyMethodsCellStr{isCurrent};
        else
            OxyMethodsList=oxyMethodsCellStr;
        end
    end
else
   methodListStr=sprintf('No Oxy Processing Methods Loaded\nPlease import or configure methods first\n'); 

    if(nargout==0)
        fprintf(2,'%s',methodListStr);
        return;
    else
        oxyMethodsCellStr='';
    end
end