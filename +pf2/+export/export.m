function export(data, filepath, varargin)
% EXPORT Auto-detect format and export fNIRS data to file
%
% Automatically detects the output format from the file extension and calls
% the appropriate exporter. If no filepath is provided, opens a save dialog
% for interactive selection.
%
% For batch export of a cell array to a directory, pass a directory path
% and a 'Format' name-value pair to select the output format.
%
% Syntax:
%   pf2.export.export(data, filepath)
%   pf2.export.export(data)
%   pf2.export.export(allData, 'output/', 'Format', 'snirf')  % Batch export
%
% Inputs:
%   data     - fNIRS data structure (processed or raw), or cell array for
%              batch export
%   filepath - (optional) Output file path or directory. Supported formats:
%              .nir     - fNIR Devices/Biopac format
%              .snirf   - SNIRF standardized format (recommended)
%              If omitted, opens save dialog for selection.
%
% Name-Value Parameters (batch mode):
%   'Format'  - Output format: 'snirf' or 'nir' (required for batch)
%   All other name-value pairs are passed through to the format exporter
%   (Dir1-Dir4, Prefix, Verbose, NormalizeRaw, StripExtraRawChannels).
%
% Example:
%   % Process and export with auto-detected format
%   data = pf2.import.import('subject01.nir');
%   processed = processFNIRS2(data);
%   pf2.export.export(processed, 'subject01_processed.snirf');
%
%   % Interactive save dialog
%   pf2.export.export(processed);
%
%   % Batch export cell array to directory
%   pf2.export.export(allData, 'output/', 'Format', 'snirf', 'Dir1', 'Group');
%
%   % Explicit format (bypasses auto-detect)
%   pf2.export.asSNIRF(processed, 'output.snirf');
%
% See also: pf2.export.asSNIRF, pf2.export.asNIR, pf2.import.import

if nargin < 1
    error('pf2:export:NoData', 'No data provided. Usage: pf2.export.export(data) or pf2.export.export(data, filepath)');
end

if nargin < 2 || isempty(filepath)
    % No filepath provided: open save dialog
    [file, path] = uiputfile({...
        '*.snirf', 'SNIRF Format (*.snirf)'; ...
        '*.nir', 'fNIR Devices/Biopac (*.nir)'; ...
        '*.*', 'All Files (*.*)'}, ...
        'Save fNIRS Data As');

    if isequal(file, 0)
        % User cancelled
        fprintf('Export cancelled.\n');
        return;
    end

    filepath = fullfile(path, file);
end

% --- Batch mode: cell array + directory path ---
[~, ~, ext] = fileparts(filepath);
if iscell(data) && (isempty(ext) || ~ismember(lower(ext), {'.snirf', '.nir'}))
    % Extract Format from varargin
    fmt = '';
    passArgs = {};
    i = 1;
    while i <= numel(varargin)
        if (ischar(varargin{i}) || isstring(varargin{i})) ...
                && strcmpi(varargin{i}, 'Format')
            if i < numel(varargin)
                fmt = lower(char(varargin{i+1}));
                i = i + 2;
                continue;
            end
        end
        passArgs{end+1} = varargin{i}; %#ok<AGROW>
        i = i + 1;
    end

    if isempty(fmt)
        error('pf2:export:NoFormat', ...
            'Batch export requires a ''Format'' parameter (''snirf'' or ''nir'').');
    end

    switch fmt
        case 'snirf'
            pf2.export.asSNIRF(data, filepath, passArgs{:});
        case 'nir'
            pf2.export.asNIR(data, filepath, passArgs{:});
        otherwise
            error('pf2:export:UnknownFormat', ...
                'Unknown format: ''%s''. Supported: ''snirf'', ''nir''.', fmt);
    end
    return;
end

% --- Single-file mode ---
ext = lower(ext);

% Route to appropriate exporter based on extension
switch ext
    case '.snirf'
        pf2.export.asSNIRF(data, filepath, varargin{:});

    case '.nir'
        pf2.export.asNIR(data, filepath, varargin{:});

    otherwise
        error('pf2:export:UnknownFormat', ...
            'Unknown output format: %s\nSupported formats: .snirf (recommended), .nir', ext);
end

% Display confirmation
fprintf('Exported: %s\n', filepath);
fprintf('  Format: %s\n', getFormatName(ext));

end

function name = getFormatName(ext)
% Return human-readable format name
switch lower(ext)
    case '.snirf'
        name = 'SNIRF';
    case '.nir'
        name = 'fNIR Devices/Biopac';
    otherwise
        name = 'Unknown';
end
end
