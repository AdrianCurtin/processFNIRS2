function plot1200_3D(dataVals,alphaVals,useHighRes,showSD,showCh,show1020)

if(nargin<6)
    show1020=false;
end
if(nargin<5)
    showCh=true;
end
if(nargin<4)
    showSD=true;
end
if(nargin<3)
    useHighRes=true;
end
if(nargin<2)
    alphaVals=ones(size(dataVals));
    
end




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

fnir1200=load('fnir1200_tal.mat');  %Estimation of fnirs talaraich coordinates
fnir1200=fnir1200.fnir1200;
fnir1200_sd=load('fnir1200_tal_sd.mat');  %Estimation of fnirs talaraich coordinates
fnir1200_sd=fnir1200_sd.fnir1200_sd;
%load('hit_fp_52_tal.mat'); %Load tal cooords for 52ch frontopolar hitachi (Takizawa 2013)
%%
%patch('vertices', cerebro_mdl.v, 'faces', cerebro_mdl.f.v,'FaceVertexCData',ones(size(cerebro_mdl.v)));
%shading('interp');
%subplot(1,1,1);
colormap(hot(256));
%lighting('phong')

camproj('perspective');
axis square
%axis off
axis equal
axis tight

plotFNIRS=true;
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

h=patch('vertices', mdl.v, 'faces', mdl.f,'FaceVertexCData',repmat(ones([size(mdl.v,1),1]),[1,3]).*brainColor,'FaceColor',brainColor,'AmbientStrength',0.6);
%set(h,'linestyle','None');
shading interp
cameratoolbar
lht=camlight('headlight');
lht.Color=[0.68,0.68,0.68];
camlight(lht,'headlight');

hold on;
[X,Y] = meshgrid(1:8,1:2);
 Z = sin(X) + cos(Y);
 
% caxis([min(dataVals),max(dataVals)]); 
% cmap=colormap;
% 
% if(size(dataVals(:))==size(X(:))) % Not a color so reshape
% 
% C=ind2rgb(dataVals, cmap);
% 
% C=reshape(C,size(X,1),size(X,2),3);
% 
% alphaVals=reshape(alphaVals,size(X,1),size(X,2));
% 
% end

C=dataVals;
hSurface=surf(X,Y,Z,C);
hSurface.FaceColor='interp';
hSurface.FaceLighting='none';
hSurface.AlphaData=alphaVals;
hSurface.FaceAlpha='interp';

if(plotFNIRS)
    for i=1:size(fnir1200,1)
        if(~isnan(fnir1200.tx(i)))
            if(showCh)
                text(tx2x(fnir1200.tx(i)),ty2y(fnir1200.ty(i)),tz2z(fnir1200.tz(i)),fnir1200.Optode(i),'HorizontalAlignment','center')
                hold on
                h = scatter3(tx2x(fnir1200.tx(i)),ty2y(fnir1200.ty(i)),tz2z(fnir1200.tz(i)),200,'filled','white');
            end
            hSurface.XData(i)=fnir1200.tx(i);
            hSurface.YData(i)=fnir1200.ty(i);
            hSurface.ZData(i)=fnir1200.tz(i);
        end
    end
end

if(plotHit52_frontal)
    for i=1:size(hit_fp_52,1)
        if(~isnan(hit_fp_52.tx(i)))
            text(tx2x(hit_fp_52.tx(i)),ty2y(hit_fp_52.ty(i)),tz2z(hit_fp_52.tz(i)),hit_fp_52.Optode(i),'HorizontalAlignment','center')
            hold on
            h = scatter3(tx2x(hit_fp_52.tx(i)),ty2y(hit_fp_52.ty(i)),tz2z(hit_fp_52.tz(i)),200,'filled','g');
        end
    end
end


if(plotFNIRS_SD)
    for i=1:size(fnir1200_sd,1)
        if(~isnan(fnir1200_sd.tx(i)))
            text(tx2x(fnir1200_sd.tx(i)),ty2y(fnir1200_sd.ty(i)),tz2z(fnir1200_sd.tz(i)),fnir1200_sd.Optode(i),'HorizontalAlignment','center')
            hold on
            if(contains(fnir1200_sd.Optode(i),'D'))
                h = scatter3(fnir1200_sd.tx(i),fnir1200_sd.ty(i),fnir1200_sd.tz(i),200,'filled','r');
            else
                h = scatter3(fnir1200_sd.tx(i),fnir1200_sd.ty(i),fnir1200_sd.tz(i),200,'filled','y');
            end
        end
    end
end

if(plot1020)

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

%TAL landmarks
%hold on
%h = scatter3(0,0,71,200,'filled','k'); %top central
%h = scatter3(0,-102,0,200,'filled','k'); %back occipital
%h = scatter3(0,70,0,200,'filled','k'); %center frontal
%h = scatter3(-61,0,0,200,'filled','k'); %left temporal
%h = scatter3(62,0,0,200,'filled','k'); %right temporal


xlabel('x (L/R)');
ylabel('y (R/C)');
zlabel('z (U/D)');
campos([0,1000+2.5,25]);  %Front facing
camlight(lht,'headlight');

%%



%%%%%%% Old code to calculate 1020

% 
% centerpos=mean(cerebro_mdl_05.v);
% objsizeRange=max(cerebro_mdl_05.v)-min(cerebro_mdl_05.v);
% rsizeRange=[13.909,17.0586,13.8562];
% rcenterpos=[12.777,14.2065,16.5204];
% 
% z=nirx_head_gemo.ext1020sys.coords3d;
% 
% cerebro1020=(z-rcenterpos)./3;%%.*objsizeRange(reorderIdx)+centerpos(reorderIdx);
% cerebro1020_labels=nirx_head_gemo.ext1020sys.labels;
% 
% cerebro1020=cerebro1020(:,[2,3,1]).*[-1,1,1];
% 
% nz=cerebro1020(1,:);
% cerebro1020=cerebro1020+centerpos.*[1,1,1];
% cerebro1020=cerebro1020-nz;
% 
% rX=atan(1/40)
% rot_x=[1,0,0;0,cos(rX),-sin(rX);0,sin(rX),cos(rX)];
% cerebro1020=[rot_x*cerebro1020']';
% 
% rY=atan(1/20);
% 
% rot_y=[cos(rY),0,sin(rY);0,1,0;-sin(rY),0,cos(rY)];
% 
% cerebro1020=[rot_y*cerebro1020']';
% 
% 
% rZ=0;%atan(1/5);
% rot_z=[cos(rZ),-sin(rZ),0;sin(rZ),cos(rZ),0;0,0,1];
% cerebro1020=[rot_z*cerebro1020']';
% cerebro1020=cerebro1020+nz;

