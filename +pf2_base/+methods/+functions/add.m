function varargout=add(varargin)
% ADD Open the GUI to add a new processing function definition
%
% Wrapper that launches the processFNIRS2 add/edit-function GUI to register a
% new processing function (its arguments, defaults, and metadata) so it can
% be used in raw/oxy method pipelines. Outputs are forwarded from
% processFNIRS2_configureMethods_functionAddEdit.
%
% Syntax:
%   pf2_base.methods.functions.add()
%   out = pf2_base.methods.functions.add()
%
% Inputs:
%   varargin - Reserved; the underlying add/edit GUI is invoked with no
%              arguments (new-function mode).
%
% Outputs:
%   varargout - Whatever the add/edit-function GUI returns when an output is
%               requested (e.g. the app handle); empty otherwise.
%
% Example:
%   % Open the GUI to define a new processing function
%   pf2_base.methods.functions.add();
%
% See also: pf2_base.methods.functions.edit,
%           processFNIRS2_configureMethods_functionAddEdit

if(nargout>0)
    varargout{1:nargout}=processFNIRS2_configureMethods_functionAddEdit();
else
   processFNIRS2_configureMethods_functionAddEdit(); 
   varargout=[];
end