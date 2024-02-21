function [infoOut]=tablerow2struct (inputTable)

variableNames = inputTable.Properties.VariableNames;

numVariables = length(variableNames);

numRows = height(inputTable);

infoOut=[];

for i=1:numRows

    info = struct();
    
    for y = 1:numVariables
        curVariableName = variableNames{y};
        info.(curVariableName)=inputTable{i,curVariableName};
    end

    infoOut=[infoOut;info];
end