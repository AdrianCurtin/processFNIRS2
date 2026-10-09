function [maskCV]=pf2_SMAR_mask(x,N,tauUp,tauLow)
% PF2_SMAR_MASK Create logical mask using SMAR artifact detection
%
% Returns a logical mask (true = clean, false = artifact) using the SMAR
% algorithm's coefficient of variation (CV) criterion. Unlike pf2_SMAR which
% replaces artifacts with NaN, this returns only the mask for external use.
%
% Like pf2_SMAR, this operates on raw light intensity only: the CV is not
% meaningful for baseline-relative optical density or hemoglobin data. In a
% processing pipeline, place it before pf2_Intensity2OD.
%
% Reference:
%   Ayaz, H., Izzetoglu, M., Shewokis, P. A., & Onaral, B. (2010).
%   Sliding-window motion artifact rejection for Functional Near-Infrared
%   Spectroscopy. 2010 Annual International Conference of the IEEE
%   Engineering in Medicine and Biology, 6567-6570.
%   DOI: 10.1109/iembs.2010.5627113
%
% Syntax:
%   maskCV = pf2_SMAR_mask(x)
%   maskCV = pf2_SMAR_mask(x, N, tauUp, tauLow)
%
% Inputs:
%   x      - Raw light intensity matrix [T x C], strictly positive
%            (before pf2_Intensity2OD). Not valid for OD or hemoglobin.
%   N      - Window length in samples (default: 10, made odd if even)
%   tauUp  - Upper CV threshold (default: 0.025). Clean if |CV| < tauUp.
%   tauLow - Lower CV threshold (default: -1, disabled)
%
% Outputs:
%   maskCV - Logical mask [T x C] where true = clean, false = artifact/NaN
%
% Algorithm:
%   1. Compute local CV of the intensity in a centered sliding window:
%      CV = std(window) / mean(window)
%   2. Mark a sample clean where tauLow < |CV| < tauUp and CV is not NaN
%      (the first and last (N-1)/2 samples have no full window and are
%      marked artifact)
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   wl = data.device.wavelengths();
%   clean = pf2_SMAR_mask(data.raw(:, wl > 0));
%   fprintf('Clean: %.1f%% of samples\n', 100*mean(clean(:)));
%
% See also: pf2_SMAR, pf2_SMAR2, pf2_Intensity2OD, pf2_thresholdValues_mask

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

nonPos = any(x <= 0, 1);
if any(nonPos)
    warning('pf2:smarMask:nonPositiveInput', ...
        ['pf2_SMAR_mask expects strictly positive raw light intensity, but %d of %d ' ...
         'channels contain zero or negative values. Optical density and ' ...
         'hemoglobin data are not valid SMAR input; apply SMAR before ' ...
         'pf2_Intensity2OD.'], nnz(nonPos), numel(nonPos));
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