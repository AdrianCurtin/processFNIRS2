function name = findAuxByType(data, type, fallback)
% FINDAUXBYTYPE Find an auxiliary signal name by its inferred signal type
%
% Scans a data struct's .Aux container for the first signal whose inferred
% family (via pf2_base.auxSignalType) matches the requested type. Handles both
% the nested representation (Aux.<name>) and the flattened representation
% (Aux.<name>_data / <name>_time) by reducing field names to base names.
%
% Syntax:
%   name = pf2_base.fnirs.findAuxByType(data, type)
%   name = pf2_base.fnirs.findAuxByType(data, type, fallback)
%
% Inputs:
%   data     - fNIRS data struct (with optional .Aux container).
%   type     - Target family ('HR'|'EKG'|'PPG'|'ACCEL'|'GSR'|'EEG').
%   fallback - (Optional) Name returned when no match is found (default: '').
%
% Outputs:
%   name - Base name of the first matching Aux signal, else the fallback.
%
% Example:
%   nm = pf2_base.fnirs.findAuxByType(proc, 'ACCEL', 'accelerometer');
%
% See also: pf2_base.auxSignalType, pf2.data.auxOnGrid

if nargin < 3
    fallback = '';
end
name = fallback;

if ~isfield(data, 'Aux') || isempty(data.Aux) || ~isstruct(data.Aux)
    return;
end

fn = fieldnames(data.Aux);
fn = fn(~strcmpi(fn, 'flattened'));
base = unique(regexprep(fn, '_(data|time|unit)$', ''), 'stable');

for i = 1:numel(base)
    info = pf2_base.auxSignalType(base{i});
    if strcmp(info.type, type)
        name = base{i};
        return;
    end
end

end
