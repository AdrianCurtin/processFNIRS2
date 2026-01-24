% pf2.methods.raw - Raw processing stage method management (Stage 1)
% processFNIRS2 v0.8
%
% Stage 1 converts raw light intensity to optical density with:
%   - Motion artifact correction (SMAR, TDDR, MARA, Wavelet)
%   - Filtering (low-pass, band-pass, high-pass)
%   - Ambient channel subtraction
%   - ICA-based noise removal
%
% Method Selection:
%   list              - List all available raw methods
%   setMethod         - Select active method (by name, index, or interactive)
%   describeMethod    - Display detailed method documentation
%
% Method Configuration:
%   configureMethods  - GUI for creating/editing method chains
%   importMethods     - Import method definitions from config file
%
% Example:
%   % List methods
%   pf2.methods.raw.list();
%
%   % Interactive selection
%   pf2.methods.raw.setMethod();
%
%   % Set by name
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%
%   % View description
%   pf2.methods.raw.describeMethod('x5_TDDR');
%
% Common Raw Methods:
%   x1_lpf          - Low-pass filter only
%   x2_lpf_smar     - Low-pass + SMAR motion correction
%   x5_TDDR         - Temporal derivative distribution repair
%   x3_bpf          - Band-pass filter (0.008-0.1 Hz)
%
% See also: pf2.methods.oxy, pf2.methods, processFNIRS2
