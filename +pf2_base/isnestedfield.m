function isvalidfield=isnestedfield(var,nestedFieldString)

% Extends isfield by looking for each instance within a struct or object
%   Example: MyStruct.subfield1.subsubfield
%       isfield(MyStruct,'subfield1.subsubfield') should return true
%   Note: Also tests for the existence of properties in object


if(nargin<=1)
    isvalidfield=True;
else

    fieldParts=strsplit(nestedFieldString,'.');
    curPartName=fieldParts{1};
    
    isvalidfield=isfield(var,curPartName);
    if(isvalidfield)
        for i=2:length(fieldParts)
            var=var.(curPartName);
            curPartName=fieldParts{i};
            isvalidfield=isfield(var,curPartName)|isprop(var,curPartName);
            
            if(isempty(isvalidfield)||~isvalidfield)
                isvalidfield=false;
                break;
            end
        end
    end

end


end