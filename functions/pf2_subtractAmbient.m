function data=pf2_subtractAmbient(rawData,ambientData,channelList)

% pf2_subtractAmbient takes arguments 
   %    rawData (Nx(ChxWv)) containing raw light intensity
   %    ambientData (NxCh) continain ambient light intensity
   %    channelList (ChXwv) containing channel number info for matching
   
%   Subtract Ambient subtracts the ambient light data from matched raw
%   channels

[~,i]=unique(channelList);
uCh=channelList(i);

for i=1:length(uCh)
    
   rawData(:,channelList==uCh(i))=rawData(:,channelList==uCh(i))-ambientData(:,uCh(i)); 
end

data=rawData;