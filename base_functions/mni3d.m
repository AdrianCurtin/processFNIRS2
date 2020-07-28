function mni3d(x,y,z)

% Uses dataset from http://sprout022.sprout.yale.edu/mni2tal/mni2tal.html
% To project MNI scans
% Used to calibrate brain size


A=imread('MNI_T1_1mm_stripped_xy.png');

A=reshape(A,217,181,181);

A=permute(A,[2,1,3]);

A=A(:,:,end:-1:1);

szA=size(A);

center=[90,126,72];

imX=reshapeIM(A(szA(1)-center(1)-x,:,:));

imY=reshapeIM(A(:,szA(2)-center(2)-y,:));


imZ=reshapeIM(A(:,:,szA(3)-center(3)-z));

imgCoord1=[szA(1)-center(1),y,szA(3)-center(3)];
imgCoord2=[0-center(1),y,szA(3)-center(3)];
imgCoord3=[szA(1)-center(1),y,0-center(3)];
imgCoord4=[0-center(1),y,0-center(3)];

xImage = [imgCoord1(1) imgCoord2(1); imgCoord3(1) imgCoord4(1)];       % The x data for the image corners
yImage = [imgCoord1(2) imgCoord2(2); imgCoord3(2) imgCoord4(2)];            % The y data for the image corners
zImage = [imgCoord1(3) imgCoord2(3); imgCoord3(3) imgCoord4(3)];   % The z data for the image corners

[imY3,imYA]=makeAlpha(imY);

hold on

h=surf(xImage,yImage,zImage,...    % Plot the surface
     'CData',imY3,...
     'FaceColor','texturemap','FaceLighting','none','FaceAlpha','texturemap','AlphaData',imYA,'EdgeColor','none');

imgCoord1=[x,szA(2)-center(2),szA(3)-center(3)];
imgCoord2=[x,0-center(2),szA(3)-center(3)];
imgCoord3=[x,szA(2)-center(2),0-center(3)];
imgCoord4=[x,0-center(2),0-center(3)];

xImage = [imgCoord1(1) imgCoord2(1); imgCoord3(1) imgCoord4(1)];       % The x data for the image corners
yImage = [imgCoord1(2) imgCoord2(2); imgCoord3(2) imgCoord4(2)];            % The y data for the image corners
zImage = [imgCoord1(3) imgCoord2(3); imgCoord3(3) imgCoord4(3)];   % The z data for the image corners


[imX3,imXA]=makeAlpha(imX);
h=surf(xImage,yImage,zImage,...    % Plot the surface
     'CData',imX3,...
     'FaceColor','texturemap','FaceLighting','none','FaceAlpha','texturemap','AlphaData',imXA,'EdgeColor','none');
 

imgCoord1=[szA(1)-center(1),szA(2)-center(2),z];
imgCoord2=[0-center(1),szA(2)-center(2),z];
imgCoord3=[szA(1)-center(1),0-center(2),z];
imgCoord4=[0-center(1),0-center(2),z];

xImage = [imgCoord1(1) imgCoord2(1); imgCoord3(1) imgCoord4(1)];       % The x data for the image corners
yImage = [imgCoord1(2) imgCoord2(2); imgCoord3(2) imgCoord4(2)];            % The y data for the image corners
zImage = [imgCoord1(3) imgCoord2(3); imgCoord3(3) imgCoord4(3)];   % The z data for the image corners


[imZ3,imZA]=makeAlpha(imZ);
h=surf(xImage,yImage,zImage,...    % Plot the surface
     'CData',imZ3,...
     'FaceColor','texturemap','FaceLighting','none','FaceAlpha','texturemap','AlphaData',imZA,'EdgeColor','none'); 
hold off

axis square

end


function im=reshapeIM(im)

szIm=size(im);
imIdx=(szIm==1);

im=reshape(im,szIm(~imIdx))';

end

function [im3,imAlpha]=makeAlpha(im)

im3=repmat(im,[1,1,3]);

imAlpha=im(:,:)~=0;

end
