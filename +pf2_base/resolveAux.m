function [sig, sigName] = resolveAux(Aux, name)
% RESOLVEAUX Fetch a native auxiliary signal from a nested or flattened container
%
% Returns the canonical (un-resampled) signal struct for a named auxiliary
% signal, handling both representations used in processFNIRS2: nested
% (Aux.<name>.{data,time}, a table, or a numeric array) and the split/resample
% flattened form (Aux.<name>_data plus Aux.<name>_time, with a logical
% Aux.flattened flag). This is the shared resolver used by pf2.data.auxOnGrid
% and the physiology/motion routines.
%
% Syntax:
%   [sig, sigName] = pf2_base.resolveAux(Aux, name)
%
% Inputs:
%   Aux  - The .Aux container struct.
%   name - Signal name [char|string] (base name, e.g. 'heartRate').
%
% Outputs:
%   sig     - Canonical signal struct {data,time,unit,varNames,type,kind}
%             (via pf2_base.normalizeAux), on the signal's native time base.
%   sigName - The resolved field/base name.
%
% Errors:
%   pf2:resolveAux:notFound when the signal is absent (message lists the
%   available base names).
%
% Example:
%   sig = pf2_base.resolveAux(proc.Aux, 'heartRate');   % native HR series
%
% See also: pf2.data.auxOnGrid, pf2_base.normalizeAux

name = char(string(name));
fn = fieldnames(Aux);
lfn = lower(fn);
lname = lower(name);

% 1. Direct field (struct / table / numeric), excluding the flattened flag
hit = find(strcmp(lfn, lname), 1);
if ~isempty(hit) && ~strcmpi(fn{hit}, 'flattened')
    raw = Aux.(fn{hit});
    if isstruct(raw) || istable(raw) || isnumeric(raw)
        sigName = fn{hit};
        sig = pf2_base.normalizeAux(raw, 'Single', true, 'Name', sigName);
        return;
    end
end

% 2. Flattened pair: <name>_data (+ <name>_time / <name>_unit)
dHit = find(strcmp(lfn, [lname '_data']), 1);
if ~isempty(dHit)
    raw = Aux.(fn{dHit});
    sigName = name;
    if istable(raw) || isstruct(raw)
        % The flattened *_data field is itself self-contained (carries its own
        % time column); normalize it directly.
        sig = pf2_base.normalizeAux(raw, 'Single', true, 'Name', name);
    else
        s = struct('data', raw);
        tHit = find(strcmp(lfn, [lname '_time']), 1);
        if ~isempty(tHit), s.time = Aux.(fn{tHit}); end
        uHit = find(strcmp(lfn, [lname '_unit']), 1);
        if ~isempty(uHit), s.unit = Aux.(fn{uHit}); end
        sig = pf2_base.normalizeAux(s, 'Single', true, 'Name', name);
    end
    return;
end

% Not found: list friendly base names (strip _data/_time/_unit suffixes + flag)
base = unique(regexprep(fn(~strcmpi(fn, 'flattened')), '_(data|time|unit)$', ''), 'stable');
error('pf2:resolveAux:notFound', ...
    'Aux signal "%s" not found. Available: %s', name, strjoin(base, ', '));

end
