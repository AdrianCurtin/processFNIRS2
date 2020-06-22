function [ imgOut,optPos2Plot ] = InterpolateValues3D(fNIR,data2plot,minVal,maxVal,bufferMult,titleString,clrBarTitle)
%processFNIRS2.Data.Plot.ImageValues
%
% Uses an imagemap to change the color of each cell based on data2plot
% fNIR is a data structure that contains the fNIRS structure info, data2
% plot houses the numbers themselves
%
% Short separation channels are not presented here and are skipped
%
if(nargin<7)
    clrBarTitle='';
end

if(nargin<6)
   titleString=''; 
end

if(nargin<5)
    bufferMult=1;
else
    bufferMult=round(bufferMult);
end



if(nargin<3||isempty(minVal))
   minVal=nanmin(data2plot); 
end

if(nargin<4)
    if(length(minVal)==2)
        maxVal=[];
    else
        maxVal=nanmax(data2plot);
    end
end

cla


if(length(minVal)==2&&sum(minVal>0)==1&&isempty(maxVal))  %% expects two minimum values
    twosided=true; 
    minVal=sort(minVal);
    maxVal(1)=nanmax(data2plot(:));
    maxVal(2)=nanmin(data2plot(:));
    
    if(maxVal(2)>=minVal(1))
        twosided=false;
        minVal=minVal(2);
        maxVal=maxVal(1);
    elseif(maxVal(1)<=minVal(2)) % reverse plot
        twosided=false;
        maxVal=maxVal(2);
        minVal=minVal(1);
    end
    
elseif(isempty(maxVal))
     maxVal=nanmax(data2plot(:));
    
    twosided=false;
else
    twosided=false; 
end

if(isempty(fNIR))
    global setF
end

probeInfo=[];

if(isempty(fNIR)&&isfield(setF,'device'))
    
    cfgFilePath=setF.device.cfg.File;
    if(~isfield(setF.device.Probe{1},'OptLayout2D'))
        probeInfo=pf2_base.loadDeviceCfg(cfgFilePath,true);
        setF.device=probeInfo;
    else
       probeInfo=setF.device; 
    end
elseif(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename')&&~contains(fNIR.info.probename,'Unknown')) 
    %try to load the probename cfg file
    cfgFilePath=sprintf('%s.cfg',fNIR.info.probename);
else
    cfgFilePath='';
end

if(~isempty(probeInfo))

elseif(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
    
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

%clf(gcf)


%h{1}= axes('Position',[0.05,0.05,0.9,0.9],'Box','on');

imgSize=1000;

OptPosX=probeInfo.OptPos3DX(~probeInfo.IsShortSeparation);
OptPosY=probeInfo.OptPos3DY(~probeInfo.IsShortSeparation);
OptPosZ=probeInfo.OptPos3DZ(~probeInfo.IsShortSeparation);

useHighRes = true;
show1020 = true;
showSD = true;
% TAL EEG locations from Automated cortical projection of EEG sensors: Anatomical correlation via the international 10–10 system
if(useHighRes)
    cerebro_mdl=load('cerebro_mdl.mat');    %high res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl;
else
    cerebro_mdl=load('cerebro_mdl_05.mat');  %Low-res model
    cerebro_mdl=cerebro_mdl.cerebro_mdl_05;
end

if(show1020)
    c1020=load('cerebro_1020_table.mat'); %estimation of 10-20 coordinates
    c1020=c1020.cerebro_1020_table;
end

cmap = colormap(hot(256));
%lighting('phong')

camproj('perspective');
axis square
%axis off
axis equal
axis tight

plotFNIRS=false;
plotFNIRS_SD=showSD;
plot1020=show1020;
plotHit52_frontal=false;
brainColor=[0.92,0.68,0.68];
cMdl=cerebro_mdl;



tx2x=@(x) x;%/50*1.73;  %L/R scaling
ty2y=@(y) y;%/140*4.76+0.5; %rostral/caudal scaling
tz2z=@(z) z;%/80*2.5+2.3;  %up down scaling

x2tx=@(x) x*49/1.73;  %L/R scaling
y2ty=@(y) (y-0.57)*143.5/4.76; %rostral/caudal scaling
z2tz=@(z) (z-2.32)*79/2.5;  %up down scaling


reorderIdx=[3,1,2];
mdl.v=cMdl.v(:,reorderIdx);
mdl.v=[x2tx(mdl.v(:,1)),y2ty(mdl.v(:,2)),z2tz(mdl.v(:,3))];
mdl.f=cMdl.f.v(:,reorderIdx);
%mdl.f=[x2tx(mdl.f(:,1)),y2ty(mdl.f(:,2)),z2tz(mdl.f(:,3))];

%set(h,'linestyle','None');
shading interp
cameratoolbar
lht=camlight('headlight');
lht.Color=[0.68,0.68,0.68];
camlight(lht,'headlight');

hold on;

C=data2plot;

num_vertices = size(mdl.v, 1);
max_distance_2 = 300;
Cs = zeros(num_vertices, 3);
controlPoints = [OptPosX, OptPosY, OptPosZ];
num_control = size(controlPoints, 1);
c_min = min(C,[],'all');
c_max = max(C,[],'all');

tic
dist_array = zeros(num_vertices, num_control);
for i=1:num_control
    p = repmat(controlPoints(i,:), num_vertices, 1);
    dist_array(:,i) = sum((mdl.v - p).^2, 2);
end

[d, ind] = min(dist_array, [], 2);
ind(d > max_distance_2) = 0;

c_ind = round(length(cmap)*(C(:) - c_min)/(c_max - c_min));

projectmode = 'interp';
switch(projectmode)
    case 'nearest'
        C_temp = [brainColor;reshape(ind2rgb(c_ind, cmap), [num_control, 3])];

        counts = histcounts(ind);
        for i=1:num_control+1
            Cs(ind==i-1,:) = repmat(C_temp(i,:), counts(i), 1); 
        end
    case 'interp'
        v_ind = nan(num_vertices, 1);
        dist_array(dist_array >= max_distance_2) = Inf;

        my_interp_fx = @(dist, val, pow, dim) sum(val.*(1./(dist.^pow + 1e-8))./sum(1./(dist.^pow + 1e-8), dim), dim);
        C_temp = repmat(C(:)', num_vertices, 1);
        v_ind = my_interp_fx(dist_array, C_temp, 0.5, 2);

        v_ind = round(length(cmap)*(v_ind - c_min)/(c_max - c_min));
        
        Cs = reshape(ind2rgb(v_ind, cmap), [num_vertices, 3]);
        Cs(ind == 0,:) = repmat(brainColor, sum(ind == 0), 1);
end
toc

h=patch('vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',Cs,'FaceColor','interp','AmbientStrength',0.6, 'LineStyle', 'None');
text(probeInfo.OptPos3DX, probeInfo.OptPos3DY, probeInfo.OptPos3DZ, string(1:length(probeInfo.OptPos3DZ)), 'HorizontalAlignment', 'center');

if(plotHit52_frontal)
    for i=1:size(hit_fp_52,1)
        if(~isnan(hit_fp_52.tx(i)))
            text(tx2x(hit_fp_52.tx(i)),ty2y(hit_fp_52.ty(i)),tz2z(hit_fp_52.tz(i)),hit_fp_52.Optode(i), 'HorizontalAlignment','center')
            hold on
            h = scatter3(tx2x(hit_fp_52.tx(i)),ty2y(hit_fp_52.ty(i)),tz2z(hit_fp_52.tz(i)),200,'filled','g');
        end
    end
end


if(plotFNIRS_SD)
    text(probeInfo.SrcPos3DX, probeInfo.SrcPos3DY, probeInfo.SrcPos3DZ, 'S'+string(1:length(probeInfo.SrcPos3DX)), 'HorizontalAlignment', 'center');
    hold on
    h = scatter3(probeInfo.SrcPos3DX,probeInfo.SrcPos3DY,probeInfo.SrcPos3DZ,200,'filled','r');
    text(probeInfo.DetPos3DX, probeInfo.DetPos3DY, probeInfo.DetPos3DZ, 'D'+string(1:length(probeInfo.DetPos3DX)), 'HorizontalAlignment', 'center');
    hold on
    h = scatter3(probeInfo.DetPos3DX,probeInfo.DetPos3DY,probeInfo.DetPos3DZ,200,'filled','y');
end

if(~plot1020)

for i=1:size(c1020,1)
    %text(cerebro1020(i,1),cerebro1020(i,2),cerebro1020(i,3),cerebro1020_labels{i})
    if(~isnan(c1020.BA(i)))
        h = scatter3(c1020.tx(i),c1020.ty(i),c1020.tz(i),200,'filled');
        hold on
        
        text(c1020.tx(i),c1020.ty(i),c1020.tz(i),c1020.Electrode(i),'HorizontalAlignment','center')
        %text(x2tx(c1020.x(i)),y2ty(c1020.y(i)),z2tz(c1020.z(i)),c1020.Electrode(i),'HorizontalAlignment','center')
        
    end
end
end

xlabel('x (L/R)');
ylabel('y (R/C)');
zlabel('z (U/D)');
campos([0,1000+2.5,25]);  %Front facing
camlight(lht,'headlight');