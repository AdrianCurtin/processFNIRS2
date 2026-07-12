function fs = samplingFreq(data, nirs)
% SAMPLINGFREQ Best available sampling frequency in Hz
%
% Prefers data.fs; falls back to the median inverse time-step of the SNIRF
% time vector; returns NaN if neither is usable.
%
% Inputs:
%   data - fNIRS data struct
%   nirs - SNIRF /nirs structure (with .data.time)
%
% Outputs:
%   fs - sampling frequency in Hz (NaN if unknown)
%
% Example:
%   fs = pf2_base.bids.samplingFreq(data, snirf.nirs);
%
% See also: pf2.export.asBIDS

fs = NaN;
if isstruct(data) && isfield(data, 'fs') && ~isempty(data.fs) && data.fs > 0
    fs = data.fs;
    return;
end
try
    t = nirs.data.time(:);
    if numel(t) > 1
        dt = median(diff(t));
        if dt > 0
            fs = 1 / dt;
        end
    end
catch
    fs = NaN;
end
end
