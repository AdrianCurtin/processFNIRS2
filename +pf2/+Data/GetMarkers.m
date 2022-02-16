function [markerTimes,tableMrkTimes, matchedPatterns] = GetMarkers(varargin) %(fNIR, markersStart,markersEnd)   or (fNIR, markerPattern)
%GetMarkers Function which matches markers and marker patterns to
%return start and end times
% markersStart, markersEnd, and markerPattern  may be  N x mrk  arrays or
%                                                   cell arrays of 1 x mrk 
   %                        wher N is the number of patterns and mrk is the
   %                        number of markers in the pattern
   %                ex: markersStart [50,51] will look for the marker
   %                            pattern 50 followed by 51
   %                ex: markersStart [50;51] will look for the markers
   %                            50 and markers valued at 51
      %                ex: markerPattern {25,[50,51]} will look for markers
      %                            25 and the pattern 50-51
%   Note: in patterns, all extra markers are removed, ie: the pattern [1,4]
%                   will return the markers 1 and 4 in the set [1,2,3,4]
   

%   GetMarkers(fNIR, markersStart)
%       returns all markers at specified time
%
%
%   GetMarkers(fNIR, markersStart,markersEnd)
%       returns all markers between start and end marker pairs 
%               if only one start marker is given, all start-end pairs are
%               matched
%               if only one end marker is given, all start- end pairs are
%               matched
%                   otherwise each start and end marker must be paired
%
%   GetMarkers(fNIR,markerPattern)
%       returns all start and end times for markers matching specific
%       pattern (with any interleaving markers allowed)

% Additional parameters
%       %markerColumn: the column number containing the respective markers
%       %markerVariableName: the variable name containing respective marker
%                         values (in a table), will overwrite markerColumn
%       %timeColumn: the column number containing the marker timing
%       %returnIndicies:  will return marker indicies instead of times as
%               the default time output
%       %exactMatch: requires that all makers are explicitly found in order



p=inputParser;

validfNIR_Input = @(x) (isstruct(x) && (isfield(x,'raw')||isfield(x,'time')||isfield(x,'info')));
validfNIR_or_marker_Input = @(x) (istable(x)&&size(x,1)>1)||(isnumeric(x)&&length(x)>1) ||validfNIR_Input(x);
validScalarNum = @(x) isnumeric(x) && ismatrix(x)||islogical(x);
validScalarNumOrCell = @(x) (isnumeric(x) && ismatrix(x) || iscell(x));
isStringOrChar = @(x) isstring(x)||ischar(x);

addRequired(p,'fNIR',validfNIR_or_marker_Input);
addOptional(p,'markersStart',[],validScalarNum);
addOptional(p,'markersEnd',[],validScalarNum);
addParameter(p,'markerPattern',[],validScalarNumOrCell);
addParameter(p,'markerColumn',2,validScalarNum);
addParameter(p,'markerVariableName',[],isStringOrChar);
addParameter(p,'timeColumn',1,validScalarNum);
addParameter(p,'returnIndicies',false,validScalarNum);
addParameter(p,'exactMatch',false,validScalarNum);
addParameter(p,'sortTimes',false,validScalarNum);



parse(p,varargin{:});

fNIR=p.Results.fNIR;
markersStart=p.Results.markersStart;
markersEnd=p.Results.markersEnd;

markerPatternIn=p.Results.markerPattern;
markerColumn=p.Results.markerColumn;
markerVariableName=p.Results.markerVariableName;
timeColumn=p.Results.timeColumn;
returnIndicies=p.Results.returnIndicies;
exactMatch=p.Results.exactMatch;
sortTimes=p.Results.sortTimes;

if(iscell(markersStart))
    markerPatternIn=markersStart;
    markersStart=[];
end


if(timeColumn<=0)
    returnIndicies=true;
end

isFNIRstruct=validfNIR_Input(fNIR);

if(isempty(markersEnd)&&isempty(markerPatternIn)) % if only start patterns are provided, only start times are returned
    startMrkOnly=true;
else
    startMrkOnly=false;
end

if(~isFNIRstruct)
    %processing data as just markers
    temp=fNIR;
    fNIR=[];
    fNIR.markers=temp;
    
    if(istable(fNIR.markers)&&~isempty(markerVariableName))
        markerColumn=find(ismember(fNIR.markers.Properties.VariableNames,markerVariableName));
    end
elseif(isFNIRstruct&&~isfield(fNIR,'markers')||size(fNIR.markers,1)<1)
    warning('fNIR struct has no marker data')
    markerTimes=[];
    return;
end

uMatchingMarkers=[];

for i=1:size(markersStart,1)
   if(iscell(markersStart(i)))
       uMatchingMarkers=[uMatchingMarkers,unique(markersStart{i})];
   else
       uMatchingMarkers=[uMatchingMarkers,unique(markersStart(i,:))];
   end
end

for i=1:size(markersEnd,1)
   if(iscell(markersEnd(i)))
       uMatchingMarkers=[uMatchingMarkers,unique(markersEnd{i})];
   else
       uMatchingMarkers=[uMatchingMarkers,unique(markersEnd(i,:))];
   end
end

for i=1:size(markerPatternIn,1)
   if(iscell(markerPatternIn(i)))
       uMatchingMarkers=[uMatchingMarkers,unique(markerPatternIn{i})];
   else
       uMatchingMarkers=[uMatchingMarkers,unique(markerPatternIn(i,:))];
   end
end


markerVals=fNIR.markers(:,markerColumn);



if(istable(markerVals))
    markerVals=markerVals{:,1};
end

if(~exactMatch)
    % non-exact match discards all misc markers before match
    reducedIndex=find(ismember(markerVals,uMatchingMarkers));
else
    % exact match retains all misc markers before match
    reducedIndex=[1:size(markerVals,1)]';
end
reducedMarkers=fNIR.markers(reducedIndex,:);

if(timeColumn<=0)
    reducedTimes=reducedIndex;
else
    reducedTimes=reducedMarkers(:,timeColumn);
end

if(istable(reducedTimes))
    reducedTimes=reducedTimes{:,1};
end

if(isempty(reducedTimes))
    markerTimes=[];
    tableMrkTimes={};
    matchedPatterns=cell(0);
    return;
end

if(isnumeric(markerVals(1))&&isnumeric(reducedTimes(1)))
    returnArray=true;
else
    returnArray=false;
end

[uMarkers,~,uMrkIdx]=unique(reducedMarkers(:,markerColumn));

if(istable(uMarkers))
    uMarkers=uMarkers{:,1};
end

if(isempty(uMarkers))
    markerTimes=[];
    tableMrkTimes={};
    matchedPatterns=cell(0);
    return;
end

%for i=1:length(uMatchingMarkers)
%   uMatchIdx(i)=find(uMatchingMarkers(i)==uMarkers);
%end



if(isempty(markerPatternIn))
    % convert start and end terms into ucodes (characters)
    markersStartStr=cell(0);
    for i=1:size(markersStart,1)
       if(iscell(markersStart(i)))
           startVals=markersStart{i};
       else
           startVals=markersStart(i,:);
       end
       
       uStartVals=nan(size(startVals));
       for j=1:length(startVals)
           uStartVals(j)=find(startVals(j)==uMarkers);
       end
       
       markersStartStr{i}=char(uStartVals+47); %convert to ascii
    end
    

    % convert end terms into ucodes (characters)
    markersEndStr=cell(0);
    for i=1:size(markersEnd,1)
       if(iscell(markersEnd(i)))
           endVals=markersEnd{i};
       else
           endVals=markersEnd(i,:);
       end
       
       uEndVals=nan(size(endVals));
       for j=1:length(endVals)
           uEndVals(j)=find(endVals(j)==uMarkers);
       end
       
       markersEndStr{i}=char(uEndVals+47); %convert to ascii
    end
    

    
    %merge strings for start and end
    
    markerPatternChar=cell(0);
    for i=1:size(markersStart,1)
       if(size(markersEnd,1)==0)
            markerPatternChar{i}=sprintf('%s',markersStartStr{i});
            matchedPatterns{i}=markersStart(i,:);
       elseif(size(markersEnd,1)==1)
           markerPatternChar{i}=sprintf('%s\\w*?%s',markersStartStr{i},markersEndStr{1});
           matchedPatterns{i,1}=markersStart(i,:);
           matchedPatterns{i,2}=markersEndStr(1,:);
       elseif(size(markersEnd,1)==size(markersStart,1))
           markerPatternChar{i}=sprintf('%s?%s',markersStartStr{i},markersEndStr{i});
           matchedPatterns{i,1}=markersStart(i,:);
           matchedPatterns{i,2}=markersEndStr(i,:);
       elseif(size(markersStart,1)==1)
           for j=1:size(markersEnd,1)
               markerPatternChar{j}=sprintf('%s\\w*?%s',markersStartStr{1},markersEndStr{j});
               matchedPatterns{j,1}=markersStart(1,:);
               matchedPatterns{j,2}=markersEndStr(j,:);
           end
       else
          error('Marker mismatch\nPlease supply 1 start marker for each end marker or only one start/end marker'); 
       end
        
    end
    
else
    %convert pattern into ucodes
    markerPatternNum=markerPatternIn;
    markerPatternChar=cell(0);
    matchedPatterns=cell(0);
    for i=1:size(markerPatternNum,1)
        % For each markerPattern
        if(iscell(markerPatternNum(i)))
           patternVals=markerPatternNum{i};
       else
           patternVals=markerPatternNum(i,:);
        end
       
       % recode values into unique marker ids
       uPatternVals=nan(size(patternVals));
       for j=1:length(uMarkers)
           matchedVals=patternVals==uMarkers(j);
           if(any(matchedVals))
                uPatternVals(matchedVals)=j;
           end
       end
       
       if(any(isnan(uPatternVals)))
           markerPatternChar{i}='';
           matchedPatterns(i)=markerPatternNum(i);
           continue
       else
       
           markersPatternStr{i}=uValsToString(uPatternVals); %convert to ascii

           markerPatternChar{i}=char(markersPatternStr{i});

           matchedPatterns(i)=markerPatternNum(i);
       end
    end
end

regMrkStr=char(uValsToString(uMrkIdx)');

markerTimes=[];
tableMrkTimes=cell(0);
for i=1:size(markerPatternChar,1)
    if (~isempty(markerPatternChar{i}))
        clean_mrk_str=onlyPatternMrk(markerPatternChar{i},regMrkStr);
        [patterns,startIdx,endIdx]=regexp(clean_mrk_str,markerPatternChar{i},'match');
        startIdx=startIdx(:);
        endIdx=endIdx(:);
        tableMrkTimes{i}=table(reducedTimes(startIdx),reducedTimes(endIdx),ones(length(startIdx),1)*i,reducedIndex(startIdx),reducedIndex(endIdx),reducedTimes(endIdx)-reducedTimes(startIdx));
        tableMrkTimes{i}.Properties.VariableNames={'StartTime','EndTime','PatternNum','StartIndex','EndIndex','TimeDiff'};

        markerTimes=[markerTimes;tableMrkTimes{i}];
    end
end

if(isempty(markerTimes))
   return; 
end

if(returnIndicies)
   markerTimes=markerTimes(:,[4,5,3,1,2,6]);
end

if(sortTimes)
    markerTimes=sortrows(markerTimes,1);
end

if(returnArray)
   markerTimes=[markerTimes{:,1},markerTimes{:,2},markerTimes{:,3}]; 
end

if(length(markerPatternChar)==1)
   markerTimes=markerTimes(:,[1,2]);
   if(startMrkOnly)
       markerTimes=markerTimes(:,1);
       if(istable(markerTimes))
          markerTimes=markerTimes{:,1}; 
       end
   end
elseif(startMrkOnly)
   markerTimes=markerTimes(:,[1,3]);
end

end

function regMrkIdx=uValsToString(uVals)
    reg_numeric_idx=uVals<=10;
    reg_upper_idx=(~reg_numeric_idx)&uVals<=37;
    reg_lower_idx=(~reg_numeric_idx&~reg_upper_idx&uVals<=63);

    regMrkIdx=nan(size(uVals));
    regMrkIdx(reg_numeric_idx)=uVals(reg_numeric_idx)+47;
    regMrkIdx(reg_upper_idx)=uVals(reg_upper_idx)+64;
    regMrkIdx(reg_lower_idx)=uVals(reg_lower_idx)+96;
    if(max(uVals>63))
        error('Too many unique markers');
    end
end

function cleanedMarkers=onlyPatternMrk(input_pattern,markers)


    if(ischar(input_pattern))
        input_pattern=double(input_pattern);
    end
    
    if(ischar(markers))
       markers=double(markers); 
       returnChar=true;
    else
       returnChar=false; 
    end
    
    uInput=unique(input_pattern);
    numInputs=length(uInput);
    
    markers(~ismember(markers,uInput))=0;
    
    if(returnChar)
        markers(markers==0)=',';
        markers=char(markers);
    end
    
    cleanedMarkers=markers;

end

