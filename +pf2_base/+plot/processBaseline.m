function [fNIR, baselineWindow] = processBaseline(fNIR, baseline, bioMlist)
% PROCESSBASELINE Apply baseline correction to fNIRS data for plotting
%
% Processes baseline correction specification and applies it to fNIRS data.
% Supports various baseline formats including duration from start, duration
% from end, explicit time windows, and external baseline data.
%
% Syntax:
%   [fNIR, baselineWindow] = pf2_base.plot.processBaseline(fNIR, baseline)
%   [fNIR, baselineWindow] = pf2_base.plot.processBaseline(fNIR, baseline, bioMlist)
%
% Inputs:
%   fNIR      - fNIRS data structure with time and biomarker fields
%   baseline  - Baseline specification:
%               - false: No baseline correction
%               - true: Use default 10s baseline from start
%               - Positive scalar: Baseline duration from start (seconds)
%               - Negative scalar: Baseline duration from end of recording
%               - [start, end]: Explicit baseline time window
%               - fNIRS struct: Use as external baseline reference
%   bioMlist  - Cell array of biomarker names to check (default: {'HbO'})
%               Used when baseline is an fNIRS struct.
%
% Outputs:
%   fNIR           - Baseline-corrected fNIRS data
%   baselineWindow - [start, end] times of baseline window used [1 x 2]
%                    Empty if no baseline applied. NaN for unspecified bounds.
%
% Example:
%   % Apply 10 second baseline from start
%   [corrected, blWin] = pf2_base.plot.processBaseline(fNIR, 10);
%
%   % Apply baseline from last 5 seconds
%   [corrected, blWin] = pf2_base.plot.processBaseline(fNIR, -5);
%
%   % Apply explicit baseline window
%   [corrected, blWin] = pf2_base.plot.processBaseline(fNIR, [5, 15]);
%
% See also: pf2.data.split, pf2.data.plot.oxy, pf2.data.plot.roi

if nargin < 3
    bioMlist = {'HbO'};
end

baselineWindow = [];

% Get time bounds
if ~isfield(fNIR, 'time')
    error('pf2_base:plot:processBaseline:missingTime', 'fNIRS data must have time field');
end

t = fNIR.time;
tmin = min(t, [], 'omitnan');
tmax = max(t, [], 'omitnan');
duration = tmax - tmin;

% Handle different baseline specifications
if islogical(baseline) && baseline
    % true -> use default 10s baseline
    baseline = 10;
    fNIR = pf2.data.split(fNIR, 'blLength', baseline, 'relative', true);
    baselineWindow = [nan, baseline];

elseif isnumeric(baseline) && isscalar(baseline) && baseline > 0 && baseline < duration
    % Positive scalar: baseline duration from start
    fNIR = pf2.data.split(fNIR, 'blLength', baseline, 'relative', true);
    baselineWindow = [nan, baseline];

elseif isnumeric(baseline) && isscalar(baseline) && baseline < 0 && baseline > -duration
    % Negative scalar: baseline from end
    blStart = duration + baseline;
    blEnd = duration;
    fNIR = pf2.data.split(fNIR, 'blStartTime', blStart, 'blEndTime', blEnd, 'relative', true);
    baselineWindow = [blStart + tmin, blEnd + tmin];

elseif isnumeric(baseline) && length(baseline) == 2
    % Explicit [start, end] window
    blStart = baseline(1);
    blEnd = baseline(2);

    % Handle negative values as offsets from end
    if blStart < 0
        blStart = duration + blStart;
    end
    if blEnd < 0
        blEnd = duration + blEnd;
    end

    fNIR = pf2.data.split(fNIR, 'blStartTime', blStart, 'blEndTime', blEnd, 'relative', true);
    baselineWindow = [blStart + tmin, blEnd + tmin];

elseif isstruct(baseline) && isfield(baseline, 'time')
    % External baseline data
    if ~iscell(bioMlist)
        bioMlist = {bioMlist};
    end

    % Check that baseline has required biomarker
    if isfield(baseline, bioMlist{1})
        fNIR = pf2.data.split(fNIR, tmin, tmax, 'blfNIR', baseline);
    end
    baselineWindow = [];

elseif ~(islogical(baseline) && ~baseline) && ~isempty(baseline)
    % Invalid specification (but not false or empty)
    warning('Invalid baseline specification, no baseline applied');
end

end
