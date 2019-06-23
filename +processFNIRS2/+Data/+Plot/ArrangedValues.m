function [ figHandle ] = ArrangedValues(fNIR,data2plot,minVal,maxVal)
%processFNIRS2.Data.Plot.ArrangedValues
%
% Uses an imagemap to change the color of each cell based on data2plot
%
if(nargin<4)
    maxVal=nanmax(data2plot);
end

if(nargin<3)
   minVal=nanmin(data2plot); 
end

if(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end


if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
    warning('Missing or invalid configuration file path\n')
    
    disp('No device specified. Please load device configuration');
    probeInfo=pf2_base.loadDeviceCfg([],true);
    if(~isempty(probeInfo))
        error('No valid devices selected');
    end
    
elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
    probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
end

if(pf2_base.isnestedfield(probeInfo,'Probe'))
    deviceInfo=probeInfo.Info;
    if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
        probeNum=1;
    end
    probeInfo=probeInfo.Probe{probeNum};
else
   error('Unable to identify probe'); 
end

if(length(data2plot)~=probeInfo.NumOptodes)
    error('Must have a value for all optodes');
end



h=cell(0);
for(optIdx=1:length(data2plot))
    optNum=probeInfo.ChannelList(optIdx);

    optPos=probeInfo.OptLayout2D{optNum};
    optPos([3,4])=optPos([3,4]).*[0.85,0.9];
    optPos([1])=optPos([1])+0.01;
    h{optIdx}= axes('Position',optPos,'Box','on');
    
%     gh=gcf();
%     dcm_obj=datacursormode(gh);
%     set(dcm_obj,'DisplayStyle','datatip',...
%         'SnapToDataVertex','off','Enable','on');
%     set(dcm_obj,'UpdateFcn', @myupdatefcn);
    

    caxis('manual')
    caxis([minVal,maxVal]);
    
    image(data2plot(optIdx));
    axis off
    
    title(sprintf('Opt %i',optNum));
    
end

end
