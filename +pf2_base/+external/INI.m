classdef INI < dynamicprops
% INI Reader/writer for INI-style configuration files.
%
% Summary:
%   Parses and serializes INI/.cfg files of the form
%
%       [SectionName]
%       key = value
%       ; a comment
%
%   Each section is exposed as a dynamic property on the object whose value
%   is a struct of that section's key/value pairs. Values are stored as
%   evaluable MATLAB literals on write (numbers, strings, cells, structs,
%   matrices) and recovered on read by evaluating the right-hand side, with
%   a fall-back to the raw string when evaluation fails. This makes the
%   container suitable both for human-edited device .cfg files and for
%   round-tripping packed processing-method structs.
%
%   Sections are tracked by their original (human-readable) names in the
%   Sections property; the corresponding dynamic property uses a sanitized,
%   MATLAB-valid identifier derived from that name. Reading/writing/lookup
%   accept the original name and resolve to the sanitized property
%   internally, so callers may use either form.
%
% Inputs (constructor, name/value pairs):
%   'File'        - char/string. Path of the file to read/write. Default 'INI.ini'.
%   'CommentChar' - char. Comment marker recognized on read (whole-line and
%                   trailing/inline). Default '%' (matches device .cfg files).
%   'NewLineChar' - char. Line terminator emitted on write. Default newline.
%   'Sections'    - cellstr. Initial section name list. Default {}.
%
% Outputs:
%   obj - INI object. Section data is available as obj.<SanitizedSection>.
%
% Methods:
%   obj = INI(P1,V1,...)        Construct and set properties.
%   obj = obj.set(P1,V1,...)    Set one or more properties.
%   v   = obj.get(PROPERTY)     Get a property (accepts original section name).
%   obj = obj.read([FILE])      Read FILE (or the stored File) into sections.
%   obj = obj.write([FILE])     Write sections to FILE (or the stored File).
%   obj = obj.add(N1,S1,...)    Add section N1 holding struct S1 (etc.).
%   obj = obj.remove([S1,...])  Remove named sections, or all if none given.
%
% Examples:
%   cfg = pf2_base.external.INI('File', 'device.cfg');
%   cfg.read();
%   info = cfg.get('Info');
%
%   cfg2 = pf2_base.external.INI('File', tempname);
%   cfg2.add('Probe1', struct('Wavelength', [730 850]));
%   cfg2.write();
%
% See also: pf2_base.loadDeviceCfg, pf2_base.PipelineFunction,
%           pf2.import.importSNIRF

    properties
        File        = 'INI.ini';  % File path used by read()/write()
        CommentChar = '%';        % Comment marker (whole-line and inline)
        NewLineChar = newline;    % Line terminator emitted on write
        Sections    = {};         % Original (unsanitized) section names
    end

    properties (Access = private)
        % Map from sanitized property name -> original section name. Lets
        % write() and lookups recover the human-readable header.
        PropToSection = struct();
    end

    methods

        function obj = INI(varargin)
            for k = 1:2:numel(varargin)
                obj.set(varargin{k}, varargin{k+1});
            end
        end

        function obj = set(obj, varargin)
            % Set one or more named properties (case-insensitive).
            for k = 1:2:numel(varargin)
                name  = varargin{k};
                value = varargin{k+1};
                prop  = obj.resolveProperty(name);
                if isempty(prop)
                    error('pf2_base:external:INI:badProperty', ...
                        'Property "%s" not supported.', name);
                end
                obj.(prop) = value;
            end
        end

        function value = get(obj, name)
            % Get a property by name (case-insensitive; accepts original
            % section names as well as sanitized identifiers).
            if nargin < 2
                value = obj;
                return;
            end
            prop = obj.resolveProperty(name);
            if isempty(prop)
                error('pf2_base:external:INI:badProperty', ...
                    'Property "%s" not supported.', name);
            end
            value = obj.(prop);
        end

        function obj = read(obj, varargin)
            % Read an INI file into per-section dynamic properties.
            if nargin >= 2 && ~isempty(varargin{1})
                obj.File = varargin{1};
            end

            obj.clearSections();

            text = obj.readFileText(obj.File);
            lines = regexp(text, '\r\n|\r|\n', 'split');

            currentSection = '';      % sanitized property name
            data           = struct();

            n = numel(lines);
            i = 1;
            while i <= n
                rawLine = lines{i};
                i = i + 1;
                line = strtrim(rawLine);

                if isempty(line) || obj.isCommentLine(line)
                    continue;
                end

                if line(1) == '['
                    close = strfind(line, ']');
                    if isempty(close)
                        continue;  % malformed header; skip
                    end
                    % Commit the previous section before starting a new one.
                    if ~isempty(currentSection)
                        obj.(currentSection) = data;
                    end
                    sectionName    = strtrim(line(2:close(1)-1));
                    currentSection = obj.ensureSection(sectionName);
                    data           = struct();
                    continue;
                end

                eq = strfind(line, '=');
                if isempty(eq) || isempty(currentSection)
                    continue;  % not a key=value pair inside a section
                end

                key    = strtrim(line(1:eq(1)-1));
                rhsRaw = obj.stripInlineComment(line(eq(1)+1:end));

                % A value literal may legitimately span multiple physical
                % lines (e.g. a long struct(...) or a quoted string with
                % embedded newlines). Accumulate continuation lines until
                % the literal parses, the next section starts, or input ends.
                rhs = rhsRaw;
                [value, ok] = obj.parseValue(rhs);
                while ~ok && i <= n
                    peek = strtrim(lines{i});
                    if ~isempty(peek) && (peek(1) == '[' || obj.isCommentLine(peek) ...
                            || obj.looksLikeAssignment(peek))
                        break;  % belongs to something else
                    end
                    rhs = sprintf('%s\n%s', rhs, obj.stripInlineComment(lines{i}));
                    i = i + 1;
                    [value, ok] = obj.parseValue(rhs);
                end
                if ~ok
                    value = strtrim(rhs);  % give up: store raw string
                end

                fieldName = pf2_base.external.INI.sanitizeName(key);
                if ~isempty(fieldName)
                    data.(fieldName) = value;
                end
            end

            if ~isempty(currentSection)
                obj.(currentSection) = data;
            end

            obj.Sections = sort(obj.Sections);
        end

        function obj = write(obj, varargin)
            % Serialize all sections to an INI file.
            if nargin >= 2 && ~isempty(varargin{1})
                obj.File = varargin{1};
            end

            obj.Sections = sort(obj.Sections);

            fid = fopen(obj.File, 'w');
            if fid < 0
                error('pf2_base:external:INI:cannotOpen', ...
                    'Could not open "%s" for writing.', obj.File);
            end
            cleanup = onCleanup(@() fclose(fid));

            for s = 1:numel(obj.Sections)
                sectionName = obj.Sections{s};
                prop        = obj.sectionProperty(sectionName);
                if isempty(prop) || ~isprop(obj, prop)
                    continue;
                end
                value = obj.(prop);
                value = pf2_base.external.INI.coerceToStruct(value);

                fprintf(fid, '[%s]%s', sectionName, obj.NewLineChar);

                if isstruct(value)
                    fields = fieldnames(value);
                    for f = 1:numel(fields)
                        literal = pf2_base.external.INI.toLiteral(value.(fields{f}));
                        fprintf(fid, '%s = %s%s', fields{f}, literal, obj.NewLineChar);
                    end
                end

                fprintf(fid, '%s', obj.NewLineChar);
            end
        end

        function obj = add(obj, varargin)
            % Add one or more sections, each holding a struct (or struct-like
            % object). add(NAME1, S1, NAME2, S2, ...).
            for k = 1:2:numel(varargin)
                sectionName = varargin{k};
                value       = varargin{k+1};
                prop        = obj.ensureSection(sectionName);
                obj.(prop)  = value;
            end
            obj.Sections = sort(obj.Sections);
        end

        function obj = remove(obj, varargin)
            % remove() clears all sections; remove(N1, N2, ...) removes named.
            if isempty(varargin)
                obj.clearSections();
                return;
            end
            for k = 1:numel(varargin)
                prop = obj.sectionProperty(varargin{k});
                if isempty(prop)
                    prop = pf2_base.external.INI.sanitizeName(varargin{k});
                end
                obj.dropSectionByProperty(prop);
            end
        end

    end

    methods (Access = private)

        function prop = resolveProperty(obj, name)
            % Resolve a user-supplied name to an existing property name,
            % matching the fixed properties case-insensitively and section
            % names by their original or sanitized form. Returns '' if none.
            prop = '';
            fixed = {'File', 'CommentChar', 'NewLineChar', 'Sections'};
            idx = find(strcmpi(name, fixed), 1);
            if ~isempty(idx)
                prop = fixed{idx};
                return;
            end
            % Original section name?
            secProp = obj.sectionProperty(name);
            if ~isempty(secProp) && isprop(obj, secProp)
                prop = secProp;
                return;
            end
            % Already a valid dynamic property name?
            if isprop(obj, name)
                prop = name;
                return;
            end
            % Sanitized form of an arbitrary name.
            cand = pf2_base.external.INI.sanitizeName(name);
            if ~isempty(cand) && isprop(obj, cand)
                prop = cand;
            end
        end

        function prop = sectionProperty(obj, sectionName)
            % Return the sanitized property name registered for a section's
            % original name, or '' if that section is not registered.
            prop = '';
            mapFields = fieldnames(obj.PropToSection);
            for k = 1:numel(mapFields)
                if strcmp(obj.PropToSection.(mapFields{k}), sectionName)
                    prop = mapFields{k};
                    return;
                end
            end
        end

        function prop = ensureSection(obj, sectionName)
            % Register a section by its original name, creating the backing
            % dynamic property if needed, and return the property name.
            prop = obj.sectionProperty(sectionName);
            if ~isempty(prop) && isprop(obj, prop)
                return;
            end
            prop = pf2_base.external.INI.sanitizeName(sectionName);
            if isempty(prop)
                prop = 'Section';
            end
            % Avoid collision with the fixed properties.
            while any(strcmp(prop, {'File', 'CommentChar', 'NewLineChar', ...
                    'Sections', 'PropToSection'}))
                prop = ['x_' prop]; %#ok<AGROW>
            end
            if ~isprop(obj, prop)
                obj.addprop(prop);
            end
            obj.PropToSection.(prop) = sectionName;
            if ~ismember(sectionName, obj.Sections)
                obj.Sections{end+1} = sectionName;
            end
        end

        function clearSections(obj)
            % Delete all dynamic section properties and reset tracking.
            mapFields = fieldnames(obj.PropToSection);
            for k = 1:numel(mapFields)
                p = findprop(obj, mapFields{k});
                if ~isempty(p)
                    delete(p);
                end
            end
            obj.PropToSection = struct();
            obj.Sections = {};
        end

        function dropSectionByProperty(obj, prop)
            % Remove a single section identified by its property name.
            if isfield(obj.PropToSection, prop)
                sectionName = obj.PropToSection.(prop);
                obj.Sections(strcmp(obj.Sections, sectionName)) = [];
                obj.PropToSection = rmfield(obj.PropToSection, prop);
            end
            p = findprop(obj, prop);
            if ~isempty(p)
                delete(p);
            end
        end

        function out = stripInlineComment(obj, str)
            % Remove a trailing inline comment from a value string. A comment
            % marker (CommentChar or '#') only terminates the value when it
            % appears outside any quoted span and outside any bracket/paren
            % nesting. ';' is NOT treated as a comment here because it is a
            % valid matrix row separator; it only matters at depth 0, where a
            % value would not legitimately contain one.
            out = str;
            markers = unique([obj.CommentChar, '#']);
            inStr = false;
            q = '';
            depth = 0;
            i = 1;
            n = numel(str);
            while i <= n
                c = str(i);
                if inStr
                    if c == q
                        if i < n && str(i+1) == q
                            i = i + 1;  % escaped quote
                        else
                            inStr = false;
                        end
                    end
                elseif c == '''' || c == '"'
                    inStr = true;
                    q = c;
                elseif c == '(' || c == '[' || c == '{'
                    depth = depth + 1;
                elseif c == ')' || c == ']' || c == '}'
                    depth = depth - 1;
                elseif depth <= 0 && any(c == markers)
                    out = str(1:i-1);
                    return;
                end
                i = i + 1;
            end
        end

        function tf = isCommentLine(obj, line)
            % True if a trimmed line begins with a comment marker. Both ';'
            % and '#' are honored regardless of CommentChar so common files
            % parse, while CommentChar remains the canonical marker.
            tf = false;
            if isempty(line)
                return;
            end
            c = line(1);
            if c == obj.CommentChar || c == ';' || c == '#'
                tf = true;
            end
        end

    end

    methods (Static, Access = private)

        function tf = looksLikeAssignment(line)
            % Heuristic: a continuation line that itself looks like "key ="
            % (an identifier followed by '=') belongs to the next field, not
            % to the current multi-line value.
            tf = ~isempty(regexp(line, '^[A-Za-z_]\w*\s*=', 'once'));
        end

        function [value, ok] = parseValue(rhs)
            % Recover a MATLAB value from the right-hand side of key=value.
            % Quoted strings become char; otherwise the literal is evaluated
            % (numbers, vectors/matrices, cells, struct(...)). ok=false means
            % the literal is incomplete (e.g. unbalanced brackets) and more
            % continuation lines are needed.
            value = '';
            ok = false;
            s = strtrim(rhs);
            if isempty(s)
                value = '';
                ok = true;
                return;
            end

            if s(1) == '''' || s(1) == '"'
                [str, complete] = pf2_base.external.INI.parseQuoted(s);
                if complete
                    value = str;
                    ok = true;
                end
                return;
            end

            % Don't attempt eval until brackets/parens are balanced, so a
            % multi-line literal isn't prematurely (mis)parsed.
            if ~pf2_base.external.INI.bracketsBalanced(s)
                return;
            end

            try
                value = eval(s);
                ok = true;
            catch
                % A bare word (unquoted text) is a valid string value.
                if ~isempty(regexp(s, '^[\w\.\- /\\:]+$', 'once'))
                    value = s;
                    ok = true;
                end
            end
        end

        function [str, complete] = parseQuoted(s)
            % Parse a leading quoted literal, honoring doubled-quote escapes.
            % complete=false if no closing quote is found (multi-line value).
            complete = false;
            q = s(1);
            i = 2;
            n = numel(s);
            buf = '';
            while i <= n
                c = s(i);
                if c == q
                    if i < n && s(i+1) == q
                        buf = [buf q]; %#ok<AGROW>
                        i = i + 2;
                    else
                        str = buf;
                        complete = true;
                        return;
                    end
                else
                    buf = [buf c]; %#ok<AGROW>
                    i = i + 1;
                end
            end
            str = buf;  % unterminated; treat what we have as partial
        end

        function tf = bracketsBalanced(s)
            % True if (), [], {} are balanced outside of quoted spans.
            depth = 0;
            inStr = false;
            q = '';
            i = 1;
            n = numel(s);
            while i <= n
                c = s(i);
                if inStr
                    if c == q
                        if i < n && s(i+1) == q
                            i = i + 1;  % escaped quote
                        else
                            inStr = false;
                        end
                    end
                else
                    switch c
                        case {'''', '"'}
                            inStr = true;
                            q = c;
                        case {'(', '[', '{'}
                            depth = depth + 1;
                        case {')', ']', '}'}
                            depth = depth - 1;
                    end
                end
                i = i + 1;
            end
            tf = (depth <= 0) && ~inStr;
        end

        function literal = toLiteral(value)
            % Serialize a MATLAB value to a parseable INI literal string.
            value = pf2_base.external.INI.coerceToStruct(value);

            if ischar(value)
                literal = ['''' strrep(value, '''', '''''') ''''];
                return;
            end
            if isstring(value)
                if isscalar(value)
                    literal = ['"' char(value) '"'];
                else
                    parts = arrayfun(@(x) ['"' char(x) '"'], value(:)', ...
                        'UniformOutput', false);
                    literal = ['[' strjoin(parts, ' ') ']'];
                end
                return;
            end
            if isa(value, 'function_handle')
                fstr = func2str(value);
                literal = ['''' strrep(fstr, '''', '''''') ''''];
                return;
            end
            if isstruct(value)
                fields = fieldnames(value);
                parts = cell(1, numel(fields));
                for k = 1:numel(fields)
                    fv = value.(fields{k});
                    fvLit = pf2_base.external.INI.toLiteral(fv);
                    % The struct(...) constructor interprets a cell value as
                    % element dimensions, which would turn a single cell-array
                    % field into a struct array. Wrap cell field values in an
                    % extra cell so they survive as a scalar field value.
                    if iscell(fv)
                        fvLit = ['{' fvLit '}'];
                    end
                    parts{k} = sprintf('''%s'',%s', fields{k}, fvLit);
                end
                literal = ['struct(' strjoin(parts, ',') ')'];
                return;
            end
            if iscell(value)
                literal = pf2_base.external.INI.cellLiteral(value);
                return;
            end
            if islogical(value)
                literal = pf2_base.external.INI.numericLiteral(double(value), '%d');
                return;
            end
            if isnumeric(value)
                if isinteger(value)
                    literal = pf2_base.external.INI.numericLiteral(value, '%d');
                else
                    literal = pf2_base.external.INI.numericLiteral(value, '%.15g');
                end
                return;
            end
            % Last resort: empty literal.
            literal = '[]';
        end

        function literal = cellLiteral(c)
            % Serialize a cell array to a {...} literal.
            if isempty(c)
                literal = '{}';
                return;
            end
            [r, cc] = size(c);
            rows = cell(1, r);
            for ii = 1:r
                elems = cell(1, cc);
                for jj = 1:cc
                    elems{jj} = pf2_base.external.INI.toLiteral(c{ii, jj});
                end
                rows{ii} = strjoin(elems, ',');
            end
            literal = ['{' strjoin(rows, ';') '}'];
        end

        function literal = numericLiteral(value, fmt)
            % Serialize a numeric/logical scalar or matrix to a literal.
            if isscalar(value)
                literal = sprintf(fmt, value);
                return;
            end
            if isempty(value)
                literal = '[]';
                return;
            end
            r = size(value, 1);
            rows = cell(1, r);
            for ii = 1:r
                elems = arrayfun(@(x) sprintf(fmt, x), value(ii, :), ...
                    'UniformOutput', false);
                rows{ii} = strjoin(elems, ',');
            end
            literal = ['[' strjoin(rows, ';') ']'];
        end

        function value = coerceToStruct(value)
            % Convert struct-like objects to a struct for serialization.
            % Objects exposing toStruct() are converted to their canonical
            % legacy struct so the writer emits known field names.
            if isobject(value) && ~isstring(value) ...
                    && ~isa(value, 'function_handle')
                if ismethod(value, 'toStruct')
                    value = value.toStruct();
                else
                    try
                        value = struct(value);
                    catch
                        % leave as-is; toLiteral falls back to '[]'
                    end
                end
            end
        end

        function name = sanitizeName(raw)
            % Produce a valid MATLAB identifier from an arbitrary name.
            % Non-identifier characters collapse to underscores; the result
            % is run through makeValidName for guaranteed validity.
            if isstring(raw)
                raw = char(raw);
            end
            if isempty(raw)
                name = '';
                return;
            end
            cleaned = regexprep(raw, '[^A-Za-z0-9]+', '_');
            cleaned = regexprep(cleaned, '_+', '_');
            cleaned = regexprep(cleaned, '^_+|_+$', '');
            if isempty(cleaned)
                name = '';
                return;
            end
            name = char(matlab.lang.makeValidName(cleaned));
        end

        function text = readFileText(filePath)
            % Read an entire text file into a char row vector.
            fid = fopen(filePath, 'r');
            if fid < 0
                error('pf2_base:external:INI:cannotOpen', ...
                    'Could not open "%s" for reading.', filePath);
            end
            cleanup = onCleanup(@() fclose(fid));
            text = fread(fid, '*char')';
            clear cleanup;
        end

    end

end
