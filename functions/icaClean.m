function [data1f,data2f,chosen_method]=icaClean(data1,data2)
% data1: either raw730 or raw850 (regular wavelength light intensities)
% data2: raw805 (ambient channel)
% data1f: raw805 effect eliminated data1

%addpath('C:\Meltem\MeltemPC\fNIR\K9\RunICA')
%addpath('C:\Kurtulus PC\DOCUMENTS\Anesth\RunICA');

if(size(data1,1)>size(data1,2))
   data1=data1';
   data2=data2';
   tranposeOutput=true;
else
   tranposeOutput=false; 
end

chosen_method = 'None';
mixedsig=[data1; data2;];

M=mean(mixedsig');
mixedsign=mixedsig-mean(mixedsig')'*ones(1,size(mixedsig,2));

dum_ica=2; %1=runica, 2=fastica
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
    [A{1},W{1}] = fastica(mixedsign, 'only', 'pca');
    [sig{1},A_pca,W_pca] = runpca(mixedsign,2,0);
    [sig{2},A{2},W{2}] = fastica(mixedsign,... %'whiteSig',whitesig,'dewhiteMat',DWM,'whiteMat',WM,...
        'initGuess',[1 1; 0 1],'verbose', 'off', 'displayMode', 'off');
    for j = 1:numel(A)
        if ~isempty(A{j})&&size(W{j},1)==size(W{j},2)
            A{j}=inv(W{j});
        else
            [Wt,sph] = fastica(mixedsign,'verbose','off'); %,'weight',Winit);
            W{2}=Wt*sph;
            if ~isempty(Wt)&&size(W{2},1)==size(W{2},2)
                A{j}=inv(W{2});
                sig{2}=(W{2}*mixedsign);
            else
               data1f=data1;
               data2f=data2;
               return;
            end
        end
    end

end

%j = 2;
for j = 1:numel(sig)
    CC11=corrcoef(mixedsign(1,:),sig{j}(1,:));
    CC12=corrcoef(mixedsign(1,:),sig{j}(2,:));
    CC21=corrcoef(mixedsign(2,:),sig{j}(1,:));
    CC22=corrcoef(mixedsign(2,:),sig{j}(2,:));
    [~,i]=max([(abs(CC12(1,2))+abs(CC21(1,2)))/abs(CC22(1,2)) (abs(CC11(1,2))+abs(CC22(1,2)))/abs(CC21(1,2)) ]');
    k{j} = i;
    if i==1
        i2=2;
        k2{j} = 2;
    elseif i==2
        i2=1;
        k2{j} = 1;
    end
    CCerr=corrcoef(mixedsign(2,:),sig{j}(i,:));
    CCsig=corrcoef(mixedsign(1,:),sig{j}(i2,:));
    CCes=corrcoef(mixedsign(2,:),sig{j}(i2,:));
    valsig{j}=(abs(CCes(1,2)));
end

if valsig{2} < valsig{1}
    vec=A{2}(1,i)*sig{2}(k{2},:);
    vec2=A{2}(2,i2)*sig{2}(k2{2},:);

    data1f=data1;
    data1f(1,:)=data1(1,:)-(vec-vec(1));
    data1f=data1f';

    data2f=data2;
    data2f(1,:)=data2(1,:)-(vec2-vec2(1));
    data2f=data2f';
    chosen_method = 'ICA';
    figure
    %yyaxis left
    plot(data1); hold on;plot(data2); 
    %yyaxis right
    plot(data1f);plot(data2f);hold off
    legend ({'Orig Wav','Orig Amb','Corr Wav','Corr Amb'})
    title(chosen_method)
    pause;
    close gcf;
else
    vec=A_pca(1,i)*sig{1}(k{1},:); 
    vec2=A_pca(2,i2)*sig{1}(k2{1},:);

    data1f=data1;
    data1f(1,:)=data1(1,:)-(vec-vec(1));   
    data1f=data1f';

    data2f=data2;
    data2f(1,:)=data2(1,:)-(vec2-vec2(1));  
    data2f=data2f';
    chosen_method = 'PCA';
    figure
    %yyaxis left
    plot(data1); hold on;plot(data2);
    %yyaxis right 
    plot(data1f);plot(data2f);hold off
    legend ({'Orig Wav','Orig Amb','Corr Wav','Corr Amb'});
    title(chosen_method)
    pause;
    close gcf;
end
