function [data]=pf2_ambient_ICA_clean(rawData,ambientData,channelList,icaWeight)

% pf2_subtractAmbient takes arguments 
   %    rawData (Nx(ChxWv)) containing raw light intensity
   %    ambientData (NxCh) continain ambient light intensity
   %    channelList (ChXwv) containing channel number info for matching
   %    Weight adds padding to ends of signals
   
%   Subtract Ambient subtracts the ambient light data from matched raw
%   channels

%   Function requires fastICA to operate
if(~exist('fastica')==2)
    setUpFastICA
end
%


if(nargin<4)
    icaWeight=0;
end


[~,i]=unique(channelList);
uCh=channelList(i);

numRawCh=size(rawData,2);
numAmbCh=size(ambientData,2);

if(icaWeight>0)
   rawData=[ones(numRawCh,icaWeight);rawData;ones(numRawCh,icaWeight)];
   ambientData=[ones(numAmbCh,icaWeight);ambientData;ones(numAmbCh,icaWeight)];
end

for i=1:length(uCh)
    tempArr=rawData(:,channelList==uCh(i));
    for i2=1:size(rawData(:,channelList==uCh(i)),2)
        tempArr(:,i2)=icaClean(tempArr(:,i2),ambientData(:,uCh(i))); 
    end
    rawData(:,channelList==uCh(i))=tempArr;
end


data=rawData(icaWeight+1:end-icaWeight,:);
