function [fNIR] = ImportHitachiMES(file,pathname,channelCheck)

forceChannelCheck=false;

if(nargin<3) % channel check is on by default with no file
    channelCheck=true;
else
    forceChannelCheck=true; % but if you manually specifiy it is honored
end
    

curdir=cd;

if(nargin<2||isempty(pathname))
    pathname=cd;
end

if nargin < 1
  [file, pathname] = uigetfile({'*MES*.*';'*.*'},'Open Hitachi MES file');
  filename=[pathname,file];
  fid = fopen([pathname file]);

elseif ~isstr(file)
  error('Input must be a string representing a filename');
elseif nargin<2
    fid=fopen(file);
    filename=file;
else
    if(isfile(file))
     filename=file;
     fid=fopen(filename);
    else
        
        filename=[pathname,file];
        fid=fopen(filename);
    end
end


[filepath,fileroot,ext]=fileparts(filename);

if fid==-1
  error('Data file not found or permission denied');
end

%fclose(fid);

fNIR=[];

lineF=fgetl(fid);
lineNum=1;

header=[];

delimiter='\t';

while(~feof(fid)&&(ischar(lineF))&&~strcmp(lineF,'Data'))
    [lineSplit,idx]=strsplit(lineF,delimiter);
    if(length(lineSplit)>1)
       varField=renameValid(strtrim(lineSplit{1}));
       header.(varField)=strtrim(lineF(length(lineSplit{1})+2:end));
    end
    lineF=fgetl(fid);
    lineNum=lineNum+1;
end

if(isempty(header))
    delimiter=',';
    frewind(fid);
    lineF=fgetl(fid);
    while(~feof(fid)&&(ischar(lineF))&&~strcmp(lineF,'Data'))
        [lineSplit,idx]=strsplit(lineF,delimiter);
        if(length(lineSplit)>1)
           varField=renameValid(strtrim(lineSplit{1}));
           header.(varField)=strtrim(lineF(length(lineSplit{1})+2:end));
        end
        lineF=fgetl(fid);
        lineNum=lineNum+1;
    end
end

if(isempty(header))
    error('Unkown delimiter or file type');
end


lineF=fgetl(fid);
lineNum=lineNum+1;

header.HeaderInfo=lineF;
lineF=fgetl(fid);
startLineNum=lineNum;
fclose(fid);

dataLineParts=strsplit(header.HeaderInfo,delimiter);

numCols=length(dataLineParts);
timeCol=find(strcmp(dataLineParts,'Time')); %Use Time column to estimate number of columns and remove body movement mark

markCol=find(strcmp(dataLineParts,'Mark'));


fprintf('Importing %s...\n',filename);
fid=fopen(filename,'r');
for i=1:startLineNum
    line=fgetl(fid);  % Figure out the number of columns based on the header
end


f=[]; 
isNum=true(1,numCols);
for i=1:numCols
    if(i==timeCol) % find time segment
        f=[f '%s '];

        isNum(i)=false;
    else
        f=[f '%f '];
    end
end

if(~isempty(f))
    data=textscan(fid,f,'delimiter',delimiter);
    datetimeCol=data{(~isNum)};
    data=horzcat(data{isNum});
else
    disp('Data is empty!');
    data=[];
    datetimeCol=[];
end

fclose(fid);


hMES = data;%importdata(filename,delimiter,startLineNum);

if(~isempty(datetimeCol)) %Searches for first timepoint in data (to add seconds to start time)
   fNIR.info=[];
   timeColData=datetimeCol;

   if(length(datetimeCol)>=1)
    fNIR.info.startTime=timeColData{1};
   else
      warning('Unable to find first sample timepoint in MES file'); 
   end
end


hMES(isnan(hMES(:,1)),:)=[]; %remove nan columns


chWavelengths=[0;0];
wvHeaders=strsplit(header.HeaderInfo,delimiter);
for j=2:length(wvHeaders)
    temp=sscanf(wvHeaders{j},'CH%f(%f)');
    if(~isempty(temp)&&length(temp)==2)
       chWavelengths(:,j)=temp;
    end
end

numCh=size(chWavelengths,2)-1;

mrkIdx=find(hMES(:,markCol)>0);
fNIR.raw=hMES(:,1:(1+numCh));
if(isfield(header,'Sampling_Period_s'))
    s_period=str2double(header.Sampling_Period_s);
    fNIR.time=fNIR.raw(:,1)*s_period-10; % Assumes a 10 second baseline period for offset
     fNIR.raw(:,1)=fNIR.time;
     fNIR.fs=1/s_period;
end
if(isfield(header,'Wave_nm'))
    header.Wave_nm(header.Wave_nm=='''')=[];
   fNIR.info.curWv=str2double(strsplit(header.Wave_nm,delimiter)); 
   numWv=length(fNIR.info.curWv);
else
   error('Missing number of wavelengths'); 
end

if(isfield(header,'Date'))
    startDate=header.Date; 
    try
        header.StartDateTime= datetime(startDate,'InputFormat','yyyy/MM/dd HH:mm:ss'); % try to get timestamp with milliseconds
     catch
        header.StartDateTime= datetime(startDate,'InputFormat','yyyy/MM/dd HH:mm'); % else use only regular seconds
     end
    if(~isempty(datetimeCol))
        startTime=datetimeCol{1};
        startTime=datetime(startTime,'InputFormat','HH:mm:ss.SS'); % try to get timestamp with milliseconds
        header.StartDateTime.Minute=startTime.Minute;
        header.StartDateTime.Second=startTime.Second;
    end
end



fNIR.markers=[fNIR.time(mrkIdx),hMES(mrkIdx,markCol),mrkIdx];

fNIR.info.MESheader=header;
fNIR.info.chWavelengths=chWavelengths;


if(~isempty(header)&&isfield(header,'Name'))
    fNIR.info.SubjectID=header.Name;
end
if(~isempty(header)&&isfield(header,'Comment'))
    fNIR.info.Comment=header.Comment;
end
    
if(~isempty(header)&&isfield(header,'ID'))
    fNIR.info.Session=header.ID;
end
    
if(~isempty(header)&&isfield(header,'Sex'))
    fNIR.info.Sex=header.Sex;
end

if(~isempty(header)&&isfield(header,'Age'))
    fNIR.info.Age=str2double(header.Age(1:end-1));
end




fprintf('Importing Complete\n');
cd(curdir);

numRawChannels=numCh;

switch(numRawChannels)
    case 44
        fNIR.info.probename='Hitachi_ETG4000_3x5';
    case 104
        fNIR.info.probename='Hitachi_ETG4000_3x11';
    otherwise
        warning('Unidentified Probe\n');
        fNIR.info.probename='Unkown *MES.CSV file';
end



if(~channelCheck)
    ch_mask_file=sprintf('%s_CH.mat',fileroot);

try
    fmask=load(ch_mask_file,'fmask');
    fmask=fmask.fmask;
    fprintf('%i Channels marked bad\n',sum(fmask<1));
catch
    fprintf('No channel rejection present\n');
    fmask=[];
end
else
   fmask=[]; 
end


if(channelCheck)
        if(forceChannelCheck)
            fNIR=probeCheckGUI(fNIR,filename,forceChannelCheck);
        else
            fNIR=pf2_base.loadExistingMaskOrCheck(fNIR,filename); 
        end
else
   if(~isempty(fmask))
       fNIR.fchMask=fmask;
   else
       fNIR.fchMask=ones(1,numCh/numWv); 
   end
       
end


end



function Name2 = renameValid(Name)

persistent Numbers LowerCases UpperCases

if isempty(Numbers)
    Numbers = arrayfun(@(n) {sprintf('%u',n)},0:9);
    LowerCases = arrayfun(@(n) {char(n+96)},1:26);
    UpperCases = arrayfun(@(n) {char(n+64)},1:26);
end

Name2 = '';
for n = 1:length(Name)
    Character = Name(n);
    switch Character
        case Numbers
        case LowerCases
        case UpperCases
        case {'À','Á','Â','Ã','Ä','Å'},     Character = 'A';
        case 'Æ',                           Character = 'AE';
        case 'Ç',                           Character = 'C';
        case {'È','É','Ê','Ë'},             Character = 'E';
        case {'Ì','Í','Î','Ï'},             Character = 'I';
        case 'Ñ',                           Character = 'N';
        case {'Ò','Ó','Ô','Õ','Ö'},         Character = 'O';
        case {'Ù','Ú','Û','Ü'},             Character = 'U';
        case 'Ý',                           Character = 'Y';
        case '²',                           Character = '2';
        case '³',                           Character = '3';
        case '¼',                           Character = '1_4';
        case '½',                           Character = '1_2';
        case '¾',                           Character = '3_4';
        case {'à','á','â','ã','ä','å'},     Character = 'a';
        case 'æ',                           Character = 'ae';
        case 'ç',                           Character = 'c';
        case {'è','é','ê','ë'},             Character = 'e';
        case {'ì','í','î','ï'},             Character = 'i';
        case 'ñ',                           Character = 'n';
        case {'ò','ó','ô','õ','ö'},         Character = 'o';
        case {'ù','ú','û','ü','µ'},         Character = 'u';
        case {'ý','ÿ'},                     Character = 'y';
        case {' ','''', '-', '_',...
                '(','[','/','\'},         	Character = '_';
        case {'°'},                         Character = 'deg';
        otherwise,                          Character = '' ;
    end
    Name2 = [Name2, Character]; %#ok<AGROW>
end

Name2 = strrep(Name2,'__','_');
if length(Name2) > 1
    if strcmp(Name2(end),'_')
        Name2 = Name2(1:end-1);
    end
end
Name2 = matlab.lang.makeValidName(Name2);

end