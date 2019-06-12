
function [data,markers,baseline,fchMask] = ImportNIR_old(file,markerfile,channelCheck)
% Old marker file import for fNIRS 1100 system. New version outputs data as struct format
% This version is not maintained and should be used for legacy code only

markers=[];
baseline=[];
fchMask=[];

if nargin < 1
  [file, pathname] = uigetfile({'*.nir';'*.*'},'Open fNIRS file');
  fid = fopen([pathname file]);
  [markerfile, pathnameM] = uigetfile({'*.mrk';'*.*'},'Open fNIRS mrk file');
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean

  if(markerfile)
    mrkid = fopen([pathnameM markerfile]);
  else
      mrkid=-1;
  end
elseif ~isstr(file)
  error('Input must be a string representing a filename');
elseif nargin<2
    fid=fopen(file);
    mrkid=-1;
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
    markerfile='';
elseif nargin<3
    fid = fopen(file);
    mrkid = fopen(markerfile);
    channelCheck=true; %Plots raw channel light intensity and asks user to mark as either noisy, invalid, or clean
else
    fid = fopen(file);
    mrkid = fopen(markerfile);    
end


if fid==-1
  error('Data file not found or permission denied');
end
  


if (mrkid==-1&&length(markerfile)>1)
  disp('Marker file not found or permission denied: Loading without markers');
end

header.fname=file;


lineF=fgetl(fid);
while(ischar(lineF))
    if(~isempty(strfind(lineF, 'Start Code:')))
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
    
    if(~isempty(strfind(lineF, 'Baseline end')))
        break;
    end
end


data=[]; %overinitialize array

lineF=fgetl(fid); %Get Next Line
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

baseline=zeros(1,numVar);
data=zeros(4e4,numVar); %overinitialize array



lineCount=1;
while(lineF~=-1)
    if(length(strsplit(lineF,'\t'))<numVar)
        data(lineCount,:)=zeros(1,numVar);
        count=length(strsplit(lineF,'\t'));
    else
        [data(lineCount,:), count]=sscanf(lineF,'%f',[1 numVar]);
    end
    if(count==numVar)
        lineCount=lineCount+1;
    end
    lineF=fgetl(fid);
end
data(data(:,1)<=0,:)=[]; %trim zeros

fclose(fid);
clear fid line1 lineCount line

if(mrkid~=-1) %% for manual markers
    lineF=fgetl(mrkid);
    if(lineF~=-1)
        [times, count]= sscanf(lineF,'%f\t%*d\t%*d\t%*s\t%*s %*s %*s %*s %*s\n', [1 inf]);
    else
        count=0;
        lineF='';
        fclose(mrkid);
        mrkid=-1;
        
    end
   if(count~=0)
       
       
       frewind(mrkid);
       [times, count]= fscanf(mrkid,'%f\t%d\t%*d\t%*s\t%*s %*s %*s %*s %*s\n', [1 inf]);
       markers.data=zeros(ceil(count/2),1);
       markers.data(:,3)=times(1:2:end)';
       markers.data(:,2)=times(2:2:end)';
       markers.data(:,1)=markers.data(:,3)-header.startCode;
       
       markers.header{1,1}=sprintf('Manual Markers: StartCode used: %f',header.startCode);
      % fclose(mrkid);
       
       clear count;
       clear times;

   elseif contains(lineF,'marker')
       for i=1:5
           lineF=fgetl(mrkid);
           markers.headers{i,1}=lineF;
              
           if(~isempty(strfind(lineF,'Start Time:')))
               temp=strsplit(lineF,'\t');
               temp=temp{2};
               temp=strsplit(temp,' ');
               for i=1:length(temp)
                  if(~isempty(strfind(temp,':')))
                     markers.info.Time=temp;
                  end
               end
           end
       end
        
       markers.info.fname=markerfile;
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
       
   else
       markers=[];
   end
   
else
    markers=[];
end

if(mrkid~=-1&&(ischar(markerfile)))
    fclose(mrkid);
end
%clear linecount line times count;

if(channelCheck)
    if(mrkid==-1)
        fchMask=channelCheckGUI(data,file);
    elseif(mrkid~=-1)
        fchMask=channelCheckGUI(data,file,markers);
    
    end
else
       
end


data(data(:,1)==0,:)=[];

%clear count;
%clear line;




    



 
