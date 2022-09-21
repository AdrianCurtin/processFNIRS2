function isvalidfield=isnestedfield(var,nestedFieldString)

% Extends isfield by looking for each instance within a struct or object
%   Example: MyStruct.subfield1.subsubfield
%       isfield(MyStruct,'subfield1.subsubfield') should return true
%   Note: Also tests for the existence of properties in object


if(nargin<=1)
    isvalidfield=true;
else

    fieldParts=strsplit(nestedFieldString,'.');
    for i=1:length(fieldParts)
        
        curPartName=fieldParts{i};
        if(isnumeric(var)||isstring(var)||islogical(var))%gone too deep or too shallow
            isvalidfield=false;
        elseif(istable(var))
            isvalidfield=ismember(curPartName,var.Properties.VariableNames);
        else
            isvalidfield=isfield(var,curPartName)|(~istable(var)&isprop(var,curPartName));
        end
        
        

        if(all(isempty(isvalidfield))||all(~isvalidfield))
            isvalidfield=false;
            return;
        end

        var=var.(curPartName);
    end
end
        
        
  

end

