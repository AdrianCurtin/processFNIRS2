function varargout=edit(varargin)
% EDIT Open the GUI to edit an existing processing function definition
%
% Wrapper that launches the processFNIRS2 add/edit-function GUI to modify the
% definition of an existing processing function (its arguments, defaults, and
% metadata). Requires the name of the function to edit. Arguments and outputs
% are forwarded to processFNIRS2_configureMethods_functionAddEdit.
%
% Syntax:
%   pf2.GUI.functions.edit(funcName)
%   out = pf2.GUI.functions.edit(funcName, ...)
%
% Inputs:
%   funcName - Name of the processing function to edit (e.g. 'pf2_lpf')
%   varargin - Additional arguments accepted by the add/edit-function GUI.
%
% Outputs:
%   varargout - Whatever the add/edit-function GUI returns when an output is
%               requested (e.g. the app handle).
%
% Example:
%   % Edit the definition of the low-pass filter function
%   pf2.GUI.functions.edit('pf2_lpf');
%
% See also: pf2.GUI.functions.add, pf2.GUI.functions,
%           processFNIRS2_configureMethods_functionAddEdit

if(nargin<1)
	error('pf2:GUI:functions:edit:noFunctionName', 'Please provide function name to edit');
end

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods_functionAddEdit(varargin{:});
else
   processFNIRS2_configureMethods_functionAddEdit(varargin{:}); 
end