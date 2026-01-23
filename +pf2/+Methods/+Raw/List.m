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
%   pf2.Methods.Raw.List()
%
% Inputs:
%   None
%
% Outputs:
%   None (displays to console)
%
% Example:
%   % Display available raw methods
%   pf2.Methods.Raw.List();
%
%   % Typical workflow: list methods, then select one
%   pf2.Methods.Raw.List();
%   pf2.Methods.Raw.SetMethod('x2_lpf_smar');
%
% See also: pf2.Methods.Raw.SetMethod, pf2.Methods.Raw.DescribeMethod,
%           pf2.Methods.Oxy.List

pf2.Methods.Raw();