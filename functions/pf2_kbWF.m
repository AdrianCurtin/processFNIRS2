% Chiarelli Antonio Maria
% Beckman Institute of Technology
% latest version 06/02/2015
% kbWF algorithm removes movement artifacts from fNIRS data by applying kbWF algorithm 
%(Chiarelli et al.,A kurtosis-based wavelet algorithm for motion artifact correction of fNIRS data, Neuroimage, 2015)
% Example
% signal_out=kbWF(signal); default kurtosis threshold 3.3, minimum decomposition level 3rd
% inputs: signal: matrix, n time points x m channels
%signal_out=kbWF(signal,k_th);
% inputs: signal: matrix, n time points x m channels, k_th: kurtosis
% threshold (scalar, must be strictly above 3)
%signal_out=kbWF(signal,k_th,minlvl);
% inputs: signal: matrix, n time points x m channels, k_th: kurtosis
% threshold (scalar, must be strictly above 3), minlvl: minimum
% decomposition level (natural number, 3 minimum)
% output: artifact cleaned signal: matrix, n time points x m channels


function signal_out=pf2_kbWF(signal,varargin)

global WAVELABPATH
if(isempty(WAVELABPATH))
    pf2_base.toolboxes.setup_wavelab();
end


if isempty(varargin)==1
    th_kurt=3.3;
    minlvl=3;
elseif length(varargin)==1
    th_kurt=varargin{1};
    minlvl=3;
else
    th_kurt=varargin{1};
    minlvl=varargin{2};
end

DIM=size(signal);
signal_out=zeros(DIM(1),DIM(2));
qmf = MakeONFilter('Daubechies',12);        %%% db6 wavelet (db6 wavelet provided best results during simulations)
for j=1:DIM(2)                              %%% apply for all the channels
    
    L=nextpow2(DIM(1));
    y=zeros(2^L,1);
    y(1:DIM(1))=signal(:,j);
    wc = FWT_PO(y,1,qmf);                       %%%% DWT
    wc1=zeros(length(wc),1);
    for i=minlvl:L-1                             %%%% apply on coefficients form level 'minlvl' to end -1 (-1 for sampling purposes)
        
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
    xc1 = IWT_PO(wc1,1,qmf);                        %%%% apply IDWT
    signal_out(:,j)=xc1(1:DIM(1));
    
end