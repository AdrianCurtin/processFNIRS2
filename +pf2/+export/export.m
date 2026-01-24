function export(data, filepath)
% EXPORT Auto-detect format and export fNIRS data to file
%
% Automatically detects the output format from the file extension and calls
% the appropriate exporter. If no filepath is provided, opens a save dialog
% for interactive selection.
%
% Syntax:
%   pf2.export.export(data, filepath)
%   pf2.export.export(data)
%   pf2.export(data, filepath)       % Package-level call
%   pf2.export(data)                 % Interactive save dialog
%
% Inputs:
%   data     - fNIRS data structure (processed or raw)
%   filepath - (optional) Output file path. Supported formats:
%              .nir     - fNIR Devices/Biopac format
%              .snirf   - SNIRF standardized format (recommended)
%              If omitted, opens save dialog for selection.
%
% Example:
%   % Process and export with auto-detected format
%   data = pf2.import('subject01.nir');
%   processed = processFNIRS2(data);
%   pf2.export(processed, 'subject01_processed.snirf');
%
%   % Interactive save dialog
%   pf2.export(processed);
%
%   % Explicit format (bypasses auto-detect)
%   pf2.export.asSNIRF(processed, 'output.snirf');
%
% See also: pf2.export.asSNIRF, pf2.export.asNIR, pf2.import

if nargin < 1
    error('pf2:export:NoData', 'No data provided. Usage: pf2.export(data) or pf2.export(data, filepath)');
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

% Get file extension
[~, ~, ext] = fileparts(filepath);
ext = lower(ext);

% Route to appropriate exporter based on extension
switch ext
    case '.snirf'
        pf2.export.asSNIRF(data, filepath);

    case '.nir'
        pf2.export.asNIR(data, filepath);

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
