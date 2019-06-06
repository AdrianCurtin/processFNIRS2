function [fNIR] = ImportHitachiMES(file,pathname,channelCheck)
if(nargin<3)
    channelCheck=false;
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
     filename=[pathname,file];
     fid=fopen(filename);
end




if fid==-1
  error('Data file not found or permission denied');
end

%fclose(fid);

fNIR=[];

lineF=fgetl(fid);
lineNum=1;

header=[];
while(~feof(fid)&&(ischar(lineF))&&~strcmp(lineF,'Data'))
    [lineSplit,idx]=strsplit(lineF,'\t');
    if(length(lineSplit)>1)
       varField=renameValid(strtrim(lineSplit{1}));
       header.(varField)=strtrim(lineF(length(lineSplit{1})+2:end));
    end
    lineF=fgetl(fid);
    lineNum=lineNum+1;
end

lineF=fgetl(fid);
lineNum=lineNum+1;

header.HeaderInfo=lineF;
lineF=fgetl(fid);
startLineNum=lineNum;
fclose(fid);

numCols=find(strcmp(strsplit(header.HeaderInfo,'\t'),'Time'));
if(~isempty(numCols))
    numCols=numCols-1;
else
    numCols=length(strsplit(header.HeaderInfo,'\t'));
end

markCol=find(strcmp(strsplit(header.HeaderInfo,'\t'),'Mark'));


fprintf('Importing %s...\n',filename);
hMES = importdata(filename,'\t',startLineNum);
hMES.textdata=hMES.textdata(:,1:numCols);
hMES=str2double(hMES.textdata);

hMES(isnan(hMES(:,1)),:)=[]; %remove nan columns


chWavelengths=[0;0];
wvHeaders=strsplit(header.HeaderInfo);
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
   fNIR.info.curWv=str2double(strsplit(header.Wave_nm,'\t')); 
   numWv=length(fNIR.info.curWv);
else
   error('Missing number of wavelengths'); 
end



fNIR.markers=[fNIR.time(mrkIdx),hMES(mrkIdx,markCol),mrkIdx];

fNIR.info.MESheader=header;
fNIR.info.chWavelengths=chWavelengths;

if(channelCheck)
    warning('Not updated yet');
   fNIR.fchMask=hitChannelCheckGUI(fNIR,filename);
else
   fNIR.fchMask=ones(1,numCh/numWv); 
end

fprintf('Importing Complete\n');
cd(curdir);

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