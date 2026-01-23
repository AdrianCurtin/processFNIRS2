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
        debug=false;
    end
    %car=zeros(size(FNIR.time));
    
    numCh=size(x,2);
    

    if(debug)
        q1=diff(x);
        for ch=1:numCh
            medfilt1(q1(:,ch));
            q1(q1(:,ch)>0.02,ch)=1;
            q1(q1(:,ch)<-0.02,ch)=-1;
        end
        q2=sum(q1,2);
        q3=[0;abs(q2>8)]==0;
        figure(3);
        subplot(2,1,1);
        plot(q2);
    end
    %z2=diff(FNIR.hbo2);
    %z3=diff(FNIR.hb);
    %=sum(isnan(z1),2);
    %numch=size(z1,2);
    %CAR.oxy=cumsum([0;nansum(z1,2)./(numch-y)]);
    %CAR.hbo2=cumsum([0;nansum(z2,2)./(numch-y)]);
    %CAR.hb=cumsum([0;nansum(z3,2)./(numch-y)]);
    
    %CARx=zeros(size(x));
    
    %find best correlation for CAR amplitude
    %B1=zeros(1,numCh);
    if(local)
        for ch=1:numCh
			neighbors=[ch+3,ch+1,ch+2,ch-2,ch-1,ch-3];
            % Do local processing here
        end
        
        CARout=[];
    else
		%neighbors( ismember(neighbors,find(fchMask==0)))=[];
        %neighbors(neighbors<1|neighbors>numCh)=[];
        
       
        %y=sum(isnan(x),2);
        basicCAR=nanmean(x,2);
        
        basicCAR=medfilt1(basicCAR,medfiltN);
        
        CARx=repmat(basicCAR,1,numCh);
        
        CARout=x-CARx;
        %searchRange=0:0.2:2;
        %for count=1:length(searchRange)
        %    i=(searchRange(count));
        %    xCAR=dCAR*i;
        %    r(count)=corr(medfilt1(dCAR),medfilt1(dF)-medfilt1(xCAR));
        %end

        %A(ch)=interp1(r,searchRange,0,'linear','extrap');

        
        %x=medfilt1(real(CARx(:,ch)./x(:,ch)),medFiltN);
        
        %B1(ch)=max(0,nanmean(x(medFiltN:end)));

        %C(ch)=nanstd(z(n:end));
        %artIndex=abs((dCAR./dF))<(B(ch)+C(ch)*3);

        %CAR.oxy(:,ch)=CAR.oxy(:,ch)*B1(ch);
        %CAR.hbo(:,ch)=CAR.hbo(:,ch)*B2(ch);
        %CAR.hb(:,ch)=CAR.hb(:,ch)*B3(ch);
        %CAR.cbsi(:,ch)=CAR.cbsi(:,ch)*B4(ch);
        

    end
    
    %CAR.B.BOxy=B1;
 
end