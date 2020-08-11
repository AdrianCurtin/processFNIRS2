function [ figHandle ] = RawWrapper(fNIR,channels,showMarkers,wavelengths,ylimit,plotArranged,lineProps,rejectedLineProps)

if(nargin<8||isempty(rejectedLineProps))
    rejectedLineProps={'--','LineWidth',1};
end

if(nargin<7||isempty(lineProps))
    lineProps={'LineWidth',1};
end

if(nargin<6)
    plotArranged=false;  % plot when channels is all or empty
end

if(nargin<5)
    ylimit=[]; % will use max device info to plot
end


if(nargin<3)
    showMarkers=true;  %will plot all markers
end

if(nargin<2||isempty(channels)||(ischar(channels)&&strcmpi(channels,'all')))
    plotArranged=true; %Enabled when all channels are plot
    channels=[];
end

if(any(logical(channels))&&any(~isnumeric(channels)))
    if(any(~channels))
        plotArranged=true;
    end
    channels=find(channels);
end

if(~isfield(fNIR, 'probeNum'))
    probeInfo = pf2_base.loadProbeInfo(fNIR, plotArranged);
    if(nargin<4||isempty(wavelengths)||(ischar(wavelengths)&&strcmpi(wavelengths,'all')))
        [~,wvb]=unique(probeInfo.Wavelength);
        wavelengths=probeInfo.Wavelength(wvb); %unsort here
    end
    figHandle = pf2.Data.Plot.Raw(fNIR,channels,showMarkers,wavelengths,ylimit,plotArranged,lineProps,rejectedLineProps);
    return;
end

probes_index = unique(fNIR.probeNum);
for j=1:length(probes_index)
    i = probes_index(j);
    fNIR_i = fNIR;
    probeChannels = fNIR.probeNum == i;
    fNIR_i.time = fNIR.rawTime{i};
    fNIR_i.raw = fNIR.raw{i};
    plotChannels = probeChannels;
    if(~isempty(channels))
        plotChannels = channels(probeChannels);
    end
    plotChannels = find(plotChannels);
    plotChannels = plotChannels - min(plotChannels) + 1;
    fNIR_i.info.probename = fNIR.info.probename{j};
    fNIR_i.probeinfo = pf2_base.loadDeviceCfg(fNIR_i.info.probename, plotArranged);
    
    if(nargin<4||isempty(wavelengths)||(ischar(wavelengths)&&strcmpi(wavelengths,'all')))
        base_wavelength = fNIR_i.probeinfo.Probe{1}.Wavelength;
        [~,wvb]=unique(base_wavelength);
        wavelengths_i=base_wavelength(wvb); %unsort here
    end
    fNIR_i.probeinfo.Probe{1}.NumOptodes = length(fNIR.probeNum);
    fNIR_i.channels = fNIR_i.channels(probeChannels);
    figure(j)
    figHandle(j) = pf2.Data.Plot.Raw(fNIR_i,plotChannels,showMarkers,wavelengths_i,ylimit,plotArranged,lineProps,rejectedLineProps);
end
end