classdef Device
% DEVICE Immutable value class encapsulating fNIRS device configuration
%
% Consolidates device properties (wavelengths, MNI positions, SD distances,
% channel layouts) into a single object with clean accessor methods.
% Replaces scattered access through globals (setF.device, PF2.curWvSet),
% deep struct navigation, and raw .cfg files.
%
% Attach to data structs as data.device for self-describing datasets.
%
% Syntax:
%   dev = pf2.Device.load('fNIR_Devices_fNIR2000')
%   dev = pf2.Device.load(data)
%   dev = pf2.Device.fromProbeInfo(probeInfo, 'myDevice')
%   pf2.Device.clearCache()
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   dev = pf2.Device.load(data);
%   dev.wavelengths()    % [730 850 0 730 850 0 ...]
%   dev.mniPositions()   % [18x3] MNI coordinates
%   dev.hasMNI()         % true
%
% See also: pf2_base.loadDeviceCfg, pf2_base.resolveDeviceFromData

    properties (SetAccess = immutable)
        name            % Config name, e.g. 'fNIR_Devices_fNIR2000'
        manufacturer    % e.g. 'fNIR Devices'
        model           % e.g. 'Model 2000'
        nChannels       % Measurement channel count
        nShortSep       % Short-separation channel count
        defaultFs       % Default sampling rate (Hz)
        wavelengthSet   % Unique wavelengths in nm, e.g. [730, 850]
        probeInfo       % Full legacy probeInfo struct (backward compat)
    end

    methods

        function obj = Device(probeInfo, name)
        % DEVICE Construct from probeInfo struct and config name
        %
        % Inputs:
        %   probeInfo - Full probeInfo struct with .Info and .Probe{1}
        %   name      - Config name string

            obj.probeInfo = probeInfo;
            obj.name = name;

            % Extract Info fields with safe fallbacks
            info = probeInfo.Info;
            if isfield(info, 'Manufacturer')
                obj.manufacturer = info.Manufacturer;
            else
                obj.manufacturer = '';
            end
            if isfield(info, 'Name')
                obj.model = info.Name;
            else
                obj.model = '';
            end
            if isfield(info, 'DefaultSamplingRate')
                obj.defaultFs = info.DefaultSamplingRate;
            else
                obj.defaultFs = NaN;
            end

            % Channel counts from first probe
            probe = probeInfo.Probe{1};
            obj.nChannels = probe.NumOptodes;
            if isfield(probe, 'NumShortSeparation')
                obj.nShortSep = probe.NumShortSeparation;
            else
                obj.nShortSep = 0;
            end

            % Unique wavelengths (excluding 0/NaN/dark)
            wl = probe.TableCh.Wavelength(:)';
            validWl = wl(wl > 0 & ~isnan(wl));
            obj.wavelengthSet = unique(validWl);
        end

        %% Accessor methods

        function wl = wavelengths(obj)
        % WAVELENGTHS Wavelength per raw column [1 x C_raw]
            wl = obj.probeInfo.Probe{1}.TableCh.Wavelength(:)';
        end

        function ch = channelNumbers(obj)
        % CHANNELNUMBERS Optode number per raw column [1 x C_raw]
            ch = obj.probeInfo.Probe{1}.TableCh.OptodeNumber(:)';
        end

        function cl = channelList(obj)
        % CHANNELLIST Unique channel indices [1 x nCh]
            cl = obj.probeInfo.Probe{1}.TableOpt.OptodeNum(:)';
        end

        function pos = mniPositions(obj)
        % MNIPOSITIONS MNI coordinates [nCh x 3]
        %
        % Returns empty [] if no 3D positions are available.
            tbl = obj.probeInfo.Probe{1}.TableOpt;
            if all(ismember({'Pos3D_x','Pos3D_y','Pos3D_z'}, tbl.Properties.VariableNames))
                pos = [tbl.Pos3D_x, tbl.Pos3D_y, tbl.Pos3D_z];
            else
                pos = [];
            end
        end

        function sd = sdDistances(obj)
        % SDDISTANCES Source-detector distances [1 x nCh]
            sd = obj.probeInfo.Probe{1}.TableOpt.SD(:)';
        end

        function tbl = channelTable(obj)
        % CHANNELTABLE Full channel table (TableCh)
            tbl = obj.probeInfo.Probe{1}.TableCh;
        end

        function tbl = optodeTable(obj)
        % OPTODETABLE Full optode table (TableOpt)
            tbl = obj.probeInfo.Probe{1}.TableOpt;
        end

        function lay = layout2D(obj)
        % LAYOUT2D Cell array of subplot positions
            if isfield(obj.probeInfo.Probe{1}, 'OptPos') && ...
                    ismember('subplot_layout', obj.probeInfo.Probe{1}.OptPos.Properties.VariableNames)
                lay = obj.probeInfo.Probe{1}.OptPos.subplot_layout;
            else
                lay = {};
            end
        end

        function tf = hasMNI(obj)
        % HASMNI True if 3D MNI positions are available
            tbl = obj.probeInfo.Probe{1}.TableOpt;
            tf = all(ismember({'Pos3D_x','Pos3D_y','Pos3D_z'}, tbl.Properties.VariableNames)) ...
                && ~isempty(tbl.Pos3D_x) && any(tbl.Pos3D_x ~= 0);
        end

        function tf = isShortSep(obj)
        % ISSHORTSEP Logical mask for short-separation channels [1 x nCh]
            tf = obj.probeInfo.Probe{1}.TableOpt.IsShortSeparation(:)';
        end

    end

    methods (Static)

        function dev = load(nameOrData)
        % LOAD Create Device from config name or data struct (cached)
        %
        % Syntax:
        %   dev = pf2.Device.load('fNIR_Devices_fNIR2000')
        %   dev = pf2.Device.load(data)
        %
        % Inputs:
        %   nameOrData - Config name string (without .cfg extension),
        %                OR fNIRS data struct with info.probename field

            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            % Handle cache clear sentinel
            if ischar(nameOrData) && strcmp(nameOrData, '__clear__')
                cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                dev = [];
                return;
            end

            % Resolve config name from data struct
            if isstruct(nameOrData)
                if isfield(nameOrData, 'info') && isfield(nameOrData.info, 'probename')
                    cfgName = nameOrData.info.probename;
                else
                    error('pf2:Device:load:noProbename', ...
                        'Data struct must have info.probename field.');
                end
            elseif ischar(nameOrData) || isstring(nameOrData)
                cfgName = char(nameOrData);
                % Strip .cfg extension if present
                cfgName = regexprep(cfgName, '\.cfg$', '');
            else
                error('pf2:Device:load:badInput', ...
                    'Input must be a config name string or fNIRS data struct.');
            end

            % Check for unknown/invalid probe names
            if contains(cfgName, 'Unknown') || contains(cfgName, 'Unkown')
                error('pf2:Device:load:unknownProbe', ...
                    'Cannot load Device for unknown probe: %s', cfgName);
            end

            % Return from cache if available
            if cache.isKey(cfgName)
                dev = cache(cfgName);
                return;
            end

            % Load from .cfg file (no global side-effects)
            probeInfo = pf2_base.loadDeviceCfg(cfgName, true, false);

            dev = pf2.Device(probeInfo, cfgName);
            cache(cfgName) = dev;
        end

        function dev = fromProbeInfo(probeInfo, name)
        % FROMPROBEINFO Create Device from an already-loaded probeInfo struct
        %
        % For SNIRF/NIRX imports where probeInfo is built in-memory.
        %
        % Syntax:
        %   dev = pf2.Device.fromProbeInfo(probeInfo, 'myDevice')
        %   dev = pf2.Device.fromProbeInfo(probeInfo)
        %
        % Inputs:
        %   probeInfo - Full probeInfo struct with .Info and .Probe{1}
        %   name      - Optional config name (default: from Info.CfgName)

            if nargin < 2 || isempty(name)
                if isfield(probeInfo, 'Info') && isfield(probeInfo.Info, 'CfgName')
                    name = probeInfo.Info.CfgName;
                else
                    name = 'custom';
                end
            end
            dev = pf2.Device(probeInfo, name);
        end

        function clearCache()
        % CLEARCACHE Reset the persistent Device cache
        %
        % Useful for testing or after device config files change.
            pf2.Device.load('__clear__');
        end

    end

end
