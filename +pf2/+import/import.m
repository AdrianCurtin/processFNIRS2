function data = import(filepath, varargin)
% IMPORT Auto-detect and import fNIRS data from a file or directory
%
% Automatically detects the input type and routes to the appropriate
% importer. Accepts a single file, a directory (batch import), or no
% argument (opens a file picker UI).
%
% Syntax:
%   data = pf2.import.import()                        % File picker UI
%   data = pf2.import.import(filepath)                % Single file
%   data = pf2.import.import(dirpath)                 % Directory (batch)
%   data = pf2.import.import(dirpath, Name, Value)    % Directory with options
%
% Inputs:
%   filepath - (optional) Path to an fNIRS data file or directory.
%              File: auto-detects format from extension and imports.
%                .nir     - fNIR Devices/Biopac format
%                .snirf   - SNIRF standardized format
%                .csv     - Hitachi ETG-4000 format
%                .hdr     - NIRx format (header file)
%                .wl1     - NIRx format (wavelength file)
%              Directory: scans for supported files and batch-imports.
%              Omitted: opens file browser dialog.
%
% Name-Value Parameters (directory mode only, passed to importDirectory):
%   'Pattern'         - Glob pattern override (default: auto-detected)
%   'Dir1'..'Dir4'    - Info field names for directory levels
%   'ChannelCheck'    - Show channel quality GUI (default: false)
%   'ContinueOnError' - Skip failed files (default: true)
%   'Verbose'         - Print progress (default: true)
%
% Outputs:
%   data - Single file: fNIRS data struct with .raw, .time, .fs, etc.
%          Directory:   Cell array of fNIRS data structs {1 x N}
%          Cancelled:   [] (empty)
%
% Example:
%   % Interactive file selection
%   data = pf2.import.import();
%
%   % Auto-detect format from extension
%   data = pf2.import.import('subject01.snirf');
%
%   % Batch import directory
%   allData = pf2.import.import('data/');
%
%   % Batch import with directory-to-info mapping
%   allData = pf2.import.import('data/', 'Dir1', 'Group', 'Dir2', 'SubjectID');
%
% See also: pf2.import.importNIR, pf2.import.importSNIRF,
%           pf2.import.importNIRX, pf2.import.importHitachiMES,
%           pf2.import.importDirectory, pf2.import.sampleData

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
        data = [];
        return;
    end

    filepath = fullfile(path, file);
end

filepath = char(filepath);

% --- Directory: batch import ---
if isfolder(filepath)
    % Extract Pattern param if provided, otherwise auto-detect
    patternIdx = find(strcmpi(varargin, 'Pattern'), 1);
    if ~isempty(patternIdx) && patternIdx < numel(varargin)
        pattern = varargin{patternIdx + 1};
        passThrough = varargin([1:patternIdx-1, patternIdx+2:end]);
    else
        pattern = detectPattern(filepath);
        passThrough = varargin;
    end

    data = pf2.import.importDirectory(filepath, pattern, passThrough{:});
    return;
end

% --- Single file ---
if ~exist(filepath, 'file')
    error('pf2:import:FileNotFound', 'File not found: %s', filepath);
end

[~, ~, ext] = fileparts(filepath);
ext = lower(ext);

switch ext
    case '.nir'
        data = pf2.import.importNIR(filepath);
    case '.snirf'
        data = pf2.import.importSNIRF(filepath);
    case '.csv'
        data = pf2.import.importHitachiMES(filepath);
    case {'.hdr', '.wl1', '.wl2'}
        data = pf2.import.importNIRX(filepath);
    otherwise
        error('pf2:import:UnknownFormat', ...
            'Unknown file format: %s\nSupported formats: .nir, .snirf, .csv, .hdr, .wl1', ext);
end

fprintf('Imported: %s\n', filepath);
fprintf('  Format: %s\n', getFormatName(ext));
fprintf('  Samples: %d\n', size(data.raw, 1));
fprintf('  Channels: %d\n', size(data.raw, 2));
fprintf('  Duration: %.1f seconds\n', data.time(end) - data.time(1));

end


% =========================================================================
% Local helper functions
% =========================================================================

function pattern = detectPattern(dirPath)
% DETECTPATTERN Scan directory for supported fNIRS files and return a glob pattern
%   Checks for each supported extension in priority order and returns the
%   first pattern that has matching files.

    extPriority = {'.snirf', '.nir', '.hdr', '.csv'};
    for k = 1:numel(extPriority)
        testPattern = ['*' extPriority{k}];
        found = dir(fullfile(dirPath, '**', testPattern));
        found = found(~[found.isdir]);
        if ~isempty(found)
            pattern = testPattern;
            return;
        end
    end

    error('pf2:import:NoSupportedFiles', ...
        'No supported fNIRS files found in %s\nSupported: .snirf, .nir, .hdr, .csv', dirPath);
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
