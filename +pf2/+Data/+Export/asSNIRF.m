function [ ] = asSNIRF( fNIRcells, filepath )
%Takes fNIR struct and packages the .snirf file
%   Use to construct .snirf files for export and packaging

% data=pf2_base.external.jsnirfy.loadsnirf('2022-11-04_002.snirf');

if(nargin<1)
    error('No fnir file specified!');
end

if nargin<2
   [filename path]=uiputfile(['*.snirf']); 
    filepath=[path filename];
end

[ filepathdir , filename , ext ] = fileparts( filepath ) ;

logFilePath= strjoin([string(filepathdir) '/' string(filename) '.log'],'');


% Writing .snirf file

if(exist(filepathdir,'dir')~=7 && ~isempty(filepathdir))
    mkdir(filepathdir);
end

data=[];

data.formatVersion=c2v('1.0');

if(~iscell(fNIRcells)&&isstruct(fNIRcells))
    fNIRcells={fNIRcells};
else
    error('invalid fnirs data')
end

curNIR_fieldname='nirs';

numNIRS = length(fNIRcells);
nirIndex=0;

for n=1:numNIRS

    curStruct = fNIRcells{n};
    
    if(numNIRS>1)
        curNIR_fieldname='nirs'+n;
    end

    curNIRdata=[];

    metaDataTags=info2meta(curStruct);

    


    probe=[];
    
    data=[];
    stim=[];
    aux=[];


    curNIRdata.metaDataTags=metaDataTags;
    curNIRdata.probe=probe;
    
    curNIRdata.stim=stim;
    curNIRdata.data=data;
    curNIRdata.aux=aux;
    

    data.(curNIR_fieldname)=curNIRdata;

end

%  fid=fopen(filepath,'wt');
% 
%  if(fid<0)
%     error('Unable to access file for writing!');
%  end
% 
%  fprintf(fid,'fnirUSB.dll log file\r\n');
%  
%  fprintf(fid,'Start Time:\t');
%  if(isfield(fNIRstruct,'t0'))
%     fprintf(fid,'%s\r\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
%  else
%     fprintf(fid,'Wed Jan 1 1:01:01 2022\r\n');
%  end
% 
% fprintf(fid,'\r\n');
% 
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'startCode'))
%         startCode=fNIRstruct.info.header.startCode;
%     fprintf(fid,'Start Code:\t%.6f\t%i\r\n',startCode,startCode*1000);
% else
%  fprintf(fid,'Start Code:\t	9999.999999	99999999\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'freqCode'))
%         freqCode=fNIRstruct.info.header.freqCode;
%     fprintf(fid,'Freq Code:\t%.6f\r\n',freqCode);
% else
%  fprintf(fid,'Freq Code:\t	99999999.999999\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'current'))
%         current=fNIRstruct.info.header.current;
%     fprintf(fid,'Current:\t%.0f\r\n',current);
% else
%  fprintf(fid,'Current:\t	99\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'gains'))
%         gains=fNIRstruct.info.header.gains;
%     fprintf(fid,'Gains:\t%.0f\r\n',gains);
% else
%  fprintf(fid,'Gains:\t99\r\n');
% end
% 
%  fprintf(fid,'Other:\tnone\r\n');
%  
%  fprintf(fid,'-2\tBaseline Started\r\n');
% 
% 
%  arr=fNIRstruct.raw;
%  numLines=size(arr,1);
%  numCol=size(arr,2);
%  for x=1:numLines
%      fprintf(fid,'%.3f',fNIRstruct.time(x,1)); 
%     for y=2:numCol
%        fprintf(fid,'\t%.2f',arr(x,y)); 
%     end
%      fprintf(fid,'\r\n');
%      if(x==20)
%         fprintf(fid,'-3\tBaseline values\r\n');
%             fprintf(fid,'0'); 
%             for y=2:numCol
%                fprintf(fid,'\t%.2f',nanmean(arr(1:10,y))); 
%             end
%              fprintf(fid,'\r\n');
%         fprintf(fid,'-4\tBaseline end\r\n');
%      end
%  end
%  
%  fprintf(fid,'-1\tDevice Stopped\r\n');
%  fclose(fid);
%  fprintf('File successfully written to: %s\r\n',filepath);
% 
% 
% % Writing Marker file
% 
% fid=fopen(mrkFilePath,'wt');
%  fprintf(fid,'fnirUSB.dll marker file\r\n');
%  fprintf(fid,'Listening from SomePORT port\r\n');
%  
%  fprintf(fid,'Start Time:\t');
%  if(isfield(fNIRstruct,'t0'))
%     fprintf(fid,'%s\r\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
%  else
%     fprintf(fid,'Wed Jan 1 1:01:01 2022\r\n');
%  end
% 
% 
% 
% fprintf(fid,'\r\n');
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'startCode'))
%         startCode=fNIRstruct.info.header.startCode;
%     fprintf(fid,'Start Code:\t%.6f\t%i\r\n',startCode,startCode*1000);
% else
%  fprintf(fid,'Start Code:\t	9999.999999	99999999\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'freqCode'))
%         freqCode=fNIRstruct.info.header.freqCode;
%     fprintf(fid,'Freq Code:\t%.6f\r\n',freqCode);
% else
%  fprintf(fid,'Freq Code:\t	99999999.999999\r\n');
% end
% 
%  arr=fNIRstruct.markers;
%  numLines=size(arr,1);
%  numCol=size(arr,2);
%  for x=1:numLines
%      fprintf(fid,'%.3f',arr(x,1)); 
%     for y=2:numCol
%        fprintf(fid,'\t%.0f',arr(x,y)); 
%     end
%      fprintf(fid,'\r\n');
%    
%  end
%  fclose(fid);
%  fprintf('File successfully written to: %s\r\n',mrkFilePath);
% 
% 
%  if(length(fNIRstruct.info)>1)
%     fNIRstruct.info=fNIRstruct.info{1};
%  end
% 
% 
% % Writing Log file
% 
% fid=fopen(logFilePath,'wt');
%  fprintf(fid,'COBI log file 1.1\r\n');
%  fprintf(fid,'Current Device:\tfnirUSB.dll\r\n');
%  fprintf(fid,'Current Filter Module:\tFilters are OFF\r\n');
%  
%   fprintf(fid,'Start Time:\t');
%  if(isfield(fNIRstruct,'t0'))
%     fprintf(fid,'%s\r\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
%  else
%     fprintf(fid,'Wed Jan 1 1:01:01 2022\r\n');
%  end
% 
% 
% 
% fprintf(fid,'\r\n\r\n\r\n');
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'Experimenter'))
%         Experimenter=fNIRstruct.info.Experimenter;
%     fprintf(fid,'Experimenter:\r\n%s\r\n\r\n',Experimenter);
% else
%  fprintf(fid,'Experimenter:\r\n\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'SubjectID'))
%         SubjectID=fNIRstruct.info.SubjectID;
%     fprintf(fid,'SubjectID:\r\n%s\r\n\r\n',SubjectID);
% else
%  fprintf(fid,'SubjectID:\r\n\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Description'))
%         descrip=fNIRstruct.info.log_info.Description;
%     fprintf(fid,'Description:\r\n%s\r\n\r\n',descrip);
% else
%  fprintf(fid,'Description:\r\n\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'SubjectInfo'))
%         subInfo=fNIRstruct.info.log_info.SubjectInfo;
%     fprintf(fid,'Subject Info:\r\n%s\r\n\r\n',subInfo);
% else
%  fprintf(fid,'Subject Info:\r\n\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Comments'))
%         comments=fNIRstruct.info.log_info.Comments;
%     fprintf(fid,'Comments:\r\n%s\r\n - Generated by Export from processFNIRS2\r\n\r\n',comments);
% else
%  fprintf(fid,'Comments:\r\n - Generated by Export from processFNIRS2\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Flagged'))
%         Flagged=fNIRstruct.info.log_info.Flagged;
%     fprintf(fid,'Flagged:\r\n%s\r\n\r\n',Flagged);
% else
%  fprintf(fid,'Flagged:\r\n\r\n\r\n');
% end
% 
% if(isfield(fNIRstruct,'info')&&...
%     isfield(fNIRstruct.info,'probename'))
%         probename=fNIRstruct.info.probename;
%     fprintf(fid,'ProbeName:\r\n%s\r\n\r\n',probename);
% else
%  fprintf(fid,'ProbeName:Unknown\r\n\r\n\r\n');
% end
% 
%  if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
%     isfield(fNIRstruct.info.header,'Time'))
%         timestamp=fNIRstruct.info.header.Time;
%     fprintf(fid,'Original Start Time:\t');
%     for t=1:length(timestamp)
%         fprintf(fid,'%s ',timestamp{t});
%     end
%     fprintf(fid,'\r\n');   
% else
%  fprintf(fid,'Original Start Time:\tUnknown\r\n');
% end
% 
%  fprintf(fid,'Finalized Successfully');
% 
%  fclose(fid);
%  fprintf('File successfully written to: %s\r\n',logFilePath);
% 

end

function charOut=c2v(str)
    charOut=char(str)';
end

function metaData=info2meta(nirStruct)
    info=nirStruct.info;

    metaData=[];
    %SubjectID
    % MeasurementDate
    % MeasurementTime
    % LengthUnit
    % TimeUnit
    % FrequencyUnit
    % ... user fields

    infoFields=fields(info);

    for i = 1:length(infoFields)
        curField=info.(infoFields{i});

        if(isstring(curField)||ischar(curField))
            metaData.(infoFields{i})=c2v(curField);
        end
    end
    
end

