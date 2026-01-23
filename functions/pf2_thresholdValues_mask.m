function thresholdedMask= pf2_thresholdValues_mask(data,max,min)
% PF2_THRESHOLDVALUES_MASK Create logical mask for values within threshold range
%
% Creates a logical mask indicating which values in the input data fall within
% a specified range. Returns true for valid samples (within range) and false
% for samples outside the range. Useful for tracking which samples are rejected
% by threshold-based artifact detection without modifying the original data.
%
% Reference:
%   Internal pf2 implementation. Standard threshold-based artifact rejection.
%
% Syntax:
%   thresholdedMask = pf2_thresholdValues_mask(data, max)
%   thresholdedMask = pf2_thresholdValues_mask(data, max, min)
%
% Inputs:
%   data - Input signal matrix [T x C] where T=samples, C=channels
%          Can be raw intensity, optical density, or hemoglobin data.
%   max  - Upper threshold value (scalar)
%          Values >= max are marked as invalid (false).
%   min  - Lower threshold value (scalar, optional)
%          Values <= min are marked as invalid (false).
%          If not provided, only upper threshold is applied.
%
% Outputs:
%   thresholdedMask - Logical mask [T x C logical], same size as input
%                     true  = valid sample (within range)
%                     false = invalid sample (outside range or NaN)
%
% Algorithm:
%   1. Initialize mask with zeros (false)
%   2. Set mask to true where value < max
%   3. If min provided, set mask to false where value <= min
%   4. Convert to logical array
%
% Example:
%   % Find saturated samples (above 4095 for 12-bit ADC)
%   validMask = pf2_thresholdValues_mask(rawData, 4095);
%   percentValid = 100 * mean(validMask(:));
%   fprintf('%.1f%% of samples are valid\n', percentValid);
%
%   % Find samples within physiological range
%   validMask = pf2_thresholdValues_mask(hbData, 100, -100);
%   cleanData = hbData;
%   cleanData(~validMask) = NaN;
%
% Notes:
%   - To get modified data instead of mask, use pf2_thresholdValues
%   - The mask can be combined with other masks using logical operators
%   - NaN values in input result in false (invalid) in output mask
%
% See also: pf2_thresholdValues, pf2_TakizawaRejection, pf2_SMAR, applyTimeChMask

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