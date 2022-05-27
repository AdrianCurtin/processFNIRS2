function isvalidfield=isnestedfield(var,nestedFieldString)

% Extends isfield by looking for each instance within a struct or object
%   Example: MyStruct.subfield1.subsubfield
%       isfield(MyStruct,'subfield1.subsubfield') should return true
%   Note: Also tests for the existence of properties in object


if(nargin<=1)
    isvalidfield=true;
else

    fieldParts=strsplit(nestedFieldString,'.');
    curPartName=fieldParts{1};
    
    %if(isstruct(var))
        isvalidfield=any(isfield(var,curPartName))||any(isprop(var,curPartName));
        
        if(isempty(isvalidfield)||~isvalidfield)
            isvalidfield=false;
            return;
        else
            for i=2:length(fieldParts)
                var=var.(curPartName);
                curPartName=fieldParts{i};
                
                if(istable(var))
                    isvalidfield=ismember(curPartName,var.Properties.VariableNames);
                    
                else
                    isvalidfield=isfield(var,curPartName)|(~istable(var)&isprop(var,curPartName));
                end
                
                

                if(isempty(isvalidfield)||~isvalidfield)
                    isvalidfield=false;
                    return;
                end
            end
        end
        
        
  

end


end