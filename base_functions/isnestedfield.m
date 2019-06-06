function isvalidfield=isnestedfield(var,nestedFieldString)

% Extends isfield by looking for each instance within an object
%   Example: MyStruct.subfield1.subsubfield
%       isfield(MyStruct,'subfield1.subsubfield') should return true


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
            isvalidfield=isfield(var,curPartName);
            
            if(~isvalidfield)
                isvalidfield=false;
                break;
            end
        end
    end

end


end