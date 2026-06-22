% PF2_KBWF Kurtosis-based wavelet filtering for motion artifact correction
%
% Removes movement artifacts from fNIRS data using the kbWF algorithm.
% Iteratively zeros the largest wavelet coefficients at each decomposition
% level until the kurtosis drops below a threshold.
%
% Reference:
%   Chiarelli, A.M. et al. (2015). A kurtosis-based wavelet algorithm for
%   motion artifact correction of fNIRS data. NeuroImage, 112, 128-137.
%
% Syntax:
%   signal_out = pf2_kbWF(signal)
%   signal_out = pf2_kbWF(signal, kurtosis)
%   signal_out = pf2_kbWF(signal, kurtosis, minlvl)
%   signal_out = pf2_kbWF(signal, kurtosis, minlvl, wavelet)
%   signal_out = pf2_kbWF(signal, kurtosis, minlvl, wavelet, accelerate)
%
% Inputs:
%   signal     - Input signal matrix [T x C], T=samples, C=channels
%   kurtosis   - Kurtosis threshold (optional, default: 3.3, must be > 3)
%   minlvl     - Minimum decomposition level (optional, default: 3)
%   wavelet    - Wavelet family (optional, string, default: 'db6')
%                Supported: 'haar','db2'-'db10','sym4'-'sym10','coif1'-'coif5',
%                'beylkin','vaidyanathan','battle1','battle3','battle5'
%   accelerate - Parallel acceleration mode (optional, string, default: 'auto')
%                'auto'   - use parfor if pool running and nChannels > 8
%                'parfor' - use parfor if available
%                'none'   - serial processing
%
% Outputs:
%   signal_out - Artifact-cleaned signal [T x C], same size as input
%
% Example:
%   signal_out = pf2_kbWF(signal);
%   signal_out = pf2_kbWF(signal, 3.3, 3, 'sym8');
%
% Notes:
%   - Only detail coefficients (levels minlvl to L-1) are processed and
%     reconstructed. Approximation coefficients (level 0, the low-frequency
%     baseline) are zeroed, effectively removing the DC/slow-drift component.
%     This is by design in Chiarelli et al. (2015) — the output contains
%     only the artifact-cleaned high-frequency content. Downstream filtering
%     (e.g., band-pass) should account for this.
%   - The signal is zero-padded to the next power of 2 for the DWT. The
%     output is truncated back to the original length.
%
% See also: pf2_MotionCorrectWavelet, waveClean, pf2_base.wavelet.resolveWavelet


function signal_out=pf2_kbWF(signal,varargin)

% Parse varargin: (kurtosis, minlvl, wavelet, accelerate)
th_kurt = 3.3;
minlvl = 3;
wavelet = 'db6';
accelerate = 'auto';

if length(varargin) >= 1 && ~isempty(varargin{1})
    th_kurt = varargin{1};
end
if length(varargin) >= 2 && ~isempty(varargin{2})
    minlvl = varargin{2};
end
if length(varargin) >= 3 && ~isempty(varargin{3})
    wavelet = varargin{3};
end
if length(varargin) >= 4 && ~isempty(varargin{4})
    accelerate = varargin{4};
end

% Resolve wavelet family
[qmf, ~, ~] = pf2_base.wavelet.resolveWavelet(wavelet);

DIM=size(signal);
signal_out=zeros(DIM(1),DIM(2));
nChannels = DIM(2);

% Determine whether to use parfor
useParfor = false;
if ~strcmp(accelerate, 'none')
    [canUse, poolRunning] = pf2_base.accel.canParfor();
    if strcmp(accelerate, 'parfor')
        useParfor = canUse;
    elseif strcmp(accelerate, 'auto')
        useParfor = canUse && poolRunning && nChannels > 8;
    end
end

if useParfor
    parfor j=1:nChannels
        signal_out(:,j) = kbWFChannel(signal(:,j), DIM(1), th_kurt, minlvl, qmf);
    end
else
    for j=1:nChannels
        signal_out(:,j) = kbWFChannel(signal(:,j), DIM(1), th_kurt, minlvl, qmf);
    end
end

end


function col = kbWFChannel(channelData, nSamples, th_kurt, minlvl, qmf)
% Process a single channel - extracted for parfor compatibility
    L=nextpow2(nSamples);
    y=zeros(2^L,1);
    y(1:nSamples)=channelData;
    wc = pf2_base.wavelet.fwtPO(y,1,qmf);       %%%% DWT
    wc1=zeros(length(wc),1);
    for i=minlvl:L-1                             %%%% apply on coefficients from level 'minlvl' to end-1

        values=wc(2^i+1:2^(i+1));
        values1=values;
        values1(values==0)=[];
        KURT=kurtosis(values1);                 %%%% estimate kurtosis of the coefficient distribution

        while KURT>th_kurt && isempty(KURT)==0      %%%% set to zero the highest coefficient until kurtosis is above th or not defined
            values(abs(values)==max(abs(values)))=0;
            values1=values;
            values1(values==0)=[];
            KURT=kurtosis(values1);
        end

        wc1(2^i+1:2^(i+1)) =values;
    end
    xc1 = pf2_base.wavelet.iwtPO(wc1,1,qmf);        %%%% apply IDWT
    col = xc1(1:nSamples);
end
