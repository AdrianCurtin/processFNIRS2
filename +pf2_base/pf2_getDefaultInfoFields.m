function [outFields,defaultValues]=pf2_getDefaultInfoFields()
% PF2_GETDEFAULTINFOFIELDS Return default metadata field names and placeholder values
%
% Returns the standard set of info field names and their placeholder
% default values used when initializing data.info on newly imported
% fNIRS recordings.
%
% Syntax:
%   [outFields, defaultValues] = pf2_base.pf2_getDefaultInfoFields()
%
% Inputs:
%   None
%
% Outputs:
%   outFields     - Cell array of field name strings [1 x 8]
%   defaultValues - Cell array of placeholder values [1 x 8]
%                   SubjectID gets a random numeric suffix to avoid
%                   accidental merges across subjects.
%
% Example:
%   [fields, defaults] = pf2_base.pf2_getDefaultInfoFields();
%   for i = 1:numel(fields)
%       data.info.(fields{i}) = defaults{i};
%   end
%
% See also: pf2.data.importInfo, pf2.data.infoFromTable

outFields={'SubjectID','Group','Session','Trial','Block','Condition','Age','Sex'};

subNum=round(rand(1)*1000);

defaultValues={sprintf('Unknown%i',subNum),'Unknown','Unknown','Unknown','Unknown','Unknown',[],'Unknown'};