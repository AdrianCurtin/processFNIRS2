function [cleanOD_out] = waveClean(dataIn, level, alpha, convert2OD, showPlot)
% WAVECLEAN Wavelet-based motion artifact removal for fNIRS signals
%
% Applies wavelet decomposition with statistical thresholding to remove
% motion artifacts from fNIRS optical density signals. Uses Daubechies
% wavelets and p-value based coefficient rejection.
%
% Reference:
%   Molavi, B. & Dumont, G.A. (2012). Wavelet-based motion artifact removal
%   for functional near-infrared spectroscopy. Physiol. Meas. 33(2), 259.
%
% Syntax:
%   cleanOD = waveClean(dataIn)
%   cleanOD = waveClean(dataIn, level)
%   cleanOD = waveClean(dataIn, level, alpha)
%   cleanOD = waveClean(dataIn, level, alpha, convert2OD, showPlot)
%
% Inputs:
%   dataIn     - Input signal matrix [T x C] where T=samples, C=channels
%                Should be optical density data (or raw if convert2OD=true)
%   level      - Wavelet decomposition level (default: 5)
%                Higher levels capture slower artifact components.
%                Signal must have at least 2^level samples.
%   alpha      - Significance level for coefficient rejection (default: 0.1)
%                Coefficients with p < alpha are zeroed (artifact removal).
%                Lower alpha = less aggressive cleaning.
%   convert2OD - If true, convert input from raw intensity to OD (default: 0)
%                Output will be converted back to intensity.
%   showPlot   - If true, display diagnostic plots (default: false)
%
% Outputs:
%   cleanOD_out - Cleaned signal matrix [T x C], same size as input
%                 Motion artifacts are attenuated while preserving signal.
%
% Algorithm:
%   1. Apply forward wavelet transform (Daubechies-10) at specified level
%   2. Estimate noise standard deviation using MAD of detail coefficients
%   3. Zero detail coefficients with p-value < alpha (artifact signatures)
%   4. Reconstruct signal via inverse wavelet transform
%   5. Average overlapping reconstructions for signals > 2^level samples
%
% Notes:
%   - Requires WaveLab toolbox (automatically initialized via setup_wavelab)
%   - Beta version - use with caution and validate results
%   - Signal length must be at least 2^level samples
%   - Processing time increases with signal length and number of channels
%
% Example:
%   % Clean optical density data with default settings
%   cleanedOD = waveClean(odData);
%
%   % More aggressive cleaning with level 6 decomposition
%   cleanedOD = waveClean(odData, 6, 0.05);
%
% See also: pf2_MotionCorrectWavelet, pf2_SMAR, pf2_MotionCorrectTDDR


disp('Wave Clean - Beta 01');
global WAVELABPATH
if(isempty(WAVELABPATH))
    pf2_base.toolboxes.setup_wavelab();
end


if(nargin<2)
   level=5; 
end

if(nargin<3)
    alpha=0.1;
end

if(nargin<5)
    showPlot=false;
end

if(nargin<4)
    convert2OD=0;
else
    if(convert2OD)
        dataIn=-log10(dataIn./1);
    end
end

%waveshrink
QMF_Filter = MakeONFilter('Daubechies',10);
mL=9;
cleanOD_out=nan(size(dataIn));
numCh=size(dataIn,2);
sigLength=size(dataIn,1);

if(sigLength<2^level)
   error('Unable to reconstruct signal at Level %i\nSignal has %i samples and must have at least %i',level,sigLength,2^level); 
end

for ch=1:numCh
    signalOD=dataIn(:,ch);
    len=length(signalOD);
    maxPow=floor(log2(len));
    maxSize=2^maxPow;
    overlap=(len-maxSize)/(len);

    if(overlap<0.3)
        t{1}=1:maxSize;
        t{2}=len-maxSize+1:len;

        s{1}=signalOD(t{1});
        s{2}=signalOD(t{2});
    else
        t{1}=1:maxSize;
        t{2}=len-maxSize+1:len;
        t{3}=round(len/2)-maxSize/2+1:round(len/2)+maxSize/2;

        s{1}=signalOD(t{1});
        s{2}=signalOD(t{2});
        s{3}=signalOD(t{3});
    end

    t1=ones(1,maxSize);

    if(showPlot)
    figure(1);
    plot(t{1},t1,'linewidth',5);
    hold on;
    plot(t{2},t1*2,'linewidth',5);
    if(length(s)>2)
        plot(t{3},t1*3,'linewidth',5);
    end
    hold off;
    end

    combinedSig=NaN(length(s),len);

    cDarr=[];

    for i=1:length(s)
        sig=s{i};
        %xh=WaveShrink(sig(1:maxSize), 'SURE',mL,QMF_Filter);

        L=level;

        %for L=1:mL
        dw(L,:)=FWT_PO(sig,L,QMF_Filter);
        %end


        cA{i}=dw(L,1:2^L);
        cD{i}=dw(L,2^L+1:end);

        x=cD{i};

        if(i==1)
            cDarr=[cDarr,cD{i}];
        elseif(i==2)
            if(round(overlap*length(x))>0)
                cDarr=[cDarr,x(round(overlap*length(x)):end)];
            end
        end
    end

    sigma=(nanmedian(abs(cDarr))/0.6745);

    for i=1:length(s)

        p=(2*(1-normcdf(abs(cD{i})/sigma)));
        x=cD{i};
        x(p<alpha)=0;
        cD{i}=x;
        iw(L,:)=IWT_PO([cA{i} cD{i}],L,QMF_Filter);

        if(showPlot&&i==2)
            figure(1);
            subplot(2,1,1);
            plot(sig,'r');
            title(sprintf('Original Signal %d',mean(sig(1:500))));
            ylim([min(sig(1:500)),max(sig(1:500))]);
            subplot(2,1,2);
            plot(iw(L,1:maxSize));
            title(['Reconstructed Signal at level ' sprintf('%i %d',L,mean(iw(L,1:500)))]);
            ylim([min(sig(1:500)),max(sig(1:500))]);
            %subplot(3,1,3);
            %plot(xh(1:maxSize));
            %title('Denoised');
        end
        %clear cA cD;

        if(i==1)  %Crops signal by...    
            cutprm1=20; %Removes first 20 points from beginning
            cutprm2=20; %Removes last 100 points from end
        elseif(i==2)
                cutprm1=20;
                cutprm2=20;
        elseif(i==3)
            cutprm1=100;
            cutprm2=100;
        end

        ind=[zeros(1,cutprm1),ones(1,maxSize-cutprm1-cutprm2),zeros(1,cutprm2)]==1;
        t1=t{i};
        combinedSig(i,round(t1(ind)))=iw(L,ind);

    end

    if(showPlot)
        figure(2)
        subplot(2,1,1);
        plot(combinedSig');
        ylim([min(signalOD(:)),max(signalOD(:))]);
        subplot(2,1,2);
        plot(signalOD)
        hold on;
        plot(combinedSig');
        legend('Original','Filter (pt1)','Filter (pt2');
        ylim([min(signalOD(:)),max(signalOD(:))]);
        %plot(nanmean(combinedSig));
        hold off;
    end

    cleanOD=nanmean(combinedSig);

    if(convert2OD)
        cleanOD=10.^cleanOD;
    end
    
    cleanOD_out(:,ch)=cleanOD;
end


   
end


