% pf2.export - Export functions for saving fNIRS data
% processFNIRS2 v0.8
%
% Auto-detect Export:
%   export            - Auto-detect format from file extension (or save dialog)
%
% Format-Specific Export:
%   asSNIRF           - Export to SNIRF format (.snirf) - recommended
%   asNIR             - Export to fNIR Devices/Biopac format (.nir)
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
% See also: pf2.import, processFNIRS2
