function [fNIR] = ImportNIR(nir_filename,mrk_filename,channelCheck)
% Function to import .nir files produced by COBI Studio software
% Assumes time is firs line in data

% Change Log
% 4/30/2019 - Fixed error where incomplete baseline would result in an
% error
% 3/29/2019 - modified so that mrk_filename can be loaded as cell list of filenames, variable names also changed
%			- added separate functions for manual and automatic file loading. Manual marker now uses strsplit to avoid scientific notation errors and fscanf
%			- fixed an error where lack of info field would crash import
% 2/1/2019  - modified function so that output is contained in an fNIR struct rather than as separate baseline arguments
%			- markers are now output in fNIR.markers   (instead of just markers)
%			- marker header info and other info is now found in fNIR.info.mrkheaders
%			- changed default so that baseline data is included seamlessley with other datasets as a continous dataset

fNIR=[]; % placeholder initializations
data=[]; 
markers=[];
baseline=[];
fchMask=[];
autoLoadMrk=true;

forceChannelCheck=false; % if channelcheck is enabled manually, then honor, otherwise load only first time

if nargin < 1 % No Arguments - Open fNIRS and mrk file
	[nir_filename, pathname] = uigetfile({'*.nir';'*.*'},'Open fNIRS nir_filename');
	nir_filename=[pathname nir_filename];
    
    if(isempty(nir_filename)||~isstr(nir_filename))
       return; 
    end
	
	[mrk_filename, pathnameM] = uigetfile({'*.mrk';'*.*'},'Open fNIRS mrk nir_filename',pathname);
	mrk_filename=[pathnameM mrk_filename];
    
    if(~isstr(mrk_filename)) %cancelled
        mrk_filename=[];
    end
    autoLoadMrk=false;
	channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
elseif nargin<2
    if(isempty(nir_filename))
        [nir_filename, pathname] = uigetfile({'*.nir';'*.*'},'Open fNIRS nir_filename');
        nir_filename=[pathname nir_filename];

        if(isempty(nir_filename)||~isstr(nir_filename))
           return; 
        end
    end
    
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
    mrk_filename=[];
    autoLoadMrk=true;
elseif nargin<3
    if(isempty(nir_filename))
        [nir_filename, pathname] = uigetfile({'*.nir';'*.*'},'Open fNIRS nir_filename');
        nir_filename=[pathname nir_filename];

        if(isempty(nir_filename)||~isstr(nir_filename))
           return; 
        end
    end
    
    if(islogical(mrk_filename))
        autoLoadMrk=mrk_filename; 
    else
       autoLoadMrk=false; 
    end
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
else
    if(isempty(nir_filename))
        [nir_filename, pathname] = uigetfile({'*.nir';'*.*'},'Open fNIRS nir_filename');
        nir_filename=[pathname nir_filename];

        if(isempty(nir_filename)||~isstr(nir_filename))
           return; 
        end
    end
    if(islogical(mrk_filename))
        autoLoadMrk=mrk_filename; 
    else
       autoLoadMrk=false; 
    end
    forceChannelCheck=true;
    % if channel Check is enabled, will force the GUI to load even if the
    % file already exists
end

if(isstring(nir_filename))
   nir_filename=char(nir_filename); 
end

if ~ischar(nir_filename)
	error('Input must be a string representing a filename');
end

if(~isempty(nir_filename))
	fid = fopen(nir_filename);
end

if fid==-1
	error('Data nir_filename not found or permission denied');
end



header.fname=nir_filename;

fileroot=nir_filename(1:strfind(lower(nir_filename),'.nir')-1);
fileroot_modern=fileroot(1:strfind(lower(nir_filename),'_dev')-1);

if(contains(fileroot,'_Dev'))
    fileroot=fileroot_modern;
end


if(autoLoadMrk)
   mrk_filename=cell(4,1);
   mrk_filename{1}=sprintf('%s.mrk',fileroot);
   mrk_filename{2}=sprintf('%s_C.mrk',fileroot);
   mrk_filename{3}=sprintf('%s_Mark1.mrk',fileroot_modern);
   mrk_filename{4}=sprintf('%s_Mark2.mrk',fileroot_modern);
end



%Default names for markers, manual markers, and log file


log_filename=sprintf('%s.log',fileroot);

log_info=importCOBIlog(log_filename);


lineF=fgetl(fid);
while(ischar(lineF))
    if(contains(lineF, 'Start Code:'))
        sC=strsplit(lineF,'\t');
        if(length(sC)>1&&~isempty(sC{2}))
            header.startCodeAlt=str2double(sC{2}); %Start code for start of .nir file
        end
        if(length(sC)>2&&~isempty(sC{3}))
            header.startCode=str2double(sC{3})/1000; %start code for start of experiment
            if((header.startCodeAlt-header.startCode)>1)
                %warning(sprintf('StartCode Diff %.2f\nMay affect manual marker integrity\n',(header.startCodeAlt-header.startCode)));
            end
        else
            header.startCode=header.startCodeAlt; %if second code is missing, just use first
        end
        
    end
    if(~isempty(strfind(lineF, 'Freq Code:')))
        header.freqCode=sscanf(lineF,'Freq Code:\t%f\n',1);  %record frequency code
    end
    if(~isempty(strfind(lineF, 'Current:')))
        header.current=sscanf(lineF,'Current:\t%f\n',1);  %record LED current used
    end
    if(~isempty(strfind(lineF, 'Gains:')))
        header.gains=sscanf(lineF,'Gains:\t%f\n',1);  %record Detector Gain used
    end
    if(~isempty(strfind(lineF, 'Other:')))
        header.other=sscanf(lineF,'Other:\t%s\n',1);  %record Detector Gain used
    end
    
    if(~isempty(strfind(lineF,'Start Time:')))
       temp=strsplit(lineF,'\t');
       temp=temp{2};
       temp=strsplit(temp,' ');
       for i=1:length(temp)
          if(~isempty(strfind(temp,':')))
             header.Time=temp;

             temp2=lineF(13:end);
             try
                header.StartDateTime= datetime(temp2,'InputFormat','eee MMM dd HH:mm:ss.SSS yyyy'); % try to get timestamp with milliseconds
             catch
                header.StartDateTime= datetime(temp2,'InputFormat','eee MMM dd HH:mm:ss yyyy'); % else use only regular seconds
             end
          end
       end
    end
    
    lineF=fgetl(fid); %Get Next Line
    
    if(ischar(lineF)&&contains(lineF, 'Baseline Started'))
        countCheckFlag=true;
        lineF=fgetl(fid); %Get Next Line

        break;
    end
end


if(iscell(mrk_filename))
	
    tempData=[];
    for i=1:length(mrk_filename)
		markerCell{i}=importMrk(mrk_filename{i},header.startCode,i);
        if(isfield(markerCell{i},'data'))
            tempData=[tempData;markerCell{i}.data];
        end
    end
    
    
    markers=markerCell{1};
    if(~isempty(tempData)) % Merge and sort marker values (.info sections are only preserved for first marker file)
        [~,idx]=sort(tempData(:,1));
       markers.data=tempData(idx,:); 
    end
    
else
	markers=importMrk(mrk_filename,header.startCode);
end


spaceParsingMode=false;

while(ischar(lineF))
    
    if(countCheckFlag)
       countCheckFlag=false;
       numVar=sum(lineF(:)=='	');    
       
       if(numVar==0)
            numVar=sum(lineF(:)==' ')+1;
            spaceParsingMode=true;
       end
       baseline=nan(1000,numVar);
       blLineCount=0;
    end
     if(contains(lineF, 'Baseline Started'))
         lineF=fgetl(fid); %Get Next Line
         continue;
     end
    
    if(contains(lineF, 'Baseline end'))
        baseline(isnan(baseline(:,1)),:)=[]; %trim NaN rows;
        baseline(baseline(:,1)<=0,:)=[]; %remove markerrows and zero rows
        lineF=fgetl(fid); %Get Next Line
       break; 
    end
    
    if(~countCheckFlag)
        blLineCount=blLineCount+1;
        [baseline(blLineCount,:), numVar]=sscanf(lineF,'%f',[1 numVar]);
    end
    lineF=fgetl(fid); %Get Next Line
end




if(lineF==-1)
   return;
else
    if(~spaceParsingMode)
        line1=str2double(strsplit(lineF,'\t'));
    else
        line1=str2double(strsplit(lineF,' '));
    end
end

while (ischar(lineF)&&length(line1)>1)&&(line1(1)<0) 
            % Keeps searching for first line with values if it can't find
            % it for some reason
    if(~spaceParsingMode)
        line1=str2double(strsplit(lineF,'\t'));
    else
        line1=str2double(strsplit(lineF,' '));
    end
    lineF=fgetl(fid); %Get Next Line
end

numVar=length(line1(~isnan(line1))); %Count Elements


data=nan(5e5,numVar); %overinitialize array



lineCount=1;
while(lineF~=-1)
    if(~spaceParsingMode)
        numTabs=sum(lineF(:)=='	');
        if(lineF(end)~='\t') %.nir files are terminared with \t\n, but not always true
            numTabs=numTabs+1;
        end
    else
        numTabs=sum(lineF(:)==' ');
        if(lineF(end)~=' ') %.nir files are terminared with \t\n, but not always true
            numTabs=numTabs+1;
        end
    end
    if(numTabs<numVar)
        data(lineCount,:)=zeros(1,numVar);
        count=numTabs;
    else
        [data(lineCount,:), count]=sscanf(lineF,'%f',[1 numVar]);
    end
    if(count==numVar)
        lineCount=lineCount+1;
    end
    lineF=fgetl(fid);
end
data(isnan(data(:,1)),:)=[]; %trim nan rows
data(data(:,1)<=0,:)=[]; %trim zero or negative rows

data=[[baseline,zeros(size(baseline,1),size(data,2)-size(baseline,2))];data];

fclose(fid);
clear fid line1 lineCount line







data(data(:,1)==0,:)=[];

justOnes=all(data==1);
justOnes_Baseline=all(baseline==1);

data=data(:,~justOnes); %Drop all columns that are only 1
baseline=baseline(:,~justOnes_Baseline); %Drop all columns that are only 1

if(size(data,2)>(size(baseline,2))) % Last column in newer cobi is sample count, but not included in baseline
    data=data(:,1:end-1);
end




fNIR.raw=data;
fNIR.time=data(:,1);
fNIR.fs=1./median(diff(fNIR.time));
fNIR.fchMask=fchMask;

if(isfield(markers,'data'))
	fNIR.markers=markers.data;
else
    fNIR.markers=[];
end

fNIR.info=[];

fNIR.info.header=header;

if(isfield(markers,'info'))
	fNIR.info.mrkheaders=markers.info;
end

fNIR.info.filename=nir_filename;
fNIR.info.baseline=baseline;

if(~isempty(log_info)&&isfield(log_info,'SubjectID'))
    fNIR.info.SubjectID=log_info.SubjectID;
end
if(~isempty(log_info)&&isfield(log_info,'Experimenter'))
    fNIR.info.Experimenter=log_info.Experimenter;
end
    
if(~isempty(log_info)&&isfield(log_info,'ExperimentID'))
    fNIR.info.Session=log_info.ExperimentID;
end
    
if(~isempty(log_info)&&isfield(log_info,'Sex'))
    fNIR.info.Sex=log_info.Sex;
end

if(~isempty(log_info)&&isfield(log_info,'Age')&&~isnan(log_info.Age))
    fNIR.info.Age=log_info.Age;
end

if(~isempty(log_info))
    fNIR.info.log_info=log_info;
end
    
%clear count;
%clear line;


numRawChannels=size(data,2)-1;



switch(numRawChannels)
    case 12
        fNIR.info.probename='fNIR_Devices_fNIR1000_Linear';
    case 48
        fNIR.info.probename='fNIR_Devices_fNIR1000';
    case 48
        fNIR.info.probename='fNIR_Devices_fNIR1000';
    case 54
        fNIR.info.probename='fNIR_Devices_fNIR2000';
    otherwise
        warning('Unidentified Probe\n');
        fNIR.info.probename='Unknown .nir file';
end


%clear linecount line times count;


if(~channelCheck)
    ch_mask_file=sprintf('%s_CH.mat',fileroot);

    try
        fmask=load(ch_mask_file,'fmask');
        fmask=fmask.fmask;
        fprintf('\n%i Channels marked bad\n',sum(fmask<1));
    catch
        fprintf('\nNo channel rejection present\n');
        fmask=[];
    end
else
   fmask=[]; 
end

if(channelCheck)
    if(forceChannelCheck)
        fNIR=probeCheckGUI(fNIR,nir_filename,forceChannelCheck);
    else
        fNIR=pf2_base.loadExistingMaskOrCheck(fNIR,nir_filename); 
    end
else
   if(~isempty(fmask))
       fNIR.fchMask=fmask; 
   end
end

end

function loadExistingOrOpen()

end

function markers=importMrk(mrk_filename,startCode,mrkSourceID)
    if(nargin<3)
        mrkSourceID=0;
    end
	if((ischar(mrk_filename)||isstring(mrk_filename))&&~isempty(mrk_filename))
		mrkid = fopen(mrk_filename);
	else
		mrkid=-1;
	end
	
	markers=[];

	if (mrkid==-1&&~isempty(mrk_filename))
		%disp('Marker nir_filename not found or permission denied: Loading without markers');
		return;
	elseif(mrkid==-1)
		%no file provided so just return
		return
	end
	
	
	lineF=fgetl(mrkid);
	if(lineF~=-1)
		[times, count]= sscanf(lineF,'%f\t%*d\t%*d\t%*s\t%*s %*s %*s %*s %*s\n', [1 inf]);
	else
		count=0;
		lineF='';
		fclose(mrkid);
		mrkid=-1;
	end
	
   if(count~=0)  % Then its a manual marker file
		markers=importManualMrkFile(mrkid,startCode,true);
	elseif contains(lower(lineF),'marker') % then its an automatic marker file
		markers=importMrkFile(mrkid,mrkSourceID);
	else
	   markers=[];
	end

	if(~isempty(markers))
		markers.info.fname=mrk_filename;
	end

end
function markers=importManualMrkFile(mrkid,startCode,useStrSplit)
    if(nargin<3)
        useStrSplit=true;
    end

	frewind(mrkid);
    
    markers.info.startcode=startCode; % time noting start of fNIRS file 
        % manual marker values are subtracted from this
	
    if(~useStrSplit) %faster but more error prone
	
        [times, count]= fscanf(mrkid,'%f\t%d\t%*d\t%*s\t%*s %*s %*s %*s %*s\n', [1 inf]);
        markers.data=nan(ceil(count/2),1);
        markers.data(:,3)=times(1:2:end)'; % marker time
        markers.data(:,2)=times(2:2:end)'; % marker code
        markers.data(:,1)=markers.data(:,3)-startCode; %adjusted marker time
        markers.data(:,3)=100; %We don't use marker time here, so just use 100 as the ID

    else
        linecount=0;
        lineF=fgetl(mrkid);
        markers.data=nan(1,3);
        while(lineF~=-1)
           temp=strsplit(lineF,'\t');
           if(length(temp)>=3)
               linecount=linecount+1;
                markers.data(linecount,3)=str2num(temp{1}); % marker time
                markers.data(linecount,2)=str2num(temp{2}); % marker code
                markers.data(linecount,1)=markers.data(linecount,3)-startCode; %adjusted marker time
                if(length(temp)>=5)
                    markers.info.markerDateTime{linecount}=temp{5};
                end
           else
               continue;
           end
           lineF=fgetl(mrkid);

        end
        
        markers.data(:,3)=100;
    end

   clear count;
   clear times;
   fclose(mrkid);
end


function markers=importMrkFile(mrkid,mrkSrcID)
    if(nargin<2)
        mrkSrcID=0;
    end
	frewind(mrkid);
	for i=1:5
		   lineF=fgetl(mrkid);
		   markers.info.headers{i,1}=lineF;
			  
		   if(contains(lineF,'Start Time:'))
			   temp=strsplit(lineF,'\t');
			   temp=temp{2};
			   temp=strsplit(temp,' ');
			   for i=1:length(temp)
				  if(contains(temp,':'))
					 markers.info.Time=temp;
				  end
			   end
		   end
	end

		
	linecount=0;
	lineF=fgetl(mrkid);
	markers.data=[];
	while(lineF~=-1)
	   linecount=linecount+1;
	   
	   temp=sscanf(lineF,'%f\t%f\t%f')';
	   if(length(temp)>2)
			markers.data(linecount,:)=[temp(1:2),mrkSrcID];
	   elseif(length(temp)>1)
		   markers.data(linecount,:)=[temp(1:2),mrkSrcID];
	   else
		   markers.data(linecount,:)=[zeros(1,2),0];
	   end
	   lineF=fgetl(mrkid);
	   
    end
    
    markers.data(markers.data(:,2)==0&markers.data(:,1)==0,:)=[];
	fclose(mrkid);
end

    

function loginfo=importCOBIlog(log_filename)
    if(isstr(log_filename)&&~isempty(log_filename))
            logfid = fopen(log_filename);
        else
            logfid=-1;
    end
        
    loginfo=[];

    if (logfid==-1&&~isempty(log_filename))
        warning('COBI log file not found, loading without log file');
        return;
    elseif(logfid==-1)
        %no file provided so just return
        return
    end
    
    linecount=1;
    
     lineF=fgetl(logfid);

    while(ischar(lineF))
       
       if(contains(lineF,'COBI log file'))
           loginfo.version=sscanf(lineF,'COBI log file %f');
       elseif(contains(lineF,'Experimenter:'))
           lineF=fgetl(logfid);
           if(lineF~=-1)
               loginfo.Experimenter=lineF;
           end
       elseif(contains(lineF,'SubjectID:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           if(lineF~=-1)
               loginfo.SubjectID=lineF;
           end
       elseif(contains(lineF,'ExperimentID:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           if(lineF~=-1)
               loginfo.ExperimentID=lineF;
           end
       elseif(contains(lineF,'Description:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           loginfo.Description='';
           while(lineF~=-1)
               if(isempty(loginfo.Description))
                   loginfo.Description=lineF;
               else
                   loginfo.Description=sprintf('%s\n%s',loginfo.Description,lineF);
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
      elseif(contains(lineF,'Data Sources:'))
           lineF=fgetl(logfid);
           loginfo.DataSources='';
           linecount=linecount+1;
           while(lineF~=-1)
               if(isempty(loginfo.DataSources))
                   loginfo.DataSources=lineF;
               else
                   loginfo.DataSources=sprintf('%s\n%s',loginfo.DataSources,lineF);
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
     elseif(contains(lineF,'Marker Sources:'))
           lineF=fgetl(logfid);
           loginfo.MarkerSources='';
           linecount=linecount+1;
           while(lineF~=-1)
               if(isempty(loginfo.MarkerSources))
                   loginfo.MarkerSources=lineF;
               else
                   loginfo.MarkerSources=sprintf('%s\n%s',loginfo.MarkerSources,lineF);
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
      elseif(contains(lineF,'Broadcasts:'))
           lineF=fgetl(logfid);
           loginfo.Broadcasts='';
           linecount=linecount+1;
           while(lineF~=-1)
               if(isempty(loginfo.Broadcasts))
                   loginfo.Broadcasts=lineF;
               else
                   loginfo.Broadcasts=sprintf('%s\n%s',loginfo.Broadcasts,lineF);
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
           
       elseif(contains(lineF,'Subject Info:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           if(lineF~=-1)
               loginfo.SubjectInfo=lineF;
           end
           if(~isempty(loginfo.SubjectInfo))
               subInfoPart=strsplit(loginfo.SubjectInfo,'-');
               if(length(subInfoPart)>1)
                   if(contains(subInfoPart{2},'Male'))
                       loginfo.Sex='M';
                   elseif(contains(subInfoPart{2},'Female'))
                       loginfo.Sex='F';
                   else
                      loginfo.Sex=''; 
                   end
               else
                   loginfo.Sex='';
               end
               
               if(~isempty(subInfoPart))
                   loginfo.Age=str2double(subInfoPart{1});
               end
           
           end
       elseif(contains(lineF,'Comments:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           loginfo.Comments='';
           while(lineF~=-1)
               if(isempty(loginfo.Comments))
                   loginfo.Comments=lineF;
               else
                   loginfo.Comments=sprintf('%s\n%s',loginfo.Comments,lineF);
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
       elseif(contains(lineF,'Marker Dictionary:'))
           lineF=fgetl(logfid);
           linecount=linecount+1;
           if(lineF~=-1)
               tableHeaders=strsplit(lineF,'\t');
               lastItem=tableHeaders{end};
               if(lastItem(end)==':')
                   lastItem=lastItem(1:end-1);
                   tableHeaders{end}=lastItem;
               end
               
           else
              continue; 
           end
           lineF=fgetl(logfid);
           linecount=linecount+1;
           
           cellMarkerDict=cell(1,length(tableHeaders));
           numMrkDictItems=1;
           
           while(lineF~=-1)
               items=strsplit(lineF,'\t');
               if(~isempty(items)&&iscell(items))
                   cellMarkerDict(numMrkDictItems,1:length(items))=items;
                   numMrkDictItems=numMrkDictItems+1;
               end
               lineF=fgetl(logfid);
               linecount=linecount+1;
           end
           loginfo.MarkerDict=cell2table(cellMarkerDict(:,1:length(tableHeaders)),'VariableNames',tableHeaders);
           
       end
       lineF=fgetl(logfid);
       linecount=linecount+1;
       %disp(lineF)

    end
    fclose(logfid);
       

end

