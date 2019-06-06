function thresholdedData= pf2_thresholdValues(data,max,min)
    % Function which replaces values above and below set parameters with
    % NaN
    thresholdedData=nan(size(data));
    validMax=data<max;
    if(nargin<3)
       thresholdedData(validMax)=data(validMax);
    else
        validMin=data>min;
        thresholdedData(validMin.*validMax==1)=data(validMin.*validMax==1);
    end
    
end