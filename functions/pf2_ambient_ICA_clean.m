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
    figure;
    subplot(211)
    plot(tempArr(:,1));hold on;plot(tempArr(:,2)); plot(ambientData(:,i));legend({'730','850','amb'});
    for i2=1:size(rawData(:,channelList==uCh(i)),2)
       r_bef(i,i2) = abs(corr(tempArr(:,i2),ambientData(:,i)));
       if r_bef(i,i2) > 0.7000  && nanmean(ambientData(:,i)) > 100
%            tp = 1;
%             while tp
                [~,tempArr(:,i2),val{i,i2}]=icaClean(tempArr(:,i2),ambientData(:,i)); 
                 r_af(i,i2) = abs(corr(tempArr(:,i2),ambientData(:,i)));
%                 if r_af(i,i2) > 0.7
%                     tp = 1;
%                 else
%                     tp = 0;
%                  end
%            end
       disp(['---->  Correlation before and after for Channel: ' num2str(channelList(i)) ' using method: ' val{i,i2} ' >> ' num2str(r_bef(i,i2)) ' , ' num2str(r_af(i,i2))]);
       else
           val{i,i2} = 'None';
           tempArr(:,i2) = tempArr(:,i2);
           r_af(i,i2) = NaN;
       end
    
    end
    rawData(:,channelList==uCh(i))=tempArr;
    subplot(212)
    plot(tempArr(:,1));hold on;plot(tempArr(:,2)); plot(ambientData(:,i));legend({'730-Corr','850-Corr','amb'});
    pause;
    close gcf
end

clc;
r_bef = r_bef(:);
r_af = r_af(:);
val = val(:);
for i = 1:numel(channelList)
    if ~isnan(r_af(i))
        disp(['---->  Correlation before and after for Channel: ' num2str(channelList(i)) ' using method: ' val{i} ' >> ' num2str(r_bef(i)) ' , ' num2str(r_af(i))]);
    end
end


data=rawData(icaWeight+1:end-icaWeight,:);

