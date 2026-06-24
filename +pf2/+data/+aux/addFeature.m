function data = addFeature(data, name, values, varargin)
% ADDFEATURE Store a derived signal as a typed auxiliary feature
%
% Writes a derived feature (e.g. an HR series from heartRateFrom, RVT from
% respFeatures, an EEG band-power envelope) into data.Aux as a canonical,
% typed signal so it propagates through the pipeline and survives SNIRF export
% / re-import like any other auxiliary signal.
%
% Syntax:
%   data = pf2.data.aux.addFeature(data, name, values)
%   data = pf2.data.aux.addFeature(data, name, values, 'Name', Value)
%
% Inputs:
%   data   - fNIRS data struct (must have .time; .Aux is created if absent).
%   name   - Field name for the new aux signal [char|string].
%   values - Feature samples [T x C]. Length should match the Time grid.
%
% Name-Value Parameters:
%   'Time'     - Time vector for the feature (default: data.time).
%   'Unit'     - Unit string (default: the inferred type's canonical unit).
%   'VarNames' - Channel labels (default: synthesized).
%
% Outputs:
%   data - Input struct with data.Aux.(name) added as a canonical signal
%          struct {data,time,unit,varNames,type,kind}.
%
% Notes:
%   - The signal is normalized via pf2_base.normalizeAux, so the type/kind are
%     inferred from the field name (e.g. 'heartRate' -> HR).
%   - If data.Aux is in the flattened pipeline representation, a warning is
%     issued (mixing nested and flattened signals); re-flatten downstream if
%     needed.
%
% Example:
%   [hr, ~] = pf2.data.aux.heartRateFrom(proc.Aux.ppg.data, proc.Aux.ppg.fs);
%   proc = pf2.data.aux.addFeature(proc, 'heartRate', hr);   % typed HR series
%
% See also: pf2_base.normalizeAux, pf2.data.aux.heartRateFrom,
%           pf2.data.aux.respFeatures, pf2.export.asSNIRF

p = inputParser;
p.addRequired('data', @isstruct);
p.addRequired('name', @(x) ischar(x) || isstring(x));
p.addRequired('values', @isnumeric);
p.addParameter('Time', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('Unit', '', @(x) ischar(x) || isstring(x));
p.addParameter('VarNames', {}, @(x) iscell(x) || ischar(x) || isstring(x));
p.parse(data, name, values, varargin{:});
name = matlab.lang.makeValidName(char(string(name)));

t = p.Results.Time;
if isempty(t)
    if ~isfield(data, 'time') || isempty(data.time)
        error('pf2:addFeature:noTime', ...
            'No Time given and data.time is empty.');
    end
    t = data.time;
end

sig = struct('data', values, 'time', t(:));
if ~isempty(char(string(p.Results.Unit)))
    sig.unit = char(string(p.Results.Unit));
end
if ~isempty(p.Results.VarNames)
    sig.varNames = cellstr(p.Results.VarNames);
end

if ~isfield(data, 'Aux') || isempty(data.Aux) || ~isstruct(data.Aux)
    data.Aux = struct();
elseif isfield(data.Aux, 'flattened') && islogical(data.Aux.flattened) && data.Aux.flattened
    warning('pf2:addFeature:flattenedAux', ...
        ['data.Aux is in the flattened pipeline representation; adding a ', ...
         'nested feature "%s" mixes representations.'], name);
end

data.Aux.(name) = pf2_base.normalizeAux(sig, 'Single', true, 'Name', name);

end
