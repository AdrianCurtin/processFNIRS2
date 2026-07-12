function newName = cleanNameForINI(name)
% CLEANNAMEFORINI Sanitize a string for use as an INI section/key name
%
% Converts a string to a valid INI-compatible name by replacing special
% characters, accented letters, and spaces with safe alternatives. The
% result is also validated as a MATLAB identifier.
%
% Syntax:
%   newName = pf2_base.cleanNameForINI(name)
%
% Inputs:
%   name - String or char to sanitize. Cell arrays are unwrapped.
%
% Outputs:
%   newName - Sanitized string safe for INI files and MATLAB identifiers
%
% Example:
%   pf2_base.cleanNameForINI('My Method (v2)')  % Returns 'My_Method_v2'
%   pf2_base.cleanNameForINI('café')            % Returns 'cafe'
%   pf2_base.cleanNameForINI('Test-123')        % Returns 'Test_123'
%
% Notes:
%   - Accented characters are converted to ASCII equivalents
%   - Spaces, hyphens, brackets become underscores
%   - Double underscores are collapsed
%   - Trailing underscores are removed
%   - Result is validated with matlab.lang.makeValidName
%
% See also: matlab.lang.makeValidName, pf2.methods.raw.create

if iscell(name)
    name = name{1};
end

if isstring(name)
    name = char(name);
end

persistent Numbers LowerCases UpperCases

if isempty(Numbers)
    Numbers = arrayfun(@(n) {sprintf('%u',n)}, 0:9);
    LowerCases = arrayfun(@(n) {char(n+96)}, 1:26);
    UpperCases = arrayfun(@(n) {char(n+64)}, 1:26);
end

newName = '';
for n = 1:length(name)
    Character = name(n);
    switch Character
        case Numbers
        case LowerCases
        case UpperCases
        case {'À','Á','Â','Ã','Ä','Å'},     Character = 'A';
        case 'Æ',                           Character = 'AE';
        case 'Ç',                           Character = 'C';
        case {'È','É','Ê','Ë'},             Character = 'E';
        case {'Ì','Í','Î','Ï'},             Character = 'I';
        case 'Ñ',                           Character = 'N';
        case {'Ò','Ó','Ô','Õ','Ö'},         Character = 'O';
        case {'Ù','Ú','Û','Ü'},             Character = 'U';
        case 'Ý',                           Character = 'Y';
        case '²',                           Character = '2';
        case '³',                           Character = '3';
        case '¼',                           Character = '1_4';
        case '½',                           Character = '1_2';
        case '¾',                           Character = '3_4';
        case {'à','á','â','ã','ä','å'},     Character = 'a';
        case 'æ',                           Character = 'ae';
        case 'ç',                           Character = 'c';
        case {'è','é','ê','ë'},             Character = 'e';
        case {'ì','í','î','ï'},             Character = 'i';
        case 'ñ',                           Character = 'n';
        case {'ò','ó','ô','õ','ö'},         Character = 'o';
        case {'ù','ú','û','ü','µ'},         Character = 'u';
        case {'ý','ÿ'},                     Character = 'y';
        case {' ','''', '-', '_', ...
              '(','[','/','\'},             Character = '_';
        case {'°'},                         Character = 'deg';
        otherwise,                          Character = '';
    end
    newName = [newName, Character]; %#ok<AGROW>
end

% Clean up underscores
newName = strrep(newName, '__', '_');
if length(newName) > 1 && strcmp(newName(end), '_')
    newName = newName(1:end-1);
end

% Ensure valid MATLAB identifier
newName = matlab.lang.makeValidName(newName);

% Warn if name changed significantly
if ~strcmp(name, newName)
    warning('pf2:NameSanitized', ...
        'Name sanitized: ''%s'' -> ''%s''. Avoid special characters.', ...
        name, newName);
end

end
