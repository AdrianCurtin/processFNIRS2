function mesh = corticalMesh(varargin)
% CORTICALMESH Cortical surface mesh registered to MNI space (mm)
%
% Loads the bundled `cerebro_mdl` cortical surface and returns its vertices in
% the same MNI millimetre frame used to plot optode positions, so a forward
% model evaluated on these vertices is spatially consistent with the probe.
% The bundled mesh ships in an arbitrary model frame (axis order and unit
% scale differ from MNI); this helper replicates the axis reorder and per-axis
% min/max-to-MNI mapping that `pf2.probe.plot.interpolateValues3D` applies so
% both share one coordinate system.
%
% Syntax:
%   mesh = pf2_base.dot.corticalMesh()
%   mesh = pf2_base.dot.corticalMesh('HighRes', false)
%
% Inputs (name-value):
%   'HighRes' - Use the full-resolution mesh (default true). False loads the
%               decimated `cerebro_mdl_05` mesh (faster forward builds, coarser
%               reconstruction grid).
%
% Outputs:
%   mesh - struct with fields:
%          .vertices [nV x 3] vertex positions in MNI mm
%          .faces    [nF x 3] triangle vertex indices (1-based)
%          .brodmann [nV x 1] nearest Brodmann area label per vertex
%          .centroid [1 x 3]  vertex centroid (used for outward normals)
%          .highRes  logical, which asset was loaded
%
% Notes:
%   - Vertex ORDER is preserved from the source asset, so per-vertex labels
%     (`brodmann`) and any externally computed per-vertex field stay aligned.
%   - The MNI bounds and axis reorder mirror `interpolateValues3D` exactly; if
%     that mapping changes, update both.
%   - Result is cached (persistent) per resolution; the returned struct is a
%     copy, safe for the caller to mutate.
%
% Example:
%   mesh = pf2_base.dot.corticalMesh();
%   trisurf(mesh.faces, mesh.vertices(:,1), mesh.vertices(:,2), ...
%       mesh.vertices(:,3));
%
% See also: pf2_base.dot.sensitivityMatrix, pf2.probe.plot.interpolateValues3D

persistent CACHE_HI CACHE_LO

p = inputParser;
addParameter(p, 'HighRes', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
highRes = p.Results.HighRes;

if highRes && ~isempty(CACHE_HI)
    mesh = CACHE_HI; return;
elseif ~highRes && ~isempty(CACHE_LO)
    mesh = CACHE_LO; return;
end

if highRes
    cMdl = pf2_base.getAsset('cerebro_mdl');
else
    cMdl = pf2_base.getAsset('cerebro_mdl_05');
end

% --- Axis reorder + per-axis min/max mapping to MNI bounds -----------------
% These constants mirror interpolateValues3D (MNI branch, useTalairach=false).
MNI_RosCaud = [75, -108];
MNI_RL      = [73, -71];
MNI_UD      = [83, -70 - 13.5];

reorderIdx = [3, 1, 2];
v = cMdl.v(:, reorderIdx);

mapAxis = @(col, bnd) (col - min(col)) ./ (max(col) - min(col)) ...
    * (bnd(1) - bnd(2)) + bnd(2);

vertices = [mapAxis(v(:,1), MNI_RL), ...
            mapAxis(v(:,2), MNI_RosCaud), ...
            mapAxis(v(:,3), MNI_UD)];

faces = cMdl.f.v(:, reorderIdx);

if isfield(cMdl, 'b_area')
    brodmann = cMdl.b_area(:);
else
    brodmann = zeros(size(vertices, 1), 1);
end

mesh = struct();
mesh.vertices = vertices;
mesh.faces    = faces;
mesh.brodmann = brodmann;
mesh.centroid = mean(vertices, 1);
mesh.highRes  = highRes;

if highRes
    CACHE_HI = mesh;
else
    CACHE_LO = mesh;
end
end
