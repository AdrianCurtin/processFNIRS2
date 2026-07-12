function writeJson(filepath, s)
% WRITEJSON Write a struct as pretty-printed UTF-8 JSON
%
% Thin wrapper over jsonencode for the JSON sidecars in a BIDS dataset
% (dataset_description.json, *_nirs.json, *_coordsystem.json,
% participants.json). UTF-8 so non-ASCII metadata serializes correctly.
%
% Inputs:
%   filepath - Output path
%   s        - Struct to serialize
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeJson('dataset_description.json', struct('Name','x'));
%
% See also: pf2_base.bids.writeTsv

txt = jsonencode(s, 'PrettyPrint', true);
fid = fopen(filepath, 'w', 'n', 'UTF-8');
if fid == -1
    error('pf2:bids:writeJson:openFailed', 'Could not open %s for writing.', filepath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end
