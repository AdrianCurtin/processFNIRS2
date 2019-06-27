function dataOut=applyTimeChMask(data,ftimeChMask)

data(~ftimeChMask)=nan;

dataOut=data;