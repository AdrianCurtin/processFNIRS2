function setMethod(raw_method)
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
%   pf2.methods.raw.setMethod('x5_TDDR'); % Select TDDR method
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


if(isnumeric(raw_method)) % Lookup method based on index
	global PF2
	if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections'))
        if(raw_method<=length(PF2.myRawMethods.cfg.Sections))
            if(raw_method==0)
                raw_method=1;
            end
            raw_method=PF2.myRawMethods.cfg.Sections{raw_method};
        end
	end
	
	if(isnumeric(raw_method))
		error('Unable to find method %i',raw_method);
	end
end

if(isstring(raw_method)||ischar(raw_method))

	pf2('Raw_Method',raw_method);
end