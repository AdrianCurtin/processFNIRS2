function [Xcorr, maskCV, MA_idx]=pf2_SMAR2(x,N,chNum,tauArtifact,tauClean,minSeg)
% PF2_SMAR2 Enhanced Sliding Motion Artifact Rejection (v2.0) for fNIRS data
%
% An adaptive variant of the SMAR algorithm. Instead of a fixed threshold on
% the coefficient of variation (CV), it detects abrupt changes in the CV
% (its temporal derivative, dCV) relative to each channel's typical dCV, then
% expands each detection to the surrounding stretch of elevated dCV.
%
% Like pf2_SMAR, it operates on raw light intensity only. The CV (std/mean)
% is meaningful only for a strictly positive signal with a stable DC level;
% optical density and hemoglobin are baseline-relative and hover around zero,
% so their CV is unbounded. In a processing pipeline, place pf2_SMAR2 before
% pf2_Intensity2OD.
%
% Reference:
%   Ayaz, H., Izzetoglu, M., Shewokis, P. A., & Onaral, B. (2010).
%   Sliding-window motion artifact rejection for Functional Near-Infrared
%   Spectroscopy. 2010 Annual International Conference of the IEEE
%   Engineering in Medicine and Biology, 6567-6570.
%   DOI: 10.1109/iembs.2010.5627113
%
% Syntax:
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x)
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x, N)
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x, N, chNum, tauArtifact, tauClean, minSeg)
%
% Inputs:
%   x           - Raw light intensity matrix [T x C] where T=samples,
%                 C=channels. Must be strictly positive (before
%                 pf2_Intensity2OD). Not valid for optical density or
%                 hemoglobin data; a warning is issued for channels whose
%                 values are not all positive.
%   N           - Window length in samples for CV calculation (default: 10)
%                 Made odd if even. Typical range: 5-20 samples.
%   chNum       - Channel number mapping [1 x C] (default: 1:C, no pairing)
%                 Columns with the same chNum (e.g. the two wavelengths of
%                 one source-detector pair) are masked together: if any of
%                 them has an artifact, all are masked. Must have one entry
%                 per column of x.
%   tauArtifact - Artifact detection threshold multiplier (default: 10)
%                 A sample is detected when |dCV| > median(|dCV|)*tauArtifact,
%                 with the median taken per channel. Lower = more aggressive.
%                 |dCV| is heavy-tailed, so values below ~8 flag a large
%                 share of artifact-free data.
%   tauClean    - Clean boundary threshold multiplier (default: 1)
%                 Each detection is expanded to the surrounding run of
%                 samples with |dCV| > median(|dCV|)*tauClean. Must be > 0
%                 and is normally below tauArtifact.
%   minSeg      - Minimum clean segment length in samples (default: N+2)
%                 Clean gaps shorter than this between two masked segments
%                 are masked too. Values >= N+1 bridge the separate dCV
%                 peaks at an artifact's onset and offset, so short
%                 artifacts are masked in full.
%   (Empty inputs [] select the default.)
%
% Outputs:
%   Xcorr   - Corrected signal matrix [T x C], same size as input
%             Artifact samples are replaced with NaN values
%   maskCV  - Logical mask [T+2 x C] indicating artifacts (true = artifact)
%             Padded by one false row at start and end (legacy layout):
%             maskCV(2:end-1,:) aligns with the rows of x.
%   MA_idx  - Cell array {1 x C} of artifact segment indices
%             Each cell contains an [M x 2] matrix of [start_idx, end_idx]
%             rows of x for each masked segment
%
% Algorithm:
%   1. Compute local CV in a centered sliding window (shrinking at the
%      recording edges) and its temporal derivative dCV
%   2. Detect samples where |dCV| > median(|dCV|)*tauArtifact (or dCV is
%      NaN, e.g. from NaN input)
%   3. Expand each detection to its surrounding run of
%      |dCV| > median(|dCV|)*tauClean
%   4. Pair columns sharing a chNum (mask union)
%   5. Merge masked segments separated by fewer than minSeg clean samples
%   6. Replace masked samples with NaN
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   wl = data.device.wavelengths();
%   raw = data.raw(:, wl > 0);
%   [corrected, mask, idx] = pf2_SMAR2(raw);
%   fprintf('Rejected %.1f%% of samples\n', 100*mean(mask(2:end-1,:), 'all'));
%
%   % Wavelength pairing (columns 1-18 and 19-36 are the same 18 channels)
%   chNum = [1:18, 1:18];
%   [corrected, mask, idx] = pf2_SMAR2(raw, 10, chNum);
%
% Notes:
%   - The dCV-based adaptive threshold, two-threshold artifact expansion,
%     segment merging, and wavelength pairing are processFNIRS2 extensions
%     of the original SMAR algorithm (Ayaz 2010), which uses a single fixed
%     CV threshold (see pf2_SMAR).
%   - The defaults were calibrated on artifact-free synthetic intensity and
%     the fNIR2000/fNIR1200 sample recordings (about 4% of artifact-free
%     fNIR2000 samples rejected). Check the rejection rate on your own data.
%
% See also: pf2_SMAR, pf2_sSMART, pf2_Intensity2OD, pf2_MotionCorrectTDDR

if nargin<1
    error('pf2:smar2:notEnoughInputs', 'Not enough Input arguments');
end
if nargin<2 || isempty(N)
    N=10;  %Default Window Length
end
if nargin<3 || isempty(chNum)
    chNum=1:size(x,2);
end
if nargin<4 || isempty(tauArtifact)
    tauArtifact=10;
end
if nargin<5 || isempty(tauClean)
    tauClean=1;
end
if nargin<6 || isempty(minSeg)
    minSeg=N+2;
end

if(N<1)
    error('pf2:smar2:invalidWindowLength', 'Invalid Window Length');
end
if ~(tauClean>0)
    error('pf2:smar2:invalidTauClean', ...
        ['tauClean must be > 0 (got %g). With tauClean <= 0 every sample ' ...
         'counts as elevated, so any detection masks the whole channel.'], tauClean);
end
if numel(chNum)~=size(x,2)
    error('pf2:smar2:chNumLength', ...
        'chNum must have one entry per column of x (%d), got %d.', ...
        size(x,2), numel(chNum));
end

nonPos = any(x <= 0, 1);
if any(nonPos)
    warning('pf2:smar2:nonPositiveInput', ...
        ['pf2_SMAR2 expects strictly positive raw light intensity, but %d of %d ' ...
         'channels contain zero or negative values. Optical density and ' ...
         'hemoglobin data are not valid SMAR input; apply SMAR before ' ...
         'pf2_Intensity2OD.'], nnz(nonPos), numel(nonPos));
end

[len, nCh]=size(x);

% The adaptive threshold compares each sample's |dCV| with the channel's
% typical |dCV|. When the (odd-rounded) window spans the whole recording,
% every window holds the same samples, dCV is zero everywhere, and nothing
% can be detected; return unmasked rather than silently passing artifacts.
Nodd = N + (rem(N,2)==0);
if len <= Nodd
    warning('pf2:smar2:insufficientData', ...
        ['Recording has %d samples but the SMAR2 window is %d samples, so ' ...
         'artifacts cannot be detected. Returning the input unmasked; use ' ...
         'a window shorter than the recording.'], len, Nodd);
    Xcorr = x;
    maskCV = false(len+2, nCh);
    MA_idx = repmat({zeros(0,2)}, 1, nCh);
    return
end

[~,dCVx]=calcLocalCV(x,N);
adCVx=abs(dCVx);
dCVx_median=median(adCVx,1,'omitnan');

% Adaptive thresholds relative to each channel's typical |dCV|
dCVthreshold=dCVx_median.*tauArtifact;
dCVthresholdClean=dCVx_median.*tauClean;

detected=adCVx>dCVthreshold|isnan(adCVx);
elevated=adCVx>dCVthresholdClean|isnan(adCVx);

% Expand each detection to its surrounding run of elevated |dCV|
mask=detected;
for i=1:nCh
    [runStart, runEnd]=findRuns(elevated(:,i));
    for t=1:numel(runStart)
        if any(detected(runStart(t):runEnd(t),i))
            mask(runStart(t):runEnd(t),i)=true;
        end
    end
end

% Wavelength pairing: mask union across columns sharing a chNum
[uCh,~,uChIdx]=unique(chNum);
if(length(uCh)<length(chNum))
    for i=1:length(uCh)
        chMatch=find(uChIdx==i);
        if(length(chMatch)<=1)
            continue;
        end
        mask(:,chMatch)=repmat(any(mask(:,chMatch),2),[1,length(chMatch)]);
    end
end

% Merge masked segments separated by short clean gaps
MA_idx=cell(1,nCh);
for i=1:nCh
    [segStart, segEnd]=findRuns(mask(:,i));
    if isempty(segStart)
        MA_idx{i}=zeros(0,2);
        continue;
    end
    gap=segStart(2:end)-segEnd(1:end-1)-1;
    keep=[true; gap(:)>=minSeg];
    mergedStart=segStart(keep);
    mergedEnd=segEnd([keep(2:end); true]);
    for t=1:numel(mergedStart)
        mask(mergedStart(t):mergedEnd(t),i)=true;
    end
    MA_idx{i}=[mergedStart(:), mergedEnd(:)];
end

Xcorr=x;
Xcorr(mask)=nan;

maskCV=[false(1,nCh); mask; false(1,nCh)];

end


%%_Subfunctions_________________________________________________________

%__________________________________________________________________________
function [runStart, runEnd] = findRuns(v)
% FINDRUNS Start and end indices of each run of true values in a vector
%
% Inputs:
%   v - Logical column vector [T x 1]
%
% Outputs:
%   runStart - Column vector of first indices of each true run
%   runEnd   - Column vector of last indices of each true run

d=diff([false; v(:); false]);
runStart=find(d==1);
runEnd=find(d==-1)-1;

end

%__________________________________________________________________________
function [CVx, dCVx] = calcLocalCV(x,N)
% CALCLOCALCV Calculate local coefficient of variation and its derivative
%
% Computes the coefficient of variation (CV = std/mean) within a sliding
% window centered at each sample, plus its first temporal derivative (dCV).
% The window shrinks at the recording edges, so edge samples are evaluated
% rather than rejected outright. Used internally by pf2_SMAR2.
%
% Inputs:
%   x - Input signal matrix [T x C] where T=samples, C=channels
%   N - Window length in samples for SMAR (will be made odd if even)
%
% Outputs:
%   CVx  - Coefficient of variation matrix [T x C]
%   dCVx - First temporal derivative of CVx [T x C] (backward difference;
%          the first sample uses the forward difference)

if nargin<1
    error('pf2:smar2:notEnoughInputs', 'Not enough Input arguments');
end

if(N<1)
    error('pf2:smar2:invalidWindowLength', 'Invalid Window Length');
end

if(rem(N,2)==0)
    N=N+1;
end

% Vectorized local CV via movmean/movstd (O(T) per channel). 'omitnan'
% computes each window over its non-NaN samples; windows shrink at the edges.
mu = movmean(x, N, 1, 'omitnan');
sd = movstd(x, N, 0, 1, 'omitnan');
CVx = sd ./ mu;

% Backward difference; the first sample takes the forward difference so a
% change at the very start of the recording is seen like any other.
dCVx=diff(CVx);
if isempty(dCVx)
    dCVx=zeros(size(CVx));
else
    dCVx=[dCVx(1,:);dCVx];
end

end
