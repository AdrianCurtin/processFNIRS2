function outfNIR = crop(fNIR, startTime, endTime)
% CROP Extract time segment from fNIRS data (no baseline correction)
%
% Simple wrapper around pf2.data.split for extracting a time window
% without baseline correction. For baseline correction, use split directly.
%
% Syntax:
%   cropped = pf2.data.crop(fNIR, startTime, endTime)
%   cropped = pf2.data.crop(fNIR, startTime)  % to end
%
% Inputs:
%   fNIR      - fNIRS data structure
%   startTime - Start time in seconds (absolute)
%   endTime   - End time in seconds (optional, defaults to end of data)
%
% Outputs:
%   outfNIR   - Cropped fNIRS structure with all fields truncated
%
% Example:
%   % Extract t=10 to t=60
%   segment = pf2.data.crop(data, 10, 60);
%
%   % Extract from t=100 to end
%   segment = pf2.data.crop(data, 100);
%
% See also: pf2.data.split, pf2.data.resample

if nargin < 3
    endTime = nan;  % split defaults to max(time)
end

outfNIR = pf2.data.split(fNIR, startTime, endTime);
end
