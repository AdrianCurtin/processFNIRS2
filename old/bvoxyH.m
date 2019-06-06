function [Oxy, Deoxy, Total, cbsi]=bvoxyH(MES)

numCh=(size(MES,2)-2)/2;
% Hitachi layout is [Index w1ch1 w2ch1 w1ch2 w2ch2.... marker]
w700=MES(3:end,(2:2:numCh*2));
w830=MES(3:end,(3:2:(numCh*2+1)));

bStart=1; %default values from Hitachi system
bEnd=100;
sStart=bEnd+1;
len=size(w700,1)-sStart+1;

Baseline_700=mean(w700(bStart:bEnd,:));
Baseline_830=mean(w830(bStart:bEnd,:));

Baseline_700=ones(len,1)*Baseline_700;
Baseline_830=ones(len,1)*Baseline_830;

OD_700= real(-log10(w700(sStart:end,:)./Baseline_700));
OD_830= real(-log10(w830(sStart:end,:)./Baseline_830));

%saturation coefficients

coeff=[700.8	701.5	702.3	703	703.7   826.4	827.2   827.9	828.7;  %wavelength
    0.042060317	0.042175357	0.042295032	0.042399946	0.04250284 0.099762517	0.099762517 0.099762517	0.100145609; %HBO2 absorption
    0.180362957	0.178824951	0.177265013	0.175866636	0.174526153 0.077802499	0.077802499 0.077802499	0.077798873;]; %HB absorption

%Reverse Engineered values from Hitachi data
% Need to update for 826.4, 827.2

%Sourced Data from http://omlc.org/spectra/hemoglobin/summary.html
% Wavelength (nm), HbO, (cm/M), HbR(cm/M)

altCoeff=[690,276,2051.96; ...
        692, 277,2000.48; 
    694,	279,	1949.04; ...
    696,	282,	1897.56; ...
    698,	286,	1846.08; ...
    700,	290,	1794.28; ...
    702,	294,	1741; ...
    704,	298,	1687.76; ...
    706,	302.8,	1634.48; ...
    708,	308.4,	1583.52; ...
    710,	314,	1540.48; ...
    712,	319.6,	1497.4; ...
    714,	325.2,	1454.36; ...
    716,	332,	1411.32; ...
    718,	340,	1368.28; ...
    720,	348,	1325.88; ...
    820,	916,	693.76; ...
    822,	930.4,	693.6; ...
    824,	944.8,	693.48; ...
    826,	956.4,	693.32; ...
    828,	965.2,	693.2; ...
    830,	974,	693.04; ...
    832,	982.8,	692.92; ...
    834,	991.6,	692.76; ...
    836,    1001.2,	692.64; ...
    838,	1011.6,	692.48; ...
    840,	1022,	692.36;];



Oxy=zeros(len,numCh);
Deoxy=zeros(len,numCh);
for ch=1:numCh
    %Note w1~700nm w2~830nm
    w1=MES(2,ch*2);
    w2=MES(2,ch*2+1);
    e1w1=median(coeff(2,(coeff(1,:)==w1)));
    e1w2=median(coeff(2,(coeff(1,:)==w2)));
    e2w1=median(coeff(3,(coeff(1,:)==w1)));
    e2w2=median(coeff(3,(coeff(1,:)==w2)));
    
    eHBO_700=e1w1;
    eHBR_700=e2w1;
    eHBO_830=e1w2;
    eHBR_830=e2w2;
    

    L= 1; %pathlength factor

    Oxy(:,ch)=(OD_700(:,ch)*eHBR_830-OD_830(:,ch)*eHBR_700)/(eHBO_700*eHBR_830-eHBO_830*eHBR_700)/L;
    Deoxy(:,ch)=(OD_830(:,ch)*eHBO_700-OD_700(:,ch)*eHBO_830)/(eHBO_700*eHBR_830-eHBO_830*eHBR_700)/L;

end

%add index and marker information
Total=[MES(sStart+2:end,1)-bEnd (Oxy+Deoxy) MES(sStart+2:end,46)];
Oxy=[MES(sStart+2:end,1)-bEnd Oxy MES(sStart+2:end,46)];
Deoxy=[MES(sStart+2:end,1)-bEnd Deoxy MES(sStart+2:end,46)];
cbsi=calcCBSI(Oxy,Deoxy);

end

function cOxy=calcCBSI(oxy,deoxy)

	if(~isempty(oxy)&&size(oxy,1)==size(deoxy,1)&&size(oxy,2)==size(deoxy,2))

		alpha = nanstd(oxy)./nanstd(deoxy);
		oxy0=zeros(size(oxy));
		for i=1:length(alpha)
		   oxy0(:,i)=oxy(:,i)-alpha(i)*deoxy(:,i); 
		end
		%oxy0 = oxy - alpha .* deoxy;
		cOxy= oxy0 / 2;

	elseif(isempty(oxy))
		cOxy=[];
		warning('CBSI error: Oxy arrays and Deoxy arrays are empty');
	else
		error('Oxy and Deoxy size mismatch');
	end
end