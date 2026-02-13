function CARout=pf2_CAR(x,local,medfiltN,mdebug)
% PF2_CAR Common Average Reference for fNIRS signals
%
% Applies Common Average Reference (CAR) spatial filtering to remove global
% systemic interference from fNIRS data. CAR subtracts the mean signal
% across all channels from each individual channel, reducing common-mode
% noise like blood pressure fluctuations and probe movement.
%
% Syntax:
%   CARout = pf2_CAR(x)
%   CARout = pf2_CAR(x, local)
%   CARout = pf2_CAR(x, local, medfiltN)
%   CARout = pf2_CAR(x, local, medfiltN, debug)
%
% Inputs:
%   x        - Input signal matrix [T x C] where T=samples, C=channels
%              Typically hemoglobin concentration data (HbO, HbR, etc.)
%   local    - Local CAR flag (default: false)
%              false = Global CAR using all channels
%              true  = Local CAR using neighboring channels only
%              Note: Local mode is currently only implemented for 2x8 probe
%   medfiltN - Median filter window size for smoothing the CAR signal
%              (default: 10 samples)
%              Helps reduce high-frequency noise in the reference signal
%   debug    - Debug visualization flag (default: false)
%              If true, generates diagnostic plots
%
% Outputs:
%   CARout   - CAR-filtered signal matrix [T x C], same size as input
%              Contains the original signals minus the common average
%
% Algorithm (Global CAR):
%   1. Compute mean across all channels at each time point (ignoring NaN)
%   2. Apply median filter to smooth the reference signal
%   3. Subtract filtered reference from each channel:
%      CARout = x - repmat(medfilt1(nanmean(x,2)), 1, numChannels)
%
% Notes:
%   - Local CAR is partially implemented but not fully functional
%   - NaN values in channels are excluded from mean calculation
%   - Median filtering reduces sensitivity to outlier channels
%   - CAR can distort localized activations if many channels are active
%   - Consider using CAR on hemoglobin data, not optical density
%
% Example:
%   % Basic global CAR
%   hbData_CAR = pf2_CAR(hbData);
%
%   % CAR with smaller smoothing window
%   hbData_CAR = pf2_CAR(hbData, false, 5);
%
% References:
%   - Similar to EEG average reference but adapted for fNIRS
%   - Helps reduce extra-cerebral contamination
%
% See also: pf2_lpf, pf2_ambient_ICA_clean, pf2_subtractAmbient

	if(nargin<2)
		local=false; %Local setting currently only works for 2x8 sensor
	end

    if(nargin<3)
        medfiltN=10;
    end

    if(nargin<4)
        mdebug=false;
    end

    numCh=size(x,2);

    if(local)
        error('pf2:CAR:localNotImplemented', ...
            'Local CAR mode is not implemented. Use global CAR (local=false).');
    else
        basicCAR=nanmean(x,2);

        basicCAR=medfilt1(basicCAR,medfiltN);

        CARx=repmat(basicCAR,1,numCh);

        CARout=x-CARx;
    end

end