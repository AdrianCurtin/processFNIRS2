function [y] = pf2_fnirs_MARA(x,fs,T,L,alpha)
% PF2_FNIRS_MARA Movement Artifact Removal Algorithm (MARA) for fNIRS
%
% Detects and removes motion artifacts from fNIRS signals using a moving
% standard deviation (MSD) approach with LOESS smoothing. Artifact segments
% are identified by thresholding the MSD, then reconstructed using local
% regression with weighted linear least squares and a 2nd degree polynomial.
%
% Based on v1.1 by Dr. Felix Scholkmann (BORL, University Hospital Zurich).
% v1.2a updated by Adrian Curtin to handle segments with no artifacts and
% segments that are entirely artifacts.
%
% Reference:
%   Scholkmann, F. et al. (2010). How to detect and reduce movement
%   artifacts in near-infrared imaging using moving standard deviation and
%   spline interpolation. Physiological Measurement, 31, 649-662.
%
% Syntax:
%   y = pf2_fnirs_MARA(x, fs, T, L, alpha)
%
% Inputs:
%   x     - Input signal matrix [T x C] where T=samples, C=channels
%   fs    - Sampling frequency [Hz]
%   T     - Threshold for artifact detection based on MSD amplitude
%   L     - Length of the moving window for MSD calculation (samples)
%   alpha - LOESS smoothing window length controlling high-frequency
%           preservation during artifact reconstruction
%
% Outputs:
%   y     - Denoised signal matrix [T x C], same size as input
%
% Example:
%   % 10 Hz data, threshold 0.0005, window 100, LOESS alpha 4
%   y = pf2_fnirs_MARA(rawData, 10, 0.0005, 100, 4);
%
%   % 50 Hz data with larger parameters
%   y = pf2_fnirs_MARA(rawData, 50, 25, 300, 50);
%
% See also: pf2_SMAR, pf2_MotionCorrectTDDR, pf2_fnirs_MARA2
%
% Original author: Dr. Felix Scholkmann, Felix.Scholkmann@usz.ch
% Version 1: 30 September 2008. v1.1: 29 May 2015. v1.2a: Adrian Curtin

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
    [y(:,ch)] = MAReconstruction(segments,x_n,fs)';



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



function [y] = MAReconstruction(segments,x_n,fs)

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
    if length(segmentsNEU{2,i-1})<=round(fs/3)
        a = mean(segmentsNEU{2,i-1}(1:end));
        if length(segmentsNEU{2,i})<=round(fs/3)
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>round(fs/3)) && (length(segmentsNEU{2,i})<round(fs*2)))
            b = mean(segmentsNEU{2,i}(1:round(fs/3)));
        else
            b = mean(segmentsNEU{2,i}(1:round(0.1*end)));
        end
    elseif ((length(segmentsNEU{2,i-1})>round(fs/3)) && (length(segmentsNEU{2,i-1})<round(fs*2)))
        a = mean(segmentsNEU{2,i-1}(end-round(fs/3):end));
        if length(segmentsNEU{2,i})<=round(fs/3)
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>round(fs/3)) && (length(segmentsNEU{2,i})<round(fs*2)))
            b = mean(segmentsNEU{2,i}(1:round(fs/3)));
        else
            b = mean(segmentsNEU{2,i}(1:round(0.1*end)));
        end
    else 
        a = mean(segmentsNEU{2,i-1}(end-round(0.1*end):end)); 
        if length(segmentsNEU{2,i})<=round(fs/3)
            b = mean(segmentsNEU{2,i}(1:end));
        elseif ((length(segmentsNEU{2,i})>round(fs/3)) && (length(segmentsNEU{2,i})<round(fs*2)))
            b = mean(segmentsNEU{2,i}(1:round(fs/3)));
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