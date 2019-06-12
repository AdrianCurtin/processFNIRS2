function [markerTimes,cellMrkTimes, matchedPatterns] = GetMarkers(varargin) %(fNIR, markersStart,markersEnd)   or (fNIR, markerPattern)
%GETFNIRSMARKERS Function which matches markers and marker patterns to
%return start and end times
% markersStart, markersEnd, and markerPattern  may be  N x mrk  arrays or
%                                                   cell arrays of 1 x mrk 
   %                        wher N is the number of patterns and mrk is the
   %                        number of markers in the pattern
   %                ex: markersStart [50,51] will look for the marker
   %                            pattern 50 followed by 51
   %                ex: markersStart [50;51] will look for the markers
   %                            50 and then the markers 51

%   getFNIRSmarkertimes(fNIR, markersStart)
%       returns all markers at specified time
%
%
%   getFNIRSmarkertimes(fNIR, markersStart,markersEnd)
%       returns all markers between start and end marker pairs 
%               if only one start marker is given, all start-end pairs are
%               matched
%               if only one end marker is given, all start- end pairs are
%               matched
%                   otherwise each start and end marker must be paired
%
%   getFNIRSmakertimes(fNIR,markerPattern)
%       returns all start and end times for markers matching specific
%       pattern (with any interleaving markers allowed)



p=inputParser;

validfNIRInput = @(x) (isnumeric(x)&&length(x)>1) || (isstruct(x) && (isfield(x,'raw')||isfield(x,'time')||isfield(x,'info')));
validScalarNum = @(x) isnumeric(x) && ismatrix(x);

addRequired(p,'fNIR',validfNIRInput);
addOptional(p,'markersStart',[],validScalarNum);
addOptional(p,'markersEnd',[],validScalarNum);
addParameter(p,'markerPattern',[],validScalarNum);


parse(p,varargin{:});

fNIR=p.Results.fNIR;
markersStart=p.Results.markersStart;
markersEnd=p.Results.markersEnd;

markerPattern=p.Results.markerPattern;



if(isempty(markersEnd)&&isempty(markerPattern)) % if only start patterns are provided, only start times are returned
    startMrkOnly=true;
else
    startMrkOnly=false;
end

if(~isfield(fNIR,'markers')||size(fNIR.markers,1)<1)
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

for i=1:size(markerPattern,1)
   if(iscell(markerPattern(i)))
       uMatchingMarkers=[uMatchingMarkers,unique(markerPattern{i})];
   else
       uMatchingMarkers=[uMatchingMarkers,unique(markerPattern(i,:))];
   end
end

reducedMarkers=fNIR.markers(ismember(fNIR.markers(:,2),uMatchingMarkers),:);
reducedTimes=reducedMarkers(:,1);


[uMarkers,~,uMrkIdx]=unique(reducedMarkers(:,2));

for i=1:length(uMatchingMarkers)
   uMatchIdx(i)=find(uMatchingMarkers(i)==uMarkers);
end



if(isempty(markerPattern))
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
    
    markerPattern=cell(0);
    for i=1:size(markersStart,1)
       if(size(markersEnd,1)==0)
            markerPattern{i}=sprintf('%s',markersStartStr{i});
            matchedPatterns{i}=markersStart(i,:);
       elseif(size(markersEnd,1)==1)
           markerPattern{i}=sprintf('%s\\w*?%s',markersStartStr{i},markersEndStr{1});
           matchedPatterns{i,1}=markersStart(i,:);
           matchedPatterns{i,2}=markersEndStr(1,:);
       elseif(size(markersEnd,1)==size(markersStart,1))
           markerPattern{i}=sprintf('%s?%s',markersStartStr{i},markersEndStr{i});
           matchedPatterns{i,1}=markersStart(i,:);
           matchedPatterns{i,2}=markersEndStr(i,:);
       elseif(size(markersStart,1)==1)
           for j=1:size(markersEnd,1)
               markerPattern{j}=sprintf('%s\\w*?%s',markersStartStr{1},markersEndStr{j});
               matchedPatterns{j,1}=markersStart(1,:);
               matchedPatterns{j,2}=markersEndStr(j,:);
           end
       else
          error('Marker mismatch\nPlease supply 1 start marker for each end marker or only one start/end marker'); 
       end
        
    end
    
else
    %convert pattern into ucodes
    markerPatternNum=markerPattern;
    markerPattern=cell(0);
    for i=1:size(markerPatternNum,1)
        if(iscell(markerPatternNum(i)))
           patternVals=markerPatternNum{i};
       else
           patternVals=markerPatternNum(i,:);
       end
       
       uPatternVals=nan(size(patternVals));
       for j=1:length(patternVals)
           uPatternVals(j)=find(patternVals(j)==uMarkers);
       end
       
       markersPatternStr{i}=char(uPatternVals+47); %convert to ascii
       
       markerPattern{i}(1)=markersPatternStr{i}(1);
       for c=1:length(markersPatternStr{i})
           markerPattern{i}=sprintf('%s\\w*?%s',markerPattern{i},markersPatternStr{i}(c));
       end
       
       matchedPatterns=markerPatternNum(i);
    end
end

redMrkStr=char(uMrkIdx'+47);

markerTimes=[];
for i=1:length(markerPattern)
    [patterns,startIdx,endIdx]=regexp(redMrkStr,markerPattern{i},'match');
    cellMrkTimes{i}=[reducedTimes(startIdx),reducedTimes(endIdx)];
    cellMrkTimes{i}(:,3)=i;
    
    markerTimes=[markerTimes;cellMrkTimes{i}];
end

if(isempty(markerTimes))
   return; 
end


if(length(markerPattern)==1)
   markerTimes=markerTimes(:,[1,2]);
   if(startMrkOnly)
       markerTimes=markerTimes(:,1);
   end
elseif(startMrkOnly)
   markerTimes=markerTimes(:,[1,3]);
end


end

