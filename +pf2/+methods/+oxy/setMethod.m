function setMethod(oxy_method, ctx)
% SETMETHOD Select the active oxy processing method for Stage 3 processing
%
% Sets the hemoglobin processing method used during Stage 3 of processFNIRS2.
% The method defines the sequence of filtering, artifact rejection, and
% post-processing functions applied to hemoglobin concentration data (HbO,
% HbR, etc.) after Beer-Lambert conversion. If no method is specified,
% displays available methods and prompts for selection.
%
% Syntax:
%   pf2.methods.oxy.setMethod(oxy_method)
%   pf2.methods.oxy.setMethod(methodIndex)
%   pf2.methods.oxy.setMethod()
%
% Inputs:
%   oxy_method - Method identifier, one of:
%                - String/char: Method name (e.g., 'takizawa_easy_lpf')
%                - Numeric: Method index from the available methods list
%                If omitted, displays method list and prompts for input.
%
% Example:
%   % Set method by name
%   pf2.methods.oxy.setMethod('takizawa_easy_lpf');
%
%   % Set method by index
%   pf2.methods.oxy.setMethod(3);
%
%   % Interactive selection (displays list, prompts for number)
%   pf2.methods.oxy.setMethod();
%
%   % Typical workflow
%   pf2.methods.oxy.list();                     % View available methods
%   pf2.methods.oxy.setMethod('medfilt_car');   % Select median filter + CAR
%   data = processFNIRS2(rawData);              % Process with selected method
%
% See also: pf2.methods.oxy.list, pf2.methods.oxy.describeMethod,
%           pf2.methods.oxy.configureMethods, pf2.methods.raw.setMethod,
%           processFNIRS2

if nargin < 2, ctx = []; end

if(nargin<1)
    fprintf(2,'No method provided, Please select a method\n');
	pf2.methods.oxy();
    prompt = 'Enter Method Number: ';
    oxy_method = input(prompt);
end

if(isnumeric(oxy_method)) % Lookup method based on index
	methodsLib = pf2_base.resolveMethodsLib('oxy', ctx);
	% methodsLib.cfg may be a struct or a pf2_base.external.INI object; the
	% latter exposes Sections as a property (isfield is false for objects), so
	% probe with a struct-or-object safe check before reading it.
	cfgHasSections = isfield(methodsLib,'cfg') && ...
	    ((isstruct(methodsLib.cfg) && isfield(methodsLib.cfg,'Sections')) || ...
	     (isobject(methodsLib.cfg) && isprop(methodsLib.cfg,'Sections')));
	if(cfgHasSections)
        if(oxy_method<=length(methodsLib.cfg.Sections))
            if(oxy_method==0)
                oxy_method=1;
            end
            oxy_method=methodsLib.cfg.Sections{oxy_method};
        end
	end
	
	if(isnumeric(oxy_method))
		error('pf2:methods:oxy:setMethod:methodNotFound', 'Unable to find method %i',oxy_method);
	end
end

if(isstring(oxy_method)||ischar(oxy_method))
    processFNIRS2('Oxy_Method',oxy_method);
end