function varargout=process(varargin)
% PROCESS Namespaced wrapper for the main processFNIRS2 entry point
%
% Thin pass-through to the top-level processFNIRS2 function, exposed inside
% the pf2 package so the full processing pipeline can be invoked as
% pf2.process(...). All arguments and outputs are forwarded unchanged; the
% GUI-suppression rule of processFNIRS2 still applies (assigning an output
% suppresses the GUI).
%
% Syntax:
%   pf2.process(data)
%   processed = pf2.process(data)
%   processed = pf2.process(data, rawMethod, oxyMethod)
%
% Inputs:
%   varargin - Any arguments accepted by processFNIRS2, typically an fNIRS
%              data struct (or cell array of structs) followed by optional
%              method names and name-value processing options.
%
% Outputs:
%   varargout - Whatever processFNIRS2 returns: the processed data struct
%               (or cell array) when an output is requested. With no output
%               requested the interactive GUI is launched instead.
%
% Example:
%   % Headless processing with default methods
%   data = pf2.import.sampleData.fNIR2000();
%   processed = pf2.process(data);
%
%   % Launch the GUI (no output captured)
%   pf2.process(data);
%
% See also: processFNIRS2, pf2.methods.raw.setMethod, pf2.methods.oxy.setMethod

if(nargout>0)

	varargout{1:nargout}=pf2(varargin{:});

else
	pf2(varargin{:});
end