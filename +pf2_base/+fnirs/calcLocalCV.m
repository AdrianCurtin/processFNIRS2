function [CVx] = calcLocalCV(x,N)
% CALCLOCALCV Calculate local coefficient of variation for SMAR technique
%
% Computes the local coefficient of variation (CV = std/mean) in a sliding
% window. Used internally by pf2_SMAR and pf2_SMAR2 for motion artifact
% detection. The CV is calculated as: CV = sqrt(variance) / abs(mean).
%
% Reference:
%   Ayaz, H. et al. (2010). Sliding-window motion artifact rejection for
%   Functional Near-Infrared Spectroscopy. Conf Proc IEEE Eng Med Biol Soc.
%
% Syntax:
%   CVx = calcLocalCV(x)
%   CVx = calcLocalCV(x, N)
%
% Inputs:
%   x - Input signal matrix [T x C double] where T=samples, C=channels
%       Can be raw intensity, optical density, or hemoglobin data.
%   N - Window length in samples (default: 500)
%       Larger windows provide more stable CV estimates but less temporal
%       resolution. Minimum value: 1.
%
% Outputs:
%   CVx - Coefficient of variation matrix [T-N x C double]
%         Output is shorter than input by N samples (no CV for first N points).
%         Returns NaN matrix if signal length <= N.
%
% Algorithm:
%   1. For each position n in sliding window: compute local mean over [n:n+N]
%   2. Compute local variance: sum((x - mean)^2) / N
%   3. Calculate CV: sqrt(variance) / abs(mean)
%
% Example:
%   % Compute CV with 100-sample window
%   CV = calcLocalCV(rawData, 100);
%   artifacts = CV > 0.025;  % Threshold for artifact detection
%
% See also: pf2_SMAR, pf2_SMAR2, std, mean

if nargin<1
    error('pf2_base:fnirs:calcLocalCV:notEnoughInputs', 'Not enough Input arguments');
elseif nargin==1
     N=500;  %Default Window Length
end

if(N<1)
    error('pf2_base:fnirs:calcLocalCV:invalidWindowLength', 'Invalid Window Length');
end

l=size(x);
wid=l(2);%width
len=l(1);%length

xi=zeros(len-N,wid);
xj=zeros(len-N,wid);

CVx=zeros(len-N,wid);

if(len>N)
    for n=1:length(x)-N
        xi(n,:)=sum(x(n:n+N,:))./(N+1);
        for j=0:N
            xj(n,:)=xj(n,:)+(x(n+j,:)-xi(n,:)).^2;
        end
        xj(n)=xj(n)/N;

        CVx(n,:)=sqrt(xj(n,:))./abs(xi(n,:));
    end

else
    CVx(:,:)=nan;
end