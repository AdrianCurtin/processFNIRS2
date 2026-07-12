function writeDatasetDescription(bidsRoot, opts)
% WRITEDATASETDESCRIPTION Write the required dataset_description.json
%
% Emits the BIDS dataset-level descriptor with the required Name and
% BIDSVersion, plus DatasetType and optional Authors/License.
%
% Inputs:
%   bidsRoot - dataset root directory
%   opts     - options struct from pf2.export.asBIDS (Name, BIDSVersion,
%              Authors, License)
%
% Outputs:
%   (none) - Writes dataset_description.json.
%
% Example:
%   pf2_base.bids.writeDatasetDescription(root, opts);
%
% See also: pf2.export.asBIDS, pf2_base.bids.writeReadme

name = char(opts.Name);
if isempty(name)
    [~, folder] = fileparts(bidsRoot);
    if isempty(folder)
        name = 'fNIRS dataset';
    else
        name = folder;
    end
end

s = struct();
s.Name = name;
s.BIDSVersion = char(opts.BIDSVersion);
s.DatasetType = 'raw';

if isfield(opts, 'Authors') && ~isempty(opts.Authors)
    % Cell array of char -> JSON array of strings
    s.Authors = opts.Authors;
end
if isfield(opts, 'License') && ~isempty(opts.License)
    s.License = char(opts.License);
end

pf2_base.bids.writeJson(fullfile(bidsRoot, 'dataset_description.json'), s);
end
