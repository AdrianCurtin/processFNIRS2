function h=plotCube(x,y,z,sz,faceColor)

if(nargin<5)
    faceColor='red';
end

if(isnumeric(faceColor)&&size(faceColor,1)==length(x))
    replicateColor=true;
    
    faceColorOrig=faceColor;
    
    xyz_orig=[x(:),y(:),z(:)];
else
    replicateColor=false;
end

if(isnumeric(faceColor)&&numel(faceColor)==length(x))
    faceColor=repmat(faceColor(:),1,3);
end



if(nargin<4)
    
    sz=1;
end

nodeCoordinates=[0 0 0; 0 0 1; 1 0 1; 1 0 0; 0 1 0; 0 1 1; 1 1 1; 1 1 0; ];

nodeCoordinates=nodeCoordinates*sz;

numCubes=length(x);

x= repmat(reshape(x,[1,numCubes]),8,1);
x=x(:);

y= repmat(reshape(y,[1,numCubes]),8,1);
y=y(:);
z= repmat(reshape(z,[1,numCubes]),8,1);

z=z(:);

nodeCoordinates_mapped=repmat(nodeCoordinates,numCubes,1);

if(replicateColor)
    faceColor=reshape(faceColor(:),[numCubes,3]);
    faceColor=faceColor(:)';
   faceColor=reshape(repmat(faceColor,8,1),numCubes*8,3);
end

nodeCoordinates_mapped(:,1)=nodeCoordinates_mapped(:,1)+x;
nodeCoordinates_mapped(:,2)=nodeCoordinates_mapped(:,2)+y;
nodeCoordinates_mapped(:,3)=nodeCoordinates_mapped(:,3)+z;

elementNodes = [1 4 3 2; 5 8 7 6; 1 2 6 5; 3 4 8 7; 2 3 7 6; 1 5 8 4];

elementNodes_mapped=repmat(elementNodes,numCubes,1);

elementNodes_mult=repmat(0:numCubes-1,6,1);
elementNodes_mapped=repmat(elementNodes_mult(:),1,4)*8+elementNodes_mapped;

cleanUp=true;
if(cleanUp)
    [uC,uF,uI]=unique(nodeCoordinates_mapped,'rows','stable');
    
    
    uelementNode=uI(elementNodes_mapped); % Get unique coordinatees
    
    [uNode,uNodeF,uNodeI]=unique(sort(uelementNode,2),'rows','stable');  % Get unique faces
    
    elementNodes_mapped=elementNodes_mapped(uNodeF,:); % remove duplicate faces
    
    if(replicateColor)
        

%         xyz_col_idx=uI(1:8:end);
%         
%         %faceColor(uF(xyz_col_idx),:)=faceColorOrig;
%         
%         %faceColor(ismember(uI,xyz_col_idx),:)=faceColor(uF(uI(ismember(uI,xyz_col_idx))),:);
%         
%         
%         coords_modified=ismember(uI,xyz_col_idx);
%         
%         coords_modified(1:8:end)=0;
%         sides=repmat(1:8,1,numCubes)';
%         
%         % If [1,0,0] claimed
%         
%         cubeNums=1:numCubes;
%         
%         Idx2=coords_modified(sides==2); % 0 01 % copy to 6 and 3
%         Idx3=coords_modified(sides==3);  %101 % copy to 7
%         Idx4=coords_modified(sides==4);  %1 0 0 copy to 3 and  8
%         Idx5=coords_modified(sides==5);  %010 % opy to 6 and 8
%         Idx6=coords_modified(sides==6);  %011  Copy to 7
%         Idx7_unmodified=~coords_modified(sides==7);   % 11 1 
%         Idx8=(coords_modified(sides==8));   % 11 0  Copy to 7
%         
%         Idx4to3=Idx4&~Idx3;
%         if(any(Idx4to3))
%             idxToChange3=(cubeNums(Idx4to3))*8-5;
%             idxToChange4=(cubeNums(Idx4to3))*8-4;
%             faceColor(idxToChange3,:)=faceColor(idxToChange4,:);
%             Idx3(Idx4to3)=1;
%         end
%         
%         Idx4to8=Idx4&~Idx8;
%         if(any(Idx4to8))
%             idxToChange8=(cubeNums(Idx4to8))*8;
%             idxToChange4=(cubeNums(Idx4to8))*8-4;
%             faceColor(idxToChange8,:)=faceColor(idxToChange4,:);
%             Idx8(Idx4to8)=1;
%         end
%         
%         Idx2to3=Idx2&~Idx3;
%         if(any(Idx2to3))
%             idxToChange3=(cubeNums(Idx2to3))*8-5;
%             idxToChange2=(cubeNums(Idx2to3))*8-6;
%             faceColor(idxToChange3,:)=faceColor(idxToChange2,:);
%             Idx3(Idx2to3)=1;
%         end
%         
%         Idx2to6=Idx2&~Idx6;
%         if(any(Idx2to6))
%             idxToChange6=(cubeNums(Idx2to6))*8-2;
%             idxToChange2=(cubeNums(Idx2to6))*8-6;
%             faceColor(idxToChange6,:)=faceColor(idxToChange2,:);
%             Idx6(Idx2to6)=1;
%         end
%         
%         Idx5to6=Idx5&~Idx6;
%         if(any(Idx5to6))
%             idxToChange6=(cubeNums(Idx5to6))*8-2;
%             idxToChange5=(cubeNums(Idx5to6))*8-3;
%             faceColor(idxToChange6,:)=faceColor(idxToChange5,:);
%             Idx6(Idx5to6)=1;
%         end
%         
%          Idx5to8=Idx5&~Idx8;
%         if(any(Idx5to8))
%             idxToChange8=(cubeNums(Idx5to8))*8;
%             idxToChange5=(cubeNums(Idx5to8))*8-3;
%             faceColor(idxToChange8,:)=faceColor(idxToChange5,:);
%             Idx8(Idx5to8)=1;
%         end
%         
%         
%         Idx8to7=Idx7_unmodified&Idx8;
%         if(any(Idx8to7))
%             idxToChange7=(cubeNums(Idx8to7))*8-1;
%             idxToChange8=(cubeNums(Idx8to7))*8;
%             faceColor(idxToChange7,:)=faceColor(idxToChange8,:);
%             Idx7_unmodified(Idx8to7)=0;
%         end
%         
%         Idx8to7=Idx7_unmodified&Idx8;
%         if(any(Idx8to7))
%             idxToChange7=(cubeNums(Idx8to7))*8-1;
%             idxToChange8=(cubeNums(Idx8to7))*8;
%             faceColor(idxToChange7,:)=faceColor(idxToChange8,:);
%             Idx7_unmodified(Idx8to7)=0;
%         end
%         
%         Idx8to7=Idx7_unmodified&Idx8;
%         if(any(Idx8to7))
%             idxToChange7=(cubeNums(Idx8to7))*8-1;
%             idxToChange8=(cubeNums(Idx8to7))*8;
%             faceColor(idxToChange7,:)=faceColor(idxToChange8,:);
%             Idx7_unmodified(Idx8to7)=0;
%         end
%         
%         Idx6to7=Idx7_unmodified&Idx6;
%         if(any(Idx6to7))
%             idxToChange7=(cubeNums(Idx6to7))*8-1;
%             idxToChange6=(cubeNums(Idx6to7))*8-2;
%             faceColor(idxToChange7,:)=faceColor(idxToChange6,:);
%             Idx7_unmodified(Idx6to7)=0;
%         end
%         
%         Idx3to7=Idx7_unmodified&Idx3;
%         if(any(Idx3to7))
%             idxToChange7=(cubeNums(Idx3to7))*8-1;
%             idxToChange3=(cubeNums(Idx3to7))*8-5;
%             faceColor(idxToChange7,:)=faceColor(idxToChange3,:);
%             Idx7_unmodified(Idx3to7)=0;
%         end
    else
        faceColor=[ones(size(nodeCoordinates_mapped,1),1)*faceColor(1),ones(size(nodeCoordinates_mapped,1),1)*faceColor(2),ones(size(nodeCoordinates_mapped,1),1)*faceColor(3)]; 
    end
    
    
    %faceColor=faceColor(uF,:);
    %nodeCoordinates_mapped=nodeCoordinates_mapped(uF,:);
end

ka=0.825;
kd=0.4;
ks=0.2;


if(~isstring(faceColor))
    h=patch('Faces', elementNodes_mapped, 'Vertices', nodeCoordinates_mapped,'FaceVertexCData',faceColor,'FaceColor','interp','EdgeColor','none','AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks);
else
    h=patch('Faces', elementNodes_mapped, 'Vertices', nodeCoordinates_mapped,'FaceColor',faceColor,'EdgeColor','none','AmbientStrength',ka, 'DiffuseStrength', kd, 'SpecularStrength',ks);

end