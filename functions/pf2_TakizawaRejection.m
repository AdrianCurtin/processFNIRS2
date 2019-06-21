function fMask=pf2_TakizawaRejection(fNIR,strictCriteria)
     %% Measures and optionally applies takizawa rejection criteria
     %  this script will just measure the Takizawa critera for rejection
     %  	Use applyMask =true to merge with the fchMask
     %      Use strictCriteria =true to merge the strict criteria with the
     %      mask   (uses "or" instead of "and" for the takizawa criteria
     %               actual papers are somewhat ambiguous about the logic)
     
     %  Method was originally designed for use with the Hitachi Etg-4000
     %  during a ~60 second verbal fluency task while sampling at 10hz
     %      Some factors including unit conversion were adjusted in
     %      order for this to be functional for other devices, namely
     %          1)Aproximation of units in mM*mm instead of uM
     %          2)Use/Conversion for alternate sampling frequencies
     %          3)High frequency conversion calculated as percentage of
     %          windows rather than 4 specific time periods
     %          4)Instead of 1 artifact >0.15mMmm, a margin is specified
     %          (windowsize/2)
     
     %      Due to differences in between the 2008 and 2014 methodologies,
     %      band power calculations for rule 2(2008) are conducted but not used specifically
     %      in rejection. These items appeared to be unit specific and may
     %      not be good represenations on other devices. Therefore the 2014
     %      rules are used because they are unitless.
     %      Additionally the first rule for 2008 specificed the elimination
     %      of channels with maximum digital and analog gain. This may be a
     %      specific trait of the Hitachi system and so the alternate
     %      method from 2014 using proportional standard deviation is used instead.
     
     %  References:        
	 %  Takizawa Rejection criteria specificed in Supplementary Material I of:
	 %  Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S., Yamasue, H., et al. (2008). 
     %      Reduced frontopolar activation during verbal fluency task in schizophrenia: a multi-channel near-infrared spectroscopy study. Schizophr. Res. 99, 250â€“62. doi:10.10numch/j.schres.2007.10.025.
	 
     % Updated criteria from 
     %  Takizawa, R., Fukuda, M., Kawasaki, S., Kasai, K., Mimura, M., Pu, S., Noda, T., Niwa, S. ichi, Okazaki, Y., Suda, M., Takei, Y., Aoyama, Y., Narita, K., Mikuni, M., Kameyama, M., Uehara, T., Kinou, M., Koike, S., Ishii-Takahashi, A., Ichikawa, N., Fujiwara, M., Ohta, H., Tomioka, H., Yamagata, B., Yamanaka, K., Nakagome, K., Matsuda, T., Yoshida, S., Kono, S., Yabe, H., Miura, S., Nishimura, Y., Tanii, H., Inoue, K., Yokoyama, C., Takayanagi, Y., Takahashi, K., Nakakita, M., 2014. 
     %      Neuroimaging-aided differential diagnosis of the depressive state. Neuroimage 85, 498–507. https://doi.org/10.1016/j.neuroimage.2013.05.126
     
     if(nargin<2)
         strictCriteria=false; % Uses Or instead of And for rejection criteria
     end
     
	 
     
     numch=size(fNIR.HbO,2);
     
	 fMask=false(1,numch);
     
     timeLength=max(fNIR.time)-min(fNIR.time);
	 
     if(timeLength<10)
        takizawa.reject=zeros(1,numch);
        fNIR.takizawa=takizawa;
        warning('Data not long enough for Takizawa criteria (t<10s)');
        return;
     end
     
     Fs = 1/nanmedian(diff(fNIR.time));% Caclculate sampling rate of data
     
      if(isnan(Fs))
        takizawa.row=nan(numch,6);
        takizawa.reject=zeros(1,numch);

        fNIR.takizawa=takizawa;
        warning('Unable to calculate sampling frequency from data');
        return;
      end
     
     % Automatic rejection was developed for Hitachi data reported in
     % mM*mm
     % Best practice is to use original data processed in this style, but
     % using the mean-calculated pathlength is a close approximation for wavelength
     % dependant DPF adaptations and is accurate for fixed DPF styles
     switch(fNIR.units)
         case 'uM'
             fHbO=fNIR.HbO*mean(fNIR.DPF_factor)*3/100; %pretends the data came from a 3cm detector
             fHbR=fNIR.HbR*mean(fNIR.DPF_factor)*3/100;
             fHbT=fNIR.HbTotal*mean(fNIR.DPF_factor)*3/100;
         case 'mM*mm'
             fHbO=fNIR.HbO;
             fHbR=fNIR.HbR;
             fHbT=fNIR.HbTotal;
         otherwise %assume mM*mm
             fHbO=fNIR.HbO;
             fHbR=fNIR.HbR;
             fHbT=fNIR.HbTotal;
     end
             
     
	 
     
    %% Rule 1:  High Frequency Noise
    %   Per the Takizawa 2008 Supplementary Material 1:
    %        High Frequency noise is caused by insufficient intensity of the
    %        light in the OT system and both digital and analog gain are taken
    %        to the maximum value
    %      Implementation interpretation:
    %            All channels in maximum value gain state are artifactual

    % Note:
    %    Difficult to assess the gain state of non-Hitachi systems easily,
    %    additionally there may be better ways to determine artifactual
    %    data due to poor gain

    %    Per Takizawa 2014 Supplementary Material 3:
    %        High frequency noise ise deteced using standard deviation
    %        SD of four blocks (20-35,35-50,50-65,65-80s)(during 70sVFT)
    %        for HbO and HbR and HbTotal using normal matlab std
    %        function. (sd=\sqrt(1/(n-1)\sum((x_t-x_bar)^2))

    %        If the SD_HbO > SD_Total *4 and SD_HbR >SD_toal * 4 for
    %        each block then channel is artifactual

    %        Implementation interpretation:
    %            If SD or either HbO or HbR in 15second sliding window is > 4 * SD of HbTotal
    %                Mark section as invalid

    hfWindowSize=15*Fs; % 15 second window size
    k=ceil(hfWindowSize); %Round up to nearest integer

    fHbO_sd = movstd(fHbO,k); % does not truncate array
    fHbR_sd = movstd(fHbR,k);
    fHbTotal_sd = movstd(fHbT,k);

    tk.rule1.fHbO_hf_tk=fHbO_sd./fHbTotal_sd; % Original TK2014 critera is >4x
    tk.rule1.fHbR_hf_tk=fHbR_sd./fHbTotal_sd;
       
       
   
	 
    %%	Rule 2:
    %   Per the Takizawa 2008 Supplementary Material 1:
    %	Low frequency noise has excessive power in the 0.1-1Hz of oxy and deoxy
    %		Power frequency of Oxy (HbO) and Deoxy (HbR) are calculated P_Oxy P_Deoxy
    %		Channel is determined to be an artifact if
    %			Max( P_Oxy ( N/100: N/10)) >15 or Max( P_Oxy ( N/100: N/10)) >6
    %				here (N/10 is the 1 Hz and N/100 is the 0.1 Hz threshold because of the Hitachi 10hz system)

    % Get the BandPower of 0.1-1Hz

     
    ftHbO=fft(fHbO);    %Get fast fourier of HbO and HbR
    ftHbR=fft(fHbR);

    L=size(ftHbO,1);
    L2=floor(L/2+1);

    Pxx_HbO = 1/(L*Fs)*abs(ftHbO(1:L2,:)).^2;    %Get power spectrum of HbO and HbR
    Pxx_HbR = 1/(L*Fs)*abs(ftHbR(1:L2,:)).^2;

    DF = Fs/L; % frequency increment

    freqvec = 0:DF:Fs/2;                        %Get frequencies of power vector

    fsHz=L2; %frequency at 1 hz
    point1hz=find(freqvec>0.1,1); %should be approximately L/(10*fs)
    onehz=find(freqvec>1);  % Should be approximately L/fs

    if(isempty(onehz))
        onehz=length(freqvec);
        if(max(freqvec)<0.8)
           warning('Must sample at least 2hz to use Takizawa rejection'); 
        end
    end

    if(isempty(point1hz))
       warning('unable to calculate bandpower because signal must be at least 10s long' );
    else

    end

    tk.rule2_2008.HbO_band=max(abs(Pxx_HbO(point1hz:onehz,:)));
    tk.rule2_2008.HbR_band=max(abs(Pxx_HbR(point1hz:onehz,:)));
    
    % Per Takizawa 2014 Supplementary Material 3:
    %   Low Frequency noise is detected using the low frequency value (LF)
    %   and the correlation value (r)
    %       LF= abs(1- (HbR_std-HbO_std))
    
    
    % r = pearsons correlation of HbO and HbR
    % in their dataset (n = 1251) corresponding to ~ 125 seconds of data
    %       channels with LF<0.3 and r value of <-0.9 were artifactual
    
    tk.rule2_2014.LF=abs(1-(nanstd(fHbR)./nanstd(fHbO)));  % Threshold per tk2014: LF<0.3
    tk.rule2_2014.r=corr(fHbO,fHbR,'Rows','pairwise'); %threshold per tk2014: r<-0.9
    tk.rule2_2014.r=tk.rule2_2014.r(eye(size(tk.rule2_2014.r))==1)';
    

	 
     
	 %%	Rule 3:
	 %	Channels with no change in HbO/HbR have a standard deviation of 0 and are artifactual
     
     % Calculate bandpower of HbO and HbR
	 
     numch=size(fHbO,2);

     tk.rule3.HbO=nanstd(fHbO,1); % if everything is zero than reject
     tk.rule3.HbR=nanstd(fHbR,1);
	 
	 
	 %%	Rule 4:
     %  % Per the Takizawa 2008 Supplementary Material 1 and Takizawa 2014 Supplementary Material 3:
	 %	Body movement artifacts have sharp changes
	 %		Channels with HbO and HbTotal changes of 0.15mM*mm over 20 samples (2seconds) are labeled as artifacts

    %% Calculate amount of time from 
    
        tk.rule4.criteria.HbO=0.15;%mm*mM Hb
        tk.rule4.criteria.HbTotal=0.15;%mm*mM Hb
        tk.rule4.criteria.WindowSize=2;%2 seconds
        
        changeThresholdHbO=tk.rule4.criteria.HbO;
        changeThresholdHbTotal=tk.rule4.criteria.HbTotal;
        
        r4windowSize=ceil(tk.rule4.criteria.WindowSize*Fs); % 4 samples for 2 second periods

        t = fNIR.time;
        tSteps=length(t)-r4windowSize-1;
        blankHbO=zeros(tSteps,numch);
        blankHbT=zeros(tSteps,numch);

        for i=1:tSteps
            blankHbO(i,:)=fHbO(i+r4windowSize,:)-fHbO(i,:);
            blankHbT(i,:)=fHbT(i+r4windowSize,:)-fHbT(i,:);
        end

        overThresholdHbO=abs(blankHbO)>changeThresholdHbO;
        overThresholdHbT=abs(blankHbT)>changeThresholdHbTotal;
        overThresholdBoth=overThresholdHbO&overThresholdHbT;

        tk.rule4.HbO_change=sum(overThresholdHbO,1);
        tk.rule4.HbT_change=sum(overThresholdHbT,1);
        tk.rule4.HbOT_change=sum(overThresholdBoth,1);
        
        
    %% Criteria Evaluation and output
        % Final criteria
        
        % Apply Rule 1
        tk.rule1.criteria.SDHbT=4; % Per tk2014 (SD_HbO and SD_HbR >4*SD_total)
        tk.rule1.criteria.percentHigh=0.5; % Fraction of noise required to be classified as high noise artifact channel 

        tk.rule1.HbO=tk.rule1.fHbO_hf_tk>tk.rule1.criteria.SDHbT;
        tk.rule1.HbR=tk.rule1.fHbR_hf_tk>tk.rule1.criteria.SDHbT;
        
        tk.rule1.mask=tk.rule1.HbO.*tk.rule1.HbR==1; %time mask, not channel mask
        tk.rule1.mask=(sum(tk.rule1.mask,1)/size(tk.rule1.mask,1))>tk.rule1.criteria.percentHigh; 
        
        tk.rule1.mask_strict=tk.rule1.HbO+tk.rule1.HbR>0; %time mask, not channel mask
        tk.rule1.mask_strict=(sum(tk.rule1.mask_strict,1)/size(tk.rule1.mask_strict,1))>tk.rule1.criteria.percentHigh; 
        
        % Apply Rule 2
        
        tk.rule2_2008.criteria.HbO=15; % per tk2008 (max P_oxy(10hz:1hz)>15)
        tk.rule2_2008.criteria.HbR=6; % % per tk2008 (max P_deoxy(10hz:1hz)>6)
        tk.rule2_2008.mask=(tk.rule2_2008.HbR_band>tk.rule2_2008.criteria.HbR)...
                            &(tk.rule2_2008.HbO_band>tk.rule2_2008.criteria.HbO);
                        
        tk.rule2_2008.mask_strict=(tk.rule2_2008.HbR_band>tk.rule2_2008.criteria.HbR)...
                            |(tk.rule2_2008.HbO_band>tk.rule2_2008.criteria.HbO);
                        
        tk.rule2_2014.criteria.LF=0.3; % per tk2014 (LF<0.3)
        tk.rule2_2014.criteria.r=-0.9;  % per tk2014 (r<-0.9)
        
        tk.rule2_2014.mask=(tk.rule2_2014.r<tk.rule2_2014.criteria.r)&(tk.rule2_2014.LF<tk.rule2_2014.criteria.LF);
        
        tk.rule2_2014.mask_strict=(tk.rule2_2014.r<tk.rule2_2014.criteria.r)|(tk.rule2_2014.LF<tk.rule2_2014.criteria.LF);
        
        % Apply Rule 3
        tk.rule3.critera=0; % per tk2008   (standard deviation > 0)
        
        tk.rule3.mask=(tk.rule3.HbO< tk.rule3.critera) & (tk.rule3.HbR< tk.rule3.critera);
        
        tk.rule3.mask_strict=(tk.rule3.HbO< tk.rule3.critera) | (tk.rule3.HbR< tk.rule3.critera);
        
        % Apply Rule 4
        
        tk.rule4.criteria.maxBlocks=r4windowSize/(2*timeLength/90); %arbitrary but time length of VFT was 90seconds 
        
        tk.rule4.mask=tk.rule4.HbOT_change>tk.rule4.criteria.maxBlocks;
        tk.rule4.mask_strict=tk.rule4.HbO_change>tk.rule4.criteria.maxBlocks|tk.rule4.HbT_change>tk.rule4.criteria.maxBlocks;
        
  
        takizawa.results=[tk.rule1.mask;tk.rule2_2014.mask;tk.rule3.mask;tk.rule4.mask]; 
        takizawa.results(isnan(takizawa.results))=1;
        takizawa.results_strict=[tk.rule1.mask_strict;tk.rule2_2014.mask_strict;tk.rule3.mask_strict;tk.rule4.mask_strict]; 
        takizawa.results_strict(isnan(takizawa.results_strict))=1;
        takizawa.criteria=tk;
        
        takizawa.reject=sum(takizawa.results,1)>0; %fail if any critera
        takizawa.reject_strict=sum(takizawa.results_strict,1)>0;
        
        takizawa.fchMask=~takizawa.reject; % fchMask is 1 for good channels and 0 for rejected
        takizawa.fchMask_strict=~takizawa.reject_strict;
       

        if(strictCriteria)
            fMask=takizawa.fchMask_strict;
        else
            fMask=takizawa.fchMask;
        end
    end
 
    
    