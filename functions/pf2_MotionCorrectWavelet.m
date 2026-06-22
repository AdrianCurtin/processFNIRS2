function [dodWavelet] = pf2_MotionCorrectWavelet(dod,iqr,turnon,wavelet,accelerate)
% PF2_MOTIONCORRECTWAVELET Wavelet-based motion artifact correction
%
% Performs a wavelet decomposition of the signal and removes coefficients
% that exceed iqr times the interquartile range, as these are likely due
% to motion artifacts. Uses a shift-invariant discrete wavelet transform
% via WaveLab850 (no Wavelet Toolbox required).
%
% Reference:
%   Molavi, B. & Dumont, G. A. (2012). Wavelet-based motion artifact
%   removal for functional near-infrared spectroscopy. Physiol Meas, 33,
%   259-270. Adapted from Homer2 by Behnam Molavi and S. Brigadoi.
%
% Syntax:
%   dodWavelet = pf2_MotionCorrectWavelet(dod, iqr)
%   dodWavelet = pf2_MotionCorrectWavelet(dod, iqr, turnon)
%   dodWavelet = pf2_MotionCorrectWavelet(dod, iqr, turnon, wavelet)
%   dodWavelet = pf2_MotionCorrectWavelet(dod, iqr, turnon, wavelet, accelerate)
%
% Inputs:
%   dod        - Optical density signal [T x C double]
%                T = time samples, C = channels
%   iqr        - IQR multiplier for outlier detection (scalar, typical: 1.5)
%                Higher values = fewer coefficients removed.
%                Set iqr < 0 to skip correction (returns input unchanged).
%   turnon     - Enable flag (optional, scalar). If 0, skips correction.
%   wavelet    - Wavelet family (optional, string, default: 'db2')
%                Supported: 'haar','db2'-'db10','sym4'-'sym10','coif1'-'coif5',
%                'beylkin','vaidyanathan','battle1','battle3','battle5'
%   accelerate - Parallel acceleration mode (optional, string, default: 'auto')
%                'auto'   - use parfor if pool running and nChannels > 8
%                'parfor' - use parfor if available
%                'none'   - serial processing
%
% Outputs:
%   dodWavelet - Motion-corrected optical density [T x C double]
%                Same size as input. Invalid channels return NaN.
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   od = pf2_Intensity2OD(data.raw);
%   corrected = pf2_MotionCorrectWavelet(od, 1.5);
%   corrected = pf2_MotionCorrectWavelet(od, 1.5, 1, 'db4');
%
% See also: pf2_MotionCorrectTDDR, pf2_SMAR, pf2_fnirs_MARA, pf2_base.wavelet.resolveWavelet

if exist('turnon')
   if turnon==0
       dodWavelet = dod;
   return;
   end
end

if ~exist('wavelet','var') || isempty(wavelet)
    wavelet = 'db2';
end
if ~exist('accelerate','var') || isempty(accelerate)
    accelerate = 'auto';
end

if iqr<0
    dodWavelet = dod;
    return;
end

global WAVELABPATH
if(isempty(WAVELABPATH))
    pf2_base.toolboxes.setup_wavelab();
end

% Resolve wavelet family — only the QMF filter is needed (no Wavelet Toolbox)
[qmfilter, ~, ~] = pf2_base.wavelet.resolveWavelet(wavelet);

dod(isinf(dod))=nan;
dodWavelet = dod;

SignalLength = size(dod,1); % #time points of original signal
N = ceil(log2(SignalLength)); % #of levels for the wavelet decomposition
nChannels = size(dod,2);

L = 4;  % Lowest wavelet scale used in the analysis

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
    parfor ii = 1:nChannels
        dodWavelet(:,ii) = processChannel(dod(:,ii), SignalLength, N, L, qmfilter, iqr, ii);
    end
else
    for ii = 1:nChannels
        dodWavelet(:,ii) = processChannel(dod(:,ii), SignalLength, N, L, qmfilter, iqr, ii);
    end
end



% ---------------------------------------------------------------------

function col = processChannel(channelData, SignalLength, N, L, qmfilter, iqr, chIdx)
% Process a single channel - extracted for parfor compatibility
    channelData(isinf(channelData)) = nan;
    DataPadded = zeros(2^N, 1);
    DataPadded(1:SignalLength) = channelData;

    DCVal = mean(DataPadded);
    DataPadded = DataPadded - DCVal;

    [yn, NormCoef] = NormalizationNoise(DataPadded', qmfilter);

    try
        % Forward shift-invariant DWT using WaveLab
        StatWT = FWT_TI(yn, L, qmfilter);

        % Threshold wavelet coefficients and reconstruct
        [ARSignal, ~] = WaveletAnalysis(StatWT, L, qmfilter, iqr, SignalLength);
        ARSignal = ARSignal / NormCoef + DCVal;
        col = ARSignal(1:SignalLength)';
    catch
        warning('Channel %i is invalid\n', chIdx);
        col = nan(SignalLength, 1);
    end


function [y_norm,coeff] = NormalizationNoise(y,qmf)
% Estimate noise level and normalize so MAD of finest-level coefficients = 1
% Uses WaveLab's DownDyadLo instead of cconv + dyaddown (no Wavelet Toolbox)

    y_downsampled = DownDyadLo(y, qmf);

    % Median absolute deviation (base MATLAB — no Statistics Toolbox).
    % Note: mad() defaults to MEAN absolute deviation, which is inconsistent
    % with the 1.4826 MAD->sigma constant used below; the median form is the
    % intended robust noise estimator (Molavi & Dumont 2012 / Homer2).
    medianAbsDev = median(abs(y_downsampled - median(y_downsampled)));

    if medianAbsDev ~= 0
        y_norm =  (1/1.4826).*y./medianAbsDev;
        coeff = 1/(1.4826*medianAbsDev);
    else
        y_norm = y;
        coeff = 1;
    end


function [ARSignal,StatWT]  = WaveletAnalysis(StatWT,L,qmf,iqr,SignalLength)
% Threshold wavelet coefficients and reconstruct via inverse TI-DWT
%
% Sets coefficients exceeding iqr times the interquartile range to zero
% (likely motion artifacts), then reconstructs using WaveLab's IWT_TI.
%
% Original script by Behnam Molavi (bmolavi@ece.ubc.ca), adapted for
% Homer2 by RJC, modified 10/17/2012 by S. Brigadoi.

n=size(StatWT,1);       % Length of data vector with zero padding
N=log2(size(StatWT,1)); % Finest scale (original signal)
SignalLength_tmp = SignalLength;

for j=1:N-L-1
    SignalLength_tmp = fix(SignalLength_tmp/2);
    n_blocks = 2^j; % number of blocks in the level
    l_blocks = n/n_blocks; % length of the blocks in the level
    for b=0:(2^j-1)
        sr = StatWT(b*l_blocks+1:b*l_blocks+l_blocks,j+1);

        sr_temp = sr(1:SignalLength_tmp); % compute statistics only on original data
        quants = pf2_base.compat.quantile(sr_temp,[.25 .50 .75]);  % compute quantiles
        IQR = quants(3)-quants(1);  % compute interquartile range
        prob1 = quants(3)+IQR*iqr;
        prob2 = quants(1)-IQR*iqr;
        outliers_1 = find(sr>prob1);
        outliers_2 = find(sr<prob2);
        outliers = [outliers_1' outliers_2'];
        sr(outliers) = 0;  % set outliers to 0
        StatWT(b*l_blocks+1:b*l_blocks+l_blocks,j+1) = sr;
    end
end

% Inverse shift-invariant DWT using WaveLab
ARSignal = IWT_TI(StatWT, qmf);
