function [dodCorrected] = pf2_MotionCorrectSplineSG(dod, sample_rate, frameSize, polyOrder, tMotion, tMask, STDEVthresh, AMPthresh)
% PF2_MOTIONCORRECTSPLINESG Savitzky-Golay motion artifact correction
%
% Detects motion artifacts using amplitude and derivative thresholds (same
% detection logic as spline interpolation), then corrects each artifact
% segment by fitting a Savitzky-Golay polynomial filter and subtracting
% the smoothed fit. This replaces the cubic spline with an SG smoother,
% which better handles sharp transients and preserves signal edges.
%
% Used by FRESH groups 17, 28, 38.
%
% Reference:
%   Scholkmann, F., Spichtig, S., Muehlemann, T. & Wolf, M. (2010).
%   How to detect and reduce movement artifacts in near-infrared imaging
%   using moving standard deviation and spline interpolation.
%   Physiological Measurement, 31(5), 649-662.
%
%   Savitzky, A. & Golay, M. J. E. (1964). Smoothing and differentiation
%   of data by simplified least squares procedures. Analytical Chemistry,
%   36(8), 1627-1639.
%
% Syntax:
%   dodCorrected = pf2_MotionCorrectSplineSG(dod, sample_rate)
%   dodCorrected = pf2_MotionCorrectSplineSG(dod, sample_rate, frameSize, polyOrder)
%   dodCorrected = pf2_MotionCorrectSplineSG(dod, sample_rate, frameSize, polyOrder, tMotion, tMask, STDEVthresh, AMPthresh)
%
% Inputs:
%   dod          - Optical density signal [T x C] where T=samples, C=channels
%   sample_rate  - Sampling rate in Hz [scalar]
%   frameSize    - SG filter window length in samples (must be odd, default:
%                  ~1s of data = 2*floor(sample_rate/2)+1)
%   polyOrder    - SG polynomial order (default: 3). Must be < frameSize.
%   tMotion      - Time window for motion detection in seconds (default: 0.5)
%   tMask        - Time to mask around detected artifacts in seconds (default: 1)
%   STDEVthresh  - Threshold for signal amplitude change as multiple of
%                  standard deviation. Larger = less sensitive. (default: 10)
%   AMPthresh    - Threshold for signal derivative change in OD units.
%                  Larger = less sensitive. (default: 0.5)
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
%      a. Apply Savitzky-Golay filter (sgolayfilt) to smooth the segment
%      b. Subtract the SG fit from the signal (removes artifact drift)
%      c. Anchor corrected signal to pre-artifact level
%   4. Return corrected signal
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   od = pf2_Intensity2OD(data.raw);
%   corrected = pf2_MotionCorrectSplineSG(od, data.fs);
%
%   % Custom SG parameters
%   corrected = pf2_MotionCorrectSplineSG(od, data.fs, 11, 3);
%
% See also: pf2_MotionCorrectSpline, pf2_MotionCorrectTDDR, pf2_MotionCorrectWavelet, sgolayfilt

%% Defaults
if nargin < 8, AMPthresh = 0.5; end
if nargin < 7, STDEVthresh = 10; end
if nargin < 6, tMask = 1; end
if nargin < 5, tMotion = 0.5; end
if nargin < 4, polyOrder = 3; end
if nargin < 3 || isempty(frameSize)
    frameSize = 2 * floor(sample_rate / 2) + 1;  % ~1 second, always odd
end

% Ensure frameSize is odd
if mod(frameSize, 2) == 0
    frameSize = frameSize + 1;
end

% Ensure polyOrder < frameSize
if polyOrder >= frameSize
    polyOrder = frameSize - 1;
end

[T, nCh] = size(dod);
dodCorrected = dod;

nMotion = max(1, round(tMotion * sample_rate));
nMask = round(tMask * sample_rate);

for ch = 1:nCh
    signal = dod(:, ch);

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
        continue;  % No artifacts detected
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

        ySeg = signal(iStart:iEnd);

        % Handle NaN in segment
        validIdx = ~isnan(ySeg);
        if sum(validIdx) < 2
            continue;
        end

        % Determine effective SG parameters for this segment
        effFrame = min(frameSize, segLen);
        if mod(effFrame, 2) == 0
            effFrame = effFrame - 1;  % must be odd
        end
        effFrame = max(effFrame, 3);  % minimum window = 3
        effOrder = min(polyOrder, effFrame - 1);

        % Apply Savitzky-Golay filter to get smooth fit
        % Replace NaN temporarily for filtering
        yFill = ySeg;
        if any(~validIdx)
            yFill(~validIdx) = interp1(find(validIdx), ySeg(validIdx), ...
                find(~validIdx), 'linear', 'extrap');
        end

        sgFit = pf2_base.external.sgolayfilt(yFill, effOrder, effFrame);

        % Subtract SG fit and anchor to pre-artifact boundary mean
        preWin = max(1, iStart - max(1, round(sample_rate)));
        preSamples = signal(preWin:iStart-1);
        preSamples = preSamples(~isnan(preSamples));
        if isempty(preSamples)
            preLevel = signal(iStart);
        else
            preLevel = mean(preSamples);
        end
        dodCorrected(iStart:iEnd, ch) = signal(iStart:iEnd) - sgFit + preLevel;
    end
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

% Vectorized moving-window criteria (see pf2_MotionCorrectSpline for the
% equivalence rationale): centered window of length 2*halfWin+1, shrinking at
% the edges, reproduced by movstd/movmax/movmin with default 'shrink'
% endpoints. ~O(T) vs the O(T*nMotion) per-sample loop.
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
