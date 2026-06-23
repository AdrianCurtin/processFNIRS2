function writeNirsJson(filepath, data, nirs, task)
% WRITENIRSJSON Write a BIDS-NIRS _nirs.json sidecar
%
% Emits the required acquisition metadata for a NIRS recording: TaskName,
% SamplingFrequency, NIRSChannelCount, NIRSSourceOptodeCount,
% NIRSDetectorOptodeCount and the cap fields, plus recommended manufacturer
% details and a software-filters note.
%
% Inputs:
%   filepath - output _nirs.json path
%   data     - fNIRS data struct (fs, device, processingInfo)
%   nirs     - SNIRF /nirs structure from pf2.export.asSNIRF
%   task     - task label char (matches the filename task entity)
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeNirsJson('sub-01_task-rest_nirs.json', data, nirs, 'rest');
%
% See also: pf2.export.asBIDS, pf2_base.bids.samplingFreq

s = struct();
s.TaskName = task;
s.SamplingFrequency = pf2_base.bids.samplingFreq(data, nirs);
s.NIRSChannelCount = numel(nirs.data.measurementList);
s.NIRSSourceOptodeCount = optodeCount(nirs.probe, 'sourcePos3D', 'sourcePos2D');
s.NIRSDetectorOptodeCount = optodeCount(nirs.probe, 'detectorPos3D', 'detectorPos2D');

[manu, modelName] = deviceStrings(data, nirs);

% Cap fields are required by the spec; default to device info or 'n/a'.
if isempty(manu)
    s.CapManufacturer = 'n/a';
else
    s.CapManufacturer = manu;
end
if isempty(modelName)
    s.CapManufacturersModelName = 'n/a';
else
    s.CapManufacturersModelName = modelName;
end

% Recommended fields
if ~isempty(manu)
    s.Manufacturer = manu;
end
if ~isempty(modelName)
    s.ManufacturersModelName = modelName;
end
s.SoftwareFilters = softwareFilters(data);

pf2_base.bids.writeJson(filepath, s);
end

function n = optodeCount(probe, field3D, field2D)
n = 0;
if isstruct(probe) && isfield(probe, field3D) && ~isempty(probe.(field3D))
    n = size(probe.(field3D), 1);
elseif isstruct(probe) && isfield(probe, field2D) && ~isempty(probe.(field2D))
    n = size(probe.(field2D), 1);
end
end

function [manu, modelName] = deviceStrings(data, nirs)
manu = '';
modelName = '';
if isstruct(data) && isfield(data, 'device') && isa(data.device, 'pf2.Device')
    manu = char(data.device.manufacturer);
    modelName = char(data.device.model);
end
if isempty(manu) && isfield(nirs, 'metaDataTags')
    manu = metaStr(nirs.metaDataTags, 'ManufacturerName');
end
if isempty(modelName) && isfield(nirs, 'metaDataTags')
    modelName = metaStr(nirs.metaDataTags, 'Model');
end
end

function v = metaStr(meta, field)
v = '';
if isstruct(meta) && isfield(meta, field) && ~isempty(meta.(field))
    v = char(meta.(field));
end
end

function sf = softwareFilters(data)
% Summarize processing as a free-text software-filters note when available.
sf = 'n/a';
if isstruct(data) && isfield(data, 'processingInfo') && isstruct(data.processingInfo)
    pinfo = data.processingInfo;
    parts = {};
    if isfield(pinfo, 'rawMethod') && ~isempty(pinfo.rawMethod)
        parts{end+1} = sprintf('raw=%s', char(string(pinfo.rawMethod))); %#ok<AGROW>
    end
    if isfield(pinfo, 'oxyMethod') && ~isempty(pinfo.oxyMethod)
        parts{end+1} = sprintf('oxy=%s', char(string(pinfo.oxyMethod))); %#ok<AGROW>
    end
    if ~isempty(parts)
        sf = strjoin(parts, '; ');
    end
end
end
