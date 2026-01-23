function [rawMethodsList,isCurrent]=raw(onlyCurrentMethod)

if(nargin<1)
    onlyCurrentMethod=false;
end

global PF2

methodListStr='';

if(isempty(PF2))
   pf2_base.pf2_initialize(); 
end

%rawMethods=PF2.myRawMethods.cfg.Sections;
if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections')&&length(PF2.myRawMethods.cfg.Sections)>0)
    rawMethods=PF2.myRawMethods.cfg.Sections;

    rawMethodsCellStr=cell(length(rawMethods),1);
    isCurrent=false(size(rawMethodsCellStr));
    
    methodListStr=sprintf('%s\nCurrently Loaded Raw Methods:\n',methodListStr);
    methodListStr=sprintf('%sRaw Processing Methods (Light->OD):\n',methodListStr);
    for i=1:length(rawMethods)
        if(isfield(PF2,'stageRawMethod')&&strcmpi(PF2.stageRawMethod.name,rawMethods{i}))
            methodListStr=sprintf('%s%i. %s <strong>(Current Method)</strong>\n',methodListStr,i,rawMethods{i});
            isCurrent(i)=1;
        else
            methodListStr=sprintf('%s%i. %s\n',methodListStr,i,rawMethods{i});
        end
        rawMethodsCellStr{i}=rawMethods{i};
    end

    if(nargout==0)
        fprintf('%s',methodListStr);
        return;
    else
        if(onlyCurrentMethod)
            rawMethodsList=rawMethodsCellStr{isCurrent};
        else
            rawMethodsList=rawMethodsCellStr;
        end
    end

else
    methodListStr=sprintf('No Oxy Processing Methods Loaded\nPlease import or configure methods first\n');
   
    
    if(nargout==0)
        fprintf(2,'%s',methodListStr); 
        return;
    else
        rawMethodsList='';
    end
end