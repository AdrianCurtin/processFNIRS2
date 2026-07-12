function [rawMethodsList,isCurrent]=raw(onlyCurrentMethod)
% RAW List the configured raw (Stage 1) processing methods
%
% Reports the available Stage 1 processing methods, which transform raw light
% intensity into optical density. With no output arguments the method list is
% printed to the console, with the currently selected method highlighted.
% With outputs it returns the method names and a flag marking the active one.
% Initializes the toolbox (pf2_initialize) if the global PF2 state is empty.
%
% Syntax:
%   pf2.methods.raw()
%   rawMethodsList = pf2.methods.raw()
%   [rawMethodsList, isCurrent] = pf2.methods.raw()
%   [rawMethodsList, isCurrent] = pf2.methods.raw(onlyCurrentMethod)
%
% Inputs:
%   onlyCurrentMethod - If true, return only the currently selected method
%                       name rather than the full list (default: false)
%
% Outputs:
%   rawMethodsList - Cell array of raw method names, or a single name char
%                    when onlyCurrentMethod is true. Empty when none loaded.
%   isCurrent      - Logical vector flagging the active method in the list
%
% Example:
%   % Print available raw methods
%   pf2.methods.raw();
%
%   % Get only the currently selected raw method name
%   current = pf2.methods.raw(true);
%
% See also: pf2.methods.oxy, pf2.methods.raw.setMethod, pf2.methods

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
            if(any(isCurrent))
                rawMethodsList=rawMethodsCellStr{isCurrent};
            else
                rawMethodsList='';   % no current method selected
            end
        else
            rawMethodsList=rawMethodsCellStr;
        end
    end

else
    methodListStr=sprintf('No Raw Processing Methods Loaded\nPlease import or configure methods first\n');
   
    
    if(nargout==0)
        fprintf(2,'%s',methodListStr); 
        return;
    else
        rawMethodsList='';
    end
end