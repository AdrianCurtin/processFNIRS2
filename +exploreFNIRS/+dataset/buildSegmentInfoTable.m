function outTable=buildSegmentInfoTable(FNIRS_array)

% standardizes all rows and types for provdied array 
    
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
    