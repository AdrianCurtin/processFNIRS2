function h=plotCube(x,y,z,sz,faceColor)

if(nargin<5)
    faceColor='red';
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

nodeCoordinates_mapped(:,1)=nodeCoordinates_mapped(:,1)+x;
nodeCoordinates_mapped(:,2)=nodeCoordinates_mapped(:,2)+y;
nodeCoordinates_mapped(:,3)=nodeCoordinates_mapped(:,3)+z;

elementNodes = [1 4 3 2; 5 8 7 6; 1 2 6 5; 3 4 8 7; 2 3 7 6; 1 5 8 4];

elementNodes_mapped=repmat(elementNodes,numCubes,1);

elementNodes_mult=repmat(0:numCubes-1,6,1);
elementNodes_mapped=repmat(elementNodes_mult(:),1,4)*8+elementNodes_mapped;

h=patch('Faces', elementNodes_mapped, 'Vertices', nodeCoordinates_mapped,'FaceColor',faceColor,'EdgeColor','none');
