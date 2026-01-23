function [outFields,alternateSpellings]=pf2_getFNIRSbiomFields()
% PF2_GETFNIRSBIOMFIELDS Return biomarker field names and alternate spellings
%
% Returns the list of standard biomarker field names used in processFNIRS2
% fNIRS data structures, along with a mapping of alternate spellings that
% may be encountered in imported data or legacy files. This enables
% consistent field access regardless of naming conventions used by different
% data sources.
%
% Reference:
%   Internal pf2 implementation. Biomarker definitions follow standard
%   fNIRS conventions for hemoglobin concentration changes.
%
% Syntax:
%   outFields = pf2_getFNIRSbiomFields()
%   [outFields, alternateSpellings] = pf2_getFNIRSbiomFields()
%
% Inputs:
%   None
%
% Outputs:
%   outFields          - Cell array of standard biomarker field names {1 x 6}
%                        Contains: 'raw', 'HbO', 'HbR', 'HbDiff', 'HbTotal',
%                        'CBSI'
%   alternateSpellings - Cell array {1 x 6} where each element is a cell
%                        array of alternate names for the corresponding
%                        biomarker field. First element is always the
%                        standard name.
%
% Biomarker Descriptions:
%   raw     - Raw light intensity data (alternates: 'Raw', 'MES', 'data')
%   HbO     - Oxygenated hemoglobin changes (alternates: 'hbo', 'Oxy')
%   HbR     - Deoxygenated hemoglobin changes (alternates: 'hbr', 'Hb',
%             'hb', 'Deoxy')
%   HbDiff  - Differential hemoglobin: HbO - HbR (alternates: 'hbdiff',
%             'deltahb', 'DiffHb', 'diffhb')
%   HbTotal - Total hemoglobin: HbO + HbR (alternates: 'total', 'totalhb',
%             'TotalHb', 'totalHb')
%   CBSI    - Correlation-based signal improvement (alternates: 'cbsi')
%
% Example:
%   % Get standard biomarker field names
%   biomarkers = pf2_base.pf2_getFNIRSbiomFields();
%   disp(biomarkers);  % {'raw', 'HbO', 'HbR', 'HbDiff', 'HbTotal', 'CBSI'}
%
%   % Get alternate spellings for field name mapping
%   [fields, alts] = pf2_base.pf2_getFNIRSbiomFields();
%   % alts{2} = {'HbO', 'hbo', 'Oxy'} - all valid names for HbO
%
% See also: pf2_getFNIRSfields, pf2_initialize, processFNIRS2

outFields={'raw','HbO','HbR','HbDiff','HbTotal','CBSI'};

alternateSpellings{1}={outFields{1},'Raw','MES','data'};  % raw light intensity data
alternateSpellings{2}={outFields{2},'hbo','Oxy'};  % delta[HbO]
alternateSpellings{3}={outFields{3},'hbr','Hb','hb','Deoxy'}; %delta[HbR]
alternateSpellings{4}={outFields{4},'hbdiff','deltahb','DiffHb','diffhb'}; %HbO-HbR
alternateSpellings{5}={outFields{5},'total','totalhb','TotalHb','totalHb'}; %HbO+HbR
alternateSpellings{6}={outFields{6},'cbsi'}; %CBSI(HbO,HbR)

