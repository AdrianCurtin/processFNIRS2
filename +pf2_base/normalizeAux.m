function aux = normalizeAux(aux, varargin)
% NORMALIZEAUX Standardize an auxiliary-signal container into canonical form
%
% Converts a data.Aux container (or a single signal) into a well-formed struct
% in which every named signal is a struct with the canonical fields
% {data, time, unit, varNames} plus the inferred descriptor fields
% {type, kind}. This is the canonical in-memory representation of auxiliary
% signals in processFNIRS2, analogous to normalizeMarkers for event markers.
%
% A data.Aux container is a struct whose fields are named signals (e.g.
% heartRate, accelerometer). Each signal may arrive as a struct, a table, or a
% numeric matrix; this function coerces each to the canonical signal struct.
% Housekeeping fields (the logical 'flattened' flag and any top-level numeric
% 'time'/'t' vector used by the resample/split flatten path) are passed through
% untouched so existing pipeline behavior is preserved.
%
% Syntax:
%   aux = pf2_base.normalizeAux(aux)
%   aux = pf2_base.normalizeAux(aux, 'Name', Value)
%   sig = pf2_base.normalizeAux(sig, 'Single', true, 'Name', 'heartRate')
%
% Inputs:
%   aux - Auxiliary data in any of these forms:
%         struct  - Container of named signals (default interpretation).
%         struct  - A single signal struct, with 'Single' set true.
%         table   - A single signal table, with 'Single' set true.
%         numeric - A single signal matrix, with 'Single' set true.
%         []      - Empty input (returns []).
%
% Name-Value Parameters:
%   'Single' - Treat the input as ONE signal rather than a container of
%              signals (default: false).
%   'Name'   - Signal name used for type inference in 'Single' mode
%              (default: '').
%   'fs'     - Fallback sampling rate (Hz) used to synthesize a time vector
%              when a signal has data but no time (default: []).
%
% Outputs:
%   aux - Canonical container (or canonical signal struct in 'Single' mode).
%         Each signal struct has:
%           .data     - [T x C] numeric
%           .time     - [T x 1] seconds (synthesized from fs/sample index if
%                       absent)
%           .unit     - char (defaults to the type's canonical unit, else '')
%           .varNames - {1 x C} cellstr (synthesized as ch1..chC if absent or
%                       the wrong length)
%           .type     - inferred family ('HR'|'EKG'|'PPG'|'ACCEL'|'GSR'|
%                       'EEG'|'')
%           .kind     - 'feature' | 'waveform' | ''
%
% Notes:
%   - Idempotent: re-normalizing a canonical container returns it unchanged.
%   - Field-name synonyms are recognized per signal: values/signal/y -> data;
%     t/timestamps -> time; units -> unit; names/labels/channels -> varNames.
%   - Type is inferred from each signal's field name and unit via
%     pf2_base.auxSignalType; unknown signals get type '' and still validate.
%
% Example:
%   data.Aux.heartRate.data = hr;        % no varNames, no unit
%   data.Aux = pf2_base.normalizeAux(data.Aux);
%   % -> data.Aux.heartRate.{data,time,unit='bpm',varNames={'HR'},type='HR'}
%
% See also: pf2_base.auxSignalType, pf2_base.normalizeMarkers, pf2.data.auxOnGrid

p = inputParser;
p.addParameter('Single', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Name', '', @(x) ischar(x) || isstring(x));
p.addParameter('fs', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.parse(varargin{:});
single = p.Results.Single;
sigName = char(string(p.Results.Name));
fsFallback = p.Results.fs;

% --- Empty input ----------------------------------------------------------
if isempty(aux)
    aux = [];
    return;
end

% --- Single-signal mode ---------------------------------------------------
if single
    aux = normalizeSignal(aux, sigName, fsFallback);
    return;
end

% --- Container mode -------------------------------------------------------
if ~isstruct(aux)
    error('pf2:normalizeAux:badType', ...
        'Aux container must be a struct or []; got %s.', class(aux));
end

% A container already flattened by split/resample (fields like
% heartRate_data / heartRate_time plus a logical 'flattened' flag) is a
% processed representation the pipeline depends on; leave it untouched.
% Read flattened signals through pf2.data.auxOnGrid instead.
if isfield(aux, 'flattened') && islogical(aux.flattened) && aux.flattened
    return;
end

fn = fieldnames(aux);
for k = 1:numel(fn)
    name = fn{k};
    val = aux.(name);

    % Pass through housekeeping fields untouched:
    %   - 'flattened' logical flag set by split/resample
    %   - a top-level numeric 'time'/'t' vector used by the flatten path
    if strcmpi(name, 'flattened') && islogical(val)
        continue;
    end
    if any(strcmpi(name, {'time', 't'})) && isnumeric(val)
        continue;
    end

    aux.(name) = normalizeSignal(val, name, fsFallback);
end

end

%%_Subfunctions_________________________________________________________

function sig = normalizeSignal(val, name, fsFallback)
% NORMALIZESIGNAL Coerce one signal (struct/table/numeric) to canonical form

data = [];
time = [];
unit = '';
varNames = {};
fs = fsFallback;

if istable(val)
    [data, time, varNames] = fromTable(val);
elseif isstruct(val)
    [data, time, unit, varNames, fs] = fromStruct(val, fsFallback);
elseif isnumeric(val)
    data = val;
else
    % Unrecognized payload: wrap as-is under .data so nothing is lost
    data = val;
end

% Coerce data to a 2-D numeric column-per-channel array
if isnumeric(data) && ~isempty(data)
    if isrow(data)
        data = data(:);
    end
end

T = size(data, 1);
C = size(data, 2);

% Synthesize a time vector if missing
if isempty(time) && T > 0
    if ~isempty(fs) && fs > 0
        time = (0:T-1)' / fs;
    else
        time = (0:T-1)';   % sample index (no fs available)
    end
end
time = time(:);

% Resolve type/unit descriptor from the signal name and any provided unit
info = pf2_base.auxSignalType(name, unit);
if isempty(unit) && ~isempty(info.defaultUnit)
    unit = info.defaultUnit;
end

% Synthesize / repair channel names
if ~iscell(varNames)
    varNames = {};
end
if numel(varNames) ~= C && C > 0
    varNames = arrayfun(@(c) sprintf('ch%d', c), 1:C, 'UniformOutput', false);
end

sig = struct();
sig.data = data;
sig.time = time;
sig.unit = char(string(unit));
sig.varNames = varNames(:)';
sig.type = info.type;
sig.kind = info.kind;

end

function [data, time, varNames] = fromTable(T)
% FROMTABLE Split a table signal into data / time / variable names

vn = T.Properties.VariableNames;
isTime = ismember(lower(vn), {'time', 't', 'timestamps'});
timeVars = find(isTime, 1);
if isempty(timeVars)
    time = [];
else
    time = T{:, timeVars(1)};
end
dataVars = find(~isTime);
data = T{:, dataVars};
varNames = vn(dataVars);

end

function [data, time, unit, varNames, fs] = fromStruct(s, fsFallback)
% FROMSTRUCT Pull canonical fields (with synonyms) out of a signal struct

data = pickField(s, {'data', 'values', 'value', 'signal', 'y'});
time = pickField(s, {'time', 't', 'timestamps'});
unit = pickField(s, {'unit', 'units'});
varNames = pickField(s, {'varnames', 'names', 'labels', 'channels'});
fs = pickField(s, {'fs', 'samplerate', 'samplingrate'});

% A struct whose .data field is itself a table (carrying its own time column,
% as produced by the flatten path) is split into data/time/varNames.
if istable(data)
    [dataT, timeT, varNamesT] = fromTable(data);
    data = dataT;
    if isempty(time), time = timeT; end
    if isempty(varNames), varNames = varNamesT; end
end

if isempty(unit), unit = ''; end
if isempty(fs), fs = fsFallback; end
if ~iscell(varNames)
    if isempty(varNames)
        varNames = {};
    elseif ischar(varNames) || isstring(varNames)
        varNames = cellstr(varNames);
    else
        varNames = {};
    end
end

end

function v = pickField(s, candidates)
% PICKFIELD First struct field (case-insensitive) matching a candidate name
v = [];
fn = fieldnames(s);
lfn = lower(fn);
for c = 1:numel(candidates)
    idx = find(strcmp(lfn, candidates{c}), 1);
    if ~isempty(idx)
        v = s.(fn{idx});
        return;
    end
end
end
