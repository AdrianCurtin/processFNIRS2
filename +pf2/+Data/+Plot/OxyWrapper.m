function [ figHandle ] = OxyWrapper(fNIR,channels,showMarkers,bioMlist,baseline,ylimit,plotArranged,lineProps,rejectedLineProps)
    
    if(nargin<9||isempty(rejectedLineProps))
        rejectedLineProps={'--','LineWidth',1};
    end
    
    if(nargin<8||isempty(lineProps))
        lineProps={'LineWidth',1};
    end
    
    if(nargin<7)
        plotArranged=false;  % plot when channels is all or empty
    end
    
    if(nargin<6)
        ylimit=[]; % will use max device info to plot
    end
    
    if(nargin<5)
        baseline=false;
    end
    
    
    if(nargin<4||isempty(bioMlist))
        bioMlist={'HbO','HbR'};
    end
    
    if(nargin<3)
        showMarkers=true;  %will plot all markers
    end
    
    if(~iscell(bioMlist))
        if(any(~ischar(bioMlist)))
            error('Must specify biomarkers');
        end
        if(strcmpi(bioMlist,'all'))
            bioMlist={'HbO','HbR','HbDiff','HbTotal','CBSI'};
        else
            bioMlist={bioMlist};
        end
    end
    
    if(nargin<2||isempty(channels)||(ischar(channels)&&strcmpi(channels,'all')))
        plotArranged=true; %Enabled when all channels are plot
        channels=[];
    end
    
    if(length(channels)>1&&any(logical(channels))&&any(~isnumeric(channels)))
        if(any(~channels))
            plotArranged=true;
        end
        channels=find(channels);
    end
    
    if(~isfield(fNIR, 'probeNum'))
        figHandle = pf2.Data.Plot.Oxy(fNIR, channels, showMarkers, bioMlist, baseline, ylimit, plotArranged, lineProps, rejectedLineProps);
        return;
    end
    probes_index = unique(fNIR.probeNum);
    for j=1:length(probes_index)
        i = probes_index(j);
        fNIR_i = fNIR;
        probeChannels = fNIR.probeNum == i;
        fNIR_i.HbO = fNIR.HbO(probeChannels);
        fNIR_i.HbR = fNIR.HbR(probeChannels);
        plotChannels = probeChannels;
        if(~isempty(channels))
            plotChannels = channels(probeChannels);
        end
        plotChannels = find(plotChannels);
        plotChannels = plotChannels - min(plotChannels) + 1;
        fNIR_i.info.probename = fNIR.info.probename{j};
        fNIR_i.probeinfo = pf2_base.loadDeviceCfg(fNIR_i.info.probename, plotArranged);
        fNIR_i.probeinfo.Probe{1}.NumOptodes = length(fNIR.probeNum);
        fNIR_i.channels = fNIR_i.channels(probeChannels);
        figure(j)
        figHandle(j) = pf2.Data.Plot.Oxy(fNIR_i, plotChannels, showMarkers, bioMlist, baseline, ylimit, plotArranged, lineProps, rejectedLineProps);
    end
end