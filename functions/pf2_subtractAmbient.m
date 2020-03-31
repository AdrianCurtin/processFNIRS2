function data=pf2_subtractAmbient(rawData,ambientData,channelList)

% pf2_subtractAmbient takes arguments 
   %    rawData (Nx(ChxWv)) containing raw light intensity
   %    ambientData (NxCh) continain ambient light intensity
   %    channelList (ChXwv) containing channel number info for matching
   
%   Subtract Ambient subtracts the ambient light data from matched raw
%   channels

[uCh]=unique(channelList);
%uCh=channelList(idx);


for i=1:length(uCh)
    
   rawData(:,channelList==uCh(i))=rawData(:,channelList==uCh(i))-ambientData(:,i); 
end

data=rawData;