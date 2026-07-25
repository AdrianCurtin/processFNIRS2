function outPath = asTensor(data, path, opts)
% ASTENSOR Export fNIRS data as a self-describing HDF5 tensor (contract v1.0)
%
% Writes a single, versioned, cross-language .h5 file implementing the
% foundation-model export contract (TRANSFORMER_ROADMAP.md §4). The file is
% self-describing: numeric arrays are stored as native HDF5 datasets so that
% Python h5py reads them with zero custom decoding, while all structured
% metadata (montage descriptor, QC, markers, info, provenance) is stored as
% UTF-8 JSON strings so the Python side can recover it with json.loads().
%
% The tensor payload follows the canonical [time x channel x feature] shape
% (or [window x time x channel x feature] when a windowing layer is supplied),
% where the feature axis stacks the selected biomarker fields (e.g. HbO/HbR).
% The montage descriptor is reused verbatim from pf2.probe.montage so the
% payload stays montage-agnostic, and the manifest carries QC, markers, the
% marker dictionary, demographics, and full processing provenance.
%
% Cross-language axis convention:
%   Numeric datasets are written so that numpy/h5py reads them in the order
%   given by the `dims` attribute (row-major). MATLAB is column-major and
%   HDF5/h5py is row-major, so MATLAB writers/readers reverse axes
%   accordingly: before h5write we permute the tensor to reversed dimension
%   order, which makes a Python consumer doing f['/tensor'][()] obtain shape
%   (T, C, F) (or (W, T, C, F) windowed) matching `dims`. A MATLAB reader of
%   the same dataset (this module's importEmbeddings, the tests) must reverse
%   axes again on read to recover the forward layout. 1-D datasets (/time,
%   /windowOnsets) are axis-order invariant.
%
% Reference:
%   processFNIRS2 foundation-model export contract v1.0.
%   See internal/TRANSFORMER_ROADMAP.md §4 ("The Export Contract").
%   HDF5 storage aligns with the existing SNIRF/HDF5 dependency.
%
% Syntax:
%   outPath = pf2.export.asTensor(data, path)
%   outPath = pf2.export.asTensor(data, path, 'Features', {'HbO','HbR'})
%   outPath = pf2.export.asTensor(data, path, 'Windows', windows)
%   outPath = pf2.export.asTensor(data, path, 'QC', true)
%   outPath = pf2.export.asTensor(data, path, 'QC', report)
%
% Inputs:
%   data - Processed fNIRS data struct. Must contain .time and the biomarker
%          fields selected via 'Features' (each [T x C], equal-sized). A
%          .device is required for the montage descriptor; .markers, .info,
%          and .processingInfo are included in the manifest when present.
%   path - Output .h5 file path [char/string]. A trailing '.h5' is appended
%          when missing. An existing file at this path is overwritten.
%          If omitted or empty, a save dialog opens.
%
% Name-Value Parameters:
%   'Features'        - Cell array of biomarker field names to stack along the
%                       feature axis (default: the biomarker fields present in
%                       priority {'HbO','HbR','HbTotal','HbDiff','CBSI'}; if
%                       none are present, falls back to 'OD' then 'raw').
%                       Each field must exist and be [T x C] equal-sized.
%   'Windows'         - Block/segment definition for the windowing layer: a
%                       cell array of extracted-segment structs (as produced by
%                       pf2.data.slidingWindows + pf2.data.extractBlocks) or a
%                       struct array. When supplied, the tensor is written as
%                       [W x T x C x F] and a /windowOnsets dataset is added
%                       (default: [], unwindowed [T x C x F]).
%   'QC'              - Include the QC manifest (default: false). Either a
%                       logical (true runs pf2.qc.pipeline.assess) or a
%                       precomputed report struct from that function.
%   'Aux'             - Auxiliary signals (and derived features) to align onto
%                       the tensor time grid and write to /aux. A cellstr of
%                       aux base names (e.g. {'heartRate','accelerometer'}) or
%                       true / 'all' for every aux signal present (default: {}).
%                       Multichannel signals expand to one /aux column each;
%                       windowed exports align per window.
%   'ContractVersion' - Contract version string written to the root attribute
%                       (default: the module default '1.0').
%
% Outputs:
%   outPath - Absolute path of the written .h5 file [char].
%
% On-disk schema (contract v1.0):
%   Root attributes:
%     pf2ContractVersion - '1.0'
%     createdBy          - 'processFNIRS2'
%     dims               - 'time x channel x feature' or
%                          'window x time x channel x feature'
%     samplingRate       - sampling rate in Hz [double]
%     units              - biomarker units [string]
%     featureNames       - selected feature names [string array]
%     nWindows           - number of windows (0 when unwindowed) [int]
%     nAux               - number of aux columns written to /aux [int]
%   /tensor          - float32, read by h5py as (T, C, F) or (W, T, C, F)
%                      matching `dims` (stored axis-reversed on disk so the
%                      row-major reader sees the forward order)
%   /time            - double [T x 1]
%   /windowOnsets    - double [W] (only when windowed)
%   /aux             - float32 [T x K] or [W x T x K] (only when 'Aux' given),
%                      with /aux attributes auxNames and auxUnits [string array]
%                      and dims; aligned to /time
%   /montage         - string, jsonencode of pf2.probe.montage descriptor
%   /manifest/qc            - string, JSON of QC report (when 'QC' requested)
%   /manifest/markers       - string, JSON of the canonical marker table
%   /manifest/markerDict    - string, JSON of pf2.data.getMarkerDict
%   /manifest/info          - string, JSON of data.info
%   /manifest/processingInfo - string, JSON of data.processingInfo (when present)
%
% Algorithm:
%   1. Resolve and validate the feature fields (equal-sized [T x C]).
%   2. Stack features into [T x C x F] (or epoch via 'Windows' to [W x T x C x F]).
%   3. Cast the tensor to single (float32) and write /tensor + /time as native
%      HDF5 datasets.
%   4. Build the montage descriptor (pf2.probe.montage) and the manifest blobs
%      (QC, markers, markerDict, info, processingInfo) and write each as a
%      UTF-8 JSON string dataset.
%   5. Write the root attributes (version, dims, fs, units, feature names).
%
% Example:
%   % Default export: stack the present biomarkers (HbO/HbR/...)
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   outPath = pf2.export.asTensor(proc, 'sub-01.h5');
%
%   % Windowed export for fixed-length model input, with QC manifest
%   blocks  = pf2.data.slidingWindows(proc, 'Length', 10, 'Embed', false);
%   windows = pf2.data.extractBlocks(proc, blocks, 'PreTime', 0, 'PostTime', 0);
%   outPath = pf2.export.asTensor(proc, 'sub-01_win.h5', ...
%       'Windows', windows, 'Features', {'HbO','HbR'}, 'QC', true);
%
% Notes:
%   - Numeric payloads (/tensor, /time, /windowOnsets) are native datasets so
%     Python h5py reads them directly; all metadata is JSON text decodable with
%     json.loads(). This keeps the contract cross-language.
%   - Windowed export truncates every window to the shortest common length so
%     the [W x T x C x F] tensor is rectangular.
%   - path is required in headless sessions (pf2_base.isHeadless()): the GUI
%     save dialog cannot be shown, so a missing path errors with
%     'pf2:export:asTensor:noPathHeadless' instead of hanging/crashing.
%   - String datasets are written as true scalar (H5S_SCALAR) variable-length
%     UTF-8 strings via the low-level HDF5 API, so h5py reads each as a single
%     scalar (bytes) that json.loads() decodes directly — not a 1-element
%     ndarray.
%
% See also: pf2.import.importEmbeddings, pf2.probe.montage,
%           pf2.data.slidingWindows, pf2.data.extractBlocks,
%           pf2.qc.pipeline.assess, pf2.export.asSNIRF

%% Parse inputs
% The ContractVersion default '1.0' is the single source of truth for the
% export contract version. 'Aux' selects auxiliary signals (and derived
% features) to align onto the tensor time grid and write to /aux: a cellstr of
% aux base names, or true / 'all' for every aux signal present (default: {}).
arguments
    data {mustBeA(data, 'struct')}
    path {mustBeText} = ''
    opts.Features = {}
    opts.Windows = []
    opts.QC = false
    opts.Aux = {}
    opts.ContractVersion = '1.0'
end

path = char(path);
if isempty(path)
    if pf2_base.isHeadless()
        error('pf2:export:asTensor:noPathHeadless', ...
            ['No output path was given and this session is headless (no ', ...
             'interactive save dialog available). Pass an explicit path.']);
    end
    % No path given: prompt for an output file.
    [filename, pathname] = uiputfile('*.h5', 'Save fNIRS tensor as HDF5');
    if isequal(filename, 0)   % selection cancelled
        outPath = '';
        return;
    end
    path = fullfile(pathname, filename);
end
if numel(path) < 3 || ~strcmpi(path(end-2:end), '.h5')
    path = [path '.h5'];
end
contractVersion = char(opts.ContractVersion);

assert(isfield(data, 'time') && ~isempty(data.time), ...
    'pf2:export:asTensor:noTime', 'data must contain a non-empty .time field.');

%% Resolve feature fields
features = opts.Features;
if ischar(features) || isstring(features)
    features = cellstr(features);
end
if isempty(features)
    features = i_defaultFeatures(data);
end
features = features(:)';
assert(~isempty(features), 'pf2:export:asTensor:noFeatures', ...
    ['No feature fields resolved. Pass ''Features'' explicitly (e.g. ' ...
     '{''HbO'',''HbR''}).']);

% Validate existence and equal sizing
refSize = [];
for k = 1:numel(features)
    f = features{k};
    assert(isfield(data, f) && isnumeric(data.(f)) && ~isempty(data.(f)), ...
        'pf2:export:asTensor:badFeature', ...
        'Feature field "%s" is missing, empty, or not numeric.', f);
    sz = size(data.(f));
    if isempty(refSize)
        refSize = sz;
    else
        assert(isequal(sz, refSize), 'pf2:export:asTensor:sizeMismatch', ...
            'Feature "%s" size %s does not match first feature size %s.', ...
            f, mat2str(sz), mat2str(refSize));
    end
end
nFeat = numel(features);

%% Build the tensor payload
windows = opts.Windows;
isWindowed = ~isempty(windows);

if ~isWindowed
    % [T x C x F]
    T = refSize(1);
    C = refSize(2);
    tensor = zeros(T, C, nFeat, 'single');
    for k = 1:nFeat
        tensor(:, :, k) = single(data.(features{k}));
    end
    timeVec = double(data.time(:));
    dimsStr = 'time x channel x feature';
    windowOnsets = [];
    nWindows = 0;
else
    % [W x T x C x F]
    if isstruct(windows)
        segs = num2cell(windows);
    else
        segs = windows(:);
    end
    W = numel(segs);
    assert(W > 0, 'pf2:export:asTensor:noWindows', ...
        '''Windows'' was supplied but contained no segments.');

    % Common (shortest) length across windows -> rectangular tensor
    perLen = zeros(1, W);
    for w = 1:W
        seg = segs{w};
        assert(isfield(seg, features{1}), 'pf2:export:asTensor:winNoFeature', ...
            'Window %d is missing feature field "%s".', w, features{1});
        perLen(w) = size(seg.(features{1}), 1);
    end
    T = min(perLen);
    C = size(segs{1}.(features{1}), 2);

    tensor = zeros(W, T, C, nFeat, 'single');
    windowOnsets = zeros(W, 1);
    for w = 1:W
        seg = segs{w};
        for k = 1:nFeat
            assert(isfield(seg, features{k}), ...
                'pf2:export:asTensor:winNoFeature', ...
                'Window %d is missing feature field "%s".', w, features{k});
            assert(size(seg.(features{k}), 2) == C, ...
                'pf2:export:asTensor:winChanMismatch', ...
                'Window %d feature "%s" has a different channel count.', ...
                w, features{k});
            tensor(w, :, :, k) = single(seg.(features{k})(1:T, :));
        end
        windowOnsets(w) = i_windowOnset(seg, data);
    end

    timeVec = double(segs{1}.time(:));
    timeVec = timeVec(1:T);
    dimsStr = 'window x time x channel x feature';
    nWindows = W;
end

%% Units
if isfield(data, 'units') && ~isempty(data.units)
    units = char(string(data.units));
else
    units = '';
end

%% Sampling rate
if isfield(data, 'fs') && ~isempty(data.fs)
    fs = double(data.fs);
else
    fs = NaN;
end

%% Aligned auxiliary signals (+ derived features) -> /aux
% Each requested aux signal is aligned (anti-aliased) onto the tensor time
% grid via pf2.data.auxOnGrid and expanded to one column per channel. For
% windowed exports the alignment is per-window.
auxMat = [];        % [T x K] continuous, or [W x T x K] windowed
auxNames = {};
auxUnits = {};
if isWindowed
    auxSource = segs{1};
else
    auxSource = data;
end
auxRequested = i_resolveAuxNames(auxSource, opts.Aux);
if ~isempty(auxRequested)
    try
        if ~isWindowed
            cols = {}; nm = {}; un = {};
            for s = 1:numel(auxRequested)
                nameS = auxRequested{s};
                vals = pf2.data.auxOnGrid(data, nameS, 'Time', timeVec);
                sig = pf2_base.resolveAux(data.Aux, nameS);
                for c = 1:size(vals, 2)
                    cols{end+1} = single(vals(:, c)); %#ok<AGROW>
                    nm{end+1} = i_auxColName(nameS, sig, c, size(vals, 2)); %#ok<AGROW>
                    un{end+1} = char(string(sig.unit)); %#ok<AGROW>
                end
            end
            if ~isempty(cols)
                auxMat = cell2mat(cols);     % [T x K]
                auxNames = nm; auxUnits = un;
            end
        else
            % Per-window alignment -> [W x T x K]
            kCols = {}; nm = {}; un = {};
            for s = 1:numel(auxRequested)
                nameS = auxRequested{s};
                wstack = [];
                nCh = 0; sig = [];
                for w = 1:W
                    % Align onto THIS window's own time grid (windows may carry
                    % absolute, non-shared time bases when SetT0 was not used).
                    winT = segs{w}.time(:);
                    winT = winT(1:T);
                    vals = pf2.data.auxOnGrid(segs{w}, nameS, 'Time', winT);
                    if w == 1
                        nCh = size(vals, 2);
                        sig = pf2_base.resolveAux(segs{w}.Aux, nameS);
                        wstack = zeros(W, T, nCh, 'single');
                    end
                    wstack(w, :, :) = single(vals(:, 1:nCh));
                end
                for c = 1:nCh
                    kCols{end+1} = wstack(:, :, c); %#ok<AGROW>
                    nm{end+1} = i_auxColName(nameS, sig, c, nCh); %#ok<AGROW>
                    un{end+1} = char(string(sig.unit)); %#ok<AGROW>
                end
            end
            if ~isempty(kCols)
                auxMat = zeros(W, T, numel(kCols), 'single');
                for c = 1:numel(kCols)
                    auxMat(:, :, c) = kCols{c};
                end
                auxNames = nm; auxUnits = un;
            end
        end
    catch ME
        warning('pf2:export:asTensor:auxFailed', ...
            'Aux alignment failed; /aux omitted: %s', ME.message);
        auxMat = []; auxNames = {}; auxUnits = {};
    end
end

%% Montage descriptor (reuse pf2.probe.montage verbatim)
montageJson = '';
try
    [~, descriptor] = pf2.probe.montage(data);
    montageJson = jsonencode(descriptor);
catch ME
    warning('pf2:export:asTensor:montageFailed', ...
        'Could not build montage descriptor: %s', ME.message);
end

%% Manifest blobs (JSON text)
% Markers (canonical table -> numeric array + column names for lossless JSON)
markersJson = i_markersJson(data);
markerDictJson = i_markerDictJson(data);

infoJson = '';
if isfield(data, 'info') && ~isempty(data.info)
    infoJson = jsonencode(i_jsonSafe(data.info));
end

procInfoJson = '';
if isfield(data, 'processingInfo') && ~isempty(data.processingInfo)
    procInfoJson = jsonencode(i_jsonSafe(data.processingInfo));
end

% QC manifest
qcJson = '';
qcRequested = (islogical(opts.QC) && opts.QC) || isstruct(opts.QC);
if qcRequested
    if isstruct(opts.QC)
        qcReport = opts.QC;
    else
        try
            qcReport = pf2.qc.pipeline.assess(data);
        catch ME
            qcReport = [];
            warning('pf2:export:asTensor:qcFailed', ...
                'QC assessment failed: %s', ME.message);
        end
    end
    if ~isempty(qcReport)
        qcJson = jsonencode(i_jsonSafe(qcReport));
    end
end

%% Write the file (overwrite cleanly)
if exist(path, 'file')
    delete(path);
end

% Numeric payloads as native HDF5 datasets.
% Reverse the tensor's dimension order before writing so h5py/numpy reads it
% in the forward order declared by the `dims` attribute (row-major). MATLAB
% is column-major, so without this reversal h5py would see the axes flipped.
tensorDisk = permute(tensor, ndims(tensor):-1:1);
h5create(path, '/tensor', size(tensorDisk), 'Datatype', 'single');
h5write(path, '/tensor', tensorDisk);

h5create(path, '/time', size(timeVec), 'Datatype', 'double');
h5write(path, '/time', timeVec);

if isWindowed
    h5create(path, '/windowOnsets', size(windowOnsets), 'Datatype', 'double');
    h5write(path, '/windowOnsets', windowOnsets);
end

% Aligned auxiliary signals (reverse dims for row-major like /tensor)
if ~isempty(auxMat)
    auxDisk = permute(auxMat, ndims(auxMat):-1:1);
    h5create(path, '/aux', size(auxDisk), 'Datatype', 'single');
    h5write(path, '/aux', auxDisk);
    if isWindowed
        h5writeatt(path, '/aux', 'dims', 'window x time x auxChannel');
    else
        h5writeatt(path, '/aux', 'dims', 'time x auxChannel');
    end
    h5writeatt(path, '/aux', 'auxNames', string(auxNames));
    h5writeatt(path, '/aux', 'auxUnits', string(auxUnits));
end

% Metadata as UTF-8 JSON string datasets
i_writeStringDataset(path, '/montage', montageJson);
i_writeStringDataset(path, '/manifest/markers', markersJson);
i_writeStringDataset(path, '/manifest/markerDict', markerDictJson);
if ~isempty(infoJson)
    i_writeStringDataset(path, '/manifest/info', infoJson);
end
if ~isempty(procInfoJson)
    i_writeStringDataset(path, '/manifest/processingInfo', procInfoJson);
end
if ~isempty(qcJson)
    i_writeStringDataset(path, '/manifest/qc', qcJson);
end

% Root attributes
h5writeatt(path, '/', 'pf2ContractVersion', contractVersion);
h5writeatt(path, '/', 'createdBy', 'processFNIRS2');
h5writeatt(path, '/', 'dims', dimsStr);
h5writeatt(path, '/', 'samplingRate', fs);
h5writeatt(path, '/', 'units', units);
h5writeatt(path, '/', 'featureNames', string(features));
h5writeatt(path, '/', 'nWindows', int32(nWindows));
h5writeatt(path, '/', 'nAux', int32(numel(auxNames)));

%% Return absolute path
fileInfo = dir(path);
outPath = fullfile(fileInfo.folder, fileInfo.name);

end


%%_Subfunctions_____________________________________________________________

function names = i_resolveAuxNames(src, auxOpt)
% I_RESOLVEAUXNAMES Resolve the requested aux base names from the 'Aux' option
%   auxOpt: cellstr of names, or true / 'all' for every aux signal present.
names = {};
if ~isfield(src, 'Aux') || isempty(src.Aux) || ~isstruct(src.Aux)
    return;
end
includeAll = (islogical(auxOpt) && auxOpt) || ...
    ((ischar(auxOpt) || isstring(auxOpt)) && strcmpi(char(string(auxOpt)), 'all'));
if includeAll
    fn = fieldnames(src.Aux);
    fn = fn(~strcmpi(fn, 'flattened'));
    names = unique(regexprep(fn, '_(data|time|unit)$', ''), 'stable')';
elseif iscell(auxOpt)
    names = auxOpt(:)';
elseif (ischar(auxOpt) || isstring(auxOpt)) && ~isempty(char(string(auxOpt)))
    names = cellstr(auxOpt)';
end
end

function nm = i_auxColName(sigName, sig, c, nCh)
% I_AUXCOLNAME Per-column aux name: <signal> or <signal>_<channelLabel>
if nCh <= 1
    nm = sigName;
elseif isfield(sig, 'varNames') && numel(sig.varNames) >= c && ~isempty(sig.varNames{c})
    nm = sprintf('%s_%s', sigName, sig.varNames{c});
else
    nm = sprintf('%s_%d', sigName, c);
end
end

function features = i_defaultFeatures(data)
% I_DEFAULTFEATURES Pick the biomarker fields present, else OD/raw fallback
%
% Inputs:
%   data - fNIRS data struct
%
% Outputs:
%   features - Cell array of present feature field names (possibly empty)

candidates = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'};
features = candidates(cellfun(@(f) isfield(data, f) && ~isempty(data.(f)), ...
    candidates));
if isempty(features)
    for f = {'OD', 'raw'}
        if isfield(data, f{1}) && ~isempty(data.(f{1}))
            features = f;
            return;
        end
    end
end
end


function onset = i_windowOnset(seg, parentData) %#ok<INUSD>
% I_WINDOWONSET Resolve a window's absolute onset time in seconds
%
% Inputs:
%   seg        - Extracted-segment struct
%   parentData - Parent data struct (unused; reserved)
%
% Outputs:
%   onset - Window onset time in seconds [double]

onset = NaN;
if isfield(seg, 'info') && isstruct(seg.info) ...
        && isfield(seg.info, 'WindowOnset') && ~isempty(seg.info.WindowOnset)
    onset = double(seg.info.WindowOnset);
elseif isfield(seg, 't0') && ~isempty(seg.t0)
    onset = double(seg.t0);
elseif isfield(seg, 'time') && ~isempty(seg.time)
    onset = double(seg.time(1));
end
end


function jsonStr = i_markersJson(data)
% I_MARKERSJSON Serialize the canonical marker table to JSON
%
% Inputs:
%   data - fNIRS data struct (uses data.markers)
%
% Outputs:
%   jsonStr - JSON string with .columns and .data (numeric array), or '{}'

jsonStr = '{}';
if ~isfield(data, 'markers') || isempty(data.markers)
    return;
end
try
    arr = pf2_base.markersToArray(data.markers);
    cols = {'Time', 'Code', 'Duration', 'Amplitude'};
    if istable(data.markers)
        cols = data.markers.Properties.VariableNames;
    end
    % Trim/extend column names to match the array width
    nCol = size(arr, 2);
    if numel(cols) > nCol
        cols = cols(1:nCol);
    elseif numel(cols) < nCol
        for extra = numel(cols)+1:nCol
            cols{extra} = sprintf('col%d', extra);
        end
    end
    s = struct('columns', {cols}, 'data', arr);
    jsonStr = jsonencode(s);
catch
    jsonStr = '{}';
end
end


function jsonStr = i_markerDictJson(data)
% I_MARKERDICTJSON Serialize the marker dictionary (code->label) to JSON
%
% Inputs:
%   data - fNIRS data struct
%
% Outputs:
%   jsonStr - JSON string of the dictionary as a struct array, or '[]'

jsonStr = '[]';
try
    dict = pf2.data.getMarkerDict(data);
    if istable(dict) && height(dict) > 0
        jsonStr = jsonencode(i_tableToStructArray(dict));
    end
catch
    jsonStr = '[]';
end
end


function sArr = i_tableToStructArray(tbl)
% I_TABLETOSTRUCTARRAY Convert a table to a JSON-friendly struct array
%
% Inputs:
%   tbl - MATLAB table
%
% Outputs:
%   sArr - Struct array, one element per row, string-cast for categoricals

vars = tbl.Properties.VariableNames;
n = height(tbl);
sArr = repmat(struct(), n, 1);
for r = 1:n
    for v = 1:numel(vars)
        val = tbl{r, v};
        if iscategorical(val) || isstring(val)
            val = char(string(val));
        elseif iscell(val) && isscalar(val)
            val = val{1};
        end
        sArr(r).(vars{v}) = val;
    end
end
end


function out = i_jsonSafe(in)
% I_JSONSAFE Recursively coerce a struct into a jsonencode-safe form
%
% Converts datetime/duration/categorical/table fields into strings or
% JSON-friendly containers so jsonencode does not error or emit opaque data.
%
% Inputs:
%   in - Any value (struct/cell/array/scalar)
%
% Outputs:
%   out - JSON-encodable equivalent

if isstruct(in)
    out = in;
    if numel(in) == 1
        f = fieldnames(in);
        for k = 1:numel(f)
            out.(f{k}) = i_jsonSafe(in.(f{k}));
        end
    else
        for e = 1:numel(in)
            f = fieldnames(in);
            for k = 1:numel(f)
                out(e).(f{k}) = i_jsonSafe(in(e).(f{k}));
            end
        end
    end
elseif istable(in)
    out = i_tableToStructArray(in);
elseif isdatetime(in) || isduration(in)
    out = char(string(in));
elseif iscategorical(in)
    out = cellstr(string(in));
    if isscalar(out)
        out = out{1};
    end
elseif iscell(in)
    out = cell(size(in));
    for k = 1:numel(in)
        out{k} = i_jsonSafe(in{k});
    end
elseif isobject(in) && ~isstring(in)
    % pf2.Device and similar value objects: skip (montage carries geometry)
    out = class(in);
else
    out = in;
end
end


function i_writeStringDataset(path, ds, str)
% I_WRITESTRINGDATASET Write a scalar UTF-8 JSON string as an HDF5 dataset
%
% Creates a true scalar (H5S_SCALAR) variable-length UTF-8 string dataset via
% the low-level HDF5 API so Python h5py reads it as a single scalar (bytes
% decodable by json.loads) rather than a 1-element ndarray. h5create's string
% type yields a shape-(1,) array in h5py; the scalar dataspace avoids that.
%
% Inputs:
%   path - HDF5 file path
%   ds   - Dataset path (e.g. '/montage')
%   str  - String content [char/string]

if isempty(str)
    str = '';
end
str = char(str);

fid = H5F.open(path, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
cleanupFid = onCleanup(@() H5F.close(fid));

% Ensure any intermediate groups (e.g. /manifest) exist
parts = strsplit(ds, '/');
parts = parts(~cellfun(@isempty, parts));
gcpl = 'H5P_DEFAULT';
lcpl = H5P.create('H5P_LINK_CREATE');
H5P.set_create_intermediate_group(lcpl, 1);
cleanupLcpl = onCleanup(@() H5P.close(lcpl)); %#ok<NASGU>

% Variable-length UTF-8 string datatype
strType = H5T.copy('H5T_C_S1');
H5T.set_size(strType, 'H5T_VARIABLE');
H5T.set_cset(strType, H5ML.get_constant_value('H5T_CSET_UTF8'));
cleanupType = onCleanup(@() H5T.close(strType)); %#ok<NASGU>

% Scalar dataspace
space = H5S.create('H5S_SCALAR');
cleanupSpace = onCleanup(@() H5S.close(space)); %#ok<NASGU>

dsetId = H5D.create(fid, ds, strType, space, lcpl, gcpl, 'H5P_DEFAULT');
cleanupDset = onCleanup(@() H5D.close(dsetId)); %#ok<NASGU>

% Write the scalar string (cell-wrapped for the VL string interface)
H5D.write(dsetId, strType, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', {str});
end
