% pf2.import - Import functions for loading fNIRS data
% processFNIRS2 v1.0
%
% Auto-detect Import:
%   import            - Auto-detect format from file extension (or file browser)
%
% Format-Specific Import:
%   importNIR         - Import fNIR Devices/Biopac files (.nir)
%   importNIRX        - Import NIRx system files (.hdr, .wl1, .wl2)
%   importSNIRF       - Import SNIRF format files (.snirf)
%   importHitachiMES  - Import Hitachi ETG-4000 files (.csv)
%
% Batch Import:
%   importDirectory   - Recursively import all files from a directory tree
%
% Sample Data:
%   sampleData        - Load included example datasets (interactive)
%
% Subpackages:
%   +sampleData       - Individual sample datasets
%
% Example:
%   % Auto-detect format
%   data = pf2.import('myfile.nir');
%
%   % Interactive file browser
%   data = pf2.import();
%
%   % Specific format
%   data = pf2.import.importSNIRF('myfile.snirf');
%
%   % Sample data
%   data = pf2.import.sampleData.fNIR2000();
%
% See also: pf2.export, processFNIRS2
