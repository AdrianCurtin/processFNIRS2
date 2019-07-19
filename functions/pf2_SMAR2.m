function [Xcorr, maskCV, MA_idx]=pf2_SMAR2(x,N,chNum,tauArtifact,tauClean,minSeg)
% Implementation of Sliding Motion Artificat Rejection algorithim from Ayaz, 2010
% Updated with expansion to remove artifacts from start

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

[CVx]=calcLocalCV(x,N);
aCVx=abs(CVx);
CVx_median=nanmedian(aCVx);
lowerStd=nanstd(aCVx(aCVx<2*CVx_median));

CVthreshold=CVx_median+tauArtifact*lowerStd;%CVx_median;
CVthresholdClean=CVx_median+tauClean*lowerStd;%CVx_median;%+tauUpMult*CVx_median/2;


aCVxm=[zeros(1,size(x,2));aCVx;zeros(1,size(x,2))];
maskCV=aCVxm>CVthreshold|isnan(aCVxm);%|aCVd>CVdthreshold;
maskCVclean=aCVxm>CVthresholdClean|isnan(aCVxm);%|aCVd>CVdthreshold;

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
function [CVx] = calcLocalCV(x,N)
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




end