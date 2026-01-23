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
%   pf2.Methods.Oxy.List()
%
% Inputs:
%   None
%
% Outputs:
%   None (displays to console)
%
% Example:
%   % Display available oxy methods
%   pf2.Methods.Oxy.List();
%
%   % Typical workflow: list methods, then select one
%   pf2.Methods.Oxy.List();
%   pf2.Methods.Oxy.SetMethod('takizawa_easy_lpf');
%
% See also: pf2.Methods.Oxy.SetMethod, pf2.Methods.Oxy.DescribeMethod,
%           pf2.Methods.Raw.List

pf2.Methods.Oxy();