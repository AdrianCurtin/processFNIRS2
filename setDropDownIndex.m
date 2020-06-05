function setDropDownIndex(dropDownHandle,itemIndex,arg3)

if(nargin<3)
    arg3=[];
end

if(nargin==3)
    itemIndex=arg3;
end

dropDownHandle.ItemsData=1:length(dropDownHandle.Items);
dropDownHandle.Value=itemIndex;