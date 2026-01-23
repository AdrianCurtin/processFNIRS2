function list()
% LIST Display all available raw processing methods for Stage 1
%
% Lists all configured raw processing methods available for the
% Raw-to-Optical Density conversion stage. Each method represents a
% different combination of filtering, motion correction, and artifact
% rejection functions. Methods are displayed with their index numbers
% for use with SetMethod.
%
% Syntax:
%   pf2.methods.raw.list()
%
% Inputs:
%   None
%
% Outputs:
%   None (displays to console)
%
% Example:
%   % Display available raw methods
%   pf2.methods.raw.list();
%
%   % Typical workflow: list methods, then select one
%   pf2.methods.raw.list();
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%
% See also: pf2.methods.raw.setMethod, pf2.methods.raw.describeMethod,
%           pf2.methods.oxy.list

pf2.methods.raw();