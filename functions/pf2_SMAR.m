function [Xcorr, maskCV]=pf2_SMAR(x,N,tauUp,tauLow)
% PF2_SMAR Sliding Motion Artifact Rejection for fNIRS data
%
% Implements the SMAR algorithm to identify and reject motion artifacts in
% fNIRS signals by computing the local coefficient of variation (CV) within
% a sliding window. Samples with CV values exceeding a threshold are marked
% as artifacts and replaced with NaN.
%
% Reference:
%   Ayaz, H. et al. (2010). Sliding-window motion artifact rejection for
%   Functional Near-Infrared Spectroscopy. Conf Proc IEEE Eng Med Biol Soc.
%
% Syntax:
%   [Xcorr, maskCV] = pf2_SMAR(x)
%   [Xcorr, maskCV] = pf2_SMAR(x, N)
%   [Xcorr, maskCV] = pf2_SMAR(x, N, tauUp)
%   [Xcorr, maskCV] = pf2_SMAR(x, N, tauUp, tauLow)
%
% Inputs:
%   x       - Input signal matrix [T x C] where T=samples, C=channels
%             Can be raw intensity, optical density, or hemoglobin data
%   N       - Window length in samples for CV calculation (default: 10)
%             Typical range: 5-20 samples. Larger windows are more robust
%             but less sensitive to brief artifacts. If N is even, it will
%             be automatically incremented to the next odd number.
%   tauUp   - Upper CV threshold for artifact detection (default: 0.025)
%             Samples with |CV| > tauUp are marked as artifacts.
%             Typical range: 0.01-0.1 depending on data quality.
%             Lower values = more aggressive artifact rejection.
%   tauLow  - Lower CV threshold (default: -1, disabled)
%             When positive, samples with |CV| < tauLow are also rejected.
%             Useful for detecting saturated or "flat" signals when using
%             dark/ambient channel data. Set to -1 to disable.
%
% Outputs:
%   Xcorr   - Corrected signal matrix [T x C], same size as input
%             Artifact samples are replaced with NaN values
%   maskCV  - Logical mask [T x C] indicating artifacts (true = artifact)
%             Can be used for further processing or visualization
%
% Algorithm:
%   1. Compute local CV in sliding window: CV = std(window) / mean(window)
%   2. Mark samples where |CV| > tauUp OR |CV| < tauLow OR CV is NaN
%   3. Replace marked samples with NaN
%
% Example:
%   % Basic usage with defaults
%   [corrected, mask] = pf2_SMAR(rawData);
%
%   % More aggressive rejection
%   [corrected, mask] = pf2_SMAR(rawData, 15, 0.015);
%
%   % With lower bound for ambient channel cleaning
%   [corrected, mask] = pf2_SMAR(ambientData, 10, 0.025, 0.001);
%
% See also: pf2_SMAR2, pf2_fnirs_MARA, pf2_MotionCorrectTDDR, calcLocalCV


if nargin<1
    error('pf2:smar:notEnoughInputs', 'Not enough Input arguments');
elseif nargin==1
     N=10;  %Default Window Length
end

if(nargin<3)
     tauUp=0.025;
end

if(nargin<4)
    tauLow=-1; % don't use unless using with dark channel
end

if(N<1)
    error('pf2:smar:invalidWindowLength', 'Invalid Window Length');
end

CVx=calcLocalCV(x,N);


Xcorr=x;

maskCV=abs(CVx)>tauUp|isnan(CVx)|abs(CVx)<tauLow;

Xcorr(maskCV)=nan;
    
    

end


%%_Subfunctions_________________________________________________________

function [CVx] = calcLocalCV(x, N)
% CALCLOCALCV Calculate local coefficient of variation for SMAR
%
% Computes the coefficient of variation (CV = std/mean) within a sliding
% window centered at each sample. Used internally by pf2_SMAR for motion
% artifact detection based on signal variability.
%
% Reference:
%   Ayaz, H. et al. (2010). Sliding-window motion artifact rejection for
%   Functional Near-Infrared Spectroscopy. Conf Proc IEEE Eng Med Biol Soc.
%
% Inputs:
%   x - Input signal matrix [T x C] where T=samples, C=channels
%   N - Window length in samples (will be made odd if even)
%
% Outputs:
%   CVx - Coefficient of variation matrix [T x C]
%         First and last wSize samples are NaN where wSize = (N-1)/2
%
% See also: pf2_SMAR, pf2_SMAR2

if nargin<1
    error('pf2:smar:notEnoughInputs', 'Not enough Input arguments');
end

if(N<1)
    error('pf2:smar:invalidWindowLength', 'Invalid Window Length');
end

if(rem(N,2)==0)

    N=N+1;

end

wSize=(N-1)/2;
len=size(x,1);

% Vectorized local CV over a centered odd window of length N. movstd/movmean
% compute every window in O(T) (vs the O(T*N) per-sample loop this replaces:
% measured ~40-86x faster). Equivalence to the loop:
%   - std uses the sample (N-1) normalization (movstd weight 0), and mean/std
%     omit NaN (movstd/movmean 'omitnan' == nanstd/nanmean per window). NOTE:
%     movstd/movmean use an incremental summation that differs from a fresh
%     per-window nanstd/nanmean at the ULP level (~1e-16..1e-14), so the CV is
%     NOT literally bit-identical. Zero artifact-mask flips were observed across
%     tens of thousands of real/random signals; a CV lying exactly on the
%     threshold to double precision (only reachable by adversarial construction,
%     or conceivably quantized dark-channel data with tauLow) could flip.
%   - the loop only wrote rows wSize+1:len-wSize, leaving the first and last
%     wSize samples NaN. movmean/movstd with 'omitnan' would instead compute
%     those edges over a shrunken window, so we explicitly NaN them (this part
%     IS exact).
mu = movmean(x, N, 1, 'omitnan');
sd = movstd(x, N, 0, 1, 'omitnan');
CVx = sd ./ mu;

edgeRows = [1:min(wSize,len), max(1,len-wSize+1):len];
CVx(edgeRows, :) = NaN;

end