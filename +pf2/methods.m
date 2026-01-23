function [RawMethodsList,OxyMethodsList,IsCurrent]=methods(onlyCurrent)

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

