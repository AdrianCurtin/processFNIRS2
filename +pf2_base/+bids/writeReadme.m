function writeReadme(bidsRoot, opts, nRec, nSub)
% WRITEREADME Write a minimal BIDS dataset README
%
% BIDS recommends a top-level README. This writes a short factual stub naming
% the dataset and noting how it was produced; users are expected to expand it.
%
% Inputs:
%   bidsRoot - dataset root directory
%   opts     - options struct from pf2.export.asBIDS (Name)
%   nRec     - number of recordings written
%   nSub     - number of unique subjects
%
% Outputs:
%   (none) - Writes a README file.
%
% Example:
%   pf2_base.bids.writeReadme(root, opts, 8, 4);
%
% See also: pf2.export.asBIDS, pf2_base.bids.writeDatasetDescription

name = char(opts.Name);
if isempty(name)
    [~, folder] = fileparts(bidsRoot);
    name = folder;
end

lines = {
    name
    ''
    'This BIDS-NIRS dataset was exported by processFNIRS2 (pf2.export.asBIDS).'
    ''
    sprintf('Recordings: %d', nRec)
    sprintf('Participants: %d', nSub)
    ''
    ['Each recording is stored as raw SNIRF with BIDS sidecars ' ...
     '(_nirs.json, _channels.tsv, _optodes.tsv, _coordsystem.json) and, ' ...
     'where markers are present, _events.tsv.']
    ''
    'Please expand this README with study details, task descriptions, and provenance.'
    ''
    };

fid = fopen(fullfile(bidsRoot, 'README'), 'w', 'n', 'UTF-8');
if fid == -1
    error('pf2:bids:writeReadme:openFailed', 'Could not write README.');
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', lines{:});
end
