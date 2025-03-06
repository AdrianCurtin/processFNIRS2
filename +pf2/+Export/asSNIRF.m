function [snirfData] = asSNIRF(fNIRcells, filepath, normalizeRaw, stripExtraRawChannels)
%Takes fNIR struct and packages the .snirf file with improved Python compatibility
%   Use to construct .snirf files for export and packaging
%
%   fNIRcells - FNIR structure or cell array of structures
%   filepath - Output file location (optional, will prompt if not provided)
%   normalizeRaw - Whether to normalize raw data (false by default)
%   stripExtraRawChannels - Whether to remove dark channels 
%       (time and marker signals are always removed)
%
%   Returns the generated SNIRF data structure

if(nargin < 1)
    error('No fnir file specified!');
end

if nargin < 2
   [filename, path] = uiputfile(['*.snirf']); 
   filepath = [path filename];
end

if(nargin < 3)
    normalizeRaw = false;
end

if(nargin < 4)
    stripExtraRawChannels = false;
end

[ filepathdir, filename, ext ] = fileparts(filepath);

% Writing .snirf file
if(exist(filepathdir,'dir') ~= 7 && ~isempty(filepathdir))
    mkdir(filepathdir);
end

snirfData = [];

% SNIRF format version - use latest version for best compatibility
snirfData.formatVersion = c2v('1.1');

if(~iscell(fNIRcells) && isstruct(fNIRcells))
    fNIRcells = {fNIRcells};
elseif ~iscell(fNIRcells) || isempty(fNIRcells)
    error('Invalid fnirs data: Must be a structure or non-empty cell array of structures');
end

curNIR_fieldname = 'nirs';
numNIRS = length(fNIRcells);

for n = 1:numNIRS
    curStruct = fNIRcells{n};
    
    if(numNIRS > 1)
        curNIR_fieldname = ['nirs' num2str(n)];
    end

    curNIRdata = [];

    % Convert info to metadata with enhanced field mapping
    metaDataTags = info2meta(curStruct);

    % Build probe structure and measurement list
    [probe, measurementList, probeMetaData, rawMax, forceStrippedChannelsMask] = buildProbe(curStruct);

    % Handle extra channels if needed
    rawDCchannels = strcmp(cellfun(@(x) x, {measurementList.dataTypeLabel}, 'UniformOutput', false), 'raw-DC');
    rawDCdarkChannels = strcmp(cellfun(@(x) x, {measurementList.dataTypeLabel}, 'UniformOutput', false), 'raw-DC-dark');
    extraChannels = ~(rawDCchannels | rawDCdarkChannels);

    if(stripExtraRawChannels && ~isempty(extraChannels))
        measurementList = measurementList(~extraChannels);
        [uniqueWavelengths, ~, wavelengthIndices] = unique([measurementList.wavelengthIndex]);
        for i = 1:length(measurementList)
            measurementList(i).wavelengthIndex = wavelengthIndices(i);
        end
        probe.wavelengths = probe.wavelengths(uniqueWavelengths);

        % Now remove them from the indicies
        rawDCchannels = rawDCchannels(~extraChannels);
        rawDCdarkChannels = rawDCdarkChannels(~extraChannels);
    end

    % Add probe metadata to general metadata
    probeFields = fields(probeMetaData);
    for p = 1:length(probeFields)
        metaDataTags.(probeFields{p}) = probeMetaData.(probeFields{p});
    end
    
    % Set up data section with time series and measurement list
    data = [];
    data.dataTimeSeries = curStruct.raw(:,forceStrippedChannelsMask);
    
    % Handle time data
    if size(data.dataTimeSeries, 1) == length(curStruct.time)
        data.time = curStruct.time(:)';  % Ensure row vector
    else
        % Create regular time vector if dimensions don't match
        warning('Time vector dimensions do not match data. Creating regular time vector.');
        samplingRate = 1;
        if isfield(curStruct, 'fs') && ~isempty(curStruct.fs)
            samplingRate = curStruct.fs;
        end
        data.time = (0:(size(data.dataTimeSeries, 1)-1))' / samplingRate;
    end
    
    data.measurementList = measurementList;

    if(stripExtraRawChannels && ~isempty(extraChannels))
        data.dataTimeSeries = data.dataTimeSeries(:, ~extraChannels);
    end

    % Add units to measurement list (improves compatibility)
    for k = 1:length(data.measurementList)
        if ~isfield(data.measurementList(k), 'dataUnit') || isempty(data.measurementList(k).dataUnit)
            if strcmp(data.measurementList(k).dataTypeLabel, 'raw-DC')
                data.measurementList(k).dataUnit = c2v('V'); % Or appropriate unit
            elseif strcmp(data.measurementList(k).dataTypeLabel, 'raw-DC-dark')
                data.measurementList(k).dataUnit = c2v('V'); % Or appropriate unit
            end
        end
    end

    % Handle data normalization if requested
    if(normalizeRaw)
        rawDC_channels = rawDCchannels | rawDCdarkChannels;
        
        if(~isnan(rawMax))
            normalizedData = data.dataTimeSeries(:, rawDC_channels) ./ rawMax;
        else
            if(normalizeRaw > 1)
                estimatedRawMax = normalizeRaw;
            else
                estimatedRawMax = nanmax(nanmax(data.dataTimeSeries(:, rawDC_channels)));
                warning('Normalizing to estimated rawmax %i\nIf this is not your intention, please set the normalizeRaw value to match your intended device normalization', estimatedRawMax);
            end       
       
            normalizedData = data.dataTimeSeries(:, rawDC_channels) ./ estimatedRawMax;
            metaDataTags.('RawMax') = c2v(num2str(estimatedRawMax));
        end

        metaDataTags.('Normalized') = c2v('true');
        data.dataTimeSeries(:, rawDC_channels) = normalizedData;
    end

    % Set up stimulus data
    stim = [];

    if isfield(curStruct, 'markers') && ~isempty(curStruct.markers)
        % Check if markers is a table or numeric array
        if istable(curStruct.markers)
            % Handle table format
            markerNames = curStruct.markers.Properties.VariableNames;
            
            % Find columns that could contain marker values
            valueCol = find(contains(lower(markerNames), {'value', 'type', 'code', 'id'}), 1);
            if isempty(valueCol), valueCol = 2; end
            
            % Find time column
            timeCol = find(contains(lower(markerNames), {'time', 'onset'}), 1);
            if isempty(timeCol), timeCol = 1; end
            
            % Find duration column 
            durationCol = find(contains(lower(markerNames), {'duration', 'length'}), 1);
            if isempty(durationCol), durationCol = 3; end
            
            % Convert to numeric array if possible
            markerData = table2array(curStruct.markers);
            [uniqueMarkers, ~, markerIndices] = unique(markerData(:, valueCol));
            
            % Create stim entries for each unique marker
            for m = 1:length(uniqueMarkers)
                markerIdx = markerData(:, valueCol) == uniqueMarkers(m);
                stimItem = [];
                
                % Use name from table if available, otherwise generate
                if isfield(curStruct.markers, 'name')
                    stimNames = unique(curStruct.markers.name(markerIdx));
                    stimItem.name = c2v(stimNames{1});
                else
                    stimItem.name = c2v(sprintf('marker%i', uniqueMarkers(m)));
                end
                
                % Format as [startTime, duration, value]
                stimItem.data = markerData(markerIdx, [timeCol, durationCol, valueCol]);
                
                % Add labels if we have more than 3 columns
                if size(markerData, 2) > 3
                    stimLabels = {'startTime', 'duration', 'value'};
                    for col = 1:size(markerData, 2)
                        if col ~= timeCol && col ~= durationCol && col ~= valueCol
                            stimLabels{end+1} = markerNames{col};
                        end
                    end
                    stimItem.dataLabels = stimLabels;
                end
                
                if m == 1
                    stim = stimItem;
                else
                    stim(m) = stimItem;
                end
            end
        else
            % Handle numeric array format
            [uniqueMarkers, ~, markerIndices] = unique(curStruct.markers(:, 2));
            
            for m = 1:length(uniqueMarkers)
                markerIdx = curStruct.markers(:, 2) == uniqueMarkers(m);
                stimItem = [];
                stimItem.name = c2v(sprintf('mrk%i', uniqueMarkers(m)));
                
                % Standard format: [time, duration, marker value]
                stimItem.data = curStruct.markers(markerIdx, [1, 3, 2]);
                
                % Add dataLabels if more than 3 columns
                if size(curStruct.markers, 2) > 3
                    stimLabels = {'startTime', 'duration', 'value'};
                    for col = 4:size(curStruct.markers, 2)
                        stimLabels{end+1} = sprintf('column%d', col);
                    end
                    stimItem.dataLabels = stimLabels;
                end
                
                if m == 1
                    stim = stimItem;
                else
                    stim(m) = stimItem;
                end
            end
        end
    end
    
    % Add auxiliary data if available
    aux = [];
    if isfield(curStruct, 'Aux') && ~isempty(curStruct.Aux)
        auxFieldNames = fieldnames(curStruct.Aux);
        auxCounter = 0;
        
        for i = 1:length(auxFieldNames)
            auxField = curStruct.Aux.(auxFieldNames{i});
            
            % Handle different aux data formats
            if isstruct(auxField)
                if isfield(auxField, 'data') && ~isempty(auxField.data)
                    auxCounter = auxCounter + 1;
                    auxItem = [];
                    auxItem.name = c2v(auxFieldNames{i});
                    auxItem.dataTimeSeries = auxField.data;
                    
                    % Handle time data
                    if isfield(auxField, 'time')
                        auxItem.time = auxField.time(:)';  % Ensure row vector
                    else
                        auxItem.time = data.time;  % Use main time vector
                    end
                    
                    % Add unit if available
                    if isfield(auxField, 'unit')
                        auxItem.dataUnit = c2v(auxField.unit);
                    else
                        % Try to determine unit from name
                        if contains(lower(auxFieldNames{i}), {'accel'})
                            auxItem.dataUnit = c2v('m/s^2');
                        elseif contains(lower(auxFieldNames{i}), {'gyro'})
                            auxItem.dataUnit = c2v('rad/s');
                        else
                            auxItem.dataUnit = c2v('V');  % Default unit
                        end
                    end
                    
                    if auxCounter == 1
                        aux = auxItem;
                    else
                        aux(auxCounter) = auxItem;
                    end
                end
            elseif isnumeric(auxField) && ~isempty(auxField)
                % Direct numeric data
                auxCounter = auxCounter + 1;
                auxItem = [];
                auxItem.name = c2v(auxFieldNames{i});
                auxItem.dataTimeSeries = auxField;
                auxItem.time = data.time;  % Use main time vector
                
                % Try to determine unit from name
                if contains(lower(auxFieldNames{i}), {'accel'})
                    auxItem.dataUnit = c2v('m/s^2');
                elseif contains(lower(auxFieldNames{i}), {'gyro'})
                    auxItem.dataUnit = c2v('rad/s');
                else
                    auxItem.dataUnit = c2v('V');  % Default unit
                end
                
                if auxCounter == 1
                    aux = auxItem;
                else
                    aux(auxCounter) = auxItem;
                end
            end
        end
    end

    % Add coordinate system info to probe (helpful for spatial interpretation)
    if ~isfield(probe, 'coordinateSystem')
        probe.coordinateSystem = c2v('Other');
        probe.coordinateSystemDescription = c2v('Probe coordinate system');
    end
    
    % Assemble final structure
    curNIRdata.metaDataTags = metaDataTags;
    curNIRdata.probe = probe;
    
    if ~isempty(stim)
        curNIRdata.stim = stim;
    end
    
    curNIRdata.data = data;
    
    if ~isempty(aux)
        curNIRdata.aux = aux;
    end
    
    snirfData.(curNIR_fieldname) = curNIRdata;
end

if(isstring(filepath))
    filepath = char(filepath);
end

% Save the SNIRF file
pf2_base.external.jsnirfy.savesnirf(snirfData, filepath);

fprintf('Successfully exported SNIRF file to: %s\n', filepath);
end

function charOut = c2v(str)
    % Ensure consistent string format for HDF5 compatibility
    % This creates a variable-length string that works with Python's h5py
    if isempty(str)
        charOut = '';
        return;
    elseif isnumeric(str)
        charOut = num2str(str);
        return;
    end
    charOut = char(str);
end

function metaData = info2meta(nirStruct)
    % Enhanced metadata conversion with support for all requested fields
    
    metaData = [];
    
    % Required metadata fields per SNIRF spec
    metaData.TimeUnit = c2v('s');
    metaData.LengthUnit = c2v('mm');
    metaData.FrequencyUnit = c2v('Hz');
    
    % Check if info exists
    if ~isfield(nirStruct, 'info') || isempty(nirStruct.info)
        nirStruct.info = struct();
    end
    
    info = nirStruct.info;
    
    % Handle acquisition time metadata
    if isfield(nirStruct, 't0') && ~isempty(nirStruct.t0)
        % ISO 8601 formatted date
        try
            metaData.MeasurementDate = c2v(sprintf('%i-%02d-%02d', year(nirStruct.t0), month(nirStruct.t0), day(nirStruct.t0)));
            
            % ISO 8601 formatted time with milliseconds
            ms = floor(rem(second(nirStruct.t0), 1) * 1000);
            if ~isempty(nirStruct.t0.TimeZone)
                metaData.MeasurementTimeZone = c2v(nirStruct.t0.TimeZone);
                tzd = '';  % Timezone already included in t0
            else
                tzd = '';
            end
            
            metaData.MeasurementTime = c2v(sprintf('%02d:%02d:%02d.%03d%s', hour(nirStruct.t0), minute(nirStruct.t0), floor(second(nirStruct.t0)), ms, tzd));
            
            % Add Unix timestamps for easier cross-platform time handling
            metaData.AcquisitionStartTime = c2v(num2str(posixtime(nirStruct.t0 + seconds(min(nirStruct.time)))));
            metaData.UnixTime = c2v(num2str(posixtime(nirStruct.t0)));
        catch
            warning('Error processing t0 datetime. Using default values.');
        end
    end

    % Ensure required SubjectID is present
    if isfield(info, 'SubjectID') && ~isempty(info.SubjectID)
        metaData.SubjectID = c2v(info.SubjectID);
    elseif isfield(info, 'SubjectId') && ~isempty(info.SubjectId)
        metaData.SubjectID = c2v(info.SubjectId);
    elseif isfield(info, 'Subject') && ~isempty(info.Subject)
        metaData.SubjectID = c2v(info.Subject);
    else
        metaData.SubjectID = c2v('unknown');
    end
    
    % Map fields that might have different names 
    fieldMappings = containers.Map();
    fieldMappings('manufacturer') = 'ManufacturerName';
    fieldMappings('devicemanufacturer') = 'ManufacturerName';
    fieldMappings('devicemodel') = 'Model';
    fieldMappings('model') = 'Model';
    fieldMappings('subjectname') = 'SubjectName';
    fieldMappings('name') = 'SubjectName';
    fieldMappings('patientname') = 'SubjectName';
    fieldMappings('dateofbirth') = 'DateOfBirth';
    fieldMappings('dob') = 'DateOfBirth';
    fieldMappings('birthdate') = 'DateOfBirth';
    fieldMappings('acquisitionstarttime') = 'AcquisitionStartTime';
    fieldMappings('scantime') = 'AcquisitionStartTime';
    fieldMappings('studyid') = 'StudyID';
    fieldMappings('study') = 'StudyID';
    fieldMappings('projectid') = 'StudyID';
    fieldMappings('studydescription') = 'StudyDescription';
    fieldMappings('studyinfo') = 'StudyDescription';
    fieldMappings('projectdescription') = 'StudyDescription';
    fieldMappings('accession') = 'AccessionNumber';
    fieldMappings('accessionnumber') = 'AccessionNumber';
    fieldMappings('instance') = 'InstanceNumber';
    fieldMappings('instancenumber') = 'InstanceNumber';
    fieldMappings('calibrationfile') = 'CalibrationFileName';
    fieldMappings('calibration') = 'CalibrationFileName';
    fieldMappings('unixtime') = 'UnixTime';
    fieldMappings('unixtimestamp') = 'UnixTime';
    fieldMappings('lastname') = 'lastName';
    fieldMappings('surname') = 'lastName';
    fieldMappings('middlename') = 'middleName';
    fieldMappings('firstname') = 'firstName';
    fieldMappings('givenname') = 'firstName';
    fieldMappings('sex') = 'sex';
    fieldMappings('gender') = 'sex';
    fieldMappings('mne_coordframe') = 'MNE_coordFrame';
    fieldMappings('coordframe') = 'MNE_coordFrame';
    
    % Handle device info if it exists
    if isfield(info, 'device') && isstruct(info.device)
        if isfield(info.device, 'Manufacturer') && ~isempty(info.device.Manufacturer)
            metaData.ManufacturerName = c2v(info.device.Manufacturer);
        end
        if isfield(info.device, 'Model') && ~isempty(info.device.Model)
            metaData.Model = c2v(info.device.Model);
        end
    end
    
    % Copy all relevant info fields
    infoFields = fields(info);
    for i = 1:length(infoFields)
        fieldName = infoFields{i};
        fieldValue = info.(fieldName);
        
        % Check if this field maps to a requested field
        mappedName = '';
        if isKey(fieldMappings, lower(fieldName))
            mappedName = fieldMappings(lower(fieldName));
        end
        
        % Process field value based on type
        if (isstring(fieldValue) || ischar(fieldValue)) && ~isempty(fieldValue)
            if ~isempty(mappedName)
                metaData.(mappedName) = c2v(fieldValue);
            else
                metaData.(fieldName) = c2v(fieldValue);
            end
        elseif isnumeric(fieldValue) && all(size(fieldValue) == 1) && ~isempty(fieldValue)
            if ~isempty(mappedName)
                metaData.(mappedName) = c2v(num2str(fieldValue));
            else
                metaData.(fieldName) = c2v(num2str(fieldValue));
            end
        elseif isdatetime(fieldValue) && ~isempty(fieldValue)
            if ~isempty(mappedName)
                if strcmp(mappedName, 'DateOfBirth')
                    metaData.(mappedName) = c2v(datestr(fieldValue, 'yyyy-mm-dd'));
                else
                    metaData.(mappedName) = c2v(datestr(fieldValue));
                end
            else
                metaData.(fieldName) = c2v(datestr(fieldValue));
            end
        end
    end
    
    % Process composite name fields if they exist
    if ~isfield(metaData, 'SubjectName') && (isfield(metaData, 'lastName') || isfield(metaData, 'firstName'))
        lastName = '';
        firstName = '';
        middleName = '';
        
        if isfield(metaData, 'lastName')
            lastName = metaData.lastName;
        end
        
        if isfield(metaData, 'firstName')
            firstName = metaData.firstName;
        end
        
        if isfield(metaData, 'middleName')
            middleName = metaData.middleName;
        end
        
        % Construct full name
        if ~isempty(lastName) || ~isempty(firstName)
            if ~isempty(lastName) && ~isempty(firstName)
                if ~isempty(middleName)
                    metaData.SubjectName = c2v(sprintf('%s, %s %s', lastName, firstName, middleName));
                else
                    metaData.SubjectName = c2v(sprintf('%s, %s', lastName, firstName));
                end
            elseif ~isempty(lastName)
                metaData.SubjectName = c2v(lastName);
            else
                metaData.SubjectName = c2v(firstName);
            end
        end
    end
    
    % Add study information if available
    if isfield(info, 'Session') && ~isfield(metaData, 'StudyDescription')
        metaData.StudyDescription = c2v(['Session: ' info.Session]);
    end
    
    % Handle sampling rate if available
    if isfield(nirStruct, 'fs') && ~isempty(nirStruct.fs)
        metaData.SamplingRate = c2v(num2str(nirStruct.fs));
    end
end

function [probe, measurementList, deviceMetaDataTags, rawMax, strippedChannelsMask] = buildProbe(nirStruct)
    % Enhanced probe and measurement list builder
    
    % Initialize default values
    deviceMetaDataTags = [];
    rawMax = nan;
    strippedChannels=[];
    
    if isfield(nirStruct, 'probeinfo')
        probeStruct = nirStruct.probeinfo.Probe{1};
        deviceInfoFields = nirStruct.probeinfo.Info;
    else
        % Attempt to load probe from probe name
        if isfield(nirStruct.info, 'probename')
            probename = nirStruct.info.probename;
            if ~contains(probename, 'cfg')
                probename = sprintf('%s.cfg', probename);
            end
            try
                device = pf2_base.loadDeviceCfg(probename);
                deviceInfoFields = device.Info;
                probeStruct = device.Probe{1};
            catch
                warning('Failed to load probe configuration. Using default probe.');
                device = pf2_base.loadDeviceCfg();
                deviceInfoFields = device.Info;
                probeStruct = device.Probe{1};
            end
        else
            device = pf2_base.loadDeviceCfg();
            deviceInfoFields = device.Info;
            probeStruct = device.Probe{1};
        end
    end

    % Extract device metadata
    if isfield(deviceInfoFields, 'Manufacturer')
        deviceMetaDataTags.ManufacturerName = c2v(deviceInfoFields.Manufacturer);
    end
    if isfield(deviceInfoFields, 'Name')
        deviceMetaDataTags.Model = c2v(deviceInfoFields.Name);
    end
    if isfield(deviceInfoFields, 'RawMax')
        deviceMetaDataTags.RawMax = c2v(num2str(deviceInfoFields.RawMax));
        rawMax = deviceInfoFields.RawMax;
    end

    % Initialize measurement list
    tableCh = probeStruct.TableCh;

    % Wavelength handling
    if isfield(probeStruct, 'Wavelength')
        wvList = probeStruct.Wavelength;
        wvI = probeStruct.wvI;
    else
        [wvList, ~, wvI] = unique(tableCh.Wavelength);
    end
    
    % Handle dark channels
    if ~any(wvList == 0)
        wvList(end+1) = 0;
        darkIdx = length(wvList);
    else
        darkIdx = find(wvList == 0);
    end

    measurementList=[];
    
    % Build measurement list with enhanced info for each channel
    for i = 1:size(nirStruct.raw, 2)
        measurement = [];
        curCh = tableCh(i, :);

        if curCh.isTime(1)
            strippedChannels=[strippedChannels;i];
            continue;
        elseif curCh.isMarker(1)
            strippedChannels=[strippedChannels;i];
            continue;
        elseif curCh.isDark(1)
            measurement.dataType = 1; 
            measurement.dataTypeIndex = 1;
            measurement.dataTypeLabel = c2v('raw-DC-dark');
            measurement.detectorIndex = tableCh.DetectorIndex(i);
            measurement.sourceIndex = tableCh.SourceIndex(i);
            measurement.wavelengthIndex = wvI(i);
            measurement.wavelengthActual = wvList(darkIdx);
            measurement.dataUnit = c2v('au');
        else
            measurement.dataType = 1; 
            measurement.dataTypeIndex = 1;
            measurement.dataTypeLabel = c2v('raw-DC');
            measurement.detectorIndex = tableCh.DetectorIndex(i);
            measurement.sourceIndex = tableCh.SourceIndex(i);
            measurement.wavelengthIndex = wvI(i);
            measurement.wavelengthActual = wvList(measurement.wavelengthIndex);
            measurement.dataUnit = c2v('au');
        end
      
        measurementList = [measurementList; measurement];
    end

    strippedChannelsMask = true(1, size(nirStruct.raw, 2));
    if(~isempty(strippedChannels))
        strippedChannelsMask(strippedChannels)=false;
    end

    % Build probe structure
    probe = [];

    % Handle optode positions
    if height(probeStruct.DetPos) == height(probeStruct.SrcPos) && ...
            height(probeStruct.TableOpt) == height(probeStruct.DetPos)
        [~, firstDetIdx] = unique(probeStruct.TableOpt.DetIdx);
        [~, firstSrcIdx] = unique(probeStruct.TableOpt.SrcIdx);
    else
        firstDetIdx = 1:height(probeStruct.DetPos);
        firstSrcIdx = 1:height(probeStruct.SrcPos);
    end

    % Extract 2D and 3D positions
    probe.detectorPos2D = table2array(probeStruct.DetPos(firstDetIdx, {'x_2d', 'y_2d'}));
    probe.detectorPos3D = table2array(probeStruct.DetPos(firstDetIdx, {'x', 'y', 'z'}));
    probe.sourcePos2D = table2array(probeStruct.SrcPos(firstSrcIdx, {'x_2d', 'y_2d'}));
    probe.sourcePos3D = table2array(probeStruct.SrcPos(firstSrcIdx, {'x', 'y', 'z'}));

    % Include landmark positions if available
    if isfield(probeStruct, 'landmarkPos3D')
        probe.landmarkPos3D = probeStruct.landmarkPos3D;
    end
    if isfield(probeStruct, 'landmarkLabels')
        probe.landmarkLabels = probeStruct.landmarkLabels;
    end
    
    % Add source and detector labels if available
    if isfield(probeStruct, 'SrcPos') && isfield(probeStruct.SrcPos, 'Label')
        probe.sourceLabels = probeStruct.SrcPos.Label;
    end
    if isfield(probeStruct, 'DetPos') && isfield(probeStruct.DetPos, 'Label')
        probe.detectorLabels = probeStruct.DetPos.Label;
    end
    
    % Add coordinate system info
    probe.coordinateSystem = c2v('Other');
    probe.coordinateSystemDescription = c2v('Probe-specific coordinate system');
     
    % Add wavelengths
    probe.wavelengths = wvList;
end