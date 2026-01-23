function [infoOut]=tablerow2struct (inputTable)
% TABLEROW2STRUCT Convert table rows to structure array
%
% Converts each row of a MATLAB table into a structure, where each table
% variable becomes a field in the structure. Useful for converting tabular
% data into a format suitable for iteration and field-based access.
%
% Syntax:
%   infoOut = tablerow2struct(inputTable)
%
% Inputs:
%   inputTable - MATLAB table with any number of rows and variables
%                Each row will become one element in the output struct array.
%
% Outputs:
%   infoOut - Structure array [N x 1 struct] where N = number of table rows
%             Each structure has fields corresponding to table variable names.
%             Empty array [] if input table is empty.
%
% Example:
%   % Create a sample table
%   T = table([1; 2; 3], {'A'; 'B'; 'C'}, [10; 20; 30], ...
%             'VariableNames', {'ID', 'Name', 'Value'});
%   S = tablerow2struct(T);
%   disp(S(1).Name);  % Displays 'A'
%
% See also: struct2table, table2struct

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