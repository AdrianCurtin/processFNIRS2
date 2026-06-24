function Aux = oxy3Aux(M, time, isTrig, opticalCols, counterCol, adcNames, trigNames)
% OXY3AUX Build the auxiliary-signal struct for an Artinis .oxy3 import
%
% The OxySoft .oxy3 data matrix interleaves a sample counter, optical light
% intensities, trigger/port lines, and other analog AD channels (battery,
% respiration belt, external sensors). This helper turns the AD channels into
% a canonical data.Aux container: it preserves the legacy Aux.trigger field
% (first trigger line) and additionally exports every non-trigger AD channel as
% a typed auxiliary signal, named from the OxySoft AD channel list when the
% counts align.
%
% Syntax:
%   Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, adcNames, trigNames)
%
% Inputs:
%   M           - [nSamp x width] full demuxed sample matrix.
%   time        - [nSamp x 1] time vector (s).
%   isTrig      - [1 x width] logical, true for trigger/port columns.
%   opticalCols - Indices of the optical light-intensity columns.
%   counterCol  - Column index of the sample counter (0 if none).
%   adcNames    - Cell array of AD channel names parsed from the .oxy3 XML
%                 (may be empty).
%   trigNames   - Cell array of resolved trigger channel names (may be empty).
%
% Outputs:
%   Aux - Struct of auxiliary signals in canonical form (normalizeAux). Always
%         includes the legacy Aux.trigger (when a trigger exists). Each other
%         AD channel becomes a field with {data, time, unit, varNames, type,
%         kind}; the unit defaults to the inferred signal type's canonical
%         unit, else 'V' (raw ADC).
%
% Notes:
%   - AD channels are the non-optical, non-counter, non-trigger columns of M.
%   - The AD-column <-> adcNames mapping is by order and only applied when the
%     two counts match; otherwise channels are named adc<col>.
%
% Example:
%   Aux = pf2_base.oxy3Aux(M, time, isTrig, opticalCols, counterCol, adcNames, {});
%
% See also: pf2.import.importOxy3, pf2_base.auxSignalType

if nargin < 6, adcNames = {}; end
if nargin < 7, trigNames = {}; end

width = size(M, 2);
Aux = struct();

% AD channels: every column that is not optical, not the sample counter, and
% not a trigger/port line. Triggers are excluded here so the AD-column count
% matches the XML AdChName list (which describes only the analog AD inputs);
% otherwise the name map below would never populate on real recordings, which
% almost always carry trigger lines.
trigCols = find(isTrig);
adcCols = setdiff(1:width, [counterCol, opticalCols(:)', trigCols(:)']);
adcCols = adcCols(:)';

% Best-effort name map: AD column order <-> XML AdChName order
nameMap = containers.Map('KeyType', 'double', 'ValueType', 'char');
if numel(adcNames) == numel(adcCols)
    for i = 1:numel(adcCols)
        nameMap(adcCols(i)) = adcNames{i};
    end
end

% Legacy: first trigger line as Aux.trigger (code units)
trigIdx = find(isTrig);
if ~isempty(trigIdx)
    nm = 'Trigger';
    if ~isempty(trigNames), nm = trigNames{1}; end
    Aux.trigger = struct('data', M(:, trigIdx(1)), 'time', time(:), ...
        'unit', 'code', 'varNames', {{nm}});
end

% Remaining (non-trigger) AD channels -> typed Aux signals
for col = adcCols
    if isTrig(col)
        continue;   % triggers become markers + Aux.trigger
    end
    if isKey(nameMap, col)
        rawName = nameMap(col);
    else
        rawName = sprintf('adc%d', col);
    end
    fieldName = matlab.lang.makeValidName(rawName);
    if isfield(Aux, fieldName)
        % Disambiguate to a unique field (handles 3+ identically-named channels)
        fieldName = matlab.lang.makeValidName(sprintf('%s_%d', rawName, col));
        suffix = col;
        while isfield(Aux, fieldName)
            suffix = suffix + 1;
            fieldName = matlab.lang.makeValidName(sprintf('%s_%d', rawName, suffix));
        end
    end
    info = pf2_base.auxSignalType(rawName);
    unit = info.defaultUnit;
    if isempty(unit)
        unit = 'V';   % raw ADC analog default
    end
    Aux.(fieldName) = struct('data', M(:, col), 'time', time(:), ...
        'unit', unit, 'varNames', {{rawName}});
end

% Standardize to the canonical signal form so every field carries the inferred
% {type, kind} descriptors that downstream consumers (findAuxByType, the physio
% regressors) read directly off data.Aux.<name>.
Aux = pf2_base.normalizeAux(Aux);

end
