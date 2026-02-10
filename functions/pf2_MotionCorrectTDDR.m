function [dodTDDR] = pf2_MotionCorrectTDDR(dod,sample_rate)
% PF2_MOTIONCORRECTTDDR Temporal Derivative Distribution Repair for motion artifacts
%
% Corrects motion artifacts by computing the temporal derivative of the
% signal, applying robust regression (Tukey's biweight) to reduce the
% magnitude of outlying fluctuations, then integrating to recover the
% corrected signal. High-frequency components (>0.5 Hz) are separated
% before correction and merged back afterward.
%
% Channels with partial NaN values are processed piecewise: each contiguous
% non-NaN segment is corrected independently. Segments shorter than 10
% samples are left uncorrected (original OD values preserved).
%
% Reference:
%   Fishburn, F. A. et al. (2019). Temporal Derivative Distribution Repair
%   (TDDR): A motion correction method for fNIRS. NeuroImage, 184, 171-179.
%   Script by Frank Fishburn (fishburnf@upmc.edu) 10/03/2018.
%
% Syntax:
%   dodTDDR = pf2_MotionCorrectTDDR(dod, sample_rate)
%
% Inputs:
%   dod         - Optical density signal [T x C double]
%                 T = time samples, C = channels
%                 May contain NaN values (handled piecewise).
%   sample_rate - Sampling rate in Hz (scalar)
%
% Outputs:
%   dodTDDR - Motion-corrected optical density [T x C double]
%             Same size as input dod. NaN positions are preserved.
%
% Algorithm:
%   1. Separate low-frequency (<0.5 Hz) and high-frequency components
%   2. Compute temporal derivative of low-frequency signal
%   3. Iteratively estimate robust weights via Tukey's biweight function
%   4. Apply weights to centered derivative
%   5. Integrate corrected derivative and center result
%   6. Recombine with high-frequency component
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   od = pf2_Intensity2OD(data.raw);
%   corrected = pf2_MotionCorrectTDDR(od, data.fs);
%
% See also: pf2_SMAR, pf2_MotionCorrectWavelet, pf2_fnirs_MARA

mlAct = ones(size(dod,2),1);

lstAct = find(mlAct==1);
dodTDDR = dod;

minSegment = 10; % Minimum samples for TDDR correction

for ii=1:length(lstAct)

    idx_ch = lstAct(ii);
    chData = dod(:, idx_ch);

    % Skip dead channels (all NaN from zero raw intensity)
    if all(~isfinite(chData))
        continue;
    end

    nanMask = isnan(chData);

    if ~any(nanMask)
        % No NaN — process whole channel directly
        dodTDDR(:, idx_ch) = tddr_core(chData, sample_rate);
        continue;
    end

    % Piecewise: find contiguous non-NaN segments
    transitions = diff([true; nanMask; true]);
    segStarts = find(transitions == -1);
    segEnds   = find(transitions == 1) - 1;

    for jj = 1:length(segStarts)
        idx = segStarts(jj):segEnds(jj);
        if length(idx) >= minSegment
            dodTDDR(idx, idx_ch) = tddr_core(chData(idx), sample_rate);
        end
        % Short segments: left as original OD values (uncorrected but valid)
    end

end

end


function corrected = tddr_core(signal, sample_rate)
%TDDR_CORE Apply TDDR to a single contiguous (no-NaN) signal segment.

    %% Preprocess: Separate high and low frequencies
    filter_cutoff = .5;
    filter_order = 3;
    Fc = filter_cutoff * 2/sample_rate;
    if Fc<1
        [fb,fa] = butter(filter_order,Fc);
        try
            signal_low = filtfilt(fb,fa,signal);
        catch
            signal_low = pf2_base.external.filtfilt_classic(fb,fa,signal);
        end
    else
        signal_low = signal;
    end
    signal_high = signal - signal_low;

    %% Initialize
    tune = 4.685;
    D = sqrt(eps(class(signal)));
    mu = inf;
    iter = 0;

    %% Step 1. Compute temporal derivative of the signal
    deriv = diff(signal_low);

    %% Step 2. Initialize observation weights
    w = ones(size(deriv));

    %% Step 3. Iterative estimation of robust weights
    while iter < 50

        iter = iter + 1;
        mu0 = mu;

        % Step 3a. Estimate weighted mean
        mu = sum( w .* deriv ) / sum( w );

        % Step 3b. Calculate absolute residuals of estimate
        dev = abs(deriv - mu);

        % Step 3c. Robust estimate of standard deviation of the residuals
        sigma = 1.4826 * median(dev);

        % Step 3d. Scale deviations by standard deviation and tuning parameter
        r = dev / (sigma * tune);

        % Step 3e. Calculate new weights accoring to Tukey's biweight function
        w = ((1 - r.^2) .* (r < 1)) .^ 2;

        % Step 3f. Terminate if new estimate is within machine-precision of old estimate
        if abs(mu-mu0) < D*max(abs(mu),abs(mu0))
            break;
        end

    end

    %% Step 4. Apply robust weights to centered derivative
    new_deriv = w .* (deriv-mu);

    %% Step 5. Integrate corrected derivative
    signal_low_corrected = cumsum([0; new_deriv]);

    %% Postprocess: Center the corrected signal
    signal_low_corrected = signal_low_corrected - mean(signal_low_corrected);

    %% Postprocess: Merge back with uncorrected high frequency component
    corrected = signal_low_corrected + signal_high;

end
