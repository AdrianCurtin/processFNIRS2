function [x_recon] = pf2_sSMART(x,fs,chNum,tauArtifact,tauClean,minSeg,SGdegree)

ArtifactTime=3;

N=round(ArtifactTime/fs);

%offset=nanmean(abs(x(:)))*100;

[Xcorr, maskCV, MA_idx]=pf2_SMAR2(x,N,chNum,tauArtifact,tauClean,minSeg);
%Xcorr=Xcorr-offset;

numCh=size(x,2);

alpha=ceil(fs/3);
beta=round(fs*2);

xlen=size(x,1);

x_recon=Xcorr;

for ch=1:numCh
    
   MA_ch=MA_idx{ch};
   
   if(isempty(MA_ch))
       continue;  %if no motion artifacts, continue
   end
   
   MA_a=[];
  
   for i=1:size(MA_ch,1)
       if(MA_ch(i,1)==1)
          continue;  %if first point is artifact, continue
       end
       
       MA_seg=x([MA_ch(i,1):MA_ch(i,2)],ch);
       MA_seg_smooth = smooth(MA_seg,4,'loess');%,'sgolay',SGdegree);
       MA_seg_cleaned = MA_seg-interpft(MA_seg_smooth,length(MA_seg_smooth));
       
       if(i==1)
            cleanSegIdx=[1,MA_ch(i,1)-1];
       else
           cleanSegIdx=[MA_ch(i-1,2)+1,MA_ch(i,1)-1];
       end
       
       lenClean=cleanSegIdx(2)-cleanSegIdx(1);
       lenMA=MA_ch(i,2)-MA_ch(i,1);
       
       cleanSeg=x((cleanSegIdx(1):cleanSegIdx(2)),ch);
       
       if(~isempty(MA_a))
           if(lenMA<=beta)
               b=nanmean(cleanSeg(1:min(alpha,lenClean)));
           else
               b=nanmean(cleanSeg(1:ceil(0.1*lenClean)));
           end
           cleanSeg=cleanSeg-(b-MA_a);
           
           x_recon([cleanSegIdx(1):cleanSegIdx(2)],ch)=cleanSeg;
       else
           x_recon([cleanSegIdx(1):cleanSegIdx(2)],ch)=cleanSeg;
       end
       
       if(lenClean<=beta)
           a=nanmean(cleanSeg(lenClean-min(alpha,lenClean))); %grab last good points 
       elseif(lenClean>beta)
           a=nanmean(cleanSeg(lenClean-ceil(0.1*lenClean):lenClean));
       end
       
       if(isnan(a))
           z=1;
       end
       
       if(lenMA<=beta)
           b=nanmean(MA_seg_cleaned(1:min(alpha,lenMA)));
           MA_seg_cleaned=MA_seg_cleaned-(b-a);
           MA_a=nanmean(MA_seg_cleaned(end-min(alpha,lenMA):end)); %use to adjust next clean segment
       else
           b=nanmean(MA_seg_cleaned(1:round(0.1*lenMA)));
           MA_seg_cleaned=MA_seg_cleaned-(b-a);
           MA_a=nanmean(MA_seg_cleaned(lenMA-ceil(0.1*lenMA):lenMA));
       end
       
       if(isnan(b)||isnan(a)||isnan(MA_a))
           z=1;
       end
           
%        figure(4);
%        subplot(1,2,1);
%        plot(cleanSeg);
%        subplot(1,2,2);
%        plot(MA_seg_cleaned);
%        
          
       x_recon(MA_ch(i,1):MA_ch(i,2),ch)=MA_seg_cleaned;
       
       
       
   end
   
   if(MA_ch(end,2)<xlen&&~isempty(MA_a))
       cleanSegIdx=[MA_ch(end,2)+1,xlen];
       cleanSeg=x((cleanSegIdx(1):cleanSegIdx(2)),ch);
       if(lenMA<=beta)
           b=nanmean(cleanSeg(1:min(alpha,lenMA)));
       else
           b=nanmean(cleanSeg(1:round(0.1*end)));
       end
       cleanSeg=cleanSeg-(b-MA_a);

       x_recon((cleanSegIdx(1):cleanSegIdx(2)),ch)=cleanSeg;
   end
    
end