function mni3d(mni_x,mni_y,mni_z,varargin)

% Uses dataset from http://sprout022.sprout.yale.edu/mni2tal/mni2tal.html
% To project MNI scans
% Used to calibrate brain size
validBrodmann = @(x) islogical(x) || isnumeric(x)&&all(x<=55)&&all(x>0);
validColormapLabels = {'hot', 'autumn', 'jet', 'gray', 'copper', 'bone', 'cool', 'winter', 'pink'};
validColormap = @(x) isa(x,'function_handle')||ishandle(x)||any(validatestring(x, validColormapLabels));



p=inputParser;
addOptional(p, 'BrodmannAreas', false, validBrodmann); % Colors in Brodmann areas
addParameter(p, 'BA_cmp', @lines, validColormap); % Colors in Brodmann areas
addParameter(p, 'show_cursor', true,@islogical); % Colors in Brodmann areas
addParameter(p, 'show3D', true,@islogical); % Colors in Brodmann areas
addParameter(p, 'cursor_color', [1,0,0],@numeric); % Colors in Brodmann areas


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



center=[90,126,72];
szM=size(mni_t1);


voxelRes=1;

mni_t1_x=(1:voxelRes:szM(1))-center(1);
mni_t1_y=(szM(2):-1*voxelRes:1)-center(2)-1;
mni_t1_z=(1:voxelRes:szM(3))-center(3)-1;

mni_x_ind=find(mni_t1_x>=mni_x,1);
mni_y_ind=find(mni_t1_y<=mni_y,1);
mni_z_ind=find(mni_t1_z>=mni_z,1);

tickSize=20;



xTicks=tickSize*(floor(-center(1)/tickSize)+1:1:floor((szM(1)-center(1))/tickSize));
yTicks=tickSize*(floor((szM(2)-center(2))/tickSize):-1:floor(-center(2)/tickSize));
zTicks=tickSize*(floor((szM(3)-center(3))/tickSize):-1:floor(-center(3)/tickSize));

tickLocX=rem(center(1),tickSize)+tickSize*(0:length(xTicks)-1);
tickLocY=rem(center(2),tickSize)+tickSize*(0:length(yTicks)-1);
tickLocZ=rem(szM(3)-center(3),tickSize)+tickSize*(0:length(zTicks)-1);

%mni_t1=mni_t1(1:voxelRes:end,1:voxelRes:end,end:voxelRes*-1:1);

mniX_img=reshape(mni_t1(szM(1)-mni_x_ind,:,:),size(mni_t1,2),size(mni_t1,3));
mniY_img=reshape(mni_t1(:,mni_y_ind,:),size(mni_t1,1),size(mni_t1,3));
mniZ_img=reshape(mni_t1(:,:,mni_z_ind),size(mni_t1,1),size(mni_t1,2));

mniX_composite=repmat(mniX_img,1,1,3);
mniY_composite=repmat(mniY_img,1,1,3);
mniZ_composite=repmat(mniZ_img,1,1,3);

show3D=p.Results.show3D;

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



         mni_t1(bdI)=0;

         

         bdx=mni_t1_x(bdx)';
         bdy=mni_t1_y(bdy)';
         bdz=mni_t1_z(bdz)';

         bdxyz=[bdx,bdz,bdy];

        if(show3D)


             scattercols=brainColmap(i,:).*(double(bd_mni_intensity)/255/3+0.66);
             h=plotCube(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),brodmannRes,scattercols);
             %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');



             h.DisplayName=sprintf('BA%i',BA_areas(i));
             h.Tag='BA_area_mrk';
            hold on
            legend();
        
        end
    end
    
    if(show3D)
        lighting('none');
         bdI=brdm>0.&~ismember(brdm,BA_areas);
         [bdx,bdy,bdz] = ind2sub(size(brdm),find(bdI));

         bd_mni_intensity=mni_t1(bdI);

         mni_t1(bdI)=0;



         bdx=mni_t1_x(bdx)';
         bdy=mni_t1_y(bdy)';
         bdz=mni_t1_z(bdz)';

         bdxyz=[bdx,bdz,bdy];




         scattercols=repmat((double(bd_mni_intensity)/255),1,3);
         h=plotCube(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),brodmannRes,scattercols);
         %h=scatter3(bdxyz(:,1),bdxyz(:,3),bdxyz(:,2),50*brodmannRes,scattercols,'filled');
         %h.DisplayName=sprintf('BA%i',BA_areas(i));
         %h.Tag='BA_area_mrk';

        hold on
        legend();
        
        
        axis('image');
    
    end


    %nnzMNIvals=nnzMNIvals(b);


else
    if(show3D)

        nnzMNI=mni_t1>0;%.&~ismember(brdm,BA_areas);
        nnzMNIvals=(mni_t1(nnzMNI));

        [mnx,mny,mnz] = ind2sub(size(mni_t1),find(nnzMNI));

        mnx=mni_t1_x(mnx)';
        mny=mni_t1_y(mny)';
        mnz=mni_t1_z(mnz)';


        mnxyz=[mnx,mnz,mny];

        h=plotCube(mnxyz(:,1),mnxyz(:,3),mnxyz(:,2),voxelRes,repmat(nnzMNIvals,1,3));
        h.Tag='BrainVoxel';
        h.HandleVisibility='off';
        lighting('none');
        hold on
        axis('square');
    end
    

    
end

if(show3D)
   xlabel('X (R/L)');
   zlabel('Z (U/D)');
   ylabel('Y (Ros/Caud)');
end

if(p.Results.show_cursor)
    cursor_color=p.Results.cursor_color*255;
    
    
    if(show3D)
        plot3([mni_x,mni_x],[szM(2)-center(2),-center(2)],[mni_z,mni_z],'color',cursor_color/255,'handleVisibility','off');
        plot3([szM(1)-center(1),-center(1)],[mni_y,mni_y],[mni_z,mni_z],'color',cursor_color/255,'handleVisibility','off');
        plot3([mni_x,mni_x],[mni_y,mni_y],[szM(3)-center(3),-center(3)],'color',cursor_color/255,'handleVisibility','off');
       hold off;
    end
    
    
    
    mniX_composite(mni_y_ind,:)=reshape(repmat(cursor_color,szM(1),1),szM(3)*3,1);
    mniX_composite(:,mni_z_ind,:)=repmat([255,0,0],szM(2),1);
    
    
    mniY_composite(szM(1)-mni_x_ind,:,:)=repmat(cursor_color,szM(1),1);
    mniY_composite(:,mni_z_ind,:)=repmat(cursor_color,szM(3),1);
    
    mniZ_composite(:,mni_y_ind,:)=repmat(cursor_color,szM(1),1);
    mniZ_composite(szM(1)-mni_x_ind,:,:)=repmat(cursor_color,szM(2),1);
    
end

subplot(subplotX,subplotY,1);
image(imrotate(mniX_composite,90));
axis('image');
xticklabels(yTicks);
yticklabels(zTicks);
xticks(tickLocY);
yticks(tickLocZ);
xlabel('Y');
ylabel('Z');
title(sprintf('MNI X = %.0f',mni_x));

subplot(subplotX,subplotY,2);
image(flip(imrotate(mniY_composite,90),2));
xticklabels(xTicks);
yticklabels(zTicks);
xticks(tickLocX);
yticks(tickLocZ);
axis('image');
xlabel('X');
ylabel('Z');
text(szM(1)-20,szM(3)-20,'L','Color','white');
text(20,szM(3)-20,'R','Color','white');
title(sprintf('MNI Y = %.0f',mni_y));

subplot(subplotX,subplotY,3);
image(flip(imrotate(mniZ_composite,-90),2));

xticklabels(xTicks);
yticklabels(yTicks);
xticks(tickLocX);
yticks(tickLocY);
xlabel('X');
ylabel('Y');
text(szM(1)-20,szM(2)-20,'R','Color','white');
text(20,szM(2)-20,'L','Color','white');
axis('image');
title(sprintf('MNI Z = %.0f',mni_z));

end
