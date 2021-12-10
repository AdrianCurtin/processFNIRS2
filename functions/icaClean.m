function [data1f,data2f,valica]=icaClean(data1,data2,use_fast_ica)
% data1: either raw730 or raw850 (regular wavelength light intensities)
% data2: raw805 (ambient channel)
% data1f: raw805 effect eliminated data1

%use_fast_ica selects fastica otherwise uses runica

%addpath('C:\Meltem\MeltemPC\fNIR\K9\RunICA')
%addpath('C:\Kurtulus PC\DOCUMENTS\Anesth\RunICA');

if(nargin<3)
   use_fast_ica=true; 
end

dum_ica=use_fast_ica+1; %1=runica, 2=fastica


if(size(data1,1)>size(data1,2))
   data1=data1';
   data2=data2';
   tranposeOutput=true;
else
   tranposeOutput=false; 
end

mixedsig=[data1; data2;];
M=mean(mixedsig');
mixedsign=mixedsig-mean(mixedsig')'*ones(1,size(mixedsig,2));


if dum_ica==1 %runica
    [Wt,sph] = runica(mixedsign,'verbose','off'); %,'weight',[1 1; 0 1]);
    W=Wt*sph;
    A=inv(W);
    icasig=(W*mixedsign);


elseif dum_ica==2 %fastica
	
	if(~exist('fastica'))
		pf2_base.toolboxes.setup_fastICA();
	end



    [whitesig, WM, DWM] = fastica(mixedsign, 'only', 'white');
    At=[];
    [icasig,At,Wt] = fastica(mixedsign,... %'whiteSig',whitesig,'dewhiteMat',DWM,'whiteMat',WM,...
        'initGuess',[1 1; 0 1],'verbose', 'off', 'displayMode', 'off');
    if ~isempty(At)&&size(Wt,1)==size(Wt,2)
        W=Wt; %*WM;
        A=inv(W);
    else
        [Wt,sph] = fastica(mixedsign,'verbose','off'); %,'weight',Winit);
        W=Wt*sph;
        
        if ~isempty(Wt)&&size(W,1)==size(W,2)
            A=inv(W);
            icasig=(W*mixedsign);
        else
           data1f=data1;
           data2f=data2;
           return;
        end
   end


end

CC11=corrcoef(mixedsign(1,:),icasig(1,:));
CC12=corrcoef(mixedsign(1,:),icasig(2,:));
CC21=corrcoef(mixedsign(2,:),icasig(1,:));
CC22=corrcoef(mixedsign(2,:),icasig(2,:));
[m,i]=max([(abs(CC12(1,2))+abs(CC21(1,2)))/abs(CC22(1,2)) (abs(CC11(1,2))+abs(CC22(1,2)))/abs(CC21(1,2)) ]');
%[m,i]=max([abs(CC22(1,2)) abs(CC21(1,2)) ]');
%[m,i]=max([(abs(CC12(1,2))+abs(CC21(1,2)))-abs(CC22(1,2)) (abs(CC11(1,2))+abs(CC22(1,2)))-abs(CC21(1,2)) ]');
%[m,i]=max([(abs(CC12(1,2))+abs(CC21(1,2))) (abs(CC11(1,2))+abs(CC22(1,2))) ]');
%[m,i]=max([(abs(CC12(1,2))-abs(CC22(1,2))) (abs(CC11(1,2))-abs(CC21(1,2))) ]');
if i==1
    i2=2;
elseif i==2
    i2=1;
end

CCerr=corrcoef(mixedsign(2,:),icasig(i,:));
CCsig=corrcoef(mixedsign(1,:),icasig(i2,:));
CCes=corrcoef(mixedsign(2,:),icasig(i2,:));
%valica=(abs(CCerr(1,2))+abs(CCsig(1,2)))/(abs(CCes(1,2)));
valica=(abs(CCes(1,2)));
%valica=(abs(CCerr(1,2))+abs(CCsig(1,2)))-(abs(CCes(1,2)));
%valica=(abs(CCerr(1,2)));
%val=(abs(CCerr(1,2)))/(abs(CCes(1,2)))
%val=(abs(CCsig(1,2)))/(abs(CCes(1,2)))
%pause;

vec=A(1,i)*icasig(i,:);
vec2=A(2,i2)*icasig(i2,:);

data1f=data1;
data1f(1,:)=data1(1,:)-(vec-vec(1));
data1f=data1f';

data2f=data2;
data2f(1,:)=data2(1,:)-(vec2-vec2(1));
data2f=data2f';

