function info = auxSignalType(name, unit)
% AUXSIGNALTYPE Resolve an auxiliary signal name/unit to a typed descriptor
%
% Maps a free-form auxiliary signal name (and optional unit) onto one of the
% toolbox's known signal families and returns a descriptor with sensible
% defaults (canonical unit, analysis role, frequency band, and whether the
% signal is a raw waveform or an already-derived feature). Unknown names
% resolve to a generic descriptor (type '') so they still flow through the
% Aux machinery without special handling.
%
% Known families:
%   HR    - heart rate (bpm), a derived feature; covariate of arousal
%   EKG   - electrocardiogram waveform; cardiac nuisance + HR source
%   PPG   - photoplethysmography waveform; cardiac nuisance + HR source
%   ACCEL - accelerometer / IMU; motion quality gate + nuisance
%   GSR   - electrodermal activity (GSR/EDA); covariate of arousal
%   EEG   - electroencephalography; covariate / fusion modality (own typing)
%
% Syntax:
%   info = pf2_base.auxSignalType(name)
%   info = pf2_base.auxSignalType(name, unit)
%
% Inputs:
%   name - Signal name [char|string], e.g. 'heartRate', 'ppg', 'eeg_Cz'.
%          Matching is case-insensitive and ignores separators/underscores.
%   unit - (Optional) Unit string [char|string] used as a tie-breaker when
%          the name is ambiguous or unknown (e.g. 'bpm' -> HR, 'uS' -> GSR).
%
% Outputs:
%   info - Descriptor struct with fields:
%          .type        - Canonical family ('HR'|'EKG'|'PPG'|'ACCEL'|'GSR'|
%                         'EEG'|''), '' when unrecognized.
%          .kind        - 'feature' | 'waveform' | '' (unknown).
%          .defaultUnit - Canonical unit string for the family.
%          .role        - Primary analysis role ('covariate'|'nuisance'|
%                         'motion'|'fusion'|'').
%          .roles       - Cell array of all applicable roles.
%          .band        - Typical analysis band [loHz hiHz], [] if N/A.
%          .bands       - (EEG only) struct of canonical sub-bands; [] otherwise.
%          .matchedBy   - 'name' | 'unit' | 'none' (how the type was resolved).
%
% Notes:
%   - The descriptor's role is a sensible default, never a constraint; callers
%     may use any signal in any role (e.g. PPG as a covariate).
%   - EEG is intentionally a distinct family: high sampling rate, multichannel,
%     analyzed by frequency band rather than peak/decomposition.
%
% Example:
%   info = pf2_base.auxSignalType('heartRate');     % info.type == 'HR'
%   info = pf2_base.auxSignalType('chan1', 'uS');   % info.type == 'GSR' (by unit)
%
% See also: pf2_base.normalizeAux, pf2.data.auxOnGrid

if nargin < 2
    unit = '';
end

name = lower(char(string(name)));
unit = lower(char(string(unit)));

% Collapse to alphanumerics so 'heart_rate', 'heart-rate', 'HeartRate' all match
key = regexprep(name, '[^a-z0-9]', '');

% --- Try to resolve type from the name, then fall back to the unit ----------
type = matchName(key);
matchedBy = 'name';
if isempty(type)
    type = matchUnit(unit);
    matchedBy = 'unit';
end
if isempty(type)
    matchedBy = 'none';
end

info = describe(type);
info.matchedBy = matchedBy;

end

%%_Subfunctions_________________________________________________________

function type = matchName(key)
% MATCHNAME Resolve a normalized (alphanumeric, lowercase) name to a type
%   Order matters: more specific families are tested before generic ones.

type = '';
if isempty(key)
    return;
end

% EEG: explicit token or 'eeg' prefix (e.g. eegcz, eegfp1)
if strcmp(key, 'eeg') || startsWith(key, 'eeg') || ...
        any(strcmp(key, {'electroencephalogram'}))
    type = 'EEG';
    return;
end

aliases = {
    'HR',    {'hr', 'heartrate', 'pulse', 'bpm', 'heartbeat', 'pulserate'}
    'EKG',   {'ekg', 'ecg', 'electrocardiogram', 'cardiac'}
    'PPG',   {'ppg', 'pleth', 'plethysmography', 'pulseox', 'pulseoximetry'}
    'ACCEL', {'accel', 'acc', 'accelerometer', 'imu', 'motion', 'acceleration', 'accelerometor'}
    'GSR',   {'gsr', 'eda', 'scl', 'scr', 'electrodermal', 'skinconductance', 'galvanic', 'galvanicskinresponse'}
    'RESP',  {'resp', 'respiration', 'breathing', 'breath', 'respiratory', 'rip', 'respiratorybelt', 'respbelt'}
    'TEMP',  {'temp', 'temperature', 'skintemp', 'skintemperature', 'thermistor', 'thermocouple'}
    };

% Exact match first (prevents short tokens from over-matching)
for r = 1:size(aliases, 1)
    if any(strcmp(key, aliases{r, 2}))
        type = aliases{r, 1};
        return;
    end
end

% Substring fallback for compound names (e.g. 'subj1_heartrate', 'accelX').
% Require tokens >= 5 chars so short tokens (resp, temp, rip, acc, eda, scl,
% ekg, ppg, ...) cannot spuriously match English words such as "correspond"
% or "attempt"; those short tokens are still caught by the exact-match pass.
for r = 1:size(aliases, 1)
    syns = aliases{r, 2};
    for s = 1:numel(syns)
        if numel(syns{s}) >= 5 && contains(key, syns{s})
            type = aliases{r, 1};
            return;
        end
    end
end

end

function type = matchUnit(unit)
% MATCHUNIT Resolve a type from a unit string when the name was ambiguous

type = '';
ukey = regexprep(unit, '\s', '');
if isempty(ukey)
    return;
end

if any(strcmp(ukey, {'bpm', 'beatsperminute', '1/min'}))
    type = 'HR';
elseif any(strcmp(ukey, {'us', 'µs', 'microsiemens', 'siemens', 'mho', 'µmho'}))
    type = 'GSR';
elseif any(strcmp(ukey, {'g', 'm/s^2', 'm/s2', 'ms-2'}))
    type = 'ACCEL';
elseif any(strcmp(ukey, {'mv', 'millivolt', 'millivolts'}))
    type = 'EKG';
elseif any(strcmp(ukey, {'uv', 'µv', 'microvolt', 'microvolts'}))
    type = 'EEG';
elseif any(strcmp(ukey, {'degc', '°c', 'celsius', 'degf', '°f', 'fahrenheit'}))
    type = 'TEMP';
end

end

function info = describe(type)
% DESCRIBE Build the descriptor struct for a resolved type ('' = generic)

info = struct('type', type, 'kind', '', 'defaultUnit', '', ...
    'role', '', 'roles', {{}}, 'band', [], 'bands', []);

switch type
    case 'HR'
        info.kind = 'feature';   info.defaultUnit = 'bpm';
        info.role = 'covariate'; info.roles = {'covariate'};
        info.band = [0 0.5];
    case 'EKG'
        info.kind = 'waveform';  info.defaultUnit = 'mV';
        info.role = 'nuisance';  info.roles = {'nuisance', 'source'};
        info.band = [0.5 40];
    case 'PPG'
        info.kind = 'waveform';  info.defaultUnit = 'a.u.';
        info.role = 'nuisance';  info.roles = {'nuisance', 'source'};
        info.band = [0.5 5];
    case 'ACCEL'
        info.kind = 'waveform';  info.defaultUnit = 'g';
        info.role = 'motion';    info.roles = {'motion', 'nuisance'};
        info.band = [0 20];
    case 'GSR'
        info.kind = 'waveform';  info.defaultUnit = 'uS';
        info.role = 'covariate'; info.roles = {'covariate'};
        info.band = [0 0.5];     % EDA energy is < ~0.5 Hz (SCL <0.05, SCRs ~0.05-0.5)
    case 'RESP'
        info.kind = 'waveform';  info.defaultUnit = 'a.u.';
        info.role = 'nuisance';  info.roles = {'nuisance', 'covariate'};
        info.band = [0.1 0.5];   % typical breathing ~0.15-0.4 Hz
    case 'TEMP'
        info.kind = 'feature';   info.defaultUnit = 'degC';
        info.role = 'covariate'; info.roles = {'covariate'};
        info.band = [0 0.05];    % slowly varying
    case 'EEG'
        info.kind = 'waveform';  info.defaultUnit = 'uV';
        info.role = 'covariate'; info.roles = {'covariate', 'fusion'};
        info.band = [0.5 45];
        info.bands = struct('delta', [1 4], 'theta', [4 8], ...
            'alpha', [8 13], 'beta', [13 30], 'gamma', [30 45]);
    otherwise
        % Generic / unknown: leave defaults empty
end

end
