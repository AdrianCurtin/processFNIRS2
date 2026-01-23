function isvalidfield=isnestedfield(var,nestedFieldString)
% ISNESTEDFIELD Check nested struct fields using dot notation
%
% Extends MATLAB's built-in isfield to support nested field paths with dot
% notation (e.g., 'subfield1.subfield2.subfield3'). Also supports table
% variable names and object properties. Returns true if the complete path
% exists, false otherwise.
%
% Syntax:
%   isvalidfield = isnestedfield(var, nestedFieldString)
%
% Inputs:
%   var               - Structure, object, or table to check
%                       Can be any type; numeric/string/logical returns false.
%   nestedFieldString - Field path using dot notation (e.g., 'info.header.date')
%                       Each component is checked sequentially. Empty or missing
%                       returns true (no-op case).
%
% Outputs:
%   isvalidfield - Logical scalar indicating if nested field exists
%                  Returns false if path is invalid at any level.
%
% Algorithm:
%   1. Split nestedFieldString by '.' delimiter into components
%   2. For each component, check if it exists as field, property, or table var
%   3. Navigate deeper into structure for each valid component
%   4. Return false if any component is missing or type mismatch occurs
%
% Example:
%   % Check nested field in fNIRS data structure
%   data = pf2.Import.SampleData.fNIR2000();
%   hasHeader = isnestedfield(data, 'info.header');  % true
%   hasSubID = isnestedfield(data, 'info.SubjectID');  % true
%   hasBadPath = isnestedfield(data, 'info.header.nonexistent');  % false
%
%   % Works with tables
%   T = table([1; 2], [3; 4], 'VariableNames', {'A', 'B'});
%   hasA = isnestedfield(T, 'A');  % true
%
% See also: isfield, isprop, isstruct, istable


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

