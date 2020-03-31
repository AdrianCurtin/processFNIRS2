function data=pf2_subtractAmbient(rawData,ambientData,channelList)

% pf2_subtractAmbient takes arguments 
   %    rawData (Nx(ChxWv)) containing raw light intensity
   %    ambientData (NxCh) continain ambient light intensity
   %    channelList (ChXwv) containing channel number info for matching
   
%   Subtract Ambient subtracts the ambient light data from matched raw
%   channels

[~,i]=unique(channelList);
uCh=channelList(i);
ch_p = [];

for i=1:length(uCh)
   tempArr=rawData(:,channelList==uCh(i));
   for i2=1:size(rawData(:,channelList==uCh(i)),2)
%        r_bef(i,i2) = abs(corr(tempArr(:,i2),ambientData(:,i)));
%        [s2] = movstd(ambientData(:,i),5);
%        if r_bef(i,i2) > 0.7000 && any(s2 > 50) && nanmean(ambientData(:,i))>100
% %             figure
% %             subplot(311)
% %             plot(ambientData,'k')
% %             hold on
% %             plot(rawData,'r')
% %             ylim([0 4200]);
% %             subplot(312)
% %             plot(s2,'b')
% %             hold on
% %             if i2 == 1
% %                ch_p(i2,i) = uCh(i);
% %             else
% %                ch_p(i2,i) = uCh(i)+1;
% %             end
        tempArr(:,i2)=tempArr(:,i2)-ambientData(:,i); 
%        end
   end
   rawData(:,channelList==uCh(i))=tempArr;
%    subplot(313)
%    plot(ambientData,'k')
%    hold on
%    plot(rawData,'r')
end
% if ~isempty(ch_p)
%     ch_p = ch_p(:);
%     i3 = ~(ch_p == 0);
%     subplot(313)
%     plot(ambientData,'k')
%     hold on
%     plot(rawData(:,ch_p(i3)),'r')
%     legend(string(ch_p(i3)))
%     ylim([0 4200]);
%     pause;
%     close gcf
% end
data=rawData;