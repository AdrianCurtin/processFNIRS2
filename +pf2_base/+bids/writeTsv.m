function writeTsv(filepath, headers, rows)
% WRITETSV Write a BIDS-style tab-separated file
%
% Writes a header row followed by data rows, tab-delimited, UTF-8, with the
% BIDS 'n/a' sentinel for missing values (handled by fmtCell). Used for
% events.tsv, channels.tsv, optodes.tsv and participants.tsv.
%
% Inputs:
%   filepath - Output path
%   headers  - 1xC cell array of column-name chars
%   rows     - NxC cell array of values (any scalar type per cell)
%
% Outputs:
%   (none) - Writes the file to disk.
%
% Example:
%   pf2_base.bids.writeTsv('events.tsv', {'onset','duration'}, {0,5; 10,5});
%
% See also: pf2_base.bids.fmtCell, pf2_base.bids.writeJson

nCol = numel(headers);
fid = fopen(filepath, 'w', 'n', 'UTF-8');
if fid == -1
    error('pf2:bids:writeTsv:openFailed', 'Could not open %s for writing.', filepath);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '%s\n', strjoin(headers, sprintf('\t')));

for r = 1:size(rows, 1)
    line = cell(1, nCol);
    for c = 1:nCol
        line{c} = pf2_base.bids.fmtCell(rows{r, c});
    end
    fprintf(fid, '%s\n', strjoin(line, sprintf('\t')));
end
end
