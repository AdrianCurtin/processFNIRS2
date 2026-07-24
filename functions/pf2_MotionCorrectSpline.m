function [dodCorrected] = pf2_MotionCorrectSpline(dod, sample_rate, p, tMotion, tMask, STDEVthresh, AMPthresh, accelerate)
% PF2_MOTIONCORRECTSPLINE Spline interpolation motion artifact correction
%
% Detects motion artifacts using amplitude and derivative thresholds, then
% corrects them by fitting a cubic smoothing spline to each artifact
% segment and subtracting it. This removes the slow drift introduced by
% the motion while preserving the surrounding signal. Often combined with
% wavelet correction in a hybrid pipeline (spline first, then wavelet for
% residual artifacts).
%
% Reference:
%   Scholkmann, F., Spichtig, S., Muehlemann, T. & Wolf, M. (2010).
%   How to detect and reduce movement artifacts in near-infrared imaging
%   using moving standard deviation and spline interpolation.
%   Physiological Measurement, 31(5), 649-662.
%
%   Adapted from HOMER3: hmrR_MotionCorrectSpline
%   Barker, J. W., Aarabi, A. & Bhatt, T. J. (2013).
%
% Syntax:
%   dodCorrected = pf2_MotionCorrectSpline(dod, sample_rate)
%   dodCorrected = pf2_MotionCorrectSpline(dod, sample_rate, p)
%   dodCorrected = pf2_MotionCorrectSpline(dod, sample_rate, p, tMotion, tMask, STDEVthresh, AMPthresh)
%   dodCorrected = pf2_MotionCorrectSpline(dod, sample_rate, p, tMotion, tMask, STDEVthresh, AMPthresh, accelerate)
%
% Inputs:
%   dod          - Optical density signal [T x C] where T=samples, C=channels
%   sample_rate  - Sampling rate in Hz [scalar]
%   p            - Spline smoothing parameter, 0 to 1 (default: 0.99)
%                  Values closer to 1 produce smoother splines. Typical: 0.99.
%   tMotion      - Time window for motion detection in seconds (default: 0.5)
%   tMask        - Time to mask around detected artifacts in seconds (default: 1)
%   STDEVthresh  - Threshold for signal amplitude change as multiple of
%                  standard deviation. Larger = less sensitive. (default: 10)
%   AMPthresh    - Threshold for signal derivative change in OD units.
%                  Larger = less sensitive. (default: 0.5)
%   accelerate   - Parallel acceleration mode (optional, string, default: 'auto')
%                  'auto'   - use parfor if pool running and nChannels > 8
%                  'parfor' - use parfor if available
%                  'none'   - serial processing
%
% Outputs:
%   dodCorrected - Motion-corrected optical density [T x C]
%
% Algorithm:
%   1. For each channel, detect motion artifacts:
%      a. Compute moving std in sliding window of tMotion seconds
%      b. Compute signal amplitude change in same window
%      c. Mark samples where moving_std > STDEVthresh * global_std
%         OR amplitude_change > AMPthresh
%   2. Extend artifact masks by tMask seconds on each side
%   3. For each artifact segment:
%      a. Fit cubic smoothing spline with parameter p to the segment
%      b. Subtract spline fit from the signal (removes drift from artifact)
%   4. Return corrected signal
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   od = pf2_Intensity2OD(data.raw);
%   corrected = pf2_MotionCorrectSpline(od, data.fs);
%
%   % Hybrid: spline + wavelet
%   corrected = pf2_MotionCorrectSpline(od, data.fs, 0.99);
%   corrected = pf2_MotionCorrectWavelet(corrected, data.fs);
%
% See also: pf2_MotionCorrectTDDR, pf2_MotionCorrectWavelet, pf2_SMAR, csaps

%% Defaults
if nargin < 8 || isempty(accelerate), accelerate = 'auto'; end
if nargin < 7 || isempty(AMPthresh), AMPthresh = 0.5; end
if nargin < 6 || isempty(STDEVthresh), STDEVthresh = 10; end
if nargin < 5 || isempty(tMask), tMask = 1; end
if nargin < 4 || isempty(tMotion), tMotion = 0.5; end
if nargin < 3 || isempty(p), p = 0.99; end

[T, nCh] = size(dod);
dodCorrected = dod;

nMotion = max(1, round(tMotion * sample_rate));
nMask = round(tMask * sample_rate);
hasCsaps = exist('csaps', 'file') > 0;

% Determine whether to use parfor
useParfor = false;
if ~strcmp(accelerate, 'none')
    [canUse, poolRunning] = pf2_base.accel.canParfor();
    if strcmp(accelerate, 'parfor')
        useParfor = canUse;
    elseif strcmp(accelerate, 'auto')
        useParfor = canUse && poolRunning && nCh > 8;
    end
end

if useParfor
    parfor ch = 1:nCh
        dodCorrected(:, ch) = processChannel(dod(:, ch), T, nMotion, nMask, STDEVthresh, AMPthresh, p, sample_rate, hasCsaps);
    end
else
    for ch = 1:nCh
        dodCorrected(:, ch) = processChannel(dod(:, ch), T, nMotion, nMask, STDEVthresh, AMPthresh, p, sample_rate, hasCsaps);
    end
end

end


function chOut = processChannel(signal, T, nMotion, nMask, STDEVthresh, AMPthresh, p, sample_rate, hasCsaps)
% PROCESSCHANNEL Detect and correct motion artifacts for a single channel.

    chOut = signal;

    %% Step 1: Detect motion artifacts
    artifactMask = detectMotionArtifacts(signal, nMotion, STDEVthresh, AMPthresh);

    %% Step 2: Extend mask by tMask
    if nMask > 0 && any(artifactMask)
        extended = artifactMask;
        artIdx = find(artifactMask);
        for i = 1:length(artIdx)
            lo = max(1, artIdx(i) - nMask);
            hi = min(T, artIdx(i) + nMask);
            extended(lo:hi) = true;
        end
        artifactMask = extended;
    end

    if ~any(artifactMask)
        return;  % No artifacts detected
    end

    %% Step 3: Correct each contiguous artifact segment
    segments = findContiguousSegments(artifactMask);

    for s = 1:size(segments, 1)
        iStart = segments(s, 1);
        iEnd = segments(s, 2);
        segLen = iEnd - iStart + 1;

        if segLen < 2
            continue;
        end

        tSeg = (1:segLen)';
        ySeg = signal(iStart:iEnd);

        validIdx = ~isnan(ySeg);
        if sum(validIdx) < 2
            continue;
        end

        if hasCsaps
            pp = csaps(tSeg(validIdx), ySeg(validIdx), p);
            splineFit = fnval(pp, tSeg);
        else
            polyOrd = min(5, sum(validIdx) - 1);
            coeffs = polyfit(tSeg(validIdx), ySeg(validIdx), polyOrd);
            splineFit = polyval(coeffs, tSeg);
        end

        preWin = max(1, iStart - max(1, round(sample_rate)));
        preSamples = signal(preWin:iStart-1);
        preSamples = preSamples(~isnan(preSamples));
        if isempty(preSamples)
            preLevel = signal(iStart);
        else
            preLevel = mean(preSamples);
        end
        chOut(iStart:iEnd) = signal(iStart:iEnd) - splineFit + preLevel;
    end

end


%% Local functions

function artifactMask = detectMotionArtifacts(signal, nMotion, STDEVthresh, AMPthresh)
% DETECTMOTIONARTIFACTS Detect motion artifacts via std and amplitude thresholds

T = length(signal);
artifactMask = false(T, 1);

if all(isnan(signal)) || std(signal, 'omitnan') == 0
    return;
end

globalStd = std(signal, 'omitnan');
halfWin = floor(nMotion / 2);

% Vectorized moving-window criteria (replaces the per-sample loop). The loop
% used a centered window signal(max(1,i-halfWin):min(T,i+halfWin)), i.e. a
% window of length 2*halfWin+1 that SHRINKS at the edges (clamped, not filled).
% movstd/movmax/movmin with default 'Endpoints','shrink' reproduce exactly
% that: winStd == std(window,'omitnan') and ampChange == max-min over the same
% window. movmax/movmin are exact; movstd matches per-window std to floating
% point. ~O(T) vs the O(T*nMotion) loop.
k = 2 * halfWin + 1;
winStd    = movstd(signal, k, 0, 1, 'omitnan');
ampChange = movmax(signal, k, 1, 'omitnan') - movmin(signal, k, 1, 'omitnan');

artifactMask = (winStd > STDEVthresh * globalStd) | (ampChange > AMPthresh);
artifactMask = artifactMask(:);

end


function segments = findContiguousSegments(mask)
% FINDCONTIGUOUSSEGMENTS Find start/end indices of contiguous true regions

d = diff([0; mask(:); 0]);
starts = find(d == 1);
ends = find(d == -1) - 1;
segments = [starts, ends];

end
