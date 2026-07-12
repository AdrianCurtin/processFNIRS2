function [OxyMethodsList,isCurrent]=oxy(onlyCurrentMethod)
% OXY List the configured oxy (Stage 3) processing methods
%
% Reports the available Stage 3 processing methods, which operate on
% hemoglobin concentration data (HbO, HbR, ...) after Beer-Lambert
% conversion. With no output arguments the method list is printed to the
% console, with the currently selected method highlighted. With outputs it
% returns the method names and a flag marking the active one. Initializes the
% toolbox (pf2_initialize) if the global PF2 state is empty.
%
% Syntax:
%   pf2.methods.oxy()
%   oxyMethodsList = pf2.methods.oxy()
%   [oxyMethodsList, isCurrent] = pf2.methods.oxy()
%   [oxyMethodsList, isCurrent] = pf2.methods.oxy(onlyCurrentMethod)
%
% Inputs:
%   onlyCurrentMethod - If true, return only the currently selected method
%                       name rather than the full list (default: false)
%
% Outputs:
%   OxyMethodsList - Cell array of oxy method names, or a single name char
%                    when onlyCurrentMethod is true. Empty when none loaded.
%   isCurrent      - Logical vector flagging the active method in the list
%
% Example:
%   % Print available oxy methods
%   pf2.methods.oxy();
%
%   % Get only the currently selected oxy method name
%   current = pf2.methods.oxy(true);
%
% See also: pf2.methods.raw, pf2.methods.oxy.setMethod, pf2.methods

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
            if(any(isCurrent))
                OxyMethodsList=oxyMethodsCellStr{isCurrent};
            else
                OxyMethodsList='';   % no current method selected
            end
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
        OxyMethodsList='';
    end
end