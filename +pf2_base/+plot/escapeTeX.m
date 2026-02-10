function out = escapeTeX(in)
%ESCAPETEX Escape underscores for MATLAB's TeX interpreter
%   out = pf2_base.plot.escapeTeX(in) replaces bare underscores with \_
%   so they render as literal underscores instead of subscripts.
%
%   Already-escaped \_ sequences are preserved (no double-escaping).
%
%   Accepts char, string, cellstr, or passthrough for other types.
%
%   Examples:
%       escapeTeX('DLPFC_L')          % 'DLPFC\_L'
%       escapeTeX('already\_ok')      % 'already\_ok'
%       escapeTeX({'a_b', 'c_d'})     % {'a\_b', 'c\_d'}

    if ischar(in)
        out = regexprep(in, '(?<!\\)_', '\\_');
    elseif isstring(in)
        out = regexprep(in, '(?<!\\)_', '\\_');
    elseif iscell(in)
        out = cellfun(@(s) regexprep(s, '(?<!\\)_', '\\_'), in, 'UniformOutput', false);
    else
        out = in;
    end
end
