function [fNIR] = importSNIRF(filepath, channelCheck, varargin)
% IMPORTSNIRF Import fNIRS data from SNIRF format files
%
% Reads fNIRS data stored in the Shared Near Infrared Spectroscopy Format
% (SNIRF), a standardized HDF5-based file format for fNIRS data. The SNIRF
% format enables interoperability between different fNIRS analysis software
% packages. This function extracts raw intensity data, probe geometry,
% stimulus markers, auxiliary data, and metadata from SNIRF files.
%
% Reference:
%   SNIRF Specification v1.1 (2023). Shared Near Infrared Spectroscopy
%   Format. https://github.com/fNIRS/snirf
%
% Syntax:
%   fNIR = pf2.import.importSNIRF()
%   fNIR = pf2.import.importSNIRF(filepath)
%   fNIR = pf2.import.importSNIRF(filepath, channelCheck)
%   fNIR = pf2.import.importSNIRF(filepath, channelCheck, Name, Value, ...)
%
% Inputs:
%   filepath     - Path to the SNIRF file [char | string]
%                  If omitted or empty, a file selection dialog opens.
%                  Supports both .snirf (HDF5) and .jsnirf (JSON) formats.
%   channelCheck - Run channel quality check GUI after import (default: true)
%                  Set to false to skip interactive quality assessment.
%   varargin     - Additional name-value pairs passed to loadsnirf()
%                  See pf2_base.external.jsnirfy.loadsnirf for options.
%
% Outputs:
%   fNIR - Standard pf2 fNIRS data structure containing:
%          .raw       - Raw intensity data [T x C double]
%          .time      - Time vector in seconds [T x 1 double]
%          .fs        - Sampling frequency in Hz [double]
%          .markers   - Event markers [M x 3: time, value, duration]
%          .fchMask   - Channel quality mask [1 x C: 1=good, 0=bad]
%          .info      - Metadata from SNIRF metaDataTags
%          .t0        - Recording start datetime (if available)
%          .probeinfo - Device and probe geometry structure
%          .Aux       - Auxiliary data (if present in file)
%
% Example:
%   % Import with file dialog and channel check
%   data = pf2.import.importSNIRF();
%
%   % Import specific file, skip channel check
%   data = pf2.import.importSNIRF('subject01.snirf', false);
%
%   % Process imported data
%   processed = processFNIRS2(data);
%
% Notes:
%   - Normalized data is automatically de-normalized if RawMax is available
%   - Length units are converted to mm internally (cm input is multiplied by 10)
%   - Short-separation channels (SD < 20mm) are automatically detected
%   - Probe layout is automatically generated from 3D optode positions
%
% See also: pf2.import.importNIR, pf2.import.importNIRX, pf2.export.asSNIRF,
%           pf2_base.external.jsnirfy.loadsnirf

if nargin < 2
   channelCheck = true; 
   forceChannelCheck = false;
else
   forceChannelCheck = true; 
end

includeSSchannels = true;
buildProbeLayout = true;

% Handle file selection if needed
if nargin < 1
   [filename, pathname] = uigetfile({'*.snirf;*.jsnirf','snirf files (*.snirf,*.jsnirf)';'*.*','All files (*.*)'},'Open SNIRF file');
   if isequal(filename, 0) || isequal(pathname, 0)
       error('File selection canceled.');
   end
   filepath = fullfile(pathname, filename);
elseif ~ischar(filepath) && ~isstring(filepath)
   error('Input must be a string representing a filename');
end

% Load SNIRF data using jsnirfy loader
try
    data = pf2_base.external.jsnirfy.loadsnirf(filepath, varargin{:});
catch e
    error('Failed to load SNIRF file: %s', e.message);
end

if ~isfield(data, 'nirs')
    error('No nirs struct contained in file');
end

% Initialize fNIR structure
fNIR = [];

% Process metadata
metaDataTags = stripStruct(data.nirs.metaDataTags);

% Handle markers/stimulus data
if isfield(data.nirs, 'stim') && ~isempty(data.nirs.stim)
    markerArray = [];
    stimArray = data.nirs.stim;
    
    for m = 1:length(stimArray)
        curStim = stimArray(m);
        
        % Create label field if not present
        if ~isfield(curStim, 'data') || isempty(curStim.data)
            continue;
        end
        
        % Standard SNIRF stim data is [starttime, duration, value]
        % We want [time, value, duration] for fNIR format
        if size(curStim.data, 2) >= 3
            % Reorder columns to match fNIR format [time, value, duration]
            curMarkerData = curStim.data(:, [1, 3, 2]);
            
            % Add stimulus name as a column if needed
            if isfield(curStim, 'name') && ~isempty(curStim.name)
                stimName = repmat({curStim.name}, size(curMarkerData, 1), 1);
                if ~iscell(stimName{1})
                    % Add a column for the name if more than 3 columns
                    if size(curMarkerData, 2) > 3
                        curMarkerData = [curMarkerData, cell2mat(stimName)];
                    end
                end
            end
            
            markerArray = [markerArray; curMarkerData];
        end
    end
    
    if ~isempty(markerArray)
        % Sort markers by time
        [~, sortIdx] = sort(markerArray(:, 1));
        fNIR.markers = markerArray(sortIdx, :);
    else
        fNIR.markers = [];
    end
else
    fNIR.markers = [];
end

% Extract nirs
nirs = data.nirs;

% Extract main data
data = nirs.data;

% Process measurement list
if ~isfield(data, 'measurementList') || isempty(data.measurementList)
    error('No measurement list found in SNIRF file');
end

% Convert measurement list to table for easier handling
measurementList = struct2table(data.measurementList);

% Handle normalized data
if isfield(metaDataTags, 'Normalized') && ...
   (strcmpi(metaDataTags.Normalized, '1') || strcmpi(metaDataTags.Normalized, 'true'))
    if isfield(metaDataTags, 'RawMax')
        % Find all raw DC channels (both normal and dark)
        rawDC_channels = contains(cat(1, measurementList.dataTypeLabel), 'raw-DC');
        rawMax = str2double(metaDataTags.RawMax);
        
        % De-normalize by multiplying by rawMax
        data.dataTimeSeries(:, rawDC_channels) = data.dataTimeSeries(:, rawDC_channels) * rawMax;
    else
        warning('Data is normalized but unknown max value, cannot be restored to original state');
    end
end

% Set raw data
fNIR.raw = data.dataTimeSeries;

% Initialize device structure
device = [];

% Handle time data
if isfield(data, 'time')
    if size(data.time, 1) > size(data.time, 2)
        % Ensure time is a row vector
        fNIR.time = data.time';
    else
        fNIR.time = data.time;
    end
    
    % Calculate sampling rate from time data
    fNIR.fs = 1/nanmedian(diff(fNIR.time));
else
    % Create time vector if not available
    warning('No time data found. Creating time vector with default sampling rate.');
    fNIR.fs = 10; % Default sampling rate
    fNIR.time = (0:(size(fNIR.raw, 1)-1))' / fNIR.fs;
end

if (isfield(metaDataTags,'Age') && ~isnumeric(metaDataTags.Age))
    metaDataTags.Age = str2double(metaDataTags.Age);
end

% Set metadata
fNIR.info = metaDataTags;

% Device config
device.Info.TimeIsSampleCount = 0;

% Get probe information
probeInfo = nirs.probe;

% Handle length unit conversion if needed
if strcmp(metaDataTags.LengthUnit, 'cm')
    % Convert from cm to mm for consistent internal representation
    probeInfo.detectorPos3D = probeInfo.detectorPos3D * 10;
    probeInfo.sourcePos3D = probeInfo.sourcePos3D * 10;
    if isfield(probeInfo, 'landmarkPos3D')
        probeInfo.landmarkPos3D = probeInfo.landmarkPos3D * 10;
    end
end

% Handle timestamp data
if isfield(metaDataTags, 'UnixTime')
    unixTime = str2double(metaDataTags.UnixTime);

    % Convert Unix time to datetime
    fNIR.t0 = datetime(unixTime, 'ConvertFrom', 'posixtime');

    if isfield(metaDataTags, 'MeasurementTimeZone')
        fNIR.t0.TimeZone = metaDataTags.MeasurementTimeZone;
    else
        fNIR.t0.TimeZone = 'local';
    end
elseif isfield(metaDataTags, 'MeasurementTime') && isfield(metaDataTags, 'MeasurementDate')
    hasMilliseconds = contains(metaDataTags.MeasurementTime, '.');
    dateTimeStr = [metaDataTags.MeasurementDate 'T' metaDataTags.MeasurementTime];
    
    try
        if hasMilliseconds
            try
                fNIR.t0 = datetime(dateTimeStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSz', 'TimeZone', 'GMT');
                if isfield(metaDataTags, 'MeasurementTimeZone')
                    fNIR.t0.TimeZone = metaDataTags.MeasurementTimeZone;
                else
                    fNIR.t0.TimeZone = 'local';
                end
            catch
                fNIR.t0 = datetime(dateTimeStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'local');
            end
        else
            try
                fNIR.t0 = datetime(dateTimeStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ssz', 'TimeZone', 'GMT');
                if isfield(metaDataTags, 'MeasurementTimeZone')
                    fNIR.t0.TimeZone = metaDataTags.MeasurementTimeZone;
                else
                    fNIR.t0.TimeZone = 'local';
                end
            catch
                fNIR.t0 = datetime(dateTimeStr, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss', 'TimeZone', 'local');
            end
        end
    catch
        warning('Failed to parse date/time information');
    end
end

% Set up device info for fNIR structure
device.cfg = pf2_base.external.INI();
device.Info.CfgName = 'generated SNIRF file';

% Set device manufacturer and model info if available
if isfield(metaDataTags, 'Model')
    device.Info.Name = metaDataTags.Model;
else
    device.Info.Name = 'Unknown Model';
end

if isfield(metaDataTags, 'ManufacturerName')
    device.Info.Manufacturer = metaDataTags.ManufacturerName;
else
    device.Info.Manufacturer = 'Unknown Manufacturer';
end 

% Set device sampling info
device.Info.DefaultSamplingRate = fNIR.fs;
device.Info.MaxSamplingRate = fNIR.fs;
device.Info.NumberProbes = 1;
device.Info.RawMax = nanmax(nanmax(fNIR.raw));
device.Info.RawMin = nanmin(nanmin(fNIR.raw));
device.Info.NumberChannels = 0;

% Process probe information
for p = 1:1 % Just one probe for now
    curProbeIdx = 1;
    device.Probe{p} = [];
    device.Probe{p}.TableSD = table();
    device.Probe{p}.TableCh = table(); % Map for raw probe data, 1 row per measurementList
    
    device.Probe{p}.TableCh.ColNumber = (1:height(measurementList))';
    numCh = height(measurementList);
    
    % Get unique optode pairs
    [~, firstOpt, uOpt] = unique(measurementList(:, {'sourceIndex','detectorIndex' }), 'rows',  'stable');
    device.Probe{p}.TableCh.OptodeNumber = uOpt;
    
    % Handle time signals
    timeSignalIdx = find(strcmp(measurementList.dataTypeLabel, 'time-signal'));
    if ~isempty(timeSignalIdx)
        firstOpt(firstOpt == timeSignalIdx) = []; % Remove time signal from "first opt" argument
        device.Probe{p}.TableCh.OptodeNumber(timeSignalIdx) = 0;
    end
    
    % Mark time and marker channels
    device.Probe{p}.TableCh.isTime = device.Probe{p}.TableCh.OptodeNumber == 0;
    device.Probe{p}.TableCh.isMarker = device.Probe{p}.TableCh.OptodeNumber < 0 | isnan(device.Probe{p}.TableCh.OptodeNumber);
    device.Probe{p}.TableCh.OptodeNumber(device.Probe{p}.TableCh.OptodeNumber < 1) = nan;
    device.Probe{p}.TableCh.isCh=device.Probe{p}.TableCh.OptodeNumber > 0;
    
    numOpt = length(firstOpt);
    
    % Reindex optodes for consistent ordering
    opt_list = device.Probe{p}.TableCh.OptodeNumber;
    reindexed_lookup = nan(numOpt, 2);
    reindexed_list = nan(size(opt_list));
    next_index = 1;
    
    for i = 1:length(opt_list)
        if isnan(opt_list(i))
            continue;
        end
        % Find if this optode number was already seen
        matchIdx = find(reindexed_lookup(:, 2) == opt_list(i), 1);
        if ~isempty(matchIdx)
            % Use the previously assigned index for this optode number
            reindexed_list(i) = reindexed_lookup(matchIdx, 1);
        else
            % Assign new sequential index
            reindexed_lookup(next_index, 1) = next_index;
            reindexed_lookup(next_index, 2) = opt_list(i);

            reindexed_list(i) = next_index;
            next_index = next_index + 1;
        end
    end
    
    device.Probe{p}.TableCh.OptodeNumber = reindexed_list;
    
    % Handle wavelength information
    validWVindex = ~isnan(measurementList.('wavelengthIndex')) & measurementList.('wavelengthIndex')>0;
    device.Probe{p}.TableCh.Wavelength(:) = nan;
    
    % Set wavelengths for valid indices
    if ~isempty(validWVindex) && any(validWVindex) && isfield(probeInfo, 'wavelengths')
        device.Probe{p}.TableCh.Wavelength(validWVindex) = probeInfo.wavelengths(measurementList{validWVindex, 'wavelengthIndex'})';
    end
    
    % Mark dark channels
    device.Probe{p}.TableCh.isDark = (isnan(device.Probe{p}.TableCh.Wavelength) | device.Probe{p}.TableCh.Wavelength == 0);
    
    % Explicitly mark dark channels based on dataTypeLabel
    darkLabelIdx = find(contains(measurementList.dataTypeLabel, 'dark'));
    if ~isempty(darkLabelIdx)
        device.Probe{p}.TableCh.isDark(darkLabelIdx) = true;
    end
    
    % Set source and detector indices
    device.Probe{p}.TableCh.SourceIndex(:) = measurementList.('sourceIndex');
    device.Probe{p}.TableCh.DetectorIndex(:) = measurementList.('detectorIndex');
    
    % Get unique sources and detectors
    uSrc = unique(device.Probe{p}.TableCh.SourceIndex);
    uDet = unique(device.Probe{p}.TableCh.DetectorIndex);
    
    numSrc = length(uSrc);
    numDet = length(uDet);
    
    % Create tables for source and detector positions
    device.Probe{p}.SrcPos = table();
    device.Probe{p}.DetPos = table();
    
    % Get source and detector positions
    srcXYZ = probeInfo.sourcePos3D;
    srcXYZ_2d = probeInfo.sourcePos2D;
    
    detXYZ = probeInfo.detectorPos3D;
    detXYZ_2d = probeInfo.detectorPos2D;
    
    % Store positions
    device.Probe{p}.SrcPosX = srcXYZ(:, 1);
    device.Probe{p}.SrcPosY = srcXYZ(:, 2);
    device.Probe{p}.SrcPosZ = srcXYZ(:, 3);
    device.Probe{p}.DetPosX = detXYZ(:, 1);
    device.Probe{p}.DetPosY = detXYZ(:, 2);
    device.Probe{p}.DetPosZ = detXYZ(:, 3);
    
    device.Probe{p}.SrcPos3D = srcXYZ;
    device.Probe{p}.DetPos3D = detXYZ;
    
    % Store 2D positions
    device.Probe{p}.SrcPos.x_2d = srcXYZ_2d(:, 1);
    device.Probe{p}.SrcPos.y_2d = srcXYZ_2d(:, 2);
    device.Probe{p}.SrcPos.z_2d = srcXYZ_2d(:, 1) * 0;
    device.Probe{p}.SrcPos.x = device.Probe{p}.SrcPosX(:);
    device.Probe{p}.SrcPos.y = device.Probe{p}.SrcPosY(:);
    device.Probe{p}.SrcPos.z = device.Probe{p}.SrcPosZ(:);
    
    device.Probe{p}.DetPos.x_2d = detXYZ_2d(:, 1);
    device.Probe{p}.DetPos.y_2d = detXYZ_2d(:, 2);
    device.Probe{p}.DetPos.z_2d = detXYZ_2d(:, 1) * 0;
    device.Probe{p}.DetPos.x = device.Probe{p}.DetPosX(:);
    device.Probe{p}.DetPos.y = device.Probe{p}.DetPosY(:);
    device.Probe{p}.DetPos.z = device.Probe{p}.DetPosZ(:);
    
    % Initialize channel labels
    device.Probe{p}.TableCh.Label(:) = "";
    
    % Set labels based on channel type
    for ch = 1:numCh
        if device.Probe{p}.TableCh.isTime(ch)
            device.Probe{p}.TableCh.Label(ch) = "Time"; 
        elseif device.Probe{p}.TableCh.isMarker(ch)
            device.Probe{p}.TableCh.Label(ch) = "Mrk";
        elseif device.Probe{p}.TableCh.isDark(ch)
            opt = device.Probe{p}.TableCh.OptodeNumber(ch);
            device.Probe{p}.TableCh.Label(ch) = sprintf('Opt%i_dark', opt);
        else
            wv = device.Probe{p}.TableCh.Wavelength(ch);
            opt = device.Probe{p}.TableCh.OptodeNumber(ch);
            device.Probe{p}.TableCh.Label(ch) = sprintf('Opt%i_wv%.1f', opt, wv);
        end
    end
    
    % Set up optode table
    device.Probe{p}.TableOpt = table();
    device.Probe{p}.TableOpt.OptodeNum(:) = (1:numOpt)';
    
    % Set source and detector indices for each optode
    device.Probe{p}.dI = measurementList.('detectorIndex');
    device.Probe{p}.sI = measurementList.('sourceIndex');
    
    device.Probe{p}.TableOpt.SrcIdx = measurementList{firstOpt, 'sourceIndex'};
    device.Probe{p}.TableOpt.DetIdx = measurementList{firstOpt, 'detectorIndex'};
    
    % Get unique source-detector pairs
    SDpairs = [device.Probe{p}.sI, device.Probe{p}.dI];
    SDpairs = SDpairs(sum(SDpairs,2)>0,:);
    [uPairs, ~, uPairIdx] = unique(SDpairs, 'rows', 'stable');
    validRows = ~isnan(sum(uPairs, 2));
    
    uPairs = uPairs(validRows, :);
    
    % Calculate optode positions
    for opt = 1:numOpt
        sIdx = device.Probe{p}.TableOpt.SrcIdx(opt);
        dIdx = device.Probe{p}.TableOpt.DetIdx(opt);
        
        if isnan(sIdx) || isnan(dIdx)
            srcPosX(opt) = nan;
            srcPosY(opt) = nan;
            srcPosZ(opt) = nan;
            detPosX(opt) = nan;
            detPosY(opt) = nan;
            detPosZ(opt) = nan;
            srcPos3D(opt, :) = nan(1, 3);
            detPos3D(opt, :) = nan(1, 3);
        else
            srcPosX(opt) = device.Probe{p}.SrcPosX(sIdx);
            srcPosY(opt) = device.Probe{p}.SrcPosY(sIdx);
            srcPosZ(opt) = device.Probe{p}.SrcPosZ(sIdx);
            detPosX(opt) = device.Probe{p}.DetPosX(dIdx);
            detPosY(opt) = device.Probe{p}.DetPosY(dIdx);
            detPosZ(opt) = device.Probe{p}.DetPosZ(dIdx);
            srcPos3D(opt, :) = device.Probe{p}.SrcPos3D(sIdx, :);
            detPos3D(opt, :) = device.Probe{p}.DetPos3D(dIdx, :);
        end
    end
    
    device.Probe{p}.SrcPosX = srcPosX';
    device.Probe{p}.SrcPosY = srcPosY';
    device.Probe{p}.SrcPosZ = srcPosZ';
    device.Probe{p}.DetPosX = detPosX';
    device.Probe{p}.DetPosY = detPosY';
    device.Probe{p}.DetPosZ = detPosZ';
    
    % Calculate optode midpoint positions
    device.Probe{p}.OptPosX = mean([device.Probe{p}.SrcPosX(:, 1), device.Probe{p}.DetPosX(:, 1)], 2);
    device.Probe{p}.OptPosY = mean([device.Probe{p}.SrcPosY(:, 1), device.Probe{p}.DetPosY(:, 1)], 2);
    device.Probe{p}.OptPosZ = mean([device.Probe{p}.SrcPosZ(:, 1), device.Probe{p}.DetPosZ(:, 1)], 2);
    device.Probe{p}.NumOptodes = numOpt;
    
    % Create optode position table
    device.Probe{p}.OptPos = table();
    device.Probe{p}.OptPos.x_2d = device.Probe{p}.OptPosX(:);
    device.Probe{p}.OptPos.y_2d = device.Probe{p}.OptPosY(:);
    device.Probe{p}.OptPos.z_2d = device.Probe{p}.OptPosZ(:);
    device.Probe{p}.OptPos.x = device.Probe{p}.OptPosX(:);
    device.Probe{p}.OptPos.y = device.Probe{p}.OptPosY(:);
    device.Probe{p}.OptPos.z = device.Probe{p}.OptPosZ(:);
    
    % Add positions to optode table
    device.Probe{p}.TableOpt.Pos2D_x = device.Probe{p}.OptPos.x_2d;
    device.Probe{p}.TableOpt.Pos2D_y = device.Probe{p}.OptPos.y_2d;
    device.Probe{p}.TableOpt.Pos2D_z = device.Probe{p}.OptPos.z_2d;
    
    device.Probe{p}.TableOpt.Pos3D_x = device.Probe{p}.OptPos.x;
    device.Probe{p}.TableOpt.Pos3D_y = device.Probe{p}.OptPos.y;
    device.Probe{p}.TableOpt.Pos3D_z = device.Probe{p}.OptPos.z;
    
    device.Probe{p}.DetPos3D = detPos3D;
    device.Probe{p}.SrcPos3D = srcPos3D;
    
    % Set up source-detector table
    device.Probe{p}.TableSD = table();
    
    Type_temp = [ones([height(device.Probe{p}.SrcPos), 1]); ones([height(device.Probe{p}.DetPos), 1]) * 2];
    typeStr_temp = {'Src', 'Det'};
    
    catType_temp = categorical(typeStr_temp(Type_temp(:)), typeStr_temp);
    device.Probe{p}.TableSD.Type = catType_temp(:);
    
    device.Probe{p}.TableSD.Index = [(1:height(device.Probe{p}.SrcPos))'; (1:height(device.Probe{p}.DetPos))'];
    
    for sd = 1:height(device.Probe{p}.TableSD)
        typeLabel = sprintf('%s', device.Probe{p}.TableSD.Type(sd));
        device.Probe{p}.TableSD.Label{sd} = sprintf('%s%i', typeLabel(1), device.Probe{p}.TableSD.Index(sd));
    end
    
    % Set source-detector positions
    device.Probe{p}.TableSD.Pos2D_x = [device.Probe{p}.SrcPos.x_2d(:); device.Probe{p}.DetPos.x_2d(:)];
    device.Probe{p}.TableSD.Pos2D_y = [device.Probe{p}.SrcPos.y_2d(:); device.Probe{p}.DetPos.y_2d(:)];
    device.Probe{p}.TableSD.Pos2D_z = [device.Probe{p}.SrcPos.z_2d(:); device.Probe{p}.DetPos.z_2d(:)];
    
    device.Probe{p}.TableSD.Pos3D_x = [device.Probe{p}.SrcPos.x(:); device.Probe{p}.DetPos.x(:)];
    device.Probe{p}.TableSD.Pos3D_y = [device.Probe{p}.SrcPos.y(:); device.Probe{p}.DetPos.y(:)];
    device.Probe{p}.TableSD.Pos3D_z = [device.Probe{p}.SrcPos.z(:); device.Probe{p}.DetPos.z(:)];
    
    device.Probe{p}.OptPos3D = (srcPos3D + detPos3D) / 2;
    
    % Calculate source-detector distances
    device.Probe{p}.SD = sqrt((device.Probe{p}.SrcPosX - device.Probe{p}.DetPosX).^2 + ...
        (device.Probe{p}.SrcPosY - device.Probe{p}.DetPosY).^2 + (device.Probe{p}.SrcPosZ - device.Probe{p}.DetPosZ).^2)';
    device.Probe{p}.IsShortSeparation = device.Probe{p}.SD < 20;
    device.Probe{p}.NumShortSeparation = sum(device.Probe{p}.IsShortSeparation);
    
    device.Probe{p}.TableOpt.SD = device.Probe{p}.SD(:);
    device.Probe{p}.TableOpt.IsShortSeparation = device.Probe{p}.IsShortSeparation(:);
    
    % Store channel mapping info
    device.Probe{p}.probeNum = 1;
    device.Probe{p}.wvI = reshape(measurementList.('wavelengthIndex'), [1, height(measurementList)]);
    device.Probe{p}.ChannelNumbers = uPairIdx';
    device.Probe{p}.ChannelList = 1:numCh;
    device.Probe{p}.Wavelength = probeInfo.wavelengths(:)';
    device.Info.NumberChannels = device.Info.NumberChannels + numCh;

     % Map wavelengths to channels
    for c = 1:numCh
        device.Probe{p}.TableOpt.Ch(c, :) = (find(device.Probe{p}.ChannelNumbers == device.Probe{p}.ChannelList(c)));
        wvIdxToMatch = device.Probe{p}.wvI(device.Probe{p}.TableOpt.Ch(c, :));
        if ~any(isnan(wvIdxToMatch))
            device.Probe{p}.TableOpt.wv(c, :) = device.Probe{p}.Wavelength(wvIdxToMatch);
        end

        device.Probe{p}.TableOpt.Label{c} = sprintf('Ch%i', device.Probe{p}.ChannelList(c));
    end
    
    % Generate probe layout
    if buildProbeLayout
        if isfield(device.Probe{p}, 'OptPosX') && isfield(device.Probe{p}, 'OptPosY')
            if includeSSchannels
                device.Probe{p}.OptLayout2D_ss = pf2_base.fitProbe2D(device.Probe{p}.OptPosX, device.Probe{p}.OptPosY, device.Probe{p}.OptPosZ);
            end
            
            device.Probe{p}.OptLayout2D = pf2_base.fitProbe2D(device.Probe{p}.OptPosX(~device.Probe{p}.IsShortSeparation), ...
                device.Probe{p}.OptPosY(~device.Probe{p}.IsShortSeparation), ...
                device.Probe{p}.OptPosZ(~device.Probe{p}.IsShortSeparation));
        else
            warning('buildProbeLayout option selected, but not enough information to generate Optode locations');
            device.Probe{p}.OptLayout2D = setUpFalse2D(device.Probe{p}.NumOptodes);
        end
    else
        device.Probe{p}.OptLayout2D = setUpFalse2D(device.Probe{p}.NumOptodes);
    end
    
    % Set subplot layout
    device.Probe{p}.OptPos.subplot_layout(:) = cell(size(device.Probe{p}.OptPos.z));
    device.Probe{p}.OptPos.subplot_layout(~device.Probe{p}.IsShortSeparation) = device.Probe{p}.OptLayout2D(:);
    
    if includeSSchannels
        device.Probe{p}.OptPos.subplot_layout_ss = device.Probe{p}.OptLayout2D_ss(:);
    else
        device.Probe{p}.OptPos.subplot_layout_ss = device.Probe{p}.OptPos.subplot_layout;
    end
end

% Import auxiliary data if available
if isfield(nirs, 'aux') && ~isempty(nirs.aux)
    fNIR.Aux = struct();
    
    for i = 1:length(nirs.aux)
        auxItem = nirs.aux(i);
        
        if ~isfield(auxItem, 'name') || ~isfield(auxItem, 'dataTimeSeries')
            continue;
        end
        
        % Create a valid field name
        fieldName = regexprep(auxItem.name, '[^a-zA-Z0-9_]', '_');
        
        % Create auxiliary data structure
        fNIR.Aux.(fieldName) = struct();
        fNIR.Aux.(fieldName).data = auxItem.dataTimeSeries;
        
        % Add time if available
        if isfield(auxItem, 'time')
            fNIR.Aux.(fieldName).time = auxItem.time;
        else
            fNIR.Aux.(fieldName).time = fNIR.time;
        end
        
        % Add unit if available
        if isfield(auxItem, 'dataUnit')
            fNIR.Aux.(fieldName).unit = auxItem.dataUnit;
        end
    end
end

% Set channel quality mask (all good by default)
fNIR.fchMask = ones(1, numCh);


% Save probe info
if isfield(fNIR, 'probeinfo')
    global setF
    device.cfg.add('Info', device.Info);
    for i = 1:length(device.Probe)
        device.cfg.add(sprintf('Probe%i', i), device.Probe{i});
    end
    
    setF.device = device;
else
    fNIR.probeinfo = device;
end


% Load existing channel mask if available and not checking
if ~channelCheck
    ch_mask_file = sprintf('%s_CH.mat', filepath);
    
    try
        fmask = load(ch_mask_file, 'fmask');
        fmask = fmask.fmask;
        fprintf('%i Channels marked bad\n', sum(fmask < 1));
    catch
        fprintf('No channel rejection present\n');
        fmask = [];
    end
else
    fmask = [];
end

% Run channel quality check if requested
if channelCheck
    fNIR = probeCheckGUI(fNIR, filepath, forceChannelCheck);
else
    if ~isempty(fmask)
        fNIR.fchMask = fmask;
    end
end

end

function opt_2d_coords = setUpFalse2D(numCh)
    % Create a fallback 2D layout when real coordinates aren't available
    opt_2d_coords = cell(1, numCh);
    
    for i = 1:numCh
        x1 = i - 1;
        x2 = 1;
        y1 = 0;
        y2 = 0.9;
        x2 = x2 / numCh;
        x1 = x1 / numCh;
        
        opt_2d_coords{i} = [x1, y1, x2, y2];
    end
end

function outTable = struct2table(structObj)
    % Convert structure array to table
    fieldsInStruct = fields(structObj(1));
   
    outTable = table();
    for n = 1:length(structObj)
        newTable = table();
        for f = 1:length(fieldsInStruct)
            % Handle various data types properly
            if isfield(structObj(n), fieldsInStruct{f})
                newTable.(fieldsInStruct{f}) = structObj(n).(fieldsInStruct{f});
                
                % Convert character arrays to cell strings
                if ischar(newTable.(fieldsInStruct{f})) || isstring(newTable.(fieldsInStruct{f}))
                    newTable.(fieldsInStruct{f}) = cellstr(newTable.(fieldsInStruct{f}));
                end
            else
                % Handle missing fields with empty values
                newTable.(fieldsInStruct{f}) = [];
            end
        end
        outTable = [outTable; newTable];
    end
end

function outStruct = stripStruct(structObj)
    % Clean up metadata structure by removing null characters and whitespace
    fieldsInStruct = fields(structObj);
   
    outStruct = structObj;
    
    for f = 1:length(fieldsInStruct)
        temp = structObj.(fieldsInStruct{f});
        
        % Only process character/string data
        if ischar(temp) || isstring(temp)
            % Remove null characters and trim whitespace
            outStruct.(fieldsInStruct{f}) = strtrim(strrep(reshape(temp, [1, length(temp)]), char(0), ''));
        end
    end
end