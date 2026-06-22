function probe = syncOptodeCoords(probe)
% SYNCOPTODECOORDS Mirror canonical TableOpt coordinates into the OptPos view.
%
% The probe geometry is stored canonically in TableOpt.Pos3D_x/y/z (3D) and
% TableOpt.Pos2D_x/y/z (2D). For historical reasons a parallel OptPos table
% also exposes the same per-optode coordinates as columns x/y/z (3D) and
% x_2d/y_2d/z_2d (2D) -- this is the interface the 3D renderer and the EEG
% path read. Keeping two copies invites divergence, so this helper makes
% TableOpt the single source of truth and writes OptPos as a derived view.
%
% Call it at every site that sets or mutates optode coordinates (device load,
% SNIRF/NIRx import, MNI registration) so the two stores cannot drift apart.
%
% Inputs:
%   probe - A probe struct with a TableOpt table and (optionally) an OptPos
%           table. Missing coordinate columns are skipped; a probe without an
%           OptPos table is returned unchanged.
%
% Outputs:
%   probe - The probe with OptPos.x/y/z and x_2d/y_2d/z_2d synced from
%           TableOpt.Pos3D_* and Pos2D_* respectively.
%
% Example:
%   probe.TableOpt.Pos3D_x = optMNI(:,1); % ... y, z
%   probe = pf2_base.syncOptodeCoords(probe);
%
% See also: pf2_base.loadDeviceCfg, pf2.probe.plot.interpolateValues3D

    if ~isfield(probe, 'OptPos') || ~istable(probe.OptPos)
        return;
    end
    if ~isfield(probe, 'TableOpt') || ~istable(probe.TableOpt)
        return;
    end

    vn = probe.TableOpt.Properties.VariableNames;

    if all(ismember({'Pos3D_x', 'Pos3D_y', 'Pos3D_z'}, vn))
        probe.OptPos.x = probe.TableOpt.Pos3D_x(:);
        probe.OptPos.y = probe.TableOpt.Pos3D_y(:);
        probe.OptPos.z = probe.TableOpt.Pos3D_z(:);
    end

    if all(ismember({'Pos2D_x', 'Pos2D_y', 'Pos2D_z'}, vn))
        probe.OptPos.x_2d = probe.TableOpt.Pos2D_x(:);
        probe.OptPos.y_2d = probe.TableOpt.Pos2D_y(:);
        probe.OptPos.z_2d = probe.TableOpt.Pos2D_z(:);
    end
end
