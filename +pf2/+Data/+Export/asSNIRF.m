function [ snirfData] = asSNIRF( fNIRcells, filepath )
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

snirfData=[];

snirfData.formatVersion=c2v('1.0');

if(~iscell(fNIRcells)&&isstruct(fNIRcells))
    fNIRcells={fNIRcells};
else
    error('invalid fnirs data')
end

curNIR_fieldname='nirs';

numNIRS = length(fNIRcells);

for n=1:numNIRS

    curStruct = fNIRcells{n};
    
    if(numNIRS>1)
        curNIR_fieldname='nirs'+n;
    end

    curNIRdata=[];

    metaDataTags=info2meta(curStruct);

    [probe,measurementList,probeMetaData]=buildProbe(curStruct);

    probeFields=fields(probeMetaData);
    for p=1:length(probeFields)
        metaDataTags.(probeFields{p})=probeMetaData.(probeFields{p});
    end
    
    data=[];
    data.dataTimeSeries=curStruct.raw;
    data.time = curStruct.time';
    data.measurementList=measurementList;


    stim=[];

    if(~isempty(curStruct.markers))
        [uStim,~,stimIndex]=unique(curStruct.markers(:,2));
        nStim=length(uStim);

        for n=1:nStim
            %stimFieldName=sprintf('stim%i',n);

            if(istable(curStruct.markers))
                stimItem=[];
                stimItem.name=curStruct.markers.name;
            else
                stimIdx=curStruct.markers(:,2)==uStim(n);
                stimItem=[];
                stimItem.name=sprintf('mrk%i',uStim(n));
                stimItem.data=curStruct.markers(stimIdx,[1,3,2]); % use column 3 as time [time, duration, marker value'
                %stimItem.data(:,2)=1; % set all stim durations to 1 for now
            end

            if(n==1)
                stim=stimItem;
            else
                stim=[stim;stimItem];
            end
        end
    end
    

    aux=[];
    

    curNIRdata.metaDataTags=metaDataTags;
    curNIRdata.probe=probe;

    
    curNIRdata.stim=stim;
    curNIRdata.data=data;
    curNIRdata.aux=aux;
    

    snirfData.(curNIR_fieldname)=curNIRdata;

end

if(isstring(filepath))
    filepath=char(filepath);
end

pf2_base.external.jsnirfy.savesnirf(snirfData,filepath);

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
    charOut=char(str);
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

    metaData.TimeUnit=c2v('s');
    metaData.LengthUnit=c2v('mm');
    metaData.FrequencyUnit=c2v('hz');
    
    if(isfield(nirStruct,'t0')&&~ismember('MeasurementDate',infoFields))
        metaData.MeasurementDate=c2v(sprintf('%i-%02d-%02d',year(nirStruct.t0),month(nirStruct.t0),day(nirStruct.t0)));
        ms=floor(rem(second(nirStruct.t0),1)*1000);
        tzd='z';
        warning('time zone should still be set properly');
        metaData.MeasurementTime=c2v(sprintf('%02d:%02d:%02d.%03d%s',hour(nirStruct.t0),minute(nirStruct.t0),floor(second(nirStruct.t0)),ms,tzd)); 
        metaData.AcquisitionStartTime=num2str(posixtime(nirStruct.t0+seconds(min(nirStruct.time))));
        metaData.UnixTime=num2str(posixtime(nirStruct.t0));
        
    end

    if(isfield(info,'SubjectId'))
        metaData.SubjectID=c2v(into.SubjectId);
    end
    

    for i = 1:length(infoFields)
        curField=info.(infoFields{i});

        if(isstring(curField)||ischar(curField))
            metaData.(infoFields{i})=c2v(curField);
        end
    end
    
end

function [probe,measurementList,deviceMetaDataTags]=buildProbe(nirStruct)

    if(isfield(nirStruct,'probeinfo'))
        probeStruct=nirStruct.probeinfo.Probe{1};
        deviceInfoFields=nirStruct.probeinfo.Info;
        
    else
        % attempt to load probe from probe name

        if(isfield(nirStruct.info,'probename'))
              probename = nirStruct.info.probename;

              if(~contains(probename,'cfg'))
                probename=sprintf('%s.cfg',probename);
              end
              device=pf2_base.loadDeviceCfg(probename);
              deviceInfoFields=device.Info;
              probeStruct=device.Probe{1};
        else
              device = pf2_base.loadDeviceCfg();
              deviceInfoFields=device.Info;
              probeStruct=device.Probe{1};
        end

    end


    deviceMetaDataTags=[];
    if(isfield(deviceInfoFields,'Manufacturer'))
        deviceMetaDataTags.ManufacturerName=c2v(deviceInfoFields.Manufacturer);
    end
    if(isfield(deviceInfoFields,'Name'))
        deviceMetaDataTags.Model=c2v(deviceInfoFields.Name);
    end

   

    measurementList=[];

    tableCh=probeStruct.TableCh;

    if(isfield(probeStruct,'Wavelength'))
        wvList= probeStruct.Wavelength;
        wvI=probeStruct.wvI;
    else
        [wvList,~,wvI]=unique(tableCh.Wavelength);
    end
    if(~any(wvList==0))
        wvList(end+1)=0;
        darkIdx=length(wvList);
    else
        darkIdx=find(wvList==0);
    end
    

    for i = 1:size(nirStruct.raw,2)
        measurement=[];

        curCh=tableCh(i,:);

        if(curCh.isTime(1))
            measurement.dataType=0; 
            measurement.dataTypeIndex=1;
            measurement.dataTypeLabel='time-signal';
            measurement.detectorIndex=nan;
            measurement.sourceIndex=nan;
            measurement.wavelengthIndex=nan;
            measurement.wavelengthActual=nan;
        elseif(curCh.isMarker(1))
            measurement.dataType=0; 
            measurement.dataTypeIndex=1;
            measurement.dataTypeLabel='marker-signal';
            measurement.detectorIndex=nan;
            measurement.sourceIndex=nan;
            measurement.wavelengthIndex=nan;
            measurement.wavelengthActual=nan;
        elseif(curCh.isDark(1))
            measurement.dataType=1; 
            measurement.dataTypeIndex=1;
            measurement.dataTypeLabel='raw-DC-dark';
            measurement.detectorIndex=tableCh.DetectorIndex(i);
            measurement.sourceIndex=tableCh.SourceIndex(i);
            measurement.wavelengthIndex=wvI(i);
            measurement.wavelengthActual=wvList(darkIdx);
        else
            measurement.dataType=1; 
            measurement.dataTypeIndex=1;
            measurement.dataTypeLabel='raw-DC';
            measurement.detectorIndex=tableCh.DetectorIndex(i);
            measurement.sourceIndex=tableCh.SourceIndex(i);
            measurement.wavelengthIndex=wvI(i);
            measurement.wavelengthActual=(wvList(measurement.wavelengthIndex));
        end
      
        if(i==1)
            measurementList=measurement;
        else
            measurementList=[measurementList;measurement];
        end
    end

     probe=[];

     if(height(probeStruct.DetPos)==height(probeStruct.SrcPos)&& ...
            height(probeStruct.TableOpt)==height(probeStruct.DetPos))
         [~,firstDetIdx] = unique(probeStruct.TableOpt.DetIdx);
         [~,firstSrcIdx] = unique(probeStruct.TableOpt.SrcIdx);
     else
        firstDetIdx=1:height(probeStruct.DetPos);
        firstSrcIdx=1:height(probeStruct.SrcPos);
     end

     probe.detectorPos2D=table2array(probeStruct.DetPos(firstDetIdx,{'x_2d','y_2d'}));
     probe.detectorPos3D=table2array(probeStruct.DetPos(firstDetIdx,{'x','y','z'}));
     
     probe.sourcePos2D=table2array(probeStruct.SrcPos(firstSrcIdx,{'x_2d','y_2d'}));
     probe.sourcePos3D=table2array(probeStruct.SrcPos(firstSrcIdx,{'x','y','z'}));

     if(isfield(probeStruct,'landmarkPos3D'))
        probe.landmarkPos3D=probeStruct.landmarkPos3D;
     end
     if(isfield(probeStruct,'landmarkLabels'))
        probe.landmarkLabels=probeStruct.landmarkLabels;
     end
     
     probe.wavelengths=wvList';
end

