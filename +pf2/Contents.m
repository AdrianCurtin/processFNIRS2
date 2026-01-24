% pf2 - processFNIRS2 main user interface package
% processFNIRS2 v0.8
%
% Top-Level Functions:
%   help              - Interactive help system
%   methods           - List all processing methods
%   process           - Process fNIRS data (alias for processFNIRS2)
%   gui               - Launch processing GUI
%
% Subpackages:
%   +import           - Import fNIRS data from various formats
%   +export           - Export fNIRS data to various formats
%   +data             - Data manipulation and time series visualization
%   +probe            - Probe geometry and topographic visualization
%   +methods          - Processing method management
%   +settings         - Configuration and parameter settings
%   +gui              - GUI-related functions
%   +process          - Processing pipeline functions
%
% Quick Start:
%   data = pf2.import.sampleData.fNIR2000();  % Load sample
%   processed = processFNIRS2(data);           % Process
%   pf2.data.plot(processed);                  % Visualize
%
% Progressive Disclosure:
%   The API uses depth = specificity. Parent-level calls auto-detect
%   or prompt interactively; child-level calls are explicit.
%
%   pf2.import()                      % Interactive file browser
%   pf2.import('file.nir')            % Auto-detect format
%   pf2.import.importNIR('file.nir')  % Explicit format
%
% See also: processFNIRS2, exploreFNIRS
