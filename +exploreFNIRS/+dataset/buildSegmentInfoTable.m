function outTable=buildSegmentInfoTable(FNIRS_array)
% BUILDSEGMENTINFOTABLE Build a summary table from an array of fNIRS data structs
%
% Iterates over a cell array of processed fNIRS structs and extracts the
% .info fields from each into a standardized MATLAB table. Handles type
% mismatches and missing fields across segments by filling with NaN,
% empty strings, or NaT as appropriate.
%
% Syntax:
%   outTable = exploreFNIRS.dataset.buildSegmentInfoTable(FNIRS_array)
%
% Inputs:
%   FNIRS_array - Cell array of fNIRS data structs, each containing an
%                 .info sub-struct with metadata fields (e.g., subject ID,
%                 condition, age). Scalar numeric, string, char, logical,
%                 categorical, and single-cell table values are extracted.
%
% Outputs:
%   outTable - MATLAB table with one row per segment and columns for each
%              unique .info field found across all segments. Missing values
%              are filled with type-appropriate defaults.
%
% Example:
%   data = {seg1, seg2, seg3};  % cell array of fNIRS structs
%   infoTable = exploreFNIRS.dataset.buildSegmentInfoTable(data);
%   disp(infoTable);
%
% See also: exploreFNIRS.dataset.standardizeROIs, exploreFNIRS
    
warning off MATLAB:table:RowsAddedExistingVars

if(isempty(FNIRS_array))
    error('No Data to build exploreFNIRS data table!\n')
    return;
else
    
    numF=length(FNIRS_array);
    
    outTable=table();
    for i=1:numF
        fprintf('Row %i of %i\n',i,numF);

       curFNIRseg=FNIRS_array{i};
       
       if(~isfield(curFNIRseg,'info'))
           warning('All fNIRS segments must have a .info section');
           continue;
       end
       curFields=fields(curFNIRseg.info);
       for j=1:length(curFields)
           curFieldName=curFields{j};

           curField=curFNIRseg.info.(curFieldName);
           
           if(isempty(curField)|| ...
                   (isnumeric(curField)&&length(curField)==1)||...  %numeric items of 1
                   ischar(curField)||isstring(curField)||...        %strings or chars
                   (islogical(curField)&&length(curField)==1)||...   %logical values
                   (iscategorical(curField)&&length(curField)==1)||... %categorical values
                   (istable(curField)&&size(curField,1)==1&&size(curField,2)==1)) %singular tables
               
              if(istable(curField)&&size(curField,1)==1&&size(curField,2)==1)
                  curField=curField{1,1};
              end
              
              if(isstring(curField)||ischar(curField))
                    curField=string(strtrim(curField));
              end
              
               
              if(ismember(curFieldName,outTable.Properties.VariableNames)&&~isempty(curField))
                  if(strcmpi(curField,'missing')&&isnumeric(outTable.(curFieldName)(1,1)))
                      outTable.(curFieldName)(i,1)=nan;
                  else
                      outTable.(curFieldName)(i,1)=curField;
                  end
              elseif(~isempty(curField))
                  if(ischar(curField)) % adds columns
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=nominal(curField);
                  elseif(isstring(curField))
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=nominal(curField);
                  elseif(isnumeric(curField))
                      outTable.(curFieldName)=nan(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=curField;
                  elseif(islogical(curField))
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=nominal(string(curField));
                  elseif(iscategorical(curField))
                      outTable.(curFieldName)=strings(size(outTable,1),1);
                      outTable.(curFieldName)(i,1)=string(curField);
                  end
                  
              end
           end
       end

       missingFieldsIdx=~ismember(outTable.Properties.VariableNames,curFields);

       if(any(missingFieldsIdx))
           missingFieldsName=outTable.Properties.VariableNames(missingFieldsIdx);
           for f=1:length(missingFieldsName)
               switch(class(outTable.(missingFieldsName{f})))
                   case 'double'
                       outTable.(missingFieldsName{f})(i,:)=nan;
                   case 'string'
                       outTable.(missingFieldsName{f})(i,:)="";
                   case 'char'
                       outTable.(missingFieldsName{f})(i,:)='';
                   case 'cell'
                       outTable.(missingFieldsName{f})(i,:)={};
                   case 'logical'
                       outTable.(missingFieldsName{f})(i,:)=nan;
                   case 'duration'
                       outTable.(missingFieldsName{f})(i,:)=duration(0,0,nan);
                   case 'datetime'
                       outTable.(missingFieldsName{f})(i,:)=NaT;
                   otherwise
                        error('Unknown type!');
               end
              
           end
            
       end
    end
    %close(hF);
end
    