function [structOut]=mergestructs (inputStruct1,inputStruct2,overwriteValues)

if(nargin<3)
    overwriteValues=true;
end


structOut=inputStruct1;

structFields2=fields(inputStruct2);

numFields = length(structFields2);

for i=1:numFields

    curVariableName = structFields2{i};
    
    if(~overwriteValues)
        if(isfield(inputStruct1,curVariableName))
            continue;
        end
    end
        
    structOut.(curVariableName)=inputStruct2.(curVariableName);
end