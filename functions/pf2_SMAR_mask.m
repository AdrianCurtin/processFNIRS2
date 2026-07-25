function [maskCV]=pf2_SMAR_mask(x,N,tauUp,tauLow)
% PF2_SMAR_MASK Create logical mask using SMAR artifact detection
%
% Returns a logical mask (true = clean, false = artifact) using the SMAR
% algorithm's coefficient of variation (CV) criterion. Unlike pf2_SMAR which
% replaces artifacts with NaN, this returns only the mask for external use.
%
% Reference:
%   Ayaz, H. et al. (2010). Sliding-window motion artifact rejection for
%   Functional Near-Infrared Spectroscopy. Conf Proc IEEE Eng Med Biol Soc.
%
% Syntax:
%   maskCV = pf2_SMAR_mask(x)
%   maskCV = pf2_SMAR_mask(x, N, tauUp, tauLow)
%
% Inputs:
%   x      - Input signal matrix [T x C]
%   N      - Window length in samples (default: 10, made odd if even)
%   tauUp  - Upper CV threshold (default: 0.025). Clean if |CV| < tauUp.
%   tauLow - Lower CV threshold (default: -1, disabled)
%
% Outputs:
%   maskCV - Logical mask [T x C] where true = clean, false = artifact/NaN
%
% See also: pf2_SMAR, pf2_SMAR2, pf2_thresholdValues_mask

if nargin<1
    error('pf2:smarMask:notEnoughInputs', 'Not enough Input arguments');
elseif nargin==1
     N=10;
end

if(nargin<3)
     tauUp=0.025;
end

if(nargin<4)
    tauLow=-1;
end

if(N<1)
    error('pf2:smarMask:invalidWindowLength', 'Invalid Window Length');
end

CVx=calcLocalCV(x,N);

maskCV=(abs(CVx)<tauUp&~isnan(CVx)&abs(CVx)>tauLow);

end


%%_Subfunctions_________________________________________________________

function [CVx] = calcLocalCV(x,N)
% CALCLOCALCV Calculate local coefficient of variation for SMAR masking
%
% Computes the coefficient of variation (CV = std/mean) within a sliding
% window centered at each sample. Used internally by pf2_SMAR_mask.
%
% Inputs:
%   x - Input signal matrix [T x C] where T=samples, C=channels
%   N - Window length in samples (will be made odd if even)
%
% Outputs:
%   CVx - Coefficient of variation matrix [T x C]
%         First and last wSize samples are NaN where wSize = (N-1)/2

if nargin<1
    error('pf2:smarMask:notEnoughInputs', 'Not enough Input arguments');
end

if(N<1)
    error('pf2:smarMask:invalidWindowLength', 'Invalid Window Length');
end

l=size(x);
len=l(1);

if(rem(N,2)==0)
    N=N+1;
end

wSize=(N-1)/2;

% Vectorized local CV via movmean/movstd, with the same endpoint NaNs the loop
% (i=wSize+1:len-wSize) produced. ~40x faster; matches the loop to floating-
% point precision (ULP-level movstd/movmean differences, zero mask flips on
% real/random data); see pf2_SMAR for the full rationale.
mu = movmean(x, N, 1, 'omitnan');
sd = movstd(x, N, 0, 1, 'omitnan');
CVx = sd ./ mu;
CVx([1:min(wSize,len), max(1,len-wSize+1):len], :) = NaN;

end