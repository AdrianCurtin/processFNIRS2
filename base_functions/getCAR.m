function CARout=getCAR(x,local,medfiltN,mdebug)
    % Use for array of x

	if(nargin<2)
		local=false; %Local setting currently only works for 2x8 sensor
	end

    if(nargin<3)
        medFiltN=10;
    end

    if(nargin<4)
        debug=false;
    end
    %car=zeros(size(FNIR.time));
    
    numCh=size(x,2);
    

    if(debug)
        q1=diff(x);
        for ch=1:numCh
            pf2_base.external.medfilt1(q1(:,ch));
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
        
        basicCAR=pf2_base.external.medfilt1(basicCAR,medFiltN);
        
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