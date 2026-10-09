function [x_recon, maskCV, MA_idx] = pf2_sSMART(x, fs, chNum, tauArtifact, tauClean, minSeg, ArtifactTime, InterpMethod, ShiftCorrect)
% PF2_SSMART Sliding Motion Artifact Rejection with interpolated reconstruction
%
% Detects motion artifacts using SMAR2 (adaptive dCV thresholding), then
% reconstructs masked regions by interpolating from surrounding clean data.
% Optionally corrects DC baseline shifts caused by optode displacement
% during artifacts before interpolating.
%
% Operates on raw light intensity, before pf2_Intensity2OD: SMAR2's CV
% criterion is only meaningful on a positive signal. Shift correction and
% interpolation are done on log10 intensity, where motion-induced coupling
% changes are additive and the result matches interpolating optical density.
%
% References:
%   sSMART method:
%     Curtin, A., & Ayaz, H. (2019). sSMART: statistical Sliding Motion
%     Artifact Reconstruction Technique for functional Near-Infrared
%     Spectroscopy. AHFE 2019 International Conference on Neuroergonomics
%     and Cognitive Engineering, July 24-28, 2019, Washington, D.C., USA.
%     Advances in Neuroergonomics and Cognitive Engineering, Springer.
%   SMAR sliding-window detection stage (adapted; see pf2_SMAR2):
%     Ayaz, H., Izzetoglu, M., Shewokis, P. A., & Onaral, B. (2010).
%     Sliding-window motion artifact rejection for Functional Near-Infrared
%     Spectroscopy. 2010 Annual International Conference of the IEEE
%     Engineering in Medicine and Biology, 6567-6570.
%     DOI: 10.1109/IEMBS.2010.5627113
%
% Syntax:
%   x_recon = pf2_sSMART(x, fs)
%   x_recon = pf2_sSMART(x, fs, chNum)
%   [x_recon, maskCV, MA_idx] = pf2_sSMART(x, fs, chNum, tauArtifact, ...
%       tauClean, minSeg, ArtifactTime, InterpMethod, ShiftCorrect)
%
% Inputs:
%   x             - Raw light intensity matrix [T x C] where T=samples,
%                   C=channels. Must be strictly positive (before
%                   pf2_Intensity2OD). Not valid for optical density or
%                   hemoglobin data.
%   fs            - Sampling frequency in Hz. Used to convert ArtifactTime
%                   to samples for the SMAR2 detection window.
%   chNum         - Channel number mapping [1 x C] (default: 1:size(x,2))
%                   Passed to SMAR2 for wavelength pairing. Channels with
%                   the same chNum are grouped so that if either wavelength
%                   has an artifact, both are masked.
%   tauArtifact   - Artifact detection threshold multiplier (default: SMAR2
%                   default). Passed to SMAR2. Lower = more aggressive.
%   tauClean      - Clean boundary threshold multiplier (default: SMAR2
%                   default). Passed to SMAR2. Controls artifact expansion.
%   minSeg        - Minimum clean segment length in samples (default: SMAR2
%                   default, N+2). Short clean gaps between artifacts are
%                   merged into a single artifact region. A negative value
%                   (e.g. -1, the library default) also selects N+2, which
%                   scales with ArtifactTime and fs.
%   ArtifactTime  - SMAR2 CV window length in seconds (default: 10)
%                   Converted to samples (N = round(ArtifactTime * fs)).
%   InterpMethod  - Interpolation method for gap filling (default: 'pchip')
%                   'pchip'  - Piecewise cubic Hermite. Shape-preserving
%                              between clean samples. Good general default.
%                   'spline' - Cubic spline. Smoother (C2 continuous) but
%                              can overshoot near sharp transitions.
%                   'linear' - Linear. No overshoot, but creates kinks at
%                              gap boundaries. Fast.
%                   'makima' - Modified Akima. Compromise between pchip
%                              and spline, smooth with less overshoot.
%                   Samples before the first or after the last clean sample
%                   are never extrapolated; they hold the nearest clean value.
%   (Empty inputs [] select the default.)
%   ShiftCorrect  - Logical flag to correct DC baseline shifts (default: false)
%                   When true, measures the DC level on each side of every
%                   artifact gap and removes the offset so post-artifact
%                   data aligns with the pre-artifact baseline. Useful when
%                   optode displacement during artifacts causes permanent
%                   baseline changes. Correction is cumulative — each gap's
%                   shift is applied to all subsequent data.
%
% Outputs:
%   x_recon - Reconstructed intensity [T x C], same size as input.
%             Artifact regions are filled via interpolation.
%             When ShiftCorrect is false, clean data is preserved (to
%             floating-point precision of the log round trip).
%             When ShiftCorrect is true, post-artifact clean data may be
%             shifted to remove DC offsets.
%   maskCV  - Logical artifact mask [T+2 x C] from SMAR2 (true = artifact).
%             Padded by 1 sample at start and end for edge handling.
%   MA_idx  - Cell array {1 x C} of artifact segment indices from SMAR2.
%             Each cell contains [M x 2] matrix of [start, end] rows.
%
% Algorithm:
%   1. Convert ArtifactTime to samples: N = round(ArtifactTime * fs)
%   2. Run SMAR2 detection on the intensity (adaptive dCV thresholds,
%      wavelength pairing)
%   3. Move to log10 intensity
%   4. If ShiftCorrect: for each artifact gap, measure the mean level in a
%      1-second window before and after the gap. Shift all data after the
%      gap by the difference so baselines align. Applied cumulatively
%      across gaps (each measurement uses already-corrected data).
%   5. For each channel with NaN gaps:
%      a. Use non-NaN samples as interpolation knots
%      b. Fill interior gaps with the chosen interpolation method
%      c. Fill leading/trailing gaps with the nearest clean value
%   6. Return to intensity. Channels with < 2 clean samples are left as-is
%      (a warning lists channels that stay entirely NaN)
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   wl = data.device.wavelengths();
%   raw = data.raw(:, wl > 0);
%
%   % Basic usage (pchip default, no shift correction)
%   [corrected, mask, idx] = pf2_sSMART(raw, data.fs);
%   od = pf2_Intensity2OD(corrected);
%
%   % With baseline shift correction for optode displacement
%   [corrected, mask, idx] = pf2_sSMART(raw, data.fs, [], [], [], [], [], [], true);
%
% Notes:
%   - The sSMART method (statistical CV thresholding plus interpolated
%     reconstruction) is described in Curtin & Ayaz (2019). The
%     sliding-window detection it builds on derives from the SMAR algorithm
%     of Ayaz et al. (2010) (see pf2_SMAR2).
%   - Interpolation fills gaps smoothly but cannot recover true underlying
%     neural signal. Short gaps (< few seconds) are typically acceptable;
%     long gaps should be treated with caution in downstream analysis.
%   - DC-offset adjustment (ShiftCorrect, off by default): motion can
%     permanently displace an optode, leaving a step-like shift in the
%     baseline across the artifact. When enabled, each gap's pre/post
%     baseline difference (mean over a 1 s window on each side) is removed
%     from every sample after the gap, so the post-artifact signal realigns
%     to the pre-artifact baseline. The correction is CUMULATIVE across gaps
%     and applied INDEPENDENTLY per channel, so offsets accumulate over a
%     recording and channels can drift relative to one another. It targets
%     step-like displacement shifts only; if a gap straddles a genuine slow
%     hemodynamic change, that real signal is removed along with the shift.
%     With many gaps the corrections compound into an aggressive high-pass
%     that can remove slow hemodynamics, so check the rejection rate first.
%     Leave it off unless clear baseline jumps from optode displacement are
%     visible, and inspect the reconstructed output before trusting it.
%
% See also: pf2_SMAR2, pf2_SMAR, pf2_Intensity2OD, pf2_MotionCorrectTDDR, interp1

% --- Defaults ---
if nargin < 9 || isempty(ShiftCorrect), ShiftCorrect = false; end
if nargin < 8 || isempty(InterpMethod), InterpMethod = 'pchip'; end
if nargin < 7 || isempty(ArtifactTime), ArtifactTime = 10; end
if nargin < 6 || (~isempty(minSeg) && minSeg < 0), minSeg = []; end
if nargin < 5, tauClean = []; end
if nargin < 4, tauArtifact = []; end
if nargin < 3 || isempty(chNum), chNum = 1:size(x, 2); end

validMethods = {'pchip', 'spline', 'linear', 'makima'};
if ~ismember(InterpMethod, validMethods)
    error('pf2_sSMART:invalidMethod', ...
        'InterpMethod must be one of: %s', strjoin(validMethods, ', '));
end

N = max(1, round(ArtifactTime * fs));

% --- Step 1: Detect artifacts (SMAR2 applies its defaults to empty args) ---
[Xcorr, maskCV, MA_idx] = pf2_SMAR2(x, N, chNum, tauArtifact, tauClean, minSeg);

% --- Step 2: Move to log intensity; correct baseline shifts across gaps ---
[nSamples, numCh] = size(x);
x_recon = log10(Xcorr);
x_recon(~isfinite(x_recon)) = NaN;

if ShiftCorrect
    bw = ceil(fs);  % boundary window: 1 second of samples

    for ch = 1:numCh
        segs = MA_idx{ch};
        if isempty(segs), continue; end

        for k = 1:size(segs, 1)
            gapStart = segs(k, 1);
            gapEnd   = segs(k, 2);

            % Pre-gap: up to bw clean samples immediately before the gap
            preEnd   = gapStart - 1;
            preStart = max(1, preEnd - bw + 1);
            if preEnd < 1, continue; end
            preSeg = x_recon(preStart:preEnd, ch);
            preSeg = preSeg(~isnan(preSeg));
            if isempty(preSeg), continue; end

            % Post-gap: up to bw clean samples immediately after the gap
            postStart = gapEnd + 1;
            postEnd   = min(nSamples, postStart + bw - 1);
            if postStart > nSamples, continue; end
            postSeg = x_recon(postStart:postEnd, ch);
            postSeg = postSeg(~isnan(postSeg));
            if isempty(postSeg), continue; end

            % Shift everything from postStart onward to remove the DC jump
            dcShift = mean(postSeg) - mean(preSeg);
            x_recon(postStart:end, ch) = x_recon(postStart:end, ch) - dcShift;
        end
    end
end

% --- Step 3: Interpolate across NaN gaps ---
timeIdx = (1:nSamples)';

for ch = 1:numCh
    signal = x_recon(:, ch);
    good = ~isnan(signal);

    if all(good)
        continue;  % no gaps to fill
    end

    nGood = sum(good);
    if nGood < 2
        % Not enough clean points — fill with nearest if we have one
        if nGood == 1
            x_recon(:, ch) = signal(good);
        end
        continue;
    end

    % Interpolate interior gaps. Pass NaN as the extrapolation value:
    % pchip/spline/makima otherwise extrapolate past the last clean sample
    % by default, which diverges at the recording edges.
    x_recon(:, ch) = interp1(timeIdx(good), signal(good), timeIdx, InterpMethod, NaN);

    % Leading/trailing gaps (beyond the clean range) hold the nearest value
    remaining = isnan(x_recon(:, ch));
    if any(remaining)
        x_recon(remaining, ch) = interp1( ...
            timeIdx(good), signal(good), timeIdx(remaining), 'nearest', 'extrap');
    end
end

allNaN = all(isnan(x_recon), 1) & ~all(isnan(x), 1);
if any(allNaN)
    warning('pf2:sSMART:channelFullyMasked', ...
        ['%d channel(s) were masked in full and could not be reconstructed ' ...
         '(columns %s); they are returned as NaN.'], ...
        nnz(allNaN), mat2str(find(allNaN)));
end

x_recon = 10.^x_recon;

end
