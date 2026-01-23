function list()
% LIST Display all available oxy processing methods for Stage 3
%
% Lists all configured hemoglobin processing methods available for Stage 3
% (post-Beer-Lambert) processing. Each method represents a different
% combination of filtering, artifact rejection, and post-processing
% functions applied to hemoglobin data. Methods are displayed with their
% index numbers for use with SetMethod.
%
% Syntax:
%   pf2.methods.oxy.list()
%
% Inputs:
%   None
%
% Outputs:
%   None (displays to console)
%
% Example:
%   % Display available oxy methods
%   pf2.methods.oxy.list();
%
%   % Typical workflow: list methods, then select one
%   pf2.methods.oxy.list();
%   pf2.methods.oxy.setMethod('takizawa_easy_lpf');
%
% See also: pf2.methods.oxy.setMethod, pf2.methods.oxy.describeMethod,
%           pf2.methods.raw.list

pf2.methods.oxy();