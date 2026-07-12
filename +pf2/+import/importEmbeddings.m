function data = importEmbeddings(data, path, opts)
% IMPORTEMBEDDINGS Attach model embeddings from an HDF5 file to a data struct
%
% Reads learned features/embeddings written by the Python sibling repository
% (the consumer side of the foundation-model export contract,
% TRANSFORMER_ROADMAP.md §4.4) and attaches them to data.embeddings, aligned
% to the original recording's time base. Once attached, the embeddings behave
% like any other biomarker block, so exploreFNIRS.core.Experiment can fold
% learned features into LME / contrast benchmarks alongside HbO/HbR.
%
% Embeddings may be per-timepoint, per-window, or per-timepoint-and-channel.
% The granularity is read from the file's `dims` attribute and reflected in
% data.embeddings.dims; per-window onsets become data.embeddings.time.
%
% Cross-language axis convention:
%   The file is produced by the Python/h5py (row-major) sibling, so a
%   /embeddings dataset whose declared `dims` is e.g. [T x E] has h5py shape
%   (T, E). MATLAB h5read (column-major) returns it axis-reversed, so this
%   reader permutes the array back to the forward dimension order after
%   reading. The `dims` attribute (not just the rank) drives interpretation.
%
% Reference:
%   processFNIRS2 foundation-model export contract v1.0.
%   See internal/TRANSFORMER_ROADMAP.md §4.4 ("Re-import path").
%
% Syntax:
%   data = pf2.import.importEmbeddings(data, path)
%   data = pf2.import.importEmbeddings(data, path, 'Field', 'myEmbeddings')
%
% Inputs:
%   data - fNIRS data struct the embeddings attach to. data.time provides the
%          time base for per-timepoint embeddings; per-window embeddings use
%          the file's window onsets instead.
%   path - Path to the embeddings .h5 file [char/string].
%
% Name-Value Parameters:
%   'Field' - Field name to store the block under (default: 'embeddings').
%
% Expected input schema (written by the Python sibling):
%   /embeddings   - float32 dataset, one of:
%                     [T x E]      per-timepoint embeddings
%                     [W x E]      per-window embeddings
%                     [T x C x E]  per-timepoint-and-channel embeddings
%   /windowOnsets - double [W] window onsets in seconds (optional; only for
%                   per-window embeddings; may instead be a root attribute).
%   Root attributes (all optional except dims is strongly preferred):
%     dims           - 'time x feature' | 'window x feature' |
%                      'time x channel x feature'. When absent, the shape is
%                      inferred (2-D -> time x feature, 3-D -> time x channel
%                      x feature).
%     modelName      - source model identifier [string]
%     embeddingNames - per-embedding names [string array]
%     windowOnsets   - window onsets in seconds (alternative to the dataset)
%     pf2ContractVersion / contractVersion - contract version [string]
%
% Outputs:
%   data - Input struct with an added .embeddings (or 'Field') block:
%            .data  - the embeddings array [T x E] / [W x E] / [T x C x E]
%            .time  - aligned time vector: data.time for per-timepoint, or the
%                     window onsets for per-window granularity
%            .dims  - dimension descriptor string
%            .names - embedding names (string array; auto-generated if absent)
%            .info  - struct: modelName, sourcePath, contractVersion
%
% Algorithm:
%   1. Read /embeddings (native float32) and any /windowOnsets dataset.
%   2. Read the root attributes (dims, modelName, embeddingNames, onsets,
%      contract version), tolerating any that are missing.
%   3. Infer dims from the array shape when the attribute is absent.
%   4. Align the time base: data.time for per-timepoint, window onsets for
%      per-window; auto-name embeddings when names are absent.
%   5. Attach the assembled block to data.(Field).
%
% Example:
%   % Re-import per-timepoint embeddings produced by the Python sibling
%   data = pf2.import.sampleData.fNIR2000();
%   proc = processFNIRS2(data);
%   proc = pf2.import.importEmbeddings(proc, 'sub-01_embeddings.h5');
%   size(proc.embeddings.data)      % [T x E]
%   isequal(proc.embeddings.time, proc.time(:))   % aligned to recording
%
% Notes:
%   - Robust to missing optional attributes; only /embeddings is required.
%   - For per-window embeddings, .time holds the window onsets and .dims notes
%     the per-window granularity (one row per window, not per sample).
%
% See also: pf2.export.asTensor, pf2.data.slidingWindows,
%           exploreFNIRS.core.Experiment

%% Parse inputs
arguments
    data {mustBeA(data, 'struct')}
    path {mustBeTextScalar}
    opts.Field {mustBeTextScalar} = 'embeddings'
end
path = char(path);
field = char(opts.Field);

assert(exist(path, 'file') == 2, 'pf2:import:importEmbeddings:noFile', ...
    'Embeddings file not found: %s', path);

%% Read the embeddings array (native dataset)
% The file is row-major (Python/h5py); MATLAB h5read returns axes reversed, so
% permute back to the forward order declared by `dims` ([T x E] / [W x E] /
% [T x C x E]). A genuinely 1-D dataset is axis-order invariant.
embRaw = double(h5read(path, '/embeddings'));
emb = permute(embRaw, ndims(embRaw):-1:1);

%% Read optional root attributes (tolerate missing)
dimsStr   = i_readAttr(path, '/', 'dims', '');
modelName = i_readAttr(path, '/', 'modelName', '');
names     = i_readAttr(path, '/', 'embeddingNames', []);
onsetAttr = i_readAttr(path, '/', 'windowOnsets', []);
ver       = i_readAttr(path, '/', 'pf2ContractVersion', '');
if isempty(ver)
    ver = i_readAttr(path, '/', 'contractVersion', '');
end

%% Read optional /windowOnsets dataset
onsetDataset = [];
try
    onsetDataset = double(h5read(path, '/windowOnsets'));
catch
    onsetDataset = [];
end

%% Infer dims from shape when attribute is absent
nd = ndims(emb);
if isempty(dimsStr)
    if nd >= 3
        dimsStr = 'time x channel x feature';
    else
        dimsStr = 'time x feature';
    end
end
dimsStr = char(string(dimsStr));
isPerWindow = ~isempty(strfind(lower(dimsStr), 'window')); %#ok<STREMP>

%% Align the time base
if isPerWindow
    if ~isempty(onsetDataset)
        timeVec = onsetDataset(:);
    elseif ~isempty(onsetAttr)
        timeVec = double(onsetAttr(:));
    else
        % Fall back to sequential window indices
        timeVec = (1:size(emb, 1))';
    end
else
    if isfield(data, 'time') && ~isempty(data.time)
        timeVec = double(data.time(:));
        if numel(timeVec) ~= size(emb, 1)
            % Length mismatch: keep embeddings, note divergence, index-align
            warning('pf2:import:importEmbeddings:timeMismatch', ...
                ['Embedding rows (%d) do not match data.time (%d); ' ...
                 'using sequential indices for .time.'], ...
                size(emb, 1), numel(timeVec));
            timeVec = (1:size(emb, 1))';
        end
    else
        timeVec = (1:size(emb, 1))';
    end
end

%% Resolve embedding names
nEmb = size(emb, ndims(emb));
if isempty(names)
    names = "emb" + string(1:nEmb);
else
    names = string(names(:)');
end

%% Assemble and attach the block
block = struct();
block.data  = emb;
block.time  = timeVec;
block.dims  = dimsStr;
block.names = names;
block.info  = struct( ...
    'modelName', char(string(modelName)), ...
    'sourcePath', path, ...
    'contractVersion', char(string(ver)));

data.(field) = block;

end


%%_Subfunctions_____________________________________________________________

function val = i_readAttr(path, loc, name, default)
% I_READATTR Read an HDF5 attribute, returning a default when absent
%
% Inputs:
%   path    - HDF5 file path
%   loc     - Object location (e.g. '/')
%   name    - Attribute name
%   default - Value to return when the attribute does not exist
%
% Outputs:
%   val - Attribute value, or default on any read failure

try
    val = h5readatt(path, loc, name);
catch
    val = default;
end
end
