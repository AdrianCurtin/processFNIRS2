function SetMethod(raw_method)
% This function is a wrapper for the 'Raw_Method' argument in processFNIRS2
%   Also will look up the function number

if(nargin<1)
    fprintf(2,'No method provided, Please select a method\n');
	processFNIRS2.Methods.Raw();
    prompt = 'Enter Method Number: ';
    raw_method = input(prompt);
end


if(isnumeric(raw_method)) % Lookup method based on index
	global PF2
	if(pf2_base.isnestedfield(PF2,'myRawMethods.cfg.Sections'))
        if(raw_method<=length(PF2.myRawMethods.cfg.Sections))
            raw_method=PF2.myRawMethods.cfg.Sections{raw_method};
        end
	end
	
	if(isnumeric(raw_method))
		error('Unable to find method %i',raw_method);
	end
end

if(isstring(raw_method)||ischar(raw_method))

	processFNIRS2('Raw_Method',raw_method);
end