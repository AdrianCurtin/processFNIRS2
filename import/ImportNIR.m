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
    
	channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
elseif nargin<2
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
    mrk_filename=[];
elseif nargin<3
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
end

if ~isstr(nir_filename)
	error('Input must be a string representing a filename');
end

if(~isempty(nir_filename))
	fid = fopen(nir_filename);
end

if fid==-1
	error('Data nir_filename not found or permission denied');
end



header.fname=nir_filename;


lineF=fgetl(fid);
while(ischar(lineF))
    if(contains(lineF, 'Start Code:'))
        sC=strsplit(lineF,'\t');
        if(length(sC)>1&&~isempty(sC{2}))
            header.startCodeAlt=str2double(sC{2});
        end
        if(length(sC)>2&&~isempty(sC{3}))
            header.startCode=str2double(sC{3})/1000;
            if((header.startCodeAlt-header.startCode)>1)
                warning(sprintf('StartCode Diff %.2f\nMay affect manual marker integrity',(header.startCodeAlt-header.startCode)));
            end
        else
            header.startCode=header.startCodeAlt;
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
          end
       end
    end
    
    lineF=fgetl(fid); %Get Next Line
    
    if(contains(lineF, 'Baseline Started'))
        countCheckFlag=true;
        break;
    end
end


if(iscell(mrk_filename))
	
    tempData=[];
    for i=1:length(mrk_filename)
		markerCell{i}=importMrk(mrk_filename{i},header.startCode);
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



while(ischar(lineF))
    
    if(countCheckFlag)
       countCheckFlag=false;
       numVar=sum(lineF(:)=='	');
       baseline=nan(1000,numVar);
       blLineCount=0;
    end
    if(contains(lineF, 'Baseline end'))
        baseline(isnan(baseline(:,1)),:)=[]; %trim NaN rows;
        baseline(baseline(:,1)<=0,:)=[]; %remove markerrows and zero rows
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
    line1=str2double(strsplit(lineF,'\t'));
end

while (ischar(lineF)&&length(line1>1)&&(line1(1)<0)) %%%%% I CANT BELIEVE THIS IS FUCKING NECESSARY
    line1=str2double(strsplit(lineF,'\t'));
    lineF=fgetl(fid); %Get Next Line
end

numVar=length(line1(~isnan(line1))); %Count Elements


data=nan(5e5,numVar); %overinitialize array



lineCount=1;
while(lineF~=-1)
    numTabs=sum(lineF(:)=='	');
    if(lineF(end)~='	') %.nir files are terminared with \t\n, but not always true
        numTabs=numTabs+1;
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

fclose(fid);
clear fid line1 lineCount line

%clear linecount line times count;

if(channelCheck)
    if(isempty(markers))
        fchMask=channelCheckGUI(data,nir_filename);
    else
        fchMask=channelCheckGUI(data,nir_filename,markers);
    end
else
       
end


data(data(:,1)==0,:)=[];

if(size(baseline,2)==size(data,2))
    data=[baseline;data];
else
    warning('Mismatched baseline and data size');
end

fNIR.raw=data;
fNIR.time=data(:,1);
fNIR.fchMask=fchMask;

if(isfield(markers,'data'))
	fNIR.markers=markers.data;
end

fNIR.info=[];
if(isfield(markers,'info'))
	fNIR.info.mrkheaders=markers.info;
end

fNIR.info.filename=nir_filename;
fNIR.info.baseline=baseline;
%clear count;
%clear line;

numRawChannels=size(data,2)-1;

switch(numRawChannels)
    case 48
        fNIR.info.probename='fNIR_Devices_fNIR1000';
    case 54
        fNIR.info.probename='fNIR_Devices_fNIR2000';
    otherwise
        warning('Unidentified Probe\n');
        fNIR.info.probename='Unknown .nir file';
end

end

function markers=importMrk(mrk_filename,startCode)
	if(isstr(mrk_filename)&&~isempty(mrk_filename))
		mrkid = fopen(mrk_filename);
	else
		mrkid=-1;
	end
	
	markers=[];

	if (mrkid==-1&&~isempty(mrk_filename))
		disp('Marker nir_filename not found or permission denied: Loading without markers');
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
	elseif contains(lineF,'marker') % then its an automatic marker file
		markers=importMrkFile(mrkid);
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
    end

   clear count;
   clear times;
   fclose(mrkid);
end

function markers=importMrkFile(mrkid)
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
			markers.data(linecount,:)=temp(1:3);
	   elseif(length(temp)>1)
		   markers.data(linecount,:)=[temp(1:2),0];
	   else
		   markers.data(linecount,:)=zeros(1,3);
	   end
	   lineF=fgetl(mrkid);
	   
	end
	fclose(mrkid);
end

    



 
