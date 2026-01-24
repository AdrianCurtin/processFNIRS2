% pf2.methods - Processing method management
% processFNIRS2 v0.9
%
% List Methods:
%   methods           - List all available methods (raw + oxy)
%
% Subpackages:
%   +raw              - Raw processing stage methods (Stage 1: Raw -> OD)
%   +oxy              - Oxy processing stage methods (Stage 3: Hb -> Final)
%
% Raw Method Functions (pf2.methods.raw.*):
%   list              - List available raw methods
%   setMethod         - Select active raw method (by name or interactive)
%   describeMethod    - Display method documentation
%   configureMethods  - GUI for creating/editing methods
%   importMethods     - Import method config file
%   create            - Create new method programmatically (no GUI)
%   addFunction       - Add processing function to existing method
%
% Oxy Method Functions (pf2.methods.oxy.*):
%   list              - List available oxy methods
%   setMethod         - Select active oxy method (by name or interactive)
%   describeMethod    - Display method documentation
%   configureMethods  - GUI for creating/editing methods
%   importMethods     - Import method config file
%   create            - Create new method programmatically (no GUI)
%   addFunction       - Add processing function to existing method
%
% Common Methods:
%   describeCurrentMethods - Show currently selected methods
%
% Example:
%   % List all methods
%   pf2.methods();
%
%   % Set raw method interactively
%   pf2.methods.raw.setMethod();
%
%   % Set method by name
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%   pf2.methods.oxy.setMethod('takizawa_easy');
%
%   % View method description
%   pf2.methods.raw.describeMethod('x2_lpf_smar');
%
% See also: processFNIRS2, pf2.settings
