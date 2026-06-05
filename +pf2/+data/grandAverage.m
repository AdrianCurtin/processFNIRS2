function ga = grandAverage(segments, varargin)
% GRANDAVERAGE Alias for pf2.data.blockAverage
%
% Convenience alias so the trial/grand-averaging entry point is discoverable
% under both names. See pf2.data.blockAverage for the full documentation,
% options, and output format.
%
% Syntax:
%   ga = pf2.data.grandAverage(segments)
%   ga = pf2.data.grandAverage(segments, 'Name', Value)
%
% Inputs:
%   segments - Cell array of oxy-processed fNIRS structs (see blockAverage).
%
% Outputs:
%   ga - Grand-average struct (see pf2.data.blockAverage).
%
% Example:
%   ga = pf2.data.grandAverage(segments);
%
% See also: pf2.data.blockAverage, pf2.data.extractBlocks

ga = pf2.data.blockAverage(segments, varargin{:});

end
