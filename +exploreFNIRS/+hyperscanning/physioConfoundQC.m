function qc = physioConfoundQC(A, B, varargin)
% PHYSIOCONFOUNDQC Flag shared-physiology confound risk for a hyperscanning dyad
%
% Quantifies how strongly two subjects' physiological auxiliary signals (heart
% rate, respiration, PPG) co-vary in the low-frequency band. Shared physiology
% and ~0.1 Hz Mayer waves are a primary source of SPURIOUS inter-brain
% coherence in hyperscanning; a high aux-aux coherence is a warning that neural
% synchrony estimates in that band may be confounded.
%
% Syntax:
%   qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B)
%   qc = exploreFNIRS.hyperscanning.physioConfoundQC(A, B, 'Name', Value)
%
% Inputs:
%   A, B - fNIRS data structs for the two members of the dyad, each with a
%          physiological signal in .Aux.
%
% Name-Value Parameters:
%   'Aux'       - Aux signal name shared by both subjects (default: auto-detect,
%                 preferring HR, then PPG, then EKG).
%   'Band'      - LFO/VLFO band [loHz hiHz] to assess (default: [0.04 0.15],
%                 spanning the Mayer-wave range).
%   'Threshold' - Aux-aux coherence above which the dyad is flagged
%                 (default: 0.5).
%
% Outputs:
%   qc - Struct with fields:
%     .flag         - true if mean aux coherence in Band exceeds Threshold
%     .auxCoherence - mean aux-aux coherence in Band
%     .signal       - aux signal name used
%     .band         - band assessed
%     .threshold    - threshold used
%     .available    - false if a shared aux signal could not be resolved
%
% Notes:
%   - When no shared aux signal is available, qc.flag is false and
%     qc.available is false (no confound assessment possible).
%
% Example:
%   qc = exploreFNIRS.hyperscanning.physioConfoundQC(subjA, subjB);
%   if qc.flag, warning('Shared physiology may inflate LFO synchrony'); end
%
% See also: exploreFNIRS.coupling.partialCoherence, exploreFNIRS.coupling.coherence,
%           exploreFNIRS.hyperscanning.computeDyad

p = inputParser;
p.addRequired('A', @isstruct);
p.addRequired('B', @isstruct);
p.addParameter('Aux', '', @(x) ischar(x) || isstring(x));
p.addParameter('Band', [0.04 0.15], @(x) isnumeric(x) && numel(x) == 2);
p.addParameter('Threshold', 0.5, @(x) isnumeric(x) && isscalar(x));
p.parse(A, B, varargin{:});
band = p.Results.Band;
thr = p.Results.Threshold;

auxName = char(string(p.Results.Aux));
if isempty(auxName)
    % Auto-detect only cardio-respiratory signals: these carry the shared
    % LFO/Mayer-wave physiology relevant to the confound. EDA has negligible
    % power in this band, so it is intentionally excluded from the fallback.
    for cand = {'HR', 'PPG', 'EKG'}
        nA = pf2_base.fnirs.findAuxByType(A, cand{1}, '');
        nB = pf2_base.fnirs.findAuxByType(B, cand{1}, '');
        if ~isempty(nA) && ~isempty(nB)
            auxName = nA;
            break;
        end
    end
end

qc = struct('flag', false, 'auxCoherence', NaN, 'signal', auxName, ...
    'band', band, 'threshold', thr, 'available', false);

if isempty(auxName)
    return;
end

try
    aA = pf2.data.auxOnGrid(A, auxName);
    aB = pf2.data.auxOnGrid(B, auxName);
catch
    return;
end

% Equalize length (assume a common sampling rate across the dyad)
n = min(size(aA, 1), size(aB, 1));
if n < 8
    return;
end
sA = aA(1:n, 1);
sB = aB(1:n, 1);

fs = A.fs;
if isempty(fs) || ~isfinite(fs)
    fs = 1 / median(diff(A.time));
end

% The coherence assumes the two subjects share a synchronous time base. Warn
% on a clear sampling-rate mismatch (a sign the dyad is not time-aligned).
if isfield(B, 'fs') && ~isempty(B.fs) && isfinite(B.fs) && ...
        abs(B.fs - fs) > 1e-6 * max(fs, B.fs)
    warning('pf2:physioConfoundQC:fsMismatch', ...
        ['Subjects A (%.3g Hz) and B (%.3g Hz) have different sampling rates; ', ...
         'aux coherence assumes a common synchronous grid.'], fs, B.fs);
end

c = exploreFNIRS.coupling.coherence(sA, sB, fs, 'FreqRange', band);
qc.auxCoherence = c.value;
qc.available = true;
qc.flag = c.value > thr;

end
