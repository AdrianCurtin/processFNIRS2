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




