function [HbO, HbR, Total, HbDiff,CBSI,channels,time,units,DPF_factor]=bvoxy(varargin)
% Blood Volume and Oxygenation calculation.
% Part of ProcessFNIRS2
% Uses channel information to calculate hemoglobin changes from changes in
% light intensity
%
% bvoxy(data,ChannelNumbers,Wavelengths,baselineSamples,DPF,DeviceCoefs,'isOD',true);

% Will return as fNIR struct if only one output is given

p = inputParser;
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
validScalarNum = @(x) isnumeric(x) && isscalar(x);
validDataInput = @(x) (isnumeric(x) && ismatrix(x));

addRequired(p,'data',validDataInput);  %Raw data containing light intensity or optical density
addRequired(p,'channels',validDataInput); %Channel numbers corresponding to each column in data
addRequired(p,'wavelengths',validDataInput); %wavelengths for each column in data
addRequired(p,'distanceSrcDet',validDataInput); %source detector distance for each column in channels (in cm)
addOptional(p,'baselineSamples',[1:50],validDataInput); %array of samples to get from baseline (in seconds
addOptional(p,'age',25,validScalarPosNum); %Age to calculate DPF from (in years)
addParameter(p,'DiffPathlengthFactor',[],validScalarNum); % Force same fixed path length to use (typical is 5.93)
addParameter(p,'NoPathlength',false,@islogical); % Force same fixed path length to use (typical is 5.93)
addOptional(p,'coefs',[],validDataInput); %If empty calculate instead of using mfg coefficients
addOptional(p,'isOD',false,@islogical); %Indicates that data is in light intensity instead of OD
%addOptional(p,'dirtyBaseline',false,@islogical); %get first non-NA value to use as baseline if nothing is readily apparent;

parse(p,varargin{:});

data=p.Results.data; %in units of light intensity
channels=p.Results.channels;
wavelengths=p.Results.wavelengths; %in nm
sd_distance=p.Results.distanceSrcDet; %in cm
subject_age=p.Results.age;
baselineSamples=p.Results.baselineSamples;
DiffPathlengthFactor=p.Results.DiffPathlengthFactor; %in DPF 
coefs=p.Results.coefs;
isOD=p.Results.isOD;
NoPathlength=p.Results.NoPathlength;


if(length(baselineSamples)==1)
    baselineSamples=1:baselineSamples;
end

validChannels=(channels>0.&wavelengths>0);
rawData=data(:,validChannels);      %non-timechannels have >0 channel numbers, markers and others have - indexes
wavelengths=wavelengths(validChannels); %dark channels have 0 wavelength
timeIndex=find(channels==0);  % Added to left at end if exists
len=size(data,1);
mrkIndex=find(channels<0); %Added to right at end if exists
channels=channels(validChannels);

time=data(:,timeIndex);

uOpt=sort(unique(channels));
numOpt=length(uOpt);

numWv=sum(channels==channels(1));

rawArray=zeros(len,numOpt,numWv);
wvArray=zeros(numOpt,numWv);

if(numWv>2)
    error('MultiWavelengths are not supported yet');
end

wv700=wavelengths<805; %Split so wavelength under isobestic point is first column

%Should be fast but only supports two wavelengths
wvArray(channels(wv700),1)=wavelengths(wv700);
wvArray(channels(~wv700),2)=wavelengths(~wv700);

chArray(channels(wv700),1)=find(wv700);
chArray(channels(~wv700),2)=find(~wv700);


[wvArray,ind]=sort(wvArray,2); %Sort so left array is lower

indReshape=ind';



%Use new sort order

chArrIdx=repmat([0:numWv:((numOpt*numWv)-1)]',1,numWv)';
chArrIdx=chArrIdx(:);
chOrigInd=repmat(1:numWv,numOpt,1);

chArrIdxSorted=chArrIdx+indReshape(:);
chArray(:)=chArray(chArrIdxSorted);

for i=1:numWv
    rawArray(:,:,i)=rawData(:,chArray(:,i));
end


[eHbRArray,eHbOArray]=estimateAbsorb(wvArray,coefs);




%bStart=1; %default values from Hitachi system
%bEnd=100;
%sStart=bEnd+1;
%len=size(w700,1)-sStart+1;

Baseline=nanmean(rawArray(baselineSamples,:,:),1);
Baseline=repmat(Baseline,[len,1,1]);

eHbOArray=repmat(reshape(eHbOArray,[1,numOpt,numWv]),[len,1,1]);
eHbRArray=repmat(reshape(eHbRArray,[1,numOpt,numWv]),[len,1,1]);

if(~isOD)
    OD=real(-log10(rawArray./Baseline));
else
    OD=real(rawArray-Baseline);
end


HbO=zeros(len,numOpt);
HbR=zeros(len,numOpt);

if(numWv~=2)
    error('Sorry I don''t support this yet');
end

%Note w1~700nm w2~830nm
%While these frequencies are listed here they are generic 700 is
%effectively wv1 and 830 is effectively wv2
%Channels are sorted by wavelength so <805 should be first and >805
%should be second

od700=OD(:,:,1);
od830=OD(:,:,2);

if(NoPathlength)
    %Convert to mM*mm from uM*cm
    
    L_700=100;
    L_830=100;
    
    DPF_factor=[nan,nan];
    
    units='mM*mm';

elseif(~isempty(DiffPathlengthFactor)&&DiffPathlengthFactor>0)
    L_700=sd_distance*DiffPathlengthFactor; %0.015 = 2.5cm*5.92 /1000
    L_830=sd_distance*DiffPathlengthFactor;
    
    DPF_factor=DiffPathlengthFactor;
    
    units='uM';
else
    % Calculates DPF accurding to Felix Scholkmann, Martin Wolf, "General equation for the differential pathlength factor of the frontal human head depending on wavelength and age," J. Biomed. Opt. 18(10) 105004 (11 October 2013)
    % These calculations are valid for the frontal cortex, but until a
    % better solution is available for other corticies they will
    % temporarliy be used everywhere
    
    
    alpha=223.3;
    beta=0.05624;
    gamma=0.8493;
    delta=-5.723e-7;
    eta=0.001245;
    sigma=-0.9025;
    calcDPF=@(lambda,Age) alpha + beta*Age.^gamma+delta*lambda.^3+eta.*lambda.^2+sigma*lambda;
    
    DPF_700=calcDPF(wvArray(:,1),subject_age);
    DPF_830=calcDPF(wvArray(:,2),subject_age);
    
    
    L_700=sd_distance.*DPF_700; %0.015 = 2.5cm*5.92 /1000
    L_830=sd_distance.*DPF_830;
    
    DPF_factor=unique([DPF_700,DPF_830]);
    
    units='uM';
end

eHBO_700=eHbOArray(:,:,1);
eHBR_700=eHbRArray(:,:,1);
eHBO_830=eHbOArray(:,:,2);
eHBR_830=eHbRArray(:,:,2);

% eHBO_700=reshape(eHBO_700,[numOpt,len]);
% eHBR_700=reshape(eHBR_700,[numOpt,len]);
% eHBO_830=reshape(eHBO_830,[numOpt,len]);
% eHBR_830=reshape(eHBR_830,[numOpt,len]);
% 
% od700=reshape(od700,[numOpt,len]);
% od830=reshape(od830,[numOpt,len]);

L_700=repmat(L_700',len,1);
L_830=repmat(L_830',len,1);

HbO=(eHBR_830.*(od700./L_700)-eHBR_700.*(od830./L_830))./(eHBO_700.*eHBR_830-eHBO_830.*eHBR_700);
HbR=(eHBO_700.*(od830./L_830)-eHBO_830.*(od700./L_700))./(eHBO_700.*eHBR_830-eHBO_830.*eHBR_700);

%HbO= reshape(HbO,[numOpt,len])';
%HbR= reshape(HbR,[numOpt,len])';

%Oxy(:,ch)=(OD(1,:,ch)*eHBR_830-OD_830(:,ch)*eHBR_700)/(eHBO_700*eHBR_830-eHBO_830*eHBR_700)/DiffPathlengthFactor;
%Deoxy(:,ch)=(OD_830(:,ch)*eHBO_700-OD_700(:,ch)*eHBO_830)/(eHBO_700*eHBR_830-eHBO_830*eHBR_700)/DiffPathlengthFactor;


%add index and marker information

Total=[(HbO+HbR), data(:,mrkIndex)];
HbDiff=[(HbO-HbR), data(:,mrkIndex)];
CBSI=[calcCBSI(HbO,HbR), data(:,mrkIndex)];
HbO=[(HbO), data(:,mrkIndex)];
HbR=[(HbR), data(:,mrkIndex)];

channels=[uOpt,(mrkIndex*0-1)];

if(nargout==1) % if one output argument, return all as fNIR struct
	fNIR.HbO=HbO;
	fNIR.HbR=HbR;
	fNIR.HbDiff=HbDiff;
	fNIR.CBSI=CBSI;
	fNIR.HbTotal=Total;
	fNIR.time=time;
	fNIR.channels=channels;
	fNIR.DPF_factor=DPF_factor;
	fNIR.units=units;
	
	HbO=fNIR; %return only the struct
	return;
end

end

function [eHbR,eHbO]=estimateAbsorb(lambda,coefs)
% coeficients should be in 1/(cm*microMolar)
% but are output in millimolar (1/(cm*uM))

%Sourced Data from http://omlc.org/spectra/hemoglobin/summary.html
% molar extinction coefficient
% Wavelength (nm), HbO, (1/(cm*M)), HbR(1/(cm*M))
    altCoeff=[650,	368,	3750.12; ...
    652,	356.8,	3642.64; ...
    654,	345.6,	3535.16; ...
    656,	335.2,	3427.68; ...
    658,	325.6,	3320.2; ...
    660,	319.6,	3226.56; ...
    662,	314,	3140.28; ...
    664,	308.4,	3053.96; ...
    666,	302.8,	2967.68; ...
    668,	298,	2881.4; ...
    670,	294,	2795.12; ...
    672,	290,	2708.84; ...
    674,	285.6,	2627.64; ...
    676,	282,	2554.4; ...
    678,	279.2,	2481.16; ...
    680,	277.6,	2407.92; ...
    682,	276,	2334.68; ...
    684,	274.4,	2261.48; ...
    686,	272.8,	2188.24; ...
    688,	274.4,	2115; ...
    690,	276,	2051.96; ...
    692,	277.6,	2000.48; ...
    694,	279.2,	1949.04; ...
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
    722,	356,	1285.16; ...
    724,	364,	1244.44; ...
    726,	372.4,	1203.68; ...
    728,	381.2,	1152.8; ...
    730,	390,	1102.2; ...
    732,	398.8,	1102.2; ...
    734,	407.6,	1102.2; ...
    736,	418.8,	1101.76; ...
    738,	432.4,	1100.48; ...
    740,	446,	1115.88; ...
    742,	459.6,	1161.64; ...
    744,	473.2,	1207.4; ...
    746,	487.6,	1266.04; ...
    748,	502.8,	1333.24; ...
    750,	518,	1405.24; ...
    752,	533.2,	1515.32; ...
    754,	548.4,	1541.76; ...
    756,	562,	1560.48; ...
    758,	574,	1560.48; ...
    760,	586,	1548.52; ...
    762,	598,	1508.44; ...
    764,	610,	1459.56; ...
    766,	622.8,	1410.52; ...
    768,	636.4,	1361.32; ...
    770,	650,	1311.88; ...
    772,	663.6,	1262.44; ...
    774,	677.2,	1213; ...
    776,	689.2,	1163.56; ...
    778,	699.6,	1114.8; ...
    780,	710,	1075.44; ...
    782,	720.4,	1036.08; ...
    784,	730.8,	996.72; ...
    786,	740,	957.36; ...
    788,	748,	921.8; ...
    790,	756,	890.8; ...
    792,	764,	859.8; ...
    794,	772,	828.8; ...
    796,	786.4,	802.96; ...
    798,	807.2,	782.36; ...
    800,	816,	761.72; ...
    802,	828,	743.84; ...
    804,	836,	737.08; ...
    806,	844,	730.28; ...
    808,	856,	723.52; ...
    810,	864,	717.08; ...
    812,	872,	711.84; ...
    814,	880,	706.6; ...
    816,	887.2,	701.32; ...
    818,	901.6,	696.08; ...
    820,	916,	693.76; ...
    822,	930.4,	693.6; ...
    824,	944.8,	693.48; ...
    826,	956.4,	693.32; ...
    828,	965.2,	693.2; ...
    830,	974,	693.04; ...
    832,	982.8,	692.92; ...
    834,	991.6,	692.76; ...
    836,	1001.2,	692.64; ...
    838,	1011.6,	692.48; ...
    840,	1022,	692.36; ...
    842,	1032.4,	692.2; ...
    844,	1042.8,	691.96; ...
    846,	1050,	691.76; ...
    848,	1054,	691.52; ...
    850,	1058,	691.32; ...
    852,	1062,	691.08; ...
    854,	1066,	690.88; ...
    856,	1072.8,	690.64; ...
    858,	1082.4,	692.44; ...
    860,	1092,	694.32; ...
    862,	1101.6,	696.2; ...
    864,	1111.2,	698.04; ...
    866,	1118.4,	699.92; ...
    868,	1123.2,	701.8; ...
    870,	1128,	705.84; ...
    872,	1132.8,	709.96; ...
    874,	1137.6,	714.08; ...
    876,	1142.8,	718.2; ...
    878,	1148.4,	722.32; ...
    880,	1154,	726.44; ...
    882,	1159.6,	729.84; ...
    884,	1165.2,	733.2; ...
    886,	1170,	736.6; ...
    888,	1174,	739.96; ...
    890,	1178,	743.6; ...
    892,	1182,	747.24; ...
    894,	1186,	750.88; ...
    896,	1190,	754.52; ...
    898,	1194,	758.16; ...
    900,	1198,	761.84];

altCoeff(:,[2,3])=altCoeff(:,[2,3])*1e-3; % convert from eta to absorption coefficint mu_a 
    %by multiplying by molar concentration and 2.303 (ln(10)) and convert to
    %micromolar (mM)
    
    


if(nargin<2||isempty(coefs)) % AutoCalulate With
    coefs=altCoeff;
end
     
%fNIR Devices saturation coefficietns
      coeff_fd=[730,0.390,1.1022;...
          805, 0.836, 0.73708;...
          850, 1.058,0.69132;];
      %eHbR_730=1.1022; % [1/(mMol*cm)
      %eHBO_730=0.390;      %  
      %eHBR_805=0.73708;      %   saturation coefficients
      %eHBO_805=0.836;      %
      %eHBR_850=0.69132;      %
      %eHBO_850=1.058;      %

%Hitachi saturation coefficients

coeffHitachi=[700.8	701.5	702.3	703	703.7   826.4	827.2   827.9	828.7;  %wavelength
    0.42060317	0.42175357	0.42295032	0.42399946	0.4250284 0.99762517	0.99762517 0.99762517	1.00145609; %HBO2 absorption
    1.80362957	1.78824951	1.77265013	1.75866636	1.74526153 0.77802499	0.77802499 0.77802499	0.77798873;]; %HB absorption

%Reverse Engineered values from Hitachi data
% Need to update for 826.4, 827.2

   
eHbO=interp1(coefs(:,1),coefs(:,2),lambda)./1000;  %convert from 1/mM to 1/uM
eHbR=interp1(coefs(:,1),coefs(:,3),lambda)./1000;   %convert from 1/mM to 1/uM

end

% This script is available for download to academic researchers for
% internal research use only. All commercial use requires a license 
% from Stanford's OTL. Please contact imelda.oropeza@stanford.edu for 
% more details.
%
% -------------------------------------------------------------------
%
% assume the original signal is oxy and deoxy, and the corrected signal is
% oxy0.
%
% Xu Cui
% Stanford University
% 2009/09/28

% offline version (post-experiment data analysis)

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