function [Xcorr, maskCV, MA_idx]=pf2_SMAR2(x,N,chNum,tauArtifact,tauClean,minSeg)
% PF2_SMAR2 Enhanced Sliding Motion Artifact Rejection (v2.0) for fNIRS data
%
% An improved version of the SMAR algorithm with adaptive thresholding and
% artifact region expansion. Uses the temporal derivative of the coefficient
% of variation (dCV) for more robust artifact detection, and expands artifact
% regions to capture onset/offset transitions.
%
% Key improvements over pf2_SMAR:
%   - Adaptive thresholds based on median CV of the signal
%   - Two-threshold approach (artifact detection + clean boundary)
%   - Artifact region expansion to capture full artifact extent
%   - Wavelength pairing: rejects both wavelengths if either has artifact
%   - Minimum segment merging to avoid isolated artifact islands
%
% Reference:
%   Ayaz, H. et al. (2010). Sliding-window motion artifact rejection for
%   Functional Near-Infrared Spectroscopy. Conf Proc IEEE Eng Med Biol Soc.
%
% Syntax:
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x)
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x, N)
%   [Xcorr, maskCV, MA_idx] = pf2_SMAR2(x, N, chNum, tauArtifact, tauClean, minSeg)
%
% Inputs:
%   x           - Input signal matrix [T x C] where T=samples, C=channels
%                 Typically optical density data after log transform
%   N           - Window length in samples for CV calculation (default: 10)
%                 Typical range: 5-20 samples. Odd values recommended.
%   chNum       - Channel number mapping [1 x C] (default: 1:size(x,2))
%                 Used to pair wavelengths: channels with same chNum are
%                 grouped, and if any channel in a group has an artifact,
%                 all channels in that group are masked.
%   tauArtifact - Artifact detection threshold multiplier (default: 3)
%                 Threshold = median(CV)*2 + std(upperCV)*tauArtifact
%                 Typical range: 2-5. Lower = more aggressive rejection.
%   tauClean    - Clean boundary threshold multiplier (default: 1)
%                 Used to expand artifact regions to "clean" boundaries.
%                 Should be less than tauArtifact.
%   minSeg      - Minimum clean segment length in samples (default: N/2)
%                 Short clean segments between artifacts are merged.
%                 Prevents fragmented masking.
%
% Outputs:
%   Xcorr   - Corrected signal matrix [T x C], same size as input
%             Artifact samples are replaced with NaN values
%   maskCV  - Logical mask [T+2 x C] indicating artifacts (true = artifact)
%             Note: Padded by 1 sample at start and end for edge handling
%   MA_idx  - Cell array {1 x C} of artifact segment indices
%             Each cell contains [Mx2] matrix with [start_idx, end_idx]
%             rows for each detected artifact segment
%
% Algorithm:
%   1. Compute local CV and its temporal derivative (dCV) in sliding window
%   2. Calculate adaptive thresholds from median and upper-tail std of CV
%   3. Mark samples where |dCV| exceeds artifact threshold
%   4. Expand marked regions to clean threshold boundaries
%   5. Apply wavelength pairing (if chNum has duplicates)
%   6. Merge short inter-artifact segments (< minSeg)
%   7. Replace masked samples with NaN
%
% Example:
%   % Basic usage
%   [corrected, mask, idx] = pf2_SMAR2(odData);
%
%   % With wavelength pairing (channels 1-18 for wavelength 1, 1-18 for wavelength 2)
%   chNum = [1:18, 1:18];
%   [corrected, mask, idx] = pf2_SMAR2(odData, 10, chNum);
%
%   % Conservative settings (less rejection)
%   [corrected, mask, idx] = pf2_SMAR2(odData, 10, [], 4, 2, 10);
%
% Notes:
%   - The adaptive thresholding, two-threshold artifact expansion, and
%     wavelength pairing are processFNIRS2 extensions of the original SMAR
%     algorithm (Ayaz 2010). The original paper uses a single fixed CV
%     threshold; this implementation derives thresholds from signal statistics.
%
% See also: pf2_SMAR, pf2_fnirs_MARA, pf2_MotionCorrectTDDR, calcLocalCV

if nargin<1
    error('Not enough Input arguments');
elseif nargin==1
     N=10;  %Default Window Length
end

if(nargin<3||isempty(chNum))
   chNum=1:size(x,2); 
end

if(nargin<4)
     tauArtifact=3;
end
if(nargin<5)
     tauClean=1;
end

if(nargin<6)
    minSeg=N/2;
end

if(N<1)
    error('Invalid Window Length');
end
len=size(x,1);

[CVx,dCVx]=calcLocalCV(x,N);
aCVx=abs(CVx);
adCVx=abs(dCVx);
CVx_median=nanmedian(aCVx,1);
dCVx_median=nanmedian(adCVx,1);
aCVx_lower=aCVx;
aCVx_lower(aCVx_lower<(2.*repmat(CVx_median,[size(aCVx_lower,1),1])))=nan;
lowerStd=nanstd(aCVx_lower);

% Adaptive thresholds (pf2 extension of Ayaz 2010 SMAR)
CVthreshold=CVx_median*2+lowerStd.*tauArtifact;
CVthresholdClean=CVx_median*2+lowerStd.*tauClean;

dCVthreshold=dCVx_median.*tauArtifact;
dCVthresholdClean=dCVx_median.*tauClean;

aCVxm=[zeros(1,size(x,2));aCVx;zeros(1,size(x,2))];
adCVxm=[zeros(1,size(x,2));adCVx;zeros(1,size(x,2))];

maskCV=adCVxm>dCVthreshold|isnan(adCVxm);
maskCVclean=adCVxm>dCVthresholdClean|isnan(adCVxm);

dMask=diff(maskCV);
aMask=abs(dMask);
dMaskClean=diff(maskCVclean);

MA_idx=cell(1,size(x,2));

for(i=1:size(x,2))
   segStart=find(dMaskClean(:,i)==1);
   segEnd=find(dMaskClean(:,i)==-1);
   
   numSegs=length(segStart);
   
   
   for(t=1:numSegs)
       if(sum(aMask(segStart(t):segEnd(t),i))>0)
          maskCV(max(segStart(t),1):segEnd(t),i)=true;
       end
   end
   
end

[uCh,~,uChIdx]=unique(chNum);

if(length(uCh)<length(chNum))
   for i=1:length(uCh)
      chMatch=find(uChIdx==i);
      
      if(length(chMatch)<=1)
          continue;
      end
      
      temp=any(maskCV(:,chMatch),2);
      
      maskCV(:,chMatch)=repmat(temp,[1,length(chMatch)]);
      
   end
end

for(i=1:size(x,2))
   dX=diff([0;maskCV(:,i);0]);
   
   segMaskStart=find(dX==1);
   segMaskEnd=find(dX==-1);
   
   numMaskSegs=length(segMaskStart);
   
   maskSegIdx=nan(numMaskSegs,2);
   maskCount=0;
   t2=0;
   for(t=1:numMaskSegs)
       if(t2>=t)
           continue;
       end
       
       t2=t;
       while t2<numMaskSegs&&(segMaskStart(t2+1)-segMaskEnd(t2))<minSeg
           t2=t2+1;    
           if(t2>=numMaskSegs)
               break;
           end
       end
       maskCV(max(segMaskStart(t),1):min(segMaskEnd(t2),len),i)=true;
       maskCount=maskCount+1;
       maskSegIdx(maskCount,:)=[max(segMaskStart(t),1),min(len,segMaskEnd(t2))];
       
       t=t2;
       
   end
   maskSegIdx(isnan(maskSegIdx(:,1)),:)=[];
   MA_idx{i}=maskSegIdx;
end





Xcorr=x;



Xcorr(maskCV(2:end-1,:))=nan;
    
    

end


%%_Subfunctions_________________________________________________________

%__________________________________________________________________________
function [CVx, dCVx] = calcLocalCV(x,N)
% Function to calculate coefficient of variation for use in SMAR technique
% x:	input signal
% N:	window length for SMAR

if nargin<1
    error('Not enough Input arguments');
end

if(N<1)
    error('Invalid Window Length');
end

l=size(x);
wid=l(2);%width
len=l(1);%length

if(rem(N,2)==0)
   
    N=N+1; 
   
end

wSize=(N-1)/2;

CVx=nan(len,wid);

for i=wSize+1:len-wSize
    idx=i-wSize:i+wSize;
    x_val=x(idx,:);
    CVx(i,:)=nanstd(x_val)./nanmean(x_val);
end

dCVx=diff(CVx);
dCVx=[zeros([1,size(CVx,2)]);dCVx];

end