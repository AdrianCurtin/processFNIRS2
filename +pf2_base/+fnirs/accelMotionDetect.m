function [mask, info] = accelMotionDetect(data, varargin)
% ACCELMOTIONDETECT Flag motion samples from an accelerometer aux signal
%
% Uses an independent accelerometer/IMU signal to detect movement, rather than
% inferring motion from the optical signal itself. The accelerometer is
% aligned to the fNIRS time base, reduced to a motion metric (vector-norm or
% jerk), and thresholded to produce a per-sample motion mask and a list of
% contiguous motion windows. The mask feeds accelerometer-informed correction
% (pf2_base.fnirs.accelRegress) and aux-conditioned trial rejection
% (pf2.data.extractBlocks 'RejectByAux').
%
% Syntax:
%   [mask, info] = pf2_base.fnirs.accelMotionDetect(data)
%   [mask, info] = pf2_base.fnirs.accelMotionDetect(data, 'Name', Value)
%
% Inputs:
%   data - fNIRS data struct with .time and an accelerometer signal in .Aux.
%
% Name-Value Parameters:
%   'Signal'    - Aux signal name (default: auto-detected ACCEL-type signal,
%                 falling back to 'accelerometer').
%   'Metric'    - Motion metric: 'norm' (default) or 'jerk'.
%   'Threshold' - Absolute threshold on the metric (default: [] -> adaptive).
%   'MADScale'  - Adaptive threshold = median + MADScale * MAD when Threshold
%                 is empty (default: 5).
%   'MinDuration' - Minimum duration (s) for a motion window to be reported
%                 (default: 0, i.e. report all).
%
% Outputs:
%   mask - [T x 1] logical, true where motion exceeds the threshold (on the
%          data.time grid).
%   info - Struct with: signal, metric, threshold, values [T x 1],
%          windows [W x 2] (start/end times, s), fractionFlagged.
%
% Notes:
%   - 'jerk' (derivative of the norm) emphasizes abrupt transients; 'norm'
%     captures sustained movement.
%   - Gravity is removed from the norm by accelFeatures so a still subject sits
%     near zero.
%
% Example:
%   [mask, info] = pf2_base.fnirs.accelMotionDetect(proc, 'Metric', 'jerk');
%   fprintf('%.1f%% of samples flagged\n', 100*info.fractionFlagged);
%
% See also: pf2.data.aux.accelFeatures, pf2.data.auxOnGrid,
%           pf2_base.fnirs.accelRegress, pf2.data.extractBlocks

p = inputParser;
p.addRequired('data', @isstruct);
p.addParameter('Signal', '', @(x) ischar(x) || isstring(x));
p.addParameter('Metric', 'norm', @(x) ismember(lower(char(x)), {'norm', 'jerk'}));
p.addParameter('Threshold', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('MADScale', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('MinDuration', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.parse(data, varargin{:});
metric = lower(char(p.Results.Metric));
thr = p.Results.Threshold;
madScale = p.Results.MADScale;
minDur = p.Results.MinDuration;

sigName = char(string(p.Results.Signal));
if isempty(sigName)
    sigName = pf2_base.fnirs.findAuxByType(data, 'ACCEL', 'accelerometer');
end

% Align the accelerometer onto the fNIRS grid and reduce to a motion metric
acc = pf2.data.auxOnGrid(data, sigName);
fs = data.fs;
if isempty(fs) || ~isfinite(fs)
    fs = 1 / median(diff(data.time));
end
feat = pf2.data.aux.accelFeatures(acc, fs);

switch metric
    case 'norm'
        vals = abs(feat.norm);
    case 'jerk'
        vals = feat.jerk;
end

% Threshold (absolute or adaptive via MAD)
if isempty(thr)
    med = median(vals, 'omitnan');
    madv = median(abs(vals - med), 'omitnan');
    thr = med + madScale * 1.4826 * madv;   % 1.4826 -> ~std under normality
end

mask = vals > thr;
mask(isnan(vals)) = false;

% Build contiguous motion windows, dropping those shorter than MinDuration
windows = maskToWindows(mask, data.time(:));
if minDur > 0 && ~isempty(windows)
    keep = (windows(:, 2) - windows(:, 1)) >= minDur;
    windows = windows(keep, :);
    % Rebuild mask from kept windows
    mask = false(size(mask));
    for w = 1:size(windows, 1)
        mask(data.time >= windows(w, 1) & data.time <= windows(w, 2)) = true;
    end
end

info = struct();
info.signal = sigName;
info.metric = metric;
info.threshold = thr;
info.values = vals;
info.windows = windows;
info.fractionFlagged = mean(mask);

end

%%_Subfunctions_________________________________________________________

function w = maskToWindows(mask, t)
% MASKTOWINDOWS Convert a logical mask to [start end] time windows
w = zeros(0, 2);
if ~any(mask)
    return;
end
d = diff([false; mask(:); false]);
starts = find(d == 1);
ends = find(d == -1) - 1;
w = [t(starts), t(ends)];
end
