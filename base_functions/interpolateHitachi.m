function interpolateHitachi(fNIRarr,minVal,maxVal,clrmap)
if(nargin<4)
    clrmap='hot';
end
if(nargin<3)
    maxVal=max(fNIRarr);
end

if(nargin<2)
   minval=min(fNIRarr); 
end
interpArrCh=[-1,18,22,-1,-1,-1;9,13,17,21,-1,-1;4,8,12,16,20,-1;-1,3,7,11,15,19;-1,-1,2,6,10,14;-1,-1,-1,1,5,-1];
interpArr=zeros(size(interpArrCh));

for i=1:length(fNIRarr)
    interpArr(interpArrCh==i)=fNIRarr(i);
end
[X,Y] = meshgrid(1:size(interpArrCh));

[Xq,Yq] = meshgrid(0:0.1:size(interpArrCh,1)+1);
Vq = interp2(X,Y,interpArr,Xq,Yq);

Vq(Vq<minVal)=minVal;
Vq(Vq>maxVal)=maxVal;
figure(17)

imagesc(Vq);
colormap(clrmap);
colorbar()

return






