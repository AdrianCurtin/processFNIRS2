function assetList = listAssets(category)
% LISTASSETS Display available visualization assets
%
% Lists all registered assets available through pf2_base.getAsset().
% Optionally filter by category.
%
% Syntax:
%   pf2_base.listAssets()
%   pf2_base.listAssets(category)
%   assetList = pf2_base.listAssets()
%
% Inputs:
%   category - Optional filter: 'brain', 'profile', or 'all'
%              Default: 'all'
%
% Outputs:
%   assetList - Table of available assets (if output requested)
%
% Example:
%   % Display all assets
%   pf2_base.listAssets()
%
%   % List only brain model assets
%   pf2_base.listAssets('brain')
%
%   % Get as table
%   assets = pf2_base.listAssets();
%
% See also: pf2_base.getAsset

if nargin < 1
    category = 'all';
end

% Asset definitions (all in assets/ folder)
assets = {
    % Name                          Description                         Category
    'cerebro_mdl'                   'High-res brain mesh model'         'brain'
    'cerebro_mdl_05'                'Low-res brain mesh model'          'brain'
    'mni_t1'                        'MNI T1 brain volume'               'brain'
    'brodmann'                      'Brodmann area mapping'             'brain'
    'cerebro_1020'                  '10-20 EEG coordinate table'        'brain'
    'sideprofile'                   'Side profile brain image'          'profile'
    'rcSlice'                       'Coronal slice image'               'profile'
    'topprofile'                    'Top profile brain image'           'profile'
};

% Filter by category
if ~strcmp(category, 'all')
    validCategories = {'brain', 'profile'};
    if ~ismember(category, validCategories)
        error('Invalid category. Use: %s', strjoin(validCategories, ', '));
    end
    idx = strcmp(assets(:,3), category);
    assets = assets(idx, :);
end

% Create table
assetTable = cell2table(assets, ...
    'VariableNames', {'Name', 'Description', 'Category'});

% Display or return
if nargout == 0
    fprintf('\n=== processFNIRS2 Visualization Assets ===\n\n');
    fprintf('Usage: data = pf2_base.getAsset(''assetName'')\n\n');

    categories = unique(assetTable.Category);
    for i = 1:length(categories)
        cat = categories{i};
        fprintf('--- %s ---\n', upper(cat));
        idx = strcmp(assetTable.Category, cat);
        catAssets = assetTable(idx, :);
        for j = 1:height(catAssets)
            fprintf('  %-35s %s\n', catAssets.Name{j}, catAssets.Description{j});
        end
        fprintf('\n');
    end
else
    assetList = assetTable;
end

end
