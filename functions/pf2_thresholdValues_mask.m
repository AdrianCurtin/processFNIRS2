function thresholdedMask= pf2_thresholdValues_mask(data,max,min)
    % Function which replaces values above and below set parameters with
    % NaN
    thresholdedMask=zeros(size(data));
    validMax=data<max;
    if(nargin<3)
       thresholdedMask(validMax)=1;
    else
        validMin=data>min;
        thresholdedMask(validMax)=1;
        thresholdedMask(~validMin)=0;
    end
	thresholdedMask=thresholdedMask==1;
    
end