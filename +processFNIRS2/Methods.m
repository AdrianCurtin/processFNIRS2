function [RawMethodsList,OxyMethodsList,IsCurrent]=Methods(onlyCurrent)

if(nargin<1)
    
    onlyCurrent=false;
end


if(nargout==0)

    processFNIRS2.Methods.Raw();

    processFNIRS2.Methods.Oxy();






   return;
elseif(nargout>1)
    
    [RawMethods,isCur]=processFNIRS2.Methods.Raw();

    [OxyMethods,isCurB]=processFNIRS2.Methods.Oxy();

   RawMethodsList=RawMethods;
   OxyMethodsList=OxyMethods;
   IsCurrent{1}=isCur;
   IsCurrent{2}=isCurB;
   
   if(onlyCurrent)
       RawMethodsList=RawMethodsList(isCur);
       OxyMethodsList=OxyMethodsList(isCur);
   end
end

