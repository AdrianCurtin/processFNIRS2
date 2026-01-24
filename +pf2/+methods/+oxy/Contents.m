% pf2.methods.oxy - Oxy processing stage method management (Stage 3)
% processFNIRS2 v0.8
%
% Stage 3 post-processes hemoglobin concentrations with:
%   - Artifact rejection (Takizawa criterion)
%   - Additional filtering
%   - Common Average Reference (CAR)
%   - PCA-based noise reduction
%   - Detrending
%
% Method Selection:
%   list              - List all available oxy methods
%   setMethod         - Select active method (by name, index, or interactive)
%   describeMethod    - Display detailed method documentation
%
% Method Configuration:
%   configureMethods  - GUI for creating/editing method chains
%   importMethods     - Import method definitions from config file
%
% Example:
%   % List methods
%   pf2.methods.oxy.list();
%
%   % Interactive selection
%   pf2.methods.oxy.setMethod();
%
%   % Set by name
%   pf2.methods.oxy.setMethod('takizawa_easy');
%
%   % View description
%   pf2.methods.oxy.describeMethod('takizawa_hard_car');
%
% Common Oxy Methods:
%   None              - No post-processing
%   takizawa_easy     - Lenient artifact rejection
%   takizawa_hard     - Strict artifact rejection
%   car               - Common Average Reference
%   medfilt_car       - Median filter + CAR
%
% See also: pf2.methods.raw, pf2.methods, processFNIRS2
