function [y] = pf2_fnirs_MARA(x,fs,T,L,alpha)
%__________________________________________________________________________
% Function to apply the movement artifact removal algorithm (MARA)
% presented in Scholkmann et al. (2010). How to detect and reduce movement
% artifacts in near-infrared imaging using moving standard deviation and 
% spline interpolation. Physiological Measurement, 31, 649-662.

% This version (v.1.1) is slightly different to the original approach
% presented in the paper: Instead of using the spline
% interpolation this version implements a smoothing based on local 
% regression using weighted linear least squares and a 2nd degree 
% polynomial model. This imrproves the reconstruction of the signal parts
% that are affectes by the artifacts.

% This version (v.1.2a) is updated by Adrian Curtin to allow segments which
% have no artifacts to pass through and segments which are entirely artifacts to pass through, albeit
% rejected

%
% INPUT
% x:        Input signal
% fs:       Sampling frequency [Hz]
% L:        Length of the moving-window to calculate the moving standard
%           deviation (MSD)
% T:        Threshold for artifact detection
% k:        half of the centered window length (w = 1 + 2*k)
% alpha:    Parameter that defined how much high-frequency information should 
%           be preserved by the removal of the artifact (i.e., it corresponds 
%           to the length of the LOESS smoothing window)

% OUTPUT:
% y:        Denoised signal

% Example 1: [y] = spm_fnirs_MARA(x1,10,0.0005,100,4);
% (Here, the sampling frequency is 10 Hz, the threshold is 0.0005, the MSD window
% length is 100 and 4 refers to the window for the LOESS smoothing.

% Example 2: [y] = MARA_NIRSSPM(x6,50,25,300,50);
% (Here, the sampling frequency is 50 Hz, the threshold is 25, the MSD window
% length is 300 and 100 refers to the window for the LOESS smoothing.

% NOTES:
% (1) If the first sample is already a artifact, the algorithms produces
% an error. This has to be fixed for the next release.
% (2) If the treshold value T is below or above the range of the signal,
% the algorithms stops and an error message is displayed.

%__________________________________________________________________________
% Dr. Felix Scholkmann, Biomedical Optics Research Laboratory (BORL), 
% Universtiy Hospital Zurich, University of Zurich, Zurich, Switzerland
% Felix.Scholkmann@usz.ch
% Version 1: 30 September 2008. This version: 29 May 2015
%_________________________________________________________________________

%_________________________________________________________________________
%%

numCh=size(x,2);
y=nan(size(x));
for ch=1:numCh
    curX=x(:,ch);
    % % % close all
    % % % tic
    % (1) Artefact detecion

    k = round(L/2);
    [A_Idx,s2_1,s2_2] = MADetection(curX,k,T,fs,alpha);

    % (2) Segmentation
    [segments] = MASegmentation(curX,A_Idx);

    % (3) Artifact removal
    [x_n] = MARemoval(segments,alpha);

    % (4) Signal reconstruction
    [y(:,ch)] = MAReconstruction(segments,x_n)';


    %__________________________________________________________________________
    a = size(x_n);
    for i = 1:a(2);
        s(i) = length(x_n{:,i});
    end
    S = sum(s); l = length(x);
    ASR = (S/l)*100; SAR = 100-ASR;

    % % % % Plot the results
    % % % subplot(313);
    % % % min1 = min(x);min2 = min(y); minG = min([min1,min2]);
    % % % max1 = max(x);max2 = max(y); maxG = max([max1,max2]);
    % % % ylim([minG,maxG]); hold on
    % % % 
    % % % vline([A_Idx]/(fs*60),'-y');
    % % % plot([1:length(x)]/(fs*60),x,'k'); hold on
    % % % plot([1:length(y)]/(fs*60), y,'color',[0.2,0.4,1]); axis tight;
    % % % title (['Artifact-to-signal ratio (ASR): ' num2str(ASR) '%   |  Signal-to-artifact ratio (SAR): ' num2str(SAR) '%'] ,'FontSize', 14);
    % % % ylabel ('Intensity','FontSize', 12)
    % % % xlabel ('Time [min]','FontSize', 12)
    % % % legend('Input signal','Reconstructed signal');
    % % % box on
    % % % 
    % % % disp(['---->  Duration: ' num2str(toc) ' s.']);
    
end




%%_Subfunctions____________________________________________________________

function [A_Idx,s2_1,s2_2] = MADetection(x,L,T,fs,alpha);

% INPUT
% x:        Input signal
% L:        Length of the moving-window to calculate the moving standard
%           deviation (MSD)
% T:        Threshold for artifact detection
% fs:       Sampling frequency [Hz]
% k:        half of the centered window length (w = 1 + 2*k)
% alpha:    Parameter that defined how much high-frequency information should 
%           be preserved by the removal of the artifact (i.e., it corresponds 
%           to the length of the LOESS smoothing window)

% OUTPUT
% A_Idx:	Vector containing indices with respect to the begining and
%           the end of the artefacs
% s2_1:     MSD
% s2_2:     Thresholded MSD
%__________________________________________________________________________

% (1) Calculation of the MSD
[s2] = MovStd(x,L); s2_1 = s2;

if nanmax(s2) < T
    disp(['--->   MARA T threshold ' num2str(T) ' is potentially too large, no artifacts detected. std for data is between ' num2str(min(s2)) ' and ' num2str(max(s2))])
    %msgbox(['--->   Please choose a propper T value! T must be < ' num2str(max(s2))], 'Error','error');
end

if nanmin(s2) > T
    disp(['--->   MARA T threshold ' num2str(T) ' is potentially too small, all data is seen as an artifact! std for data is between ' num2str(min(s2)) ' and ' num2str(max(s2))])
    %msgbox(['--->   Please choose a propper T value! T must be > ' num2str(min(s2))], 'Error','error');
end

% % % % (2) Plot the MSD time series
% % % scrsz = get(0,'ScreenSize');
% % % figure('Position',[0 0 scrsz(3) scrsz(4)]);
% % % set(gcf, 'color', 'w')
% % % set(gcf, 'renderer', 'painters');
% % % 
% % % subplot(311); plot([1:length(x)]/(fs*60),x,'k'); axis tight
% % % title ('Input signal', 'FontSize', 14);
% % % ylabel ('Intensity','FontSize', 12)
% % % xlabel ('Time [min]','FontSize', 12)
% % % box on
% % % 
% % % subplot(312);
% % % min1 = min(s2);
% % % max1 = max(s2);
% % % ylim([min1,max1]); hold on
% % % plot([1:length(s2)]/(fs*60),s2,'k')
% % % axis tight
% % % hold on

% (3) Threshholding the MSD time series
s2_2 = (abs(s2_1)>T).*s2_1;

% (4) Detection of the begining indices and end indices of the artefact
q1=zeros(size(s2_2));
for i = 1:length(s2_2)
    if i < length(s2_2)   
        if ((s2_2(i) == 0) & ((s2_2(i+1)-s2_2(i)) > 0))
           q1(i) = i;
        elseif ((s2_2(i+1) == 0) & ((s2_2(i)-s2_2(i+1)) > 0))
           q1(i) = i;
        end
    end
end

d = find (q1>0);  
A_Idx = q1(d);


% % % hline([T],'r-','Threshold (T)')
% % % hold on
% % % vline([A_Idx]/(fs*60),'-y')
% % % plot([1:length(s2)]/(fs*60),s2,'k')
% % % title (['Moving standard deviation (MSD). MARA paramters: L = ' num2str(L) ', T = ' num2str(T) ', \alpha = ' num2str(alpha)],'FontSize', 14);
% % % ylabel ('MSD','FontSize', 12)
% % % xlabel ('Time [min]','FontSize', 12)
% % % box on
%__________________________________________________________________________



function [y] = MAReconstruction(segments,x_n)

% INPUT
% segments:	Array containing the segments of x
% x_n:      Array containing the denoised segments

% OUTPUT
% y:        Array containing the denoised data
%__________________________________________________________________________

%x_n;
segmentsNEU = segments;
for i = 2:2:size(segments,2)
    segmentsNEU{2,i} = x_n{i};          
end

for i = 2:size(segmentsNEU,2)
    if length(segmentsNEU{2,i-1})<=30
        a = mean(segmentsNEU{2,i-1}(1:end));
        if length(segmentsNEU{2,i})<=30
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>30) && (length(segmentsNEU{2,i})<200))
            b = mean(segmentsNEU{2,i}(1:30));
        else
            b = mean(segmentsNEU{2,i}(1:round(0.1*end)));
        end
    elseif ((length(segmentsNEU{2,i-1})>30) && (length(segmentsNEU{2,i-1})<200))
        a = mean(segmentsNEU{2,i-1}(end-30:end));
        if length(segmentsNEU{2,i})<=30
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>30) && (length(segmentsNEU{2,i})<200))
            b = mean(segmentsNEU{2,i}(1:30));
        else
            b = mean(segmentsNEU{2,i}(1:round(0.1*end)));
        end
    else 
        a = mean(segmentsNEU{2,i-1}(end-round(0.1*end):end)); 
        if length(segmentsNEU{2,i})<=30
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>30) && (length(segmentsNEU{2,i})<200))
            b = mean(segmentsNEU{2,i}(1:30));
        else
            b = mean(segmentsNEU{2,i}(1:round(0.1*end)));
        end       
    end
    D = b-a;
    c = segmentsNEU{2,i}-(D);   
    segmentsNEU{2,i} = c; 
end  

        
y = []; 
for i = 1:size(segmentsNEU,2)
    y = [y; segmentsNEU{2,i}];
end
%__________________________________________________________________________



function [x_n] = MARemoval(segments,alpha)

% INPUT
% segments:	Array containing the segments of x
% alpha:    Parameter that defined how much high-frequency information should 
%           be preserved by the removal of the artifact (i.e., it corresponds 
%           to the length of the LOESS smoothing window)

% OUTPUT
% x_n:      Array containing the denoised segments
%__________________________________________________________________________

if(size(segments,2)==1) % If only 1 segment, return that
    x_n(1) = {segments{2,1}};
end

for i = 2:2:size(segments,2)    
   if length(segments{2,i}) > 4
        S = smooth(segments{2,i},alpha,'loess');
        x_S(i) = {S};
        x_s = segments{2,i}-interpft(x_S{i},length(segments{2,i}));
        x_n(i) = {x_s};
    else
        x_n(i) = {segments{2,i}};
    end
end 
%__________________________________________________________________________



function [segments] = MASegmentation(x,A_Idx)

% INPUT
% segments:	Data (one dimensional vector)
% A_Idx:    Vector with indices with respect to the begining and
%           the end of the artefacs

% OUTPUT
% segments: String containing the segments of x
%__________________________________________________________________________

% (1) Add 0 to the begining of the vector with segmentation indices
A_Idx = A_Idx(end:-1:1);
A_Idx(length(A_Idx)+1) = 0;
A_Idx = A_Idx(end:-1:1);

% (2) Segmentation
for i = 1:length(A_Idx)-1
    str = num2str(i);
    seg = 'segment_';
    segments(i).number = strcat(seg,str);
    segments(i).data = x(A_Idx(i)+1:A_Idx(i+1));
end

str = num2str(length(A_Idx));
seg = 'segment_';
segments(length(A_Idx)).number = strcat(seg,str);
segments(length(A_Idx)).data = x(A_Idx(length(A_Idx))+1:end);

segments.number;
segments.data;
segments = struct2cell(segments');




%%_Subsubfunctions_________________________________________________________

function [y1] = MovStd(x,k)
%__________________________________________________________________________
% Function to calculate the moving standard deviation.
%
% INPUT
% x:    input signal
% k:    half of the centered window length (w = 1 + 2*k)
%__________________________________________________________________________


% (1) Calculate the MSD
y1 = NaN(length(x),1); % preallocate y1
for i = k+1:length(x)-k
    y1(i) = std(x(i-k:i+k));
end
%__________________________________________________________________________