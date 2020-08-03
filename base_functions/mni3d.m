function mni3d(mni_x,mni_y,mni_z,varargin)

if(nargin==0)
    mni_x=0;
    mni_z=0;
    mni_y=0;
end

% Uses dataset from http://sprout022.sprout.yale.edu/mni2tal/mni2tal.html
% To project MNI scans
% Used to calibrate brain size
validBrodmann = @(x) islogical(x) || isnumeric(x)&&all(x<=55)&&all(x>0);
validColormapLabels = {'hot', 'autumn', 'jet', 'gray', 'copper', 'bone', 'cool', 'winter', 'pink'};
validColormap = @(x) isa(x,'function_handle')||ishandle(x)||any(validatestring(x, validColormapLabels));

validColor = @(x) ischar(x) || isnumeric(x) && any(size(x) == 3);
validScalarPosNum = @(x) isnumeric(x) && x>0;
validScalarPosNumOr0 = @(x) isnumeric(x) && x>=0;

p=inputParser;
addOptional(p, 'BrodmannAreas', false, validBrodmann); % Brodmann areas to plot
addParameter(p, 'BA_cmp', @lines, validColormap); % Colormap for Brodmann areas
addParameter(p, 'show_cursor', true,@islogical); % Draw 3D lines indicating MNI positions
addParameter(p, 'show3D', true,@islogical); % Draw full voxel brain
addParameter(p, 'skip3D', false,@islogical); % Only update the lines if they've changed
addParameter(p, 'cursor_color', [1,0,0],@numeric); % Color of MNI lines
addParameter(p, 'alpha', 1,@validScalarPosNumOr0); % Alpha of voxels

parse(p,varargin{:});


if(islogical(p.Results.BrodmannAreas)&&p.Results.BrodmannAreas||isnumeric(p.Results.BrodmannAreas))
    showBrodmann=true;
    if(islogical(p.Results.BrodmannAreas))
        BA_areas=1:55;
    else
        BA_areas=p.Results.BrodmannAreas;
    end
else
    showBrodmann=false;
end



mni_t1=load('mni_t1.mat');
mni_t1=mni_t1.mni_t1;

%mni_t1=flip(mni_t1,2);

center=[91,127,73];
szM=size(mni_t1);


voxelRes=1;

x2mni=@(x) x*voxelRes-center(1);
y2mni=@(y) y*voxelRes-center(2);
z2mni=@(z) z*voxelRes-center(3);

xyz2mni=@(x,y,z) [x2mni(x),y2mni(y),z2mni(z)];

mni2x=@(mx) (mx+center(1))/voxelRes;
mni2y=@(my) (my+center(2))/voxelRes;
mni2z=@(mz) (mz+center(3))/voxelRes;

mni_t1_x=x2mni(1:voxelRes:szM(1));
mni_t1_y=y2mni(1:voxelRes:szM(2));
mni_t1_z=z2mni(1:voxelRes:szM(3));


% Not really necessary if Voxel size is 1
mni_x_ind=find(mni_t1_x>=mni_x,1);
mni_y_ind=find(mni_t1_y>=mni_y,1);
mni_z_ind=find(mni_t1_z>=mni_z,1);

tickSize=20;

tickLocX=rem(center(1),tickSize)+tickSize*(0:floor(((szM(1)-rem(center(1),tickSize))/tickSize)));
tickLocY=rem(center(2),tickSize)+tickSize*(0:floor(((szM(2)-rem(center(2),tickSize))/tickSize)));
tickLocZ=rem(center(3),tickSize)+tickSize*(0:floor(((szM(3)-rem(center(3),tickSize))/tickSize)));

xTicks=x2mni(tickLocX);
yTicks=y2mni(tickLocY);
zTicks=z2mni(tickLocZ);


mniX_img=reshape(mni_t1(mni_x_ind,:,:),size(mni_t1,2),size(mni_t1,3));
mniY_img=reshape(mni_t1(:,mni_y_ind,:),size(mni_t1,1),size(mni_t1,3));
mniZ_img=reshape(mni_t1(:,:,mni_z_ind),size(mni_t1,1),size(mni_t1,2));

mniX_composite=repmat(mniX_img,1,1,3);
mniY_composite=repmat(mniY_img,1,1,3);
mniZ_composite=repmat(mniZ_img,1,1,3);

show3D=p.Results.show3D;
skip3D=p.Results.skip3D;

if(show3D)
    subplotX=2;
    subplotY=2;
    subplot(subplotX,subplotY,4);
    hold off;
    cla;
else
    subplotX=1;
    subplotY=3;
end
if(showBrodmann)

    brdm=load('brodmann.mat');
    brdm=brdm.brdm;

    brdm=brdm(1:voxelRes:end,1:voxelRes:end,1:voxelRes:end);
    
    %center=[90,126,72];
    szB=size(brdm);

    brodmannRes=voxelRes;

    %BA_areas=[9,10,46];

    brainColmap=p.Results.BA_cmp(length(BA_areas));

    bdX_img=reshape(brdm(mni_x_ind,:,:),size(brdm,2),size(brdm,3));
    bdY_img=reshape(brdm(:,mni_y_ind,:),size(brdm,1),size(brdm,3));
    bdZ_img=reshape(brdm(:,:,mni_z_ind),size(brdm,1),size(brdm,2));
    
    
    bdX_composite=nan(size(brdm,2),size(brdm,3),3);
    bdY_composite=nan(size(brdm,1),size(brdm,3),3);
    bdZ_composite=nan(size(brdm,1),size(brdm,2),3);
  

    for i=1:length(BA_areas)
         bdI=find(brdm==BA_areas(i));
         
         if(~any(bdI))
             continue;
         end
         
         bdX_ind=bdX_img==BA_areas(i);
         bdX_ind_len=sum(bdX_ind(:));
         bdX_3d_ind=repmat(bdX_ind,1,1,3);
         
         if(bdX_ind_len>0)
            bdX_composite(bdX_3d_ind)=reshape(repmat(brainColmap(i,:),bdX_ind_len,1),[bdX_ind_len*3,1]);
         end
         
         bdY_ind=bdY_img==BA_areas(i);
         bdY_ind_len=sum(bdY_ind(:));
         bdY_3d_ind=repmat(bdY_ind,1,1,3);
         
         if(bdY_ind_len>0)
            bdY_composite(bdY_3d_ind)=reshape(repmat(brainColmap(i,:),bdY_ind_len,1),[bdY_ind_len*3,1]);
         end
         
         bdZ_ind=bdZ_img==BA_areas(i);
         bdZ_ind_len=sum(bdZ_ind(:));
         bdZ_3d_ind=repmat(bdZ_ind,1,1,3);
         
         if(bdZ_ind_len>0)
            bdZ_composite(bdZ_3d_ind)=reshape(repmat(brainColmap(i,:),bdZ_ind_len,1),[bdZ_ind_len*3,1]);
         end

         mniX_composite(bdX_3d_ind)=mniX_composite(bdX_3d_ind).*uint8(bdX_composite(bdX_3d_ind)*255);
         mniY_composite(bdY_3d_ind)=mniY_composite(bdY_3d_ind).*uint8(bdY_composite(bdY_3d_ind)*255);
         mniZ_composite(bdZ_3d_ind)=mniZ_composite(bdZ_3d_ind).*uint8(bdZ_composite(bdZ_3d_ind)*255);

         [bdx,bdy,bdz] = ind2sub(size(brdm),bdI);

         bd_mni_intensity=mni_t1(bdI);
         
         %mni_t1(bdI)=0;

         bdxyz=xyz2mni(bdx,bdy,bdz);

        if(show3D&&~skip3D)
             scattercols=brainColmap(i,:).*(double(bd_mni_intensity)/255/3+0.66);
             h=plotCube(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),brodmannRes,scattercols,'alpha',p.Results.alpha);
             %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');



             h.DisplayName=sprintf('BA%i',BA_areas(i));
             h.Tag='BA_area_mrk';
            hold on
            legend();
        
        end
    end
    
    if(show3D&&~skip3D)
        lighting('none');
         bdI=brdm>0.&~ismember(brdm,BA_areas);
         [bdx,bdy,bdz] = ind2sub(size(brdm),find(bdI));

         bd_mni_intensity=mni_t1(bdI);

         %mni_t1(bdI)=0;

         bdxyz=xyz2mni(bdx,bdy,bdz);

         scattercols=repmat((double(bd_mni_intensity)/255),1,3);
         h=plotCube(bdxyz(:,1),bdxyz(:,2),bdxyz(:,3),brodmannRes,scattercols,'alpha',p.Results.alpha);
         %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');
         %h.DisplayName=sprintf('BA%i',BA_areas(i));
         %h.Tag='BA_area_mrk';
         h.HandleVisibility='off';

        hold on
        legend();
        
        
        axis('image');
    
    end


    %nnzMNIvals=nnzMNIvals(b);


else
    if(show3D&&~skip3D)

        nnzMNI=mni_t1>0;%.&~ismember(brdm,BA_areas);
        nnzMNIvals=(mni_t1(nnzMNI));

        [mnx,mny,mnz] = ind2sub(size(mni_t1),find(nnzMNI));

        mnxyz=xyz2mni(mnx,mny,mnz);

        h=plotCube(mnxyz(:,1),mnxyz(:,2),mnxyz(:,3),voxelRes,repmat(nnzMNIvals,1,3),'alpha',p.Results.alpha);
        h.Tag='BrainVoxel';
        h.HandleVisibility='off';
        lighting('none');
        hold on
        axis('image');
    end
    

    
end

if(show3D&&~skip3D)
   xlabel('X (R/L)');
   ylabel('Y (Ros/Caud)');
   zlabel('Z (U/D)');
end

if(p.Results.show_cursor)
    cursor_color=p.Results.cursor_color*255;
    
    
    if(show3D)
        
        item = findobj(gca, "Tag", 'XZ_line');
        if(~isempty(item))
            delete(item);
        else
            hold on;
            h=plot3([mni_x,mni_x],[y2mni(szM(2)),y2mni(1)],[mni_z,mni_z],'color',cursor_color/255,'linewidth',3);
            h.Tag='XZ_line';
        end

        item = findobj(gca, "Tag", 'YZ_line');
        if(~isempty(item))
            delete(item);
        else
            h=plot3([x2mni(szM(1)),x2mni(0)],[mni_y,mni_y],[mni_z,mni_z],'color',cursor_color/255,'linewidth',3);
            h.Tag='YZ_line';
        end
        
        item = findobj(gca, "Tag", 'XY_line');
        if(~isempty(item))
            delete(item);
        else
            h=plot3([mni_x,mni_x],[mni_y,mni_y],[z2mni(szM(3)),z2mni(0)],'color',cursor_color/255,'linewidth',3);
            h.Tag='XY_line';
        end
       hold off;
    end
    
    
    
    mniX_composite(mni_y_ind,:)=reshape(repmat(cursor_color,szM(1),1),szM(3)*3,1);
    mniX_composite(:,mni_z_ind,:)=repmat([255,0,0],szM(2),1);
    
    
    mniY_composite(mni_x_ind,:,:)=repmat(cursor_color,szM(1),1);
    mniY_composite(:,mni_z_ind,:)=repmat(cursor_color,szM(3),1);
    
    mniZ_composite(:,mni_y_ind,:)=repmat(cursor_color,szM(1),1);
    mniZ_composite(mni_x_ind,:,:)=repmat(cursor_color,szM(2),1);
    
    
    
end

sh=subplot(subplotX,subplotY,1);
set(sh,'ButtonDownFcn',@(~,~)disp('axes'),...
   'HitTest','off');
item = findobj(gca, "Tag", 'mniX');
if(~isempty(item))
    item.CData=imrotate(mniX_composite,90);
else
    h=image(imrotate(mniX_composite,90));
    h.Tag='mniX';
end

set(h,'ButtonDownFcn',@buttonDownX);
set(h,'UserData',{mni_x,mni_t1_y,mni_t1_z});

axis('image');

if(~skip3D)
    xticklabels(yTicks);
    yticklabels(zTicks);
    xticks(tickLocY);
    yticks(tickLocZ);
    xlabel('Y');
    ylabel('Z');
end
title(sprintf('MNI X = %.0f',mni_x));

sh=subplot(subplotX,subplotY,2);

set(sh,'ButtonDownFcn',@(~,~)disp('axes'),...
   'HitTest','off');
item = findobj(gca, "Tag", 'mniY');
if(~isempty(item))
    item.CData=flip(imrotate(mniY_composite,90),2);
else
    h=image(flip(imrotate(mniY_composite,90),2));
    h.Tag='mniY';
end
set(h,'ButtonDownFcn',@buttonDownY);
set(h,'UserData',{mni_y,mni_t1_x,mni_t1_z});
axis('image');
if(~skip3D)
    xticklabels(xTicks(end:-1:1));
    yticklabels(zTicks);
    xticks(sort(szM(1)-tickLocX));
    yticks(tickLocZ);
    xlabel('X');
    ylabel('Z');
    text(szM(1)-20,szM(3)-20,'L','Color','white');
    text(20,szM(3)-20,'R','Color','white');
end

title(sprintf('MNI Y = %.0f',mni_y));

sh=subplot(subplotX,subplotY,3);

set(sh,'ButtonDownFcn',@(~,~)disp('axes'),...
   'HitTest','off');

item = findobj(gca, "Tag", 'mniZ');
if(~isempty(item))
    item.CData=imrotate(mniZ_composite,90);
else
    h=image(imrotate(mniZ_composite,90));
    h.Tag='mniZ';
end

set(h,'ButtonDownFcn',@buttonDownZ);
set(h,'UserData',{mni_z,mni_t1_x,mni_t1_y});
    axis('image');
if(~skip3D)
    xticklabels(xTicks);
    yticklabels(yTicks(end:-1:1));
    xticks(tickLocX);
    yticks(sort(szM(2)-tickLocY));
    xlabel('X');
    ylabel('Y');
    text(szM(1)-20,szM(2)-20,'R','Color','white');
    text(20,szM(2)-20,'L','Color','white');
end


title(sprintf('MNI Z = %.0f',mni_z));

f=gcf;
set(f,'ButtonDownFcn',@(~,~)disp('figure'),...
   'HitTest','off');

end


function buttonDownX(imageX, event_obj)
if(event_obj.Button==1)
    y=event_obj.IntersectionPoint(1);
    z=event_obj.IntersectionPoint(2);
    UserData=imageX.UserData;
    if(~isempty(UserData))
        mni_x=UserData{1};
        y2mni=UserData{2};
        z2mni=UserData{3};
        z2mni=z2mni(end:-1:1);
        mni_y=y2mni(round(y));
        mni_z=z2mni(round(z));
        
        
        mni3d(mni_x,mni_y,mni_z,'skip3d',true);
    end
end
end

function buttonDownY(imageY, event_obj)
if(event_obj.Button==1)
    x=event_obj.IntersectionPoint(1);
    z=event_obj.IntersectionPoint(2);
    UserData=imageY.UserData;
    if(~isempty(UserData))
        mni_y=UserData{1};
        x2mni=UserData{2};
        x2mni=x2mni(end:-1:1);
        z2mni=UserData{3};
        z2mni=z2mni(end:-1:1);
        mni_x=x2mni(round(x));
        mni_z=z2mni(round(z));
        
        mni3d(mni_x,mni_y,mni_z,'skip3d',true);
    end
end
end

function buttonDownZ(imageZ, event_obj)
    if(event_obj.Button==1)
        x=event_obj.IntersectionPoint(1);
        y=event_obj.IntersectionPoint(2);
        UserData=imageZ.UserData;
        if(~isempty(UserData))
            mni_z=UserData{1};
            x2mni=UserData{2};
            y2mni=UserData{3};
            y2mni=y2mni(end:-1:1);
            mni_x=x2mni(round(x));
            mni_y=y2mni(round(y));

            mni3d(mni_x,mni_y,mni_z,'skip3d',true);
        end
    end
end



