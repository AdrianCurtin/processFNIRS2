function optTo2d(optPoints)


rangeX=max(optPoints.tx)-min(optPoints.tx)
rangeY=max(optPoints.ty)-min(optPoints.ty)
rangeZ=max(optPoints.tz)-min(optPoints.tz)

if(rangeX>rangeY&&rangeY>rangeZ)
    range{3}=optPoints.tx;
    range{2}=optPoints.ty;
    range{1}=optPoints.tzz;
elseif(




end