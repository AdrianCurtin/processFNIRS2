function data = import(filepath)
% IMPORT Auto-detect and import fNIRS data from file
%
% Automatically detects the file format from the extension and calls the
% appropriate importer. If no filepath is provided, opens a file browser
% dialog for interactive selection.
%
% Syntax:
%   data = pf2.import.import(filepath)
%   data = pf2.import.import()
%
% Inputs:
%   filepath - (optional) Path to fNIRS data file. Supported formats:
%              .nir     - fNIR Devices/Biopac format
%              .snirf   - SNIRF standardized format
%              .csv     - Hitachi ETG-4000 format
%              .hdr     - NIRx format (header file)
%              .wl1     - NIRx format (wavelength file)
%              If omitted, opens file browser for selection.
%
% Outputs:
%   data     - fNIRS data structure with fields:
%              .raw, .time, .fs, .fchMask, .markers, .info
%
% Example:
%   % Auto-detect format from extension
%   data = pf2.import('subject01.nir');
%
%   % Interactive file selection
%   data = pf2.import();
%
%   % Explicit format (bypasses auto-detect)
%   data = pf2.import.importNIR('subject01.nir');
%
% See also: pf2.import.importNIR, pf2.import.importSNIRF,
%           pf2.import.importNIRX, pf2.import.importHitachiMES,
%           pf2.import.sampleData

if nargin < 1 || isempty(filepath)
    % No filepath provided: open file browser
    [file, path] = uigetfile({...
        '*.nir', 'fNIR Devices/Biopac (*.nir)'; ...
        '*.snirf', 'SNIRF Format (*.snirf)'; ...
        '*.csv', 'Hitachi ETG-4000 (*.csv)'; ...
        '*.hdr', 'NIRx Format (*.hdr)'; ...
        '*.wl1', 'NIRx Wavelength (*.wl1)'; ...
        '*.*', 'All Files (*.*)'}, ...
        'Select fNIRS Data File');

    if isequal(file, 0)
        % User cancelled
        data = [];
        return;
    end

    filepath = fullfile(path, file);
end

% Validate file exists
if ~exist(filepath, 'file')
    error('pf2:import:FileNotFound', 'File not found: %s', filepath);
end

% Get file extension
[~, ~, ext] = fileparts(filepath);
ext = lower(ext);

% Route to appropriate importer based on extension
switch ext
    case '.nir'
        data = pf2.import.importNIR(filepath);

    case '.snirf'
        data = pf2.import.importSNIRF(filepath);

    case '.csv'
        data = pf2.import.importHitachiMES(filepath);

    case {'.hdr', '.wl1', '.wl2'}
        % NIRx files - use the header or wavelength file
        data = pf2.import.importNIRX(filepath);

    otherwise
        error('pf2:import:UnknownFormat', ...
            'Unknown file format: %s\nSupported formats: .nir, .snirf, .csv, .hdr, .wl1', ext);
end

% Display confirmation
fprintf('Imported: %s\n', filepath);
fprintf('  Format: %s\n', getFormatName(ext));
fprintf('  Samples: %d\n', size(data.raw, 1));
fprintf('  Channels: %d\n', size(data.raw, 2));
fprintf('  Duration: %.1f seconds\n', data.time(end) - data.time(1));

end

function name = getFormatName(ext)
% Return human-readable format name
switch lower(ext)
    case '.nir'
        name = 'fNIR Devices/Biopac';
    case '.snirf'
        name = 'SNIRF';
    case '.csv'
        name = 'Hitachi ETG-4000';
    case {'.hdr', '.wl1', '.wl2'}
        name = 'NIRx';
    otherwise
        name = 'Unknown';
end
end
