function [data, assetPath] = getAsset(assetName, varargin)
% GETASSET Load visualization assets (images, brain models, coordinate tables)
%
% Centralized asset loader for processFNIRS2 visualization functions.
% Handles path resolution across multiple asset locations and provides
% optional caching to avoid redundant file I/O.
%
% Syntax:
%   data = pf2_base.getAsset(assetName)
%   data = pf2_base.getAsset(assetName, 'cache', figHandle)
%   [data, assetPath] = pf2_base.getAsset(assetName)
%
% Inputs:
%   assetName   - Asset identifier (string). Supported assets:
%
%                 Brain Models (.mat):
%                   'cerebro_mdl'      - High-resolution brain mesh
%                   'cerebro_mdl_05'   - Low-resolution brain mesh
%                   'mni_t1'           - MNI T1 brain volume
%                   'brodmann'         - Brodmann area mapping
%                   'cerebro_1020'     - 10-20 EEG coordinate table
%
%                 Profile Images (.png):
%                   'sideprofile'      - Side profile brain image
%                   'rcSlice'          - Coronal slice image
%                   'topprofile'       - Top profile brain image
%
%
% Optional Parameters:
%   'cache'     - Figure handle for caching. If provided, loaded data is
%                 stored in figure's UserData to avoid reloading.
%                 Default: [] (no caching)
%   'pathOnly'  - If true, returns only the path without loading.
%                 Default: false
%
% Outputs:
%   data        - Loaded asset data (struct for .mat, image for .png/.bmp)
%   assetPath   - Full path to the asset file
%
% Asset Location:
%   <pf2_root>/assets/  - All visualization assets (brain models, images)
%
% Example:
%   % Load brain mesh
%   brainModel = pf2_base.getAsset('cerebro_mdl');
%
%   % Load with caching (recommended for repeated calls)
%   fig = gcf;
%   brainModel = pf2_base.getAsset('cerebro_mdl', 'cache', fig);
%
%   % Get path only
%   [~, path] = pf2_base.getAsset('sideprofile', 'pathOnly', true);
%
% See also: pf2.probe.plot.interpolateValues3D, imread, load

% Parse inputs
p = inputParser;
p.addRequired('assetName', @ischar);
p.addParameter('cache', [], @(x) isempty(x) || isgraphics(x));
p.addParameter('pathOnly', false, @islogical);
p.parse(assetName, varargin{:});

cacheHandle = p.Results.cache;
pathOnly = p.Results.pathOnly;

% Get pf2 root path
pf2Root = pf2_base.pf2_defaultRootPath();

% Asset registry: maps asset names to filenames
% Format: {assetName, filename}
% All assets are located in <pf2_root>/assets/
assetRegistry = {
    % Brain models (.mat)
    'cerebro_mdl',      'cerebro_mdl.mat'
    'cerebro_mdl_05',   'cerebro_mdl_05.mat'
    'mni_t1',           'mni_t1.mat'
    'brodmann',         'brodmann.mat'
    'cerebro_1020',     'cerebro_1020_table.mat'

    % Profile images (.png)
    'sideprofile',      'sideprofile_mid.png'
    'rcSlice',          'rcSlice.png'
    'topprofile',       'topprofile.png'
};

% Find asset in registry
assetIdx = find(strcmp(assetRegistry(:,1), assetName), 1);

% Assets folder path
assetsFolder = fullfile(pf2Root, 'assets');

if isempty(assetIdx)
    % Not in registry - try direct filename in assets folder
    [~, ~, ext] = fileparts(assetName);
    if isempty(ext)
        error('pf2_base:getAsset:unknownAsset', ...
            'Unknown asset: %s. Use full filename with extension or a registered asset name.', assetName);
    end
    filename = assetName;
else
    filename = assetRegistry{assetIdx, 2};
end

assetPath = fullfile(assetsFolder, filename);

% Verify file exists
if ~exist(assetPath, 'file')
    error('pf2_base:getAsset:fileNotFound', ...
        'Asset file not found: %s\nExpected location: %s', filename, assetPath);
end

% Return path only if requested
if pathOnly
    data = [];
    return;
end

% Check cache first
cacheKey = matlab.lang.makeValidName(['asset_' assetName]);
if ~isempty(cacheHandle) && isvalid(cacheHandle)
    if isfield(cacheHandle.UserData, cacheKey)
        data = cacheHandle.UserData.(cacheKey);
        return;
    end
end

% Load the asset
[~, ~, ext] = fileparts(assetPath);
switch lower(ext)
    case '.mat'
        loadedData = load(assetPath);
        % If MAT contains single variable with same name as asset, extract it
        fields = fieldnames(loadedData);
        if numel(fields) == 1
            data = loadedData.(fields{1});
        else
            % Return full struct for multi-variable MAT files
            data = loadedData;
        end

    case {'.png', '.bmp', '.jpg', '.jpeg', '.tif', '.tiff'}
        [data, map, alpha] = imread(assetPath);
        % Return struct with all image data if alpha channel exists
        if ~isempty(alpha)
            imgStruct.img = data;
            imgStruct.map = map;
            imgStruct.alpha = alpha;
            data = imgStruct;
        end

    otherwise
        error('pf2_base:getAsset:unsupportedFormat', ...
            'Unsupported asset format: %s', ext);
end

% Store in cache if handle provided
if ~isempty(cacheHandle) && isvalid(cacheHandle)
    cacheHandle.UserData.(cacheKey) = data;
end

end
