% pf2.export - Export functions for saving fNIRS data
% processFNIRS2 v0.9
%
% Auto-detect Export:
%   export            - Auto-detect format from file extension (or save dialog)
%
% Format-Specific Export:
%   asSNIRF           - Export to SNIRF format (.snirf) - recommended
%   asNIR             - Export to fNIR Devices/Biopac format (.nir)
%
% Both format exporters support batch export of cell arrays. Pass a
% directory path instead of a file path and the exporter will write one
% file per element. Name-value pairs control subdirectory mapping and
% filename construction:
%
%   'Dir1'..'Dir4'  - Map .info field values to subdirectories
%   'Prefix'        - Build filenames from .info field values
%   'Verbose'       - Print progress (default: true)
%
% Example:
%   % Auto-detect format from extension
%   pf2.export(data, 'output.snirf');
%
%   % Interactive save dialog
%   pf2.export(data);
%
%   % Specific format
%   pf2.export.asSNIRF(data, 'output.snirf');
%
%   % Batch export cell array to directory
%   pf2.export.asSNIRF(allData, 'output/');
%   pf2.export.asSNIRF(allData, 'output/', 'Dir1', 'Group', 'Dir2', 'SubjectID');
%   pf2.export.asSNIRF(allData, 'output/', 'Prefix', {'SubjectID', 'SessionNum'});
%   pf2.export.export(allData, 'output/', 'Format', 'snirf', 'Dir1', 'Group');
%
% See also: pf2.import, processFNIRS2
