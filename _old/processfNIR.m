function fNIR=processfNIR(fNIR,applyRAW)

% Master Script to process fNIRS structure into oxy /deoxy data
% requires a struct with 'raw' containing light intensity data from the 16
% channel fNIRS 1100 device
% Alternatively will build fNIR struct from defined files

% Performs processing according to the settings defined in the global 'f' variable
%
% Default parameters will be filled in if the process fNIR script is run
% without any inputs

% These values can be modified using by changing properties in the global f
% variable

if(nargin<2)
    applyRAW=false; %Applies processing to raw light intensity
end
global set;
if(~isfield(set,'f'))
    disp('Initializing default ''f'' filter values');
end

if(nargin<1)
    justInitializeF=true;
else
    justInitializeF=false;
end

if(~isfield(set,'f')||justInitializeF)
    set.f=[];
    set.f.lpf=[];
    set.f.bpf=[];
    set.f.smar=[];
    set.f.linDetrend=[];
    set.f.waveletDenoise=[];
    set.f.med=[];
    set.f.CAR=[];
    set.f.icaDark=[];
    set.f.subtractDark=[];
    set.f.smooth805=[]; set.f.MARA=[]; set.f.SMAR_SplineReconstruct=[];
    set.f.TDRR=[];
    
    % Applies filtering to raw data
    set.f.import=false; %when set to false, no changes are made to .raw structure
                        %if set to true, filters and other processing steps
                        %saved in light domain will writeover the internal
                        %structures for .RAW and subsequent processing steps
                        %will include these timepoints

    %Set Defaults
    set.f.lpf.enable=false;  %perform lowpass filter
        set.f.lpf.Upper=0.3;  %Low Pass filter bound
        set.f.lpf.filtlen=40; %LPF filter length (N)
    
    set.f.bpf.enable=false;  %perform highpass filter
        set.f.bpf.Lower=0.008; %High Pass portion of butterworth filter
        set.f.bpf.Upper=0.3;  %Low Pass portion of butterworth filter
        set.f.bpf.order=3; %set default bandpass filter order
    
    set.f.smar.enable=false;   %perform SMAR (Sliding Motion Artificat Rejection
        set.f.smar.window=10;   %SMAR window size
        set.f.smar.tauUp=0.1;     %SMAR tau upper threshold
        set.f.smar.tauLow=0.003;     %SMAR tau upper threshold
        
    set.f.linDetrend.enable=false;     %perform linear detrending
    
    set.f.waveletDenoise.enable=false; %Perform wavelet denoising

    set.f.med.enable=false;    %fNIRS median filtering
        set.f.med.N=10;  %fNIRS median filtering size

    set.f.CAR.enable=false;    %perform common average reference removal

    set.f.icaDark.enable=false;    %Perform ICA between Dark channel and active channels
        set.f.icaDark.Weight=0;
    
    set.f.subtractDark.enable=false;   %Subtract ambient light channel from raw light channels
                                % Note Dark channels are not temporally in sync
                                % so measures may be not perfectly correlated
    
    set.f.smooth805.enable=false;  %perform temporal smoothing on 805 first
                              % May remove some small variations which can
                              % become much larger during a scaled ICA
                              
    set.f.upperThreshold=4300;  %Intensity at which signal is considered to be saturated (replaced with NAs)
    set.f.lowerThreshold=0;   %Intensity at which signal is considered to be insufficient (replaced with NAs)
    
    set.f.MARA.enable=false; %Uses the Motion artifact reduction algorithim by Scholkmann 2010
        set.f.MARA.T=50; % Treshold for motion artifcats and motion artifact detection (in light units)
        set.f.MARA.k=25; % One side of Moving STD window size w= 2*k+1
        set.f.MARA.smoothingParam=4; % default value for lowess smoothing
        
    set.f.SMAR_SplineReconstruct.enable=false; %Uses the Motion artifact reduction algorithim by Scholkmann 2010
        set.f.SMAR_SplineReconstruct.tauUp=0.1; % Treshold for motion artifcats and motion artifact detection (in light units)
        set.f.SMAR_SplineReconstruct.tauLow=0.003; % Treshold for motion artifcats and motion artifact detection (in light units)
        set.f.SMAR_SplineReconstruct.k=10; % One side of Moving STD window size w= 2*k+1
        set.f.SMAR_SplineReconstruct.smoothingParam=4; % default value for lowess smoothing
        
    set.f.TDRR.enable=false; % Uses Fishburn temporal deritvative distribution repair algorithim (2019)
    
    set.f.debugPlots=false; %plots oxy before and after
end

if(justInitializeF)
    
    return;
end



if(~isstruct(fNIR)) % if fNIR is an array of raw values, convert it
   temp=fNIR;
   clear fNIR;
   fNIR.raw=temp;
   clear temp;
end

numCh=(size(fNIR.raw,2)-1)/3;

fNIR.time=fNIR.raw(:,1);

fNIR.estimatedFS=1/mean(medfilt1(diff(fNIR.time)));
fs=fNIR.estimatedFS;
%     sprintf('Calculated FS is %f',fs);
% pause;

if(std(medfilt1(diff(fNIR.time)))>0.05)
    disp('Fluctating sampling interval\n');
    fNIR.estimatedFS
    figure(29);
    plot(medfilt1(diff(fNIR.time)));
    title(sprintf('Calculated FS is %f',fs));
%     pause;
end

if(isfield(fNIR,'markers')&&isfield(fNIR.markers,'headers'))
    fNIR.startTime=sscanf(fNIR.markers.headers{2,1},'Start Time: %*s %*s %*d %f:%f:%f %*d');
    fNIR.startTime=fNIR.startTime(1)*3600+fNIR.startTime(2)*60+fNIR.startTime(3);
end

fNIR.raw(fNIR.raw(:,1)==0,:)=[];

j=0:floor(size(fNIR.raw,2)/3)-1;

if(set.f.smar.enable)
   s.raw=SMAR_1100(fNIR.raw,set.f.smar.window,set.f.smar.tauUp); 
   %sinit.raw=fNIR.raw(:,[1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1]==1);
   %sinit.raw=SMAR(sinit.raw,set.f.smar.window,set.f.smar.tauUp); 
   %s.raw=nan(size(fNIR.raw));
   %s.raw(:,[1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1 1 0 1]==1)=sinit.raw;
   s.index=find(fNIR.raw(:,1)==s.raw(1,1));
   s.red=s.raw(:,3*j+4);
   s.in=isnan(s.red)==1;
   %fNIR.raw=s.raw;
%    for i=1:set.f.smar.window/2%s.index
%        s.in=[s.in(1,:);s.in(1,:);s.in;];
%    end
   %s.in=[s.in(1,:);s.in(1,:);s.in(1,:);s.in(1,:);s.in(1,:);s.in(:,:);s.in(end,:);s.in(end,:);s.in(end,:);s.in(end,:);];
end




fNIR.time=fNIR.raw(:,1);    
raw_850(:,j+1)=fNIR.raw(:,3*j+4);     % Creation of the 3 matrices
raw_805(:,j+1)=fNIR.raw(:,3*j+3);     % which store data
raw_730(:,j+1)=fNIR.raw(:,3*j+2);     % for each wavelength

clear j


if(set.f.MARA.enable)
    for(i=1:numCh)
        raw_730(:,i)=pf2_fnirs_MARA(raw_730(:,i),fs,set.f.MARA.T,set.f.MARA.k,set.f.MARA.smoothingParam);
        raw_805(:,i)=pf2_fnirs_MARA(raw_805(:,i),fs,set.f.MARA.T,set.f.MARA.k,set.f.MARA.smoothingParam);
        raw_850(:,i)=pf2_fnirs_MARA(raw_850(:,i),fs,set.f.MARA.T,set.f.MARA.k,set.f.MARA.smoothingParam);
    end
end

if(set.f.TDRR.enable)
    %SD.MeasListAct=ones(1,numCh); %pretend all channels are valid
    raw_730=pf2_MotionCorrectTDDR(raw_730,fs);
    raw_805=pf2_MotionCorrectTDDR(raw_805,fs);
    raw_850=pf2_MotionCorrectTDDR(raw_850,fs);
end

if(set.f.SMAR_SplineReconstruct.enable)
    for(i=1:numCh)
        raw_730(:,i)=pf2_SMAR_SplineReconstruct(raw_730(:,i),fs,set.f.SMAR_SplineReconstruct.tauUp,set.f.SMAR_SplineReconstruct.tauLow,set.f.SMAR_SplineReconstruct.k,set.f.SMAR_SplineReconstruct.smoothingParam);
        %raw_805(:,i)=SMAR_SplineReconstruct(raw_805(:,i),fs,set.f.SMAR_SplineReconstruct.tauUp,set.f.SMAR_SplineReconstruct.tauLow,set.f.SMAR_SplineReconstruct.k,set.f.SMAR_SplineReconstruct.smoothingParam);
        raw_850(:,i)=pf2_SMAR_SplineReconstruct(raw_850(:,i),fs,set.f.SMAR_SplineReconstruct.tauUp,set.f.SMAR_SplineReconstruct.tauLow,set.f.SMAR_SplineReconstruct.k,set.f.SMAR_SplineReconstruct.smoothingParam);
    end
end


if(set.f.smooth805.enable)
    for(i=1:numCh)
        raw_805(:,i)=smooth(raw_805(:,i)); 
    end
end

if(set.f.med.enable)
    raw_730=medfilt1(raw_730,medFiltN);
    raw_805=medfilt1(raw_805,medFiltN);
    raw_850=medfilt1(raw_850,medFiltN);
    
    
    m=floor(set.f.med.N/5);
    for i=1:m
        raw_730(i,:)=raw_730(m+1,:);
        raw_805(i,:)=raw_805(m+1,:);
        raw_850(i,:)=raw_850(m+1,:);
    end
end



if(set.f.icaDark.enable)
    for(i=1:numCh)
        ch850=raw_850(:,i);
        ch805=raw_805(:,i);
        ch730=raw_730(:,i);
        
        lWeight=set.f.icaDark.Weight;
        lIndex=[lWeight+1,length(ch805)+lWeight];
        
        
        weight850=ones(lWeight,1).*(median(ch850)+15/0.05);
        weight730=ones(lWeight,1).*(median(ch730)+15/0.09);
        weight805=ones(lWeight,1).*(median(ch805)+15);
        
        if(lWeight>0)
            ch850=[weight850;ch850;weight850];
            ch805=[weight805;ch805;weight805];
            ch730=[weight730;ch730;weight850];
        end
        
%         subplot(2,1,1)
%         plot(raw_730(:,i),'k');
%         hold on
%         subplot(2,1,2);
%         plot(raw_805(:,i));
        
        [ch850,~]=icaClean(ch850',ch805');
        
        [ch730,ch805]=icaClean(ch730',ch805');
        
        if(lWeight>0)
            raw_850(:,i)=ch850(lIndex(1):lIndex(2))-median(ch850(lIndex(1):lIndex(2)))+median(raw_850(:,i));
            raw_730(:,i)=ch730(lIndex(1):lIndex(2))-median(ch730(lIndex(1):lIndex(2)))+median(raw_730(:,i));
            raw_805(:,i)=ch805(lIndex(1):lIndex(2))-median(ch805(lIndex(1):lIndex(2)))+median(raw_805(:,i));
        else
            raw_850(:,i)=ch850;
            raw_730(:,i)=ch730;
            raw_805(:,i)=ch805;
        end
%         subplot(2,1,1);
%         hold on;
%         plot(raw_730(:,i),'r');
%         hold off;
%         
%         pause;
    end
end



if(set.f.lpf.enable)%LPF
    filttype=1; filtlen=set.f.lpf.filtlen; %fcutUpper=0.2;
%     fs=1/0.51;
    raw_730=lpf( raw_730,filttype,fs,set.f.lpf.Upper,filtlen );
    raw_805=lpf( raw_805,filttype,fs,set.f.lpf.Upper,filtlen );
    raw_850=lpf( raw_850,filttype,fs,set.f.lpf.Upper,filtlen );
    
    fNIR.LPF.fcut=set.f.lpf.Upper;
    fNIR.LPF.filtlen=filttype;
    fNIR.LPF.fs=fs;
end

nanIndexThreshold730=raw_730(:)<set.f.lowerThreshold|raw_730(:)>set.f.upperThreshold;
nanIndexThreshold850=raw_850(:)<set.f.lowerThreshold|raw_850(:)>set.f.upperThreshold;

if(set.f.bpf.enable)
        filtOrder=set.f.bpf.order; %fcutLower=0.03; fcutUpper=0.2;
        for ch=1:numCh
            raw_730(:,ch)=bpf( raw_730(:,ch),filtOrder,fs,set.f.bpf.Lower,set.f.bpf.Upper)+mean(raw_730(:,ch));
            raw_805(:,ch)=bpf( raw_805(:,ch),filtOrder,fs,set.f.bpf.Lower,set.f.bpf.Upper)+mean(raw_805(:,ch));
            raw_850(:,ch)=bpf( raw_850(:,ch),filtOrder,fs,set.f.bpf.Lower,set.f.bpf.Upper)+mean(raw_850(:,ch));
        end
        fNIR.bpf.fcut=[set.f.bpf.Lower set.f.bpf.Upper];
        fNIR.bpf.fs=fs;
end


if(applyRAW)
   fNIR.raw=[fNIR.raw(:,1),raw_730,raw_805,raw_850];
   xArr=[1,reshape([2:1+numCh;numCh*1+2:numCh*2+1;numCh*2+2:numCh*3+1],[1,3*numCh])];
   fNIR.raw=fNIR.raw(:,xArr); %Applies pre-processing here
end


raw_730(nanIndexThreshold730)=NaN;
raw_850(nanIndexThreshold850)=NaN;
% 

if(set.f.subtractDark.enable)
    for (i=1:numCh)
        
%               subplot(2,1,1)
%       plot(raw_730(:,i),'k');
%       hold on
%       subplot(2,1,2);
%       plot(raw_805(:,i));
      
        raw_850(:,i)=raw_850(:,i)-raw_805(:,i);
        raw_730(:,i)=raw_730(:,i)-raw_805(:,i);
%          subplot(2,1,1);
%         hold on;
%         plot(raw_730(:,i),'r');
%         hold off;
%         
%         pause;
        
    end
end


fNIR.fin.raw_730=raw_730;
fNIR.fin.raw_805=raw_805;
fNIR.fin.raw_850=raw_850;


%
%To OXY and DEOXY

    ss= 1; % use all sample size
    se= size(fNIR.fin.raw_850,1);
                                                          %BASELINE
                                                          %START/END
    [ fNIR.HbDiff , fNIR.bv_805 , fNIR.bv , fNIR.HbO , fNIR.HbR] = bvoxy ( 1 , min(size(fNIR.fin.raw_730,1),60) , ss , se , fNIR.fin.raw_730 , fNIR.fin.raw_805 , fNIR.fin.raw_850);
    
    
    

    if(set.f.debugPlots)
        figure(10)
        plot(fNIR.HbDiff(:,15));
        hold on;
        z=fNIR.HbDiff(:,15);
        z(s.in)=NaN;
        plot(z);
    end
   
    
    
    nanVals=isnan(fNIR.HbDiff);
    
    
   
    if(set.f.CAR.enable)
       
       %for ch=1:16
       %    fNIR.HbDiff=icaClean(fNIR.HbDiff(:,ch),fNIR.CAR(:,1)); 
       %     fNIR.HbO=icaClean(fNIR.HbDiff(:,ch),fNIR.CAR(:,1)); 
       %end
         fNIR.CAR=getCARfnir(fNIR);
        fNIR.HbDiff=fNIR.HbDiff-fNIR.CAR.HbDiff; 
       fNIR.HbO=fNIR.HbO-fNIR.CAR.HbO; 
       fNIR.HbR=fNIR.HbR-fNIR.CAR.HbR; 
    end
    
    if(set.f.smar.enable)
            smrPoints=find(s.in==1);
            nPoints=find(s.in==0);
            
            if(~isempty(nPoints))
                  
                fNIR.HbDiff(s.in)=interp1(nPoints,fNIR.HbDiff(~s.in),smrPoints,'linear',0);
                fNIR.bv_805(s.in)=interp1(nPoints,fNIR.bv_805(~s.in),smrPoints,'linear',0);
                fNIR.bv(s.in)=interp1(nPoints,fNIR.bv(~s.in),smrPoints,'linear',0);
                fNIR.HbO(s.in)=interp1(nPoints,fNIR.HbO(~s.in),smrPoints,'linear',0);
                fNIR.HbR(s.in)=interp1(nPoints,fNIR.HbR(~s.in),smrPoints,'linear',0);
            end
    end
    
    if(set.f.waveletDenoise.enable) %removes 10 seconds from both sides of data
        level=6;
        
       for ch=1:numCh
           fNIR.HbDiff(:,ch)=waveClean(fNIR.HbDiff(:,ch),level);
            fNIR.bv_805(:,ch)=waveClean(fNIR.bv_805(:,ch),level);
            fNIR.bv(:,ch)=waveClean(fNIR.bv(:,ch),level);
            fNIR.HbO(:,ch)=waveClean(fNIR.HbO(:,ch),level);
            fNIR.HbR(:,ch)=waveClean(fNIR.HbR(:,ch),level);
       end
    end
        

    
    if(set.f.linDetrend.enable)
        
        nPoints2=isnan(fNIR.HbDiff);
        
        fNIR.HbDiff(nPoints2)=detrend(fNIR.HbDiff(nPoints2),'linear');
        fNIR.bv_805(nPoints2)=detrend(fNIR.bv_805(nPoints2),'linear');
        fNIR.bv(nPoints2)=detrend(fNIR.bv(nPoints2),'linear');
        fNIR.HbO(nPoints2)=detrend(fNIR.HbO(nPoints2),'linear');
        fNIR.HbR(nPoints2)=detrend(fNIR.HbR(nPoints2),'linear');
        
        clear nPoints2;
    end
    
    if(set.f.debugPlots)
        hold on;
        plot(fNIR.HbDiff(:,1),'r');
        hold off;
        pause;
    end
    
    if(set.f.smar.enable)
            fNIR.HbDiff(s.in)=NaN;
            fNIR.bv_805(s.in)=NaN;
            fNIR.bv(s.in)=NaN;
            fNIR.HbO(s.in)=NaN;
            fNIR.HbR(s.in)=NaN;
    end
    
    
    fNIR.HbDiff(nanVals)=NaN;
    fNIR.bv_805(nanVals)=NaN;
    fNIR.bv(nanVals)=NaN;
    fNIR.HbO(nanVals)=NaN;
    fNIR.HbR(nanVals)=NaN;
    
    fNIR.HbO=real(fNIR.HbO);
    fNIR.HbR=real(fNIR.HbR);
    fNIR.bv=real(fNIR.bv);
    fNIR.bv_805=real(fNIR.bv_805);
    fNIR.HbDiff=real(fNIR.HbDiff);
    
    fNIR.HbTotal=fNIR.HbO+fNIR.HbR;
    fNIR.CBSI=calcCBSI(fNIR.HbO,fNIR.HbR);
    
    
    
    
    clear se ss i s
    
    
    