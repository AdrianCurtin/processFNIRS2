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
	oxy_method = char(oxy_method);

	% When a ProcessingContext is supplied, set the method ON the context
	% (isolated state, validated against its own methods library) rather than
	% mutating the global PF2 -- this keeps parallel/reproducible processing
	% free of shared global state.
	if(~isempty(ctx) && isa(ctx,'pf2_base.ProcessingContext'))
		ctx.setOxyMethod(oxy_method);
		return;
	end

	% Write the selected method straight into the active stage. Previously
	% this delegated to processFNIRS2('Oxy_Method',...), but that config-only
	% call (no data) is intercepted by the noop pass-through early-return in
	% processFNIRS2 and never reaches the method-assignment block, so the
	% selection was silently dropped. Set the global directly instead, matching
	% processFNIRS2's own oxy-method assignment.
	methodsLib = pf2_base.resolveMethodsLib('oxy', ctx);
	if(~pf2_base.isnestedfield(methodsLib,sprintf('cfg.%s',oxy_method)))
		error('pf2:methods:oxy:setMethod:methodNotFound', ...
			'Unable to find method named: %s', oxy_method);
	end

	global PF2 %#ok<GVMIS>
	if(pf2_base.isnestedfield(PF2,'stageOxyMethod.name')&&~strcmpi(PF2.stageOxyMethod.name,oxy_method))
		fprintf('Setting Oxy Method to: %s\n',oxy_method);
	end
	PF2.stageOxyMethod=pf2_base.pf2_unpackMethod(methodsLib.cfg.(oxy_method));
	PF2.stageOxyMethod.name=oxy_method;
end
