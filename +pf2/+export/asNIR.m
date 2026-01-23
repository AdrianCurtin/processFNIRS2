function [ ] = asNIR( fNIRstruct, filepath )
%Takes fNIR struct and writes the basic nir file
%   Use to construct artificial .nir files for future analysis

if(nargin<1)
    error('No fnirs specified!');
end

if nargin<2
   [filename path]=uiputfile(['*.nir']); 
    filepath=[path filename];
end

[ filepathdir , filename , ext ] = fileparts( filepath ) ;

mrkFilePath= strjoin([string(filepathdir) '/' string(filename) '.mrk'],'');
logFilePath= strjoin([string(filepathdir) '/' string(filename) '.log'],'');


% Writing .NIR file

if(exist(filepathdir,'dir')~=7)
    mkdir(filepathdir);
end

 fid=fopen(filepath,'wt');

 if(fid<0)
    error('Unable to access file for writing!');
 end

 fprintf(fid,'fnirUSB.dll log file\n');
 
 fprintf(fid,'Start Time:\t');
 if(isfield(fNIRstruct,'t0'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 elseif(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&isfield(fNIRstruct.info.header,'StartDateTime'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.info.header.StartDateTime,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 else
    fprintf(fid,'Wed Jan 1 1:01:01 2022\n');
 end

fprintf(fid,'\n');


if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'startCode'))
        startCode=fNIRstruct.info.header.startCode;
    fprintf(fid,'Start Code:\t%.6f\t%i\n',startCode,startCode*1000);
else
 fprintf(fid,'Start Code:\t	9999.999999	99999999\n');
end

if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'freqCode'))
        freqCode=fNIRstruct.info.header.freqCode;
    fprintf(fid,'Freq Code:\t%.6f\n',freqCode);
else
 fprintf(fid,'Freq Code:\t	99999999.999999\n');
end

if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'current'))
        current=fNIRstruct.info.header.current;
    fprintf(fid,'Current:\t%.0f\n',current);
else
 fprintf(fid,'Current:\t	99\n');
end

if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'gains'))
        gains=fNIRstruct.info.header.gains;
    fprintf(fid,'Gains:\t%.0f\n',gains);
else
 fprintf(fid,'Gains:\t99\n');
end

 fprintf(fid,'Other:\tnone\n');
 
 fprintf(fid,'-2\tBaseline Started\n');


 arr=fNIRstruct.raw;
 numLines=size(arr,1);
 numCol=size(arr,2);
 for x=1:numLines
     fprintf(fid,'%.3f',fNIRstruct.time(x,1)); 
    for y=2:numCol
       fprintf(fid,'\t%.2f',arr(x,y)); 
    end
     fprintf(fid,'\n');
     if(x==20)
        fprintf(fid,'-3\tBaseline values\n');
            fprintf(fid,'0'); 
            for y=2:numCol
               fprintf(fid,'\t%.2f',nanmean(arr(1:10,y))); 
            end
             fprintf(fid,'\n');
        fprintf(fid,'-4\tBaseline end\n');
     end
 end
 
 fprintf(fid,'-1\tDevice Stopped\n');
 fclose(fid);
 fprintf('File successfully written to: %s\n',filepath);


% Writing Marker file

fid=fopen(mrkFilePath,'wt');
 fprintf(fid,'fnirUSB.dll marker file\n');
 fprintf(fid,'Listening from SomePORT port\n');
 
 fprintf(fid,'Start Time:\t');
 if(isfield(fNIRstruct,'t0'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 elseif(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&isfield(fNIRstruct.info.header,'StartDateTime'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.info.header.StartDateTime,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 else
    fprintf(fid,'Wed Jan 1 1:01:01 2022\n');
 end



fprintf(fid,'\n');

if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'startCode'))
        startCode=fNIRstruct.info.header.startCode;
    fprintf(fid,'Start Code:\t%.6f\t%i\n',startCode,startCode*1000);
else
 fprintf(fid,'Start Code:\t	9999.999999	99999999\n');
end

if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'freqCode'))
        freqCode=fNIRstruct.info.header.freqCode;
    fprintf(fid,'Freq Code:\t%.6f\n',freqCode);
else
    fprintf(fid,'Freq Code:\t	99999999.999999\n');
end

 arr=fNIRstruct.markers;
 numLines=size(arr,1);
 numCol=size(arr,2);
 for x=1:numLines
     fprintf(fid,'%.3f',arr(x,1)); 
    for y=2:numCol
        if(rem(arr(x,y),1)==0)
            fprintf(fid,'\t%.0f',arr(x,y));
        else
            fprintf(fid,'\t%.3f',arr(x,y));
        end
    end
     fprintf(fid,'\n');
   
 end
 fclose(fid);
 fprintf('File successfully written to: %s\n',mrkFilePath);


 if(length(fNIRstruct.info)>1)
    fNIRstruct.info=fNIRstruct.info{1};
 end


% Writing Log file

fid=fopen(logFilePath,'wt');
 fprintf(fid,'COBI log file 1.1\n');
 fprintf(fid,'Current Device:\tfnirUSB.dll\n');
 fprintf(fid,'Current Filter Module:\tFilters are OFF\n');
 
  fprintf(fid,'Start Time:\t');
 if(isfield(fNIRstruct,'t0'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.t0,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 elseif(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&isfield(fNIRstruct.info.header,'StartDateTime'))
    fprintf(fid,'%s\n',datestr(fNIRstruct.info.header.StartDateTime,'ddd mmm DD hh:MM:ss.FFF yyyy'));
 else
    fprintf(fid,'Wed Jan 1 1:01:01 2022\n');
 end



fprintf(fid,'\n\n\n');

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'Experimenter'))
        Experimenter=fNIRstruct.info.Experimenter;
    fprintf(fid,'Experimenter:\n%s\n\n',Experimenter);
else
 fprintf(fid,'Experimenter:\n\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'SubjectID'))
        SubjectID=fNIRstruct.info.SubjectID;
    fprintf(fid,'SubjectID:\n%s\n\n',SubjectID);
else
 fprintf(fid,'SubjectID:\n\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Description'))
        descrip=fNIRstruct.info.log_info.Description;
    fprintf(fid,'Description:\n%s\n\n',descrip);
else
 fprintf(fid,'Description:\n\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'SubjectInfo'))
        subInfo=fNIRstruct.info.log_info.SubjectInfo;
    fprintf(fid,'Subject Info:\n%s\n\n',subInfo);
else
 fprintf(fid,'Subject Info:\n\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Comments'))
        comments=fNIRstruct.info.log_info.Comments;
    fprintf(fid,'Comments:\n%s\n - Generated by Export from processFNIRS2\n\n',comments);
else
 fprintf(fid,'Comments:\n - Generated by Export from processFNIRS2\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'log_info')&&isfield(fNIRstruct.info.log_info,'Flagged'))
        Flagged=fNIRstruct.info.log_info.Flagged;
    fprintf(fid,'Flagged:\n%s\n\n',Flagged);
else
 fprintf(fid,'Flagged:\n\n\n');
end

if(isfield(fNIRstruct,'info')&&...
    isfield(fNIRstruct.info,'probename'))
        probename=fNIRstruct.info.probename;
    fprintf(fid,'ProbeName:\n%s\n\n',probename);
else
 fprintf(fid,'ProbeName:Unknown\n\n\n');
end

 if(isfield(fNIRstruct,'info')&&isfield(fNIRstruct.info,'header')&&...
    isfield(fNIRstruct.info.header,'Time'))
        timestamp=fNIRstruct.info.header.Time;
    fprintf(fid,'Original Start Time:\t');
    for t=1:length(timestamp)
        fprintf(fid,'%s ',timestamp{t});
    end
    fprintf(fid,'\n');   
else
 fprintf(fid,'Original Start Time:\tUnknown\n');
end

 fprintf(fid,'Finalized Successfully');

 fclose(fid);
 fprintf('File successfully written to: %s\n',logFilePath);


end

