function [ hrf ] = buildHRF(fs,t, alpha1,alpha2,beta1,beta2,c )
% BUILDHRF Build canonical hemodynamic response function
%
% Generates a hemodynamic response function (HRF) using a difference-of-gammas
% model at a specified sampling frequency. The HRF models the expected BOLD or
% fNIRS signal response to a brief neural event, consisting of a primary
% positive response followed by a post-stimulus undershoot. Output is
% normalized to peak = 1.
%
% Reference:
%   Lindquist MA, Meng Loh J, Atlas LY, Wager TD. (2009).
%   Modeling the hemodynamic response function in fMRI: efficiency, bias
%   and mis-modeling. Neuroimage, 45(1 Suppl), S187-S198.
%   DOI: 10.1016/j.neuroimage.2008.10.065
%   http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3318970/
%
% Syntax:
%   hrf = buildHRF()
%   hrf = buildHRF(fs)
%   hrf = buildHRF(fs, t)
%   hrf = buildHRF(fs, t, alpha1, alpha2, beta1, beta2, c)
%
% Inputs:
%   fs     - Sampling frequency in Hz (default: 20)
%            Higher values produce smoother HRF curves.
%   t      - Duration of HRF in seconds (default: 32)
%            Matches SPM canonical HRF duration, which includes the full
%            post-stimulus undershoot.
%   alpha1 - Shape parameter for primary gamma function (default: 6)
%   alpha2 - Shape parameter for undershoot gamma function (default: 16)
%   beta1  - Scale parameter for primary gamma function (default: 1)
%   beta2  - Scale parameter for undershoot gamma function (default: beta1)
%   c      - Ratio of undershoot to main response (default: 1/6)
%            Controls the depth of the post-stimulus undershoot.
%
% Outputs:
%   hrf - Hemodynamic response function [N x 2]
%         Column 1: Time in seconds
%         Column 2: HRF amplitude (normalized to peak=1)
%
% Algorithm:
%   Via equation A1 from Lindquist et al. (2009):
%   1. Generate time vector from 0 to t at sampling frequency fs
%   2. Compute primary response: (t^(alpha1-1) * beta1^alpha1 * exp(-beta1*t)) / gamma(alpha1)
%   3. Compute undershoot: same form with alpha2, beta2, scaled by c
%   4. HRF = primary - c * undershoot
%   5. Normalize to peak amplitude = 1
%
% Example:
%   % Generate HRF at 10 Hz for GLM convolution
%   hrf = buildHRF(10);  % 10 Hz, 32 sec duration
%   plot(hrf(:,1), hrf(:,2));
%   xlabel('Time (s)'); ylabel('Amplitude');
%   title('Canonical HRF');
%
%   % Generate HRF with custom parameters for fNIRS (slower response)
%   hrf = buildHRF(10, 20, 5, 15, 0.8, 0.8, 1/7);
%
%   % Use for stimulus convolution
%   data = pf2.import.sampleData.fNIR2000();
%   stim = zeros(size(data.time));
%   stim(round(data.markers.Time*fs)) = 1;  % Delta functions at marker onsets
%   expected = conv(stim, hrf(:,2), 'same');  % Predicted response
%
% Notes:
%   - Default parameters from Lindquist et al. equation A1
%   - HRF is automatically normalized to peak = 1.0
%   - Full HRF including undershoot is preserved (matches SPM, MNE-NIRS,
%     NIRS Toolbox, and Cedalion conventions)
%   - Commonly used for GLM design matrices in fNIRS/fMRI analysis
%
% See also: pf2_base.fnirs.bvoxy, conv
if(nargin<1)
    fs=20;
end

if(nargin<2)
    t=32;
end

if(nargin<6)% Values specified next to A1
    alpha1=6;
    alpha2=16;
    beta1=1;
    beta2=beta1;
    c=1/6;
end

time=0:1/fs:t;


% Via equation A1
hrf=(time.^(alpha1-1).*beta1^alpha1.*exp(-beta1.*time))./gamma(alpha1)...
    -c*(time.^(alpha2-1)*beta2^alpha2.*exp(-beta2.*time))./gamma(alpha2);

hrf=hrf/max(hrf);

hrf=[time;hrf]';

end

