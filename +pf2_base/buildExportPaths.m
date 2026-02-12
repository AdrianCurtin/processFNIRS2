function paths = buildExportPaths(allData, dirPath, ext, opts)
% BUILDEXPORTPATHS Generate output file paths for batch export
%
% Builds a cell array of full file paths for exporting a cell array of
% fNIRS data structs. Supports mapping .info fields to subdirectories
% (Dir1-Dir4) and constructing filenames from info field values (Prefix).
%
% Syntax:
%   paths = pf2_base.buildExportPaths(allData, dirPath, ext, opts)
%
% Inputs:
%   allData - Cell array of fNIRS structs {1 x N}
%   dirPath - Output root directory [char]
%   ext     - File extension including dot [char] e.g. '.snirf', '.nir'
%   opts    - Struct with optional fields:
%             .Dir1-.Dir4  - Info field names to map to subdirectories [char]
%             .Prefix      - Cell array of info field names for filename [cell]
%
% Outputs:
%   paths   - Cell array of full file paths {1 x N}
%
% Example:
%   opts.Dir1 = 'Group';
%   opts.Prefix = {'SubjectID', 'SessionNum'};
%   paths = pf2_base.buildExportPaths(allData, 'output/', '.snirf', opts);
%
% See also: pf2.export.asSNIRF, pf2.export.asNIR

    n = numel(allData);
    paths = cell(1, n);

    dirFields = {'Dir1', 'Dir2', 'Dir3', 'Dir4'};

    for i = 1:n
        data = allData{i};

        % --- Build subdirectory from Dir1-Dir4 ---
        subParts = {};
        for k = 1:4
            fieldName = dirFields{k};
            if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
                infoField = opts.(fieldName);
                if isfield(data, 'info') && isfield(data.info, infoField) ...
                        && ~isempty(data.info.(infoField))
                    subParts{end+1} = toCharSafe(data.info.(infoField)); %#ok<AGROW>
                end
            end
        end

        if isempty(subParts)
            subDir = '';
        else
            subDir = fullfile(subParts{:});
        end

        % --- Build filename ---
        if isfield(opts, 'Prefix') && ~isempty(opts.Prefix)
            prefixParts = {};
            for p = 1:numel(opts.Prefix)
                infoField = opts.Prefix{p};
                if isfield(data, 'info') && isfield(data.info, infoField) ...
                        && ~isempty(data.info.(infoField))
                    prefixParts{end+1} = toCharSafe(data.info.(infoField)); %#ok<AGROW>
                else
                    prefixParts{end+1} = 'unknown'; %#ok<AGROW>
                end
            end
            filename = strjoin(prefixParts, '_');
        else
            filename = sprintf('data_%d', i);
        end

        % --- Assemble full path ---
        paths{i} = fullfile(dirPath, subDir, [filename ext]);
    end
end


function s = toCharSafe(val)
% Convert a value to a char suitable for filenames
    if isnumeric(val)
        s = num2str(val);
    elseif isstring(val)
        s = char(val);
    elseif ischar(val)
        s = val;
    else
        s = char(string(val));
    end
end
