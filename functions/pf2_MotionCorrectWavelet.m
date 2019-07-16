% function dodWavelet = hmrMotionCorrectWavelet(dod,SD,iqr)
%
% UI NAME:
% Wavelet_Motion_Correction
%
% Perform a wavelet transformation of the dod data and computes the
% distribution of the wavelet coefficients. It sets the coefficient
% exceeding iqr times the interquartile range to zero, because these are probably due
% to motion artifacts. set iqr<0 to skip this function.
% 
% The algorithm follows in part the procedure described by
% Molavi et al.,Physiol Meas, 33, 259-270 (2012).
%
% INPUTS:
% dod -  delta_OD 
% SD -   SD structure
% iqr -  parameter used to compute the statistics (iqr = 1.5 is 1.5 times the
%        interquartile range and is usually used to detect outliers). 
%        Increasing it, it will delete fewer coefficients.
%        If iqr<0 then this function is skipped. 
% 
%
% OUTPUTS:
% dodWavelet - dod after wavelet motion correction, same
%              size as dod (Channels that are not in the active ml remain unchanged)
%
% LOG:
% Script by Behnam Molavi bmolavi@ece.ubc.ca adapted for Homer2 by RJC
% modified 10/17/2012 by S. Brigadoi
%


function [dodWavelet] = pf2_MotionCorrectWavelet(dod,iqr,turnon)

if exist('turnon')
   if turnon==0
       dodWavelet = dod;
   return;
   end
end



if iqr<0
    dodWavelet = dod;
    return;
end

global WAVELABPATH
if(isempty(WAVELABPATH))
    pf2_base.toolboxes.setup_wavelab();
end

dodWavelet = dod;

SignalLength = size(dod,1); % #time points of original signal
N = ceil(log2(SignalLength)); % #of levels for the wavelet decomposition
DataPadded = zeros (2^N,1); % data length should be power of 2  

%p = ffpath2('db2.mat');
%fprintf('Loading %s\n', [p, '/db2.mat']);
%load([p, '/db2.mat']);  % Load a wavelet (db2 in this case)
sF = dbwavf('db2');
db2 = sqrt(2)*sF;

qmfilter = qmf(db2,4); % Quadrature mirror filter used for analysis
L = 4;  % Lowest wavelet scale used in the analysis

for ii = 1:size(dod,2)
    
    idx_ch = ii;

    DataPadded(1:SignalLength) = dod(:,idx_ch);  % zeros pad data to have length of power of 2   
    DataPadded(SignalLength+1:end) = 0;  
    
    DCVal = mean(DataPadded);         
    DataPadded = DataPadded-DCVal;    % removing mean value
    DataLength = size(DataPadded,1);  
   
    [yn NormCoef]=NormalizationNoise(DataPadded',qmfilter);
    
    StatWT = WT_inv(yn,L,N,'db2'); % discrete wavelet transform shift invariant

    [ARSignal wcTI] = WaveletAnalysis(StatWT,L,'db2',iqr,SignalLength);  % Apply artifact removal
       
    ARSignal = ARSignal/NormCoef+DCVal;           

    dodWavelet(:,idx_ch) = ARSignal(1:length(dod));

end




% ---------------------------------------------------------------------

% function pth = ffpath2(fname)
% %   FFPATH    Find file path
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % The function browses very fast current directory and directories known in 
% % 'matlabpath' and the system variable 'path'. It searches for the file,
% % name of which is in the input argument 'fname'. If a directory is found, 
% % the output argument pth is filled by path to the file name from the input
% % argument, otherwise pth is empty.
% % File names should have their extensions, but MATLAB m-files.
% % 
% % Arguments:
% %   fname   file name 
% %   pth     path to the fname
% %
% % Examples:
% %   pth = ffpath('gswin32c.exe')
% %   pth =
% %   c:\Program Files\gs\gs8.60\bin\
% %
% %   pth = ffpath('hgrc')
% %   pth =
% %   C:\PROGRA~1\MATLAB\R2006b\toolbox\local
% 
% % Miroslav Balda
% % miroslav AT balda DOT cz
% % 2008-12-15    v 0.1   only for system variable 'path'
% % 2008-12-20    v 1.0   for both 'path' and 'matlabpath'
% 
% % Brought here by Jay Dubb. In order to keep hmrMotionCorrectWavelet
% % self-contained, copied ffpath to here. 
% 
% if nargin<1
%     error('The function requires one input argument (file name)')
% end
% pth = pwd;
% if exist([pth '/' fname],'file')
%     return
% end % fname found in current dir
% 
% tp = matlabpath;
% t  = 0;
% if isunix() | ismac()
%     I = [t, findstr(tp,':'), length(tp)+1];
% elseif ispc()
%     I = [t, findstr(tp,';'), length(tp)+1];
% end    
% for k = 1:length(I)-1               %   search in path's directories
%     pth = tp(I(k)+1:I(k+1)-1);
%     % fprintf('%s\n', [pth '/' fname]);
%     if exist([pth '/' fname],'file')
%         return;
%     end
% end
% t = 5;
% pth = '';

% function wp = WT_inv(x,L,N,wavename)
%
% Perform a discrete wavelet transform of the data and of the shifted
% version of the data for every decomposition level up to N-L. The shift
% helps the reconstruction
% 
%
% INPUTS:
% x:            1D signal on which to perform the wavelet transform  
% L:            Lowest wavelet scale used in the analysis
% N:            Number of wavelet levels in which the signal can be decomposed
% wavename:     name of the wavelet used for the decomposition
%
%
% OUTPUTS:
% wp:           Wavelet decomposition coefficient matrix ( #of time
%               points x #of levels+1). The first column contains the last approximation while
%               from the second to the end the details at all levels
% 
%
% LOG:
% 10/17/2012 by S. Brigadoi


function wp = WT_inv(x,L,N,wavename)

D = N-L;
n = length(x);
wp = zeros(n,D+1);
dwtmode('per');  % set the wavelet mode to periodization

wp(:,1) = x';
for d=0:(D-1)
    n_blocks = 2^d; % number of blocks in the level
    l_blocks = n/n_blocks; % length of the blocks in the level
    for b=0:(2^d-1) 
        s = wp(b*l_blocks+1:b*l_blocks+l_blocks,1)'; % first time take signal, from the second the approximation
        s_shift = [s(end) s(1:end-1)]; % create a shift version of the block
        
        [cA,cD] = dwt(s,wavename);  % discrete wavelet transform
        [cA_shift,cD_shift] = dwt(s_shift,wavename); % discrete wavelet transform of the shifted version
        
        wp(b*l_blocks+1:b*l_blocks+l_blocks/2,1) = cA;
        wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks,1) = cA_shift;
        
        wp(b*l_blocks+1:b*l_blocks+l_blocks/2,d+2) = cD;
        wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks,d+2) = cD_shift;
    end
end


% function [ARSignal StatWT] = WaveletAnalysis(StatWT,L,wavename,iqr,SignalLength)
%
%
% Perform a wavelet motion correction of the dod data and computes the
% distribution of the wavelet coefficients. It sets the coefficient
% exceeding iqr times the interquartile range to zero, because these are probably due
% to motion artifacts. It applies the inverse discrete wavelet transform and
% reconstruct the signal. 
% 
% The algorithm follows in part the procedure described by
% Molavi et al.,Physiol Meas, 33, 259-270 (2012).
%
% INPUTS:
% StatWT:       matrix of wavelet coefficients (# of time points x # of
%               levels+1). The first column contains the approximation
%               coefficients, while the other all the details coefficients at
%               different levels
% L:            Lowest wavelet scale used in the analysis
% wavename:     name of the wavelet used in the reconstruction, should be the
%               same used in the previous decomposition
% iqr:          parameter used to compute the statistics (iqr = 1.5 means 1.5 times the
%               interquartile range and is usually used to detect outliers). 
%               Increasing it, it will delete less coefficients.
% SignalLength: Length of the original signal before zero padding
% 
%
% OUTPUTS:
% ARSIgnal:     signal reconstructed after the discrete inverse wavelet transform
%               and corrected for motion artifacts.
% StatWT:       matrix of wavelet coefficients corrected for motion
%               artifacts. Same size as StatWT input
%
% LOG:
% Script by Behnam Molavi bmolavi@ece.ubc.ca adapted for Homer2 by RJC
% modified 10/17/2012 by S. Brigadoi


function [ARSignal,StatWT]  = WaveletAnalysis(StatWT,L,wavename,iqr,SignalLength)

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
        quants = quantile(sr_temp,[.25 .50 .75]);  % compute quantiles
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
ARSignal=IWT_inv(StatWT,wavename);  % reconstruct the signal with the discrete inverse wavelet transform

% [y_norm,coeff] = NormalizationNoise(y,qmfilter)

% This function estimates the noise level and normalizes the signal so as to
% have signal to noise ratio = 1. The output signal is scaled so that the
% median absolute deviation (MAD) of the wavelet coefficients at the
% finest level is 1. 
% sigma_estimated = K*MAD; in a normal distribution K = 1.4826
%
% INPUTS:
% y:   	       signal to normalize
% qmfilter:    quadrature mirror filter
%
% OUTPUTS:
% y_norm:       normalized signal
% coeff:       1/sigma_estimated
%
% LOG:
% 10/17/2012 S. Brigadoi

function [y_norm,coeff] = NormalizationNoise(y,qmf)

    c = cconv(y,qmf,length(y)); % circular convolution (final length = length(y))
	y_downsampled = dyaddown(c); % downsample by 2

	medianAbsDev = mad(y_downsampled);
    
	if medianAbsDev ~= 0
		y_norm =  (1/1.4826).*y./medianAbsDev;
                coeff = 1/(1.4826*medianAbsDev);
	else
		y_norm = y;
                coeff = 1;
    end

    
    % function x = IWT_inv(StatWT,wavename)
%
% Perform a discrete wavelet inverse transform using the wavelet coefficients
% found in wp. It is shift invariant.
% 
%
% INPUTS:
% StatWT:       matrix of wavelet coefficients (# of time points x # of levels+1).
%               The first columns contains the approximation coefficients,
%               the others the detailed coefficients. 
% wavename:     name of the wavelet used for the recontruction (should be
%               the same used for the previous decomposition)
%
%
% OUTPUTS:
% x:            Reconstructed signal after the wavelet inverse transform
% 
%
% LOG:
% 10/17/2012 by S. Brigadoi


function x = IWT_inv(StatWT,wavename)

[n,D] = size(StatWT);
D = D-1;

wp = StatWT;
dwtmode('per');

approx = wp(:,1)'; % approximation coefficients in the first column
for d = D-1:-1:0
     n_blocks = 2^d;
     l_blocks = n/n_blocks;
    for b = 0:(2^d-1)
        
        cD = wp(b*l_blocks+1:b*l_blocks+l_blocks/2,d+2)';
        cD_shift = wp(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks,d+2)';
        cA = approx(b*l_blocks+1:b*l_blocks+l_blocks/2);
        cA_shift = approx(b*l_blocks+l_blocks/2+1:b*l_blocks+l_blocks);
        
        s1 = idwt(cA,cD,wavename); % discrete inverse wavelet transform
        s_shift = idwt(cA_shift,cD_shift,wavename); % discrete inverse wavelet transform of the shifted version
        s2 = [s_shift(2:end) s_shift(1)]; % reshifting the shifted version 
        
        approx(b*l_blocks+1:b*l_blocks+l_blocks) = (s1+s2)/2; % reconstruct the approximation of the next level
    end
end
x = approx;


