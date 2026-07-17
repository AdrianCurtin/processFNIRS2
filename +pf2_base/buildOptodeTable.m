function TableOpt = buildOptodeTable(probe)
% BUILDOPTODETABLE Assemble a per-channel TableOpt from a probe's geometry
%
% Builds the canonical per-channel optode table (TableOpt) that the rest of
% the toolbox consumes (device resolution in processFNIRS2, MNI positions,
% source-detector distances, short-separation flags, montage export). It is
% assembled from geometry fields an importer has already computed on a probe
% struct, so importers that build probe geometry in-memory (e.g.
% pf2.import.importNIRX) do not have to hand-roll the table.
%
% This produces the same OptodeNum / SrcIdx / DetIdx / Pos3D_* / SD /
% IsShortSeparation columns that pf2_base.loadDeviceCfg emits, so a
% TableOpt built here is interchangeable with one loaded from a .cfg.
%
% Syntax:
%   TableOpt = pf2_base.buildOptodeTable(probe)
%
% Inputs:
%   probe - A single probe struct (e.g. device.Probe{p}) carrying per-channel
%           geometry. Uses whichever of these fields are present:
%             .ChannelList        - 1 x nCh channel indices (else 1:nCh from SD/OptPos3D)
%             .OptPos3D           - nCh x 3 channel-midpoint MNI positions
%             .OptPosX/Y/Z        - nCh x 1 2D layout coordinates
%             .SD                 - 1 x nCh source-detector distances
%             .IsShortSeparation  - 1 x nCh logical (else derived as SD < 2)
%             .TableCh            - raw channel map; used to recover the
%                                   source/detector index of each channel
%
% Outputs:
%   TableOpt - nCh-row table with columns OptodeNum, SrcIdx, DetIdx,
%              Pos2D_x/y/z (when 2D coords are present), Pos3D_x/y/z (when 3D
%              coords are present), SD, IsShortSeparation. Position/SD columns
%              are simply omitted when the source geometry is unavailable.
%
% Example:
%   % Complete an in-memory NIRX probe so processFNIRS2 can resolve it
%   device.Probe{p}.TableOpt = pf2_base.buildOptodeTable(device.Probe{p});
%
% See also: pf2_base.loadDeviceCfg, pf2.import.importNIRX, pf2.Device

    % Channel count / list
    if isfield(probe, 'ChannelList') && ~isempty(probe.ChannelList)
        chList = probe.ChannelList(:);
    elseif isfield(probe, 'OptPos3D') && ~isempty(probe.OptPos3D)
        chList = (1:size(probe.OptPos3D, 1))';
    elseif isfield(probe, 'SD') && ~isempty(probe.SD)
        chList = (1:numel(probe.SD))';
    else
        error('pf2_base:buildOptodeTable:noChannels', ...
            'Probe has no ChannelList/OptPos3D/SD to determine channel count.');
    end
    nCh = numel(chList);

    TableOpt = table();
    TableOpt.OptodeNum = chList;

    % Source / detector index per channel (first raw measurement of each channel)
    src = nan(nCh, 1); det = nan(nCh, 1);
    if isfield(probe, 'TableCh') && istable(probe.TableCh) ...
            && all(ismember({'OptodeNumber','SourceIndex','DetectorIndex'}, ...
                            probe.TableCh.Properties.VariableNames))
        for c = 1:nCh
            idx = find(probe.TableCh.OptodeNumber == chList(c), 1);
            if ~isempty(idx)
                src(c) = probe.TableCh.SourceIndex(idx);
                det(c) = probe.TableCh.DetectorIndex(idx);
            end
        end
    end
    TableOpt.SrcIdx = src;
    TableOpt.DetIdx = det;

    % 2D layout coordinates
    if isfield(probe, 'OptPosX') && numel(probe.OptPosX) == nCh
        TableOpt.Pos2D_x = probe.OptPosX(:);
        if isfield(probe, 'OptPosY'), TableOpt.Pos2D_y = probe.OptPosY(:); end
        if isfield(probe, 'OptPosZ'), TableOpt.Pos2D_z = probe.OptPosZ(:); end
    end

    % 3D MNI channel-midpoint positions
    if isfield(probe, 'OptPos3D') && size(probe.OptPos3D, 1) == nCh
        TableOpt.Pos3D_x = probe.OptPos3D(:, 1);
        TableOpt.Pos3D_y = probe.OptPos3D(:, 2);
        TableOpt.Pos3D_z = probe.OptPos3D(:, 3);
    end

    % Source-detector distance
    if isfield(probe, 'SD') && numel(probe.SD) == nCh
        TableOpt.SD = probe.SD(:);
    end

    % Short-separation flag (derive from SD when not supplied)
    if isfield(probe, 'IsShortSeparation') && numel(probe.IsShortSeparation) == nCh
        TableOpt.IsShortSeparation = logical(probe.IsShortSeparation(:));
    elseif ismember('SD', TableOpt.Properties.VariableNames)
        TableOpt.IsShortSeparation = TableOpt.SD < 2;
    end

end
