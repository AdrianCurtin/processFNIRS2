function outData = processStageOD2Hb(data, time, subjectAge, DirtyBaseline, curProbe, baseline, dpfMode, dpfFixed, defaultAge)
% PROCESSSTAGEOD2HB Convert optical density to hemoglobin concentrations
%
% Beer-Lambert conversion stage of the fNIRS processing pipeline.
% Converts optical density (OD) data to oxygenated (HbO) and deoxygenated
% (HbR) hemoglobin concentrations using the modified Beer-Lambert law.
%
% Syntax:
%   outData = processStageOD2Hb(data, time, subjectAge, DirtyBaseline, curProbe, baseline, dpfMode, dpfFixed, defaultAge)
%
% Inputs:
%   data          - [T x C] Optical density data (T=timepoints, C=channels)
%   time          - [T x 1] Time vector in seconds
%   subjectAge    - Subject age in years (can be empty)
%   DirtyBaseline - Logical, if true use entire signal mean as baseline
%   curProbe      - Probe structure with TableCh and TableOpt
%   baseline      - Struct with fields:
%                     startTime - Baseline start time (seconds)
%                     blLength  - Baseline duration (seconds)
%   dpfMode       - DPF mode: 'None', 'Fixed', or 'Calc'
%   dpfFixed      - Fixed DPF value (used when dpfMode is 'Fixed')
%   defaultAge    - Default age for DPF calculation when subjectAge empty
%
% Outputs:
%   outData       - Struct containing:
%                     HbO       - [T x N] Oxygenated hemoglobin
%                     HbR       - [T x N] Deoxygenated hemoglobin
%                     HbTotal   - [T x N] Total hemoglobin (HbO + HbR)
%                     HbDiff    - [T x N] Differential (HbO - HbR)
%                     CBSI      - [T x N] Cerebral blood saturation index
%                     channels  - [1 x N] Channel numbers
%                     units     - Unit string (uM or mM*mm)
%                     DPF_factor - DPF value used
%                     time      - Time vector
%
% Example:
%   % Process with 10-second baseline starting at t=0
%   baseline = struct('startTime', 0, 'blLength', 10);
%   outData = pf2_base.fnirs.processStageOD2Hb(odData, time, 25, false, ...
%       curProbe, baseline, 'Calc', 5.93, 25);
%
% See also: pf2_base.fnirs.processStageRaw2OD, pf2_base.fnirs.processStageFilterHb, pf2_base.fnirs.bvoxy

% Determine DPF settings
if strcmp(dpfMode, 'None')
    NoPathlength = true;
else
    NoPathlength = false;
end

if strcmp(dpfMode, 'Fixed')
    fixedDPF = dpfFixed;
else
    fixedDPF = 0;
end

if isempty(subjectAge)
    subjectAge = defaultAge;
end

% Determine baseline samples
if DirtyBaseline
    % Use entire signal mean as baseline
    baselineSamples = 1:length(time);
else
    startTime = min(time) + baseline.startTime;
    endTime = startTime + baseline.blLength;

    startSample = find(time >= startTime, 1);
    endSample = find(time >= endTime, 1);
    baselineSamples = startSample:endSample;
end

% Get probe tables
curTableOpt = curProbe.TableOpt;
curTableCh = curProbe.TableCh;

% Filter to only channel columns
data = data(:, curTableCh.isCh);
curTableCh = curTableCh(curTableCh.isCh, :);

% Perform Beer-Lambert conversion
[outData.HbO, outData.HbR, outData.HbTotal, outData.HbDiff, outData.CBSI, ...
    outData.channels, ~, outData.units, outData.DPF_factor] = ...
    pf2_base.fnirs.bvoxy(data, curTableCh.OptodeNumber, curTableCh.Wavelength, ...
    curTableOpt.SD, baselineSamples, subjectAge, [], true, ...
    'NoPathlength', NoPathlength, 'DiffPathlengthFactor', fixedDPF);

outData.time = time;

end
