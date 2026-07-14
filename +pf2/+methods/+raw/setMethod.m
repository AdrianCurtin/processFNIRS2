function setMethod(raw_method, ctx)
% SETMETHOD Select the active raw processing method for Stage 1 processing
%
% Sets the raw processing method used during the Raw-to-Optical Density
% conversion stage of processFNIRS2. The method defines the sequence of
% filtering, motion correction, and artifact rejection functions applied
% to raw fNIRS data. If no method is specified, displays available methods
% and prompts for selection.
%
% Syntax:
%   pf2.methods.raw.setMethod(raw_method)
%   pf2.methods.raw.setMethod(methodIndex)
%   pf2.methods.raw.setMethod()
%
% Inputs:
%   raw_method - Method identifier, one of:
%                - String/char: Method name (e.g., 'x2_lpf_smar')
%                - Numeric: Method index from the available methods list
%                If omitted, displays method list and prompts for input.
%
% Example:
%   % Set method by name
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%
%   % Set method by index
%   pf2.methods.raw.setMethod(3);
%
%   % Interactive selection (displays list, prompts for number)
%   pf2.methods.raw.setMethod();
%
%   % Typical workflow
%   pf2.methods.raw.list();              % View available methods
%   pf2.methods.raw.setMethod('OD_TDDR'); % Select TDDR method
%   data = processFNIRS2(rawData);       % Process with selected method
%
% See also: pf2.methods.raw.list, pf2.methods.raw.describeMethod,
%           pf2.methods.raw.configureMethods, pf2.methods.oxy.setMethod,
%           processFNIRS2

if(nargin<1)
    fprintf(2,'No method provided, Please select a method\n');
	pf2.methods.raw();
    prompt = 'Enter Method Number: ';
    raw_method = input(prompt);
end


if nargin < 2, ctx = []; end

if(isnumeric(raw_method)) % Lookup method based on index
	methodsLib = pf2_base.resolveMethodsLib('raw', ctx);
	% methodsLib.cfg may be a struct or a pf2_base.external.INI object; the
	% latter exposes Sections as a property (isfield is false for objects), so
	% probe with a struct-or-object safe check before reading it.
	cfgHasSections = isfield(methodsLib,'cfg') && ...
	    ((isstruct(methodsLib.cfg) && isfield(methodsLib.cfg,'Sections')) || ...
	     (isobject(methodsLib.cfg) && isprop(methodsLib.cfg,'Sections')));
	if(cfgHasSections)
        if(raw_method<=length(methodsLib.cfg.Sections))
            if(raw_method==0)
                raw_method=1;
            end
            raw_method=methodsLib.cfg.Sections{raw_method};
        end
	end
	
	if(isnumeric(raw_method))
		error('pf2:methods:raw:setMethod:methodNotFound', 'Unable to find method %i',raw_method);
	end
end

if(isstring(raw_method)||ischar(raw_method))
	raw_method = char(raw_method);

	% When a ProcessingContext is supplied, set the method ON the context
	% (isolated state, validated against its own methods library) rather than
	% mutating the global PF2 -- this keeps parallel/reproducible processing
	% free of shared global state.
	if(~isempty(ctx) && isa(ctx,'pf2_base.ProcessingContext'))
		ctx.setRawMethod(raw_method);
		return;
	end

	% Write the selected method straight into the active stage. Previously
	% this delegated to processFNIRS2('Raw_Method',...), but that config-only
	% call (no data) is intercepted by the noop pass-through early-return in
	% processFNIRS2 and never reaches the method-assignment block, so the
	% selection was silently dropped. Set the global directly instead, matching
	% processFNIRS2's own raw-method assignment.
	methodsLib = pf2_base.resolveMethodsLib('raw', ctx);
	if(~pf2_base.isnestedfield(methodsLib,sprintf('cfg.%s',raw_method)))
		error('pf2:methods:raw:setMethod:methodNotFound', ...
			'Unable to find method named: %s', raw_method);
	end

	global PF2 %#ok<GVMIS>
	if(pf2_base.isnestedfield(PF2,'stageRawMethod.name')&&~strcmpi(PF2.stageRawMethod.name,raw_method))
		fprintf('Setting Raw Method to: %s\n',raw_method);
	end
	PF2.stageRawMethod=pf2_base.pf2_unpackMethod(methodsLib.cfg.(raw_method));
	PF2.stageRawMethod.name=raw_method;
end
