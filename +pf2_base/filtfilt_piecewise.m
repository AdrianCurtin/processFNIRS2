function y = filtfilt_piecewise(b,a,x,minFilt,restoreMean)
% FILTFILT_PIECEWISE Zero-phase filtering of contiguous non-NaN segments
%
% Applies zero-phase digital filtering (filtfilt) to signals containing NaN
% values by independently filtering each contiguous block of valid (non-NaN)
% data. Unlike filtfilt_interp, this approach does not interpolate across
% gaps, making it more appropriate when NaN regions represent true data
% discontinuities rather than brief artifacts.
%
% Reference:
%   Internal pf2 implementation based on standard MATLAB filtfilt.
%   See also: Gustafsson, F. (1996). Determining the initial states in
%   forward-backward filtering. IEEE Trans Signal Process 44(4):988-992.
%
% Syntax:
%   y = filtfilt_piecewise(b, a, x)
%   y = filtfilt_piecewise(b, a, x, minFilt)
%   y = filtfilt_piecewise(b, a, x, minFilt, restoreMean)
%
% Inputs:
%   b           - Filter numerator coefficients [1 x N double]
%                 Obtained from filter design functions (e.g., butter, fir1).
%   a           - Filter denominator coefficients [1 x M double]
%                 For FIR filters, a = 1. For IIR filters, obtained from
%                 filter design functions.
%   x           - Input signal matrix [T x C double] where T=samples, C=channels
%                 May contain NaN values marking artifacts or missing data.
%   minFilt     - Minimum segment length for filtering (default: 5)
%                 Segments shorter than minFilt samples are set to NaN.
%                 Should be at least 3x the filter order for stable results.
%   restoreMean - Logical flag to restore segment mean after filtering
%                 (default: false). When true, adds back the mean of each
%                 segment after high-pass or band-pass filtering.
%
% Outputs:
%   y - Filtered signal matrix [T x C double], same size as input
%       NaN values remain at their original positions. Short segments
%       (< minFilt samples) are set to NaN.
%
% Algorithm:
%   1. Identify contiguous non-NaN segments in each channel
%   2. For each segment longer than minFilt samples:
%      a. Apply zero-phase filtering via filtfilt
%      b. Optionally restore segment mean
%   3. Short segments and NaN regions remain as NaN
%
% Example:
%   % Design a low-pass Butterworth filter
%   [b, a] = butter(4, 0.1/(10/2), 'low');
%
%   % Filter data with gaps
%   data = randn(1000, 5);
%   data(100:200, 2) = NaN;  % Large gap in channel 2
%   filtered = pf2_base.filtfilt_piecewise(b, a, data);
%
%   % With mean restoration for high-pass filtering
%   [b, a] = butter(4, 0.01/(10/2), 'high');
%   filtered = pf2_base.filtfilt_piecewise(b, a, data, 10, true);
%
% Notes:
%   - Channels with fewer than minFilt total valid samples are skipped
%   - Each segment is filtered independently (no continuity across gaps)
%   - Recommended minFilt >= 3 * filter_order for stable filtering
%
% See also: filtfilt_interp, filtfilt, butter, pf2_lpf, pf2_hpf

isNanArr=(isnan(x));
diffNan=diff(isNanArr);
diffNan=[ones([1,size(x,2)]);diffNan]; %add first term
diffNan(1,~isNanArr(1,:))=-1;

if(nargin<5)
   restoreMean=false; 
end

if(nargin<4)
   minFilt=5; 
end

y=nan(size(x));

for i=1:size(x,2)
	if(sum(~isnan(x(:,i)))<minFilt) %skip really dead channels or blocked channels
		continue;
    end
    
    cleanBlockStart=find(diffNan(:,i)==-1);
    cleanBlockEnd=find(diffNan(:,i)==1)-1;
    
    if(isempty(cleanBlockStart))
       continue; 
    end
    
    if(~isempty(cleanBlockEnd)&&cleanBlockEnd(1)<cleanBlockStart(1))
        cleanBlockEnd(1)=[];
    end
    if(length(cleanBlockStart)>length(cleanBlockEnd))
       cleanBlockEnd(end+1)=size(x,1);
    end
    
    
    for j=1:length(cleanBlockStart)
        
        xIdx=cleanBlockStart(j):cleanBlockEnd(j);
        if(length(xIdx)>minFilt)
            y(xIdx,i)=pf2_base.external.filtfilt_classic(b,a,x(xIdx,i)')';
            
            if(restoreMean)
                y(xIdx,i)=y(xIdx,i)+nanmean(x(xIdx,i));
            end
        else
            y(xIdx,i)=nan; 
        end
    end

	
end

