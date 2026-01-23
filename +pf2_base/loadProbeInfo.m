function probeInfo = loadProbeInfo(fNIR, buildProbeLayout, includeSS)
% LOADPROBEINFO Extract probe geometry from fNIRS data or device config
%
% Retrieves probe layout information including optode positions, channel
% mappings, and source-detector geometry. Uses embedded probe info if
% available in the fNIRS structure, otherwise loads from device configuration
% file based on the probe name in the data metadata.
%
% Reference:
%   Internal pf2 implementation for probe geometry management.
%
% Syntax:
%   probeInfo = loadProbeInfo(fNIR)
%   probeInfo = loadProbeInfo(fNIR, buildProbeLayout)
%   probeInfo = loadProbeInfo(fNIR, buildProbeLayout, includeSS)
%
% Inputs:
%   fNIR             - fNIRS data structure with one of:
%                      .probeinfo - Direct probe geometry (returned as-is)
%                      .info.probename - Device name for config file lookup
%   buildProbeLayout - Construct 2D/3D layouts from config (default: true)
%                      Set to false for faster loading when layout not needed.
%   includeSS        - Include short-separation channels (default: true)
%                      Set to false to exclude SS channels from probe info.
%
% Outputs:
%   probeInfo - Probe geometry structure containing:
%               .ChannelNumbers - Channel indices [1 x C]
%               .Wavelength     - Wavelengths per channel [1 x C*W]
%               .SD             - Source-detector distances [1 x C]
%               .sI, .dI        - Source/detector indices per channel
%               .DetPosX, .DetPosY, .DetPosZ - 2D detector positions
%               .SrcPosX, .SrcPosY, .SrcPosZ - 2D source positions
%               .DetPos3DX, etc. - 3D positions (MNI/Talairach)
%               Additional fields vary by device configuration.
%
% Algorithm:
%   1. Check for existing .probeinfo field (return directly if present)
%   2. Extract probe name from fNIR.info.probename
%   3. Load corresponding .cfg file via loadDeviceCfg
%   4. Extract first probe from multi-probe configurations
%
% Example:
%   % Get probe info from loaded data
%   data = pf2.import.importNIR('myfile.nir');
%   probeInfo = pf2_base.loadProbeInfo(data);
%   fprintf('Probe has %d channels\n', length(probeInfo.ChannelNumbers));
%
%   % Load without building layout (faster)
%   probeInfo = pf2_base.loadProbeInfo(data, false);
%
% Notes:
%   - Prompts for GUI device selection if probe name is missing/invalid
%   - Currently assumes single probe; multi-probe support is limited
%
% See also: loadDeviceCfg, buildProbeLayout, pf2_updateCurrentDevice
if(nargin < 2)
    buildProbeLayout=true;
end

if(nargin<3)
    includeSS=true;
end

if(isfield(fNIR,'probeinfo'))
    probeInfo=fNIR.probeinfo;
else
    numProbes = 1;
    cfgFilePaths = {};
    if(pf2_base.isnestedfield(fNIR,'info.probename')&&isfield(fNIR.info,'probename'))
        if(iscell(fNIR.info.probename))
            numProbes = length(fNIR.info.probename);
        end
        for i=1:numProbes
           if(numProbes == 1)
               probename = fNIR.info.probename;
           else
               probename = fNIR.info.probename{1};
           end
           if(~contains(probename, 'Unknown'))
               cfgFilePaths{i} = sprintf('%s.cfg', probename);
           else
               cfgFilePaths{i} = '';
           end
        end
    else
        cfgFilePaths{1} = '';
    end

    for i=1:length(cfgFilePaths)
        cfgFilePath = cfgFilePaths{i};
        if(isempty(cfgFilePath)||~contains(cfgFilePath,'.cfg'))
            
            warning('Missing or invalid configuration file path\n')
            
            disp('No device specified. Please load device configuration');
            probeInfo=pf2_base.loadDeviceCfg([],true);
            if(~isempty(probeInfo))
                error('No valid devices selected');
            end
            
        elseif(~isempty(cfgFilePath)) % If we're not looking at the GUI, doesn't matter
            probeInfo=pf2_base.loadDeviceCfg(cfgFilePath, buildProbeLayout, includeSS);
        end
    end
    
    if(pf2_base.isnestedfield(probeInfo,'Probe'))
        deviceInfo=probeInfo.Info;
        if(~isfield(deviceInfo,'numberProbes')||deviceInfo.numberProbes==1)
            probeNum=1;
        end
        probeInfo=probeInfo.Probe{probeNum};
    else
        error('Unable to identify probe');
    end
end