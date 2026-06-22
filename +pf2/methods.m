function [RawMethodsList,OxyMethodsList,IsCurrent]=methods(onlyCurrent)
% METHODS List both raw and oxy processing methods in one call
%
% Convenience entry point that reports the configured Stage 1 (raw, light to
% optical density) and Stage 3 (oxy, hemoglobin) processing methods together.
% With no output arguments it prints both lists to the console; with outputs
% it returns the method names and a flag marking the currently active method
% in each stage. Delegates to pf2.methods.raw and pf2.methods.oxy.
%
% Syntax:
%   pf2.methods()
%   [rawList, oxyList, isCurrent] = pf2.methods()
%   [rawList, oxyList, isCurrent] = pf2.methods(onlyCurrent)
%
% Inputs:
%   onlyCurrent - If true, restrict the returned lists to the currently
%                 selected method in each stage (default: false)
%
% Outputs:
%   RawMethodsList - Cell array of raw (Stage 1) method names
%   OxyMethodsList - Cell array of oxy (Stage 3) method names
%   IsCurrent      - 1x2 cell: {rawCurrentMask, oxyCurrentMask}, each a
%                    logical vector flagging the active method per stage
%
% Example:
%   % Print both method lists to the console
%   pf2.methods();
%
%   % Capture the lists and the active-method flags
%   [rawList, oxyList, isCurrent] = pf2.methods();
%
% See also: pf2.methods.raw, pf2.methods.oxy, pf2.methods.describeCurrentMethods

if(nargin<1)
    
    onlyCurrent=false;
end


if(nargout==0)

    pf2.methods.raw();

    pf2.methods.oxy();






   return;
elseif(nargout>1)
    
    [RawMethods,isCur]=pf2.methods.raw();

    [OxyMethods,isCurB]=pf2.methods.oxy();

   RawMethodsList=RawMethods;
   OxyMethodsList=OxyMethods;
   IsCurrent{1}=isCur;
   IsCurrent{2}=isCurB;
   
   if(onlyCurrent)
       RawMethodsList=RawMethodsList(isCur);
       OxyMethodsList=OxyMethodsList(isCur);
   end
end

