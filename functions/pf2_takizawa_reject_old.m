function fNIR=pf2_takizawa_reject_old(fNIR,Fs)
     %% Rather than actually reject, 
     %  this script will just measure the Takizawa critera for rejection
	 %  Takizawa Rejection criteria specificed in Supplementary Material I of:
	 %  Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S., Yamasue, H., et al. (2008). Reduced frontopolar activation during verbal fluency task in schizophrenia: a multi-channel near-infrared spectroscopy study. Schizophr. Res. 99, 250–62. doi:10.1016/j.schres.2007.10.025.

    takizawa.band=zeros(1,size(fNIR.HbO,1));
    takizawa.HbO.std=std(fNIR.HbO,1);
    takizawa.HbR.std=std(fNIR.HbR,1);
    
    
    %% Get Bandpower of 0.1-1Hz  (0.5-1Hz for fNIRS1100)
    
    if(nargin<2)
        Fs = 1/mean(medfilt1(diff(fNIR.time)));% 1/0.51; % sampling rate of 1000 Hz
    end
    %Fs =fNIR.estimatedFS;
    if(isnan(Fs))
        takizawa.row=nan(size(fNIR.HbO,1),6);
        takizawa.row=[ones(size(fNIR.HbO,1),1)*6,takizawa.row];
        takizawa.reject=zeros(1,size(fNIR.HbO,1));
        logrow=zeros(1,size(fNIR.HbO,1));
    else
    
        ftHbO=fft(fNIR.HbO);
        ftHbR=fft(fNIR.HbR);

        L=size(ftHbO,1);
        L2=floor((L-1)/2+1);

        DF = Fs/L; % frequency increment
        ftHbO = ftHbO(1:L2,:);
        ftHbR = ftHbR(1:L2,:);  

        freqvec = 0:DF:Fs/2;

        fsHz=L2;
        onehz=floor((L2-1)/4);

        takizawa.HbO.band=max(abs(ftHbO(onehz:fsHz,:)));
        takizawa.HbR.band=max(abs(ftHbR(onehz:fsHz,:)));
    
   
    %% Calculate amount of time from 
    
        changeThresholdHbO=0.75; %0.15mmHb
        changeThresholdHbR=0.5; %0.15mmHb

        windowSize=4;

        t = fNIR.time;
        tSteps=length(t)-windowSize-1;
        blankHbO=zeros(tSteps,size(fNIR.HbO,1));
        blankHbR=zeros(tSteps,size(fNIR.HbO,1));

        for i=1:tSteps
            blankHbO(i,:)=fNIR.HbO(i+windowSize,:)-fNIR.HbO(i,:);
            blankHbr(i,:)=fNIR.HbR(i+windowSize,:)-fNIR.HbR(i,:);
        end

        overThresholdHbO=abs(blankHbO)>changeThresholdHbO;
        overThresholdHbR=abs(blankHbR)>changeThresholdHbR;

        takizawa.HbO.change=sum(overThresholdHbO,1);
        takizawa.HbR.change=sum(overThresholdHbR,1);

        takizawa.row=[takizawa.HbO.band',takizawa.HbO.change',takizawa.HbO.std',takizawa.HbR.band',takizawa.HbR.change',takizawa.HbR.std'];
    
    
    
    nanrow=isnan(takizawa.row(:,2));
    logrow=[takizawa.row(:,1)>4, ...
        takizawa.row(:,2)>4, ...
        takizawa.row(:,3)>0.6|takizawa.row(:,3)<0.1, ...
        takizawa.row(:,4)>3, ...
        takizawa.row(:,5)>4, ...
        takizawa.row(:,6)>0.5];
    
    takizawa.row=[sum(logrow,2),takizawa.row];
    
    takizawa.reject=takizawa.row(:,1)>2|nanrow;
    
    end
    
    fNIR.takizawa=takizawa;
    
end