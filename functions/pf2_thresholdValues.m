function thresholdedData= pf2_thresholdValues(data,max,min)
% PF2_THRESHOLDVALUES Replace values outside specified range with NaN
%
% Applies threshold-based artifact rejection by replacing values that exceed
% an upper bound or fall below a lower bound with NaN. This is useful for
% removing saturated signals, extreme outliers, or physiologically implausible
% values from fNIRS data.
%
% Reference:
%   Internal pf2 implementation. Standard threshold-based artifact rejection.
%
% Syntax:
%   thresholdedData = pf2_thresholdValues(data, max)
%   thresholdedData = pf2_thresholdValues(data, max, min)
%
% Inputs:
%   data - Input signal matrix [T x C] where T=samples, C=channels
%          Can be raw intensity, optical density, or hemoglobin data.
%   max  - Upper threshold value (scalar)
%          Values >= max are replaced with NaN.
%   min  - Lower threshold value (scalar, optional)
%          Values <= min are replaced with NaN.
%          If not provided, only upper threshold is applied.
%
% Outputs:
%   thresholdedData - Thresholded signal matrix [T x C], same size as input
%                     Values outside the valid range are replaced with NaN.
%
% Algorithm:
%   1. Initialize output with NaN values
%   2. Copy values from input where value < max
%   3. If min provided, set values <= min back to NaN
%
% Example:
%   % Remove saturated values (above 4095 for 12-bit ADC)
%   cleanRaw = pf2_thresholdValues(rawData, 4095);
%
%   % Remove both saturated and below-threshold values
%   cleanData = pf2_thresholdValues(hbData, 100, -100);
%
% Notes:
%   - Returns a logical mask instead of modified data, use pf2_thresholdValues_mask
%   - NaN values in input remain NaN in output
%
% See also: pf2_thresholdValues_mask, pf2_TakizawaRejection, pf2_SMAR

    thresholdedData=nan(size(data));
    validMax=data<max;
    if(nargin<3)
       thresholdedData(validMax)=data(validMax);
    else
        validMin=data>min;
        thresholdedData(validMax)=data(validMax);
        thresholdedData(~validMin)=nan;
    end
    
end