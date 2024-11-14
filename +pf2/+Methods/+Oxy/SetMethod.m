function SetMethod(oxy_method)
% This function is a wrapper for the 'oxy_method' argument in pf2

if(nargin<1)
    fprintf(2,'No method provided, Please select a method\n');
	pf2.Methods.Oxy();
    prompt = 'Enter Method Number: ';
    oxy_method = input(prompt);
end

if(isnumeric(oxy_method)) % Lookup method based on index
	global PF2
	if(pf2_base.isnestedfield(PF2,'myOxyMethods.cfg.Sections'))
        if(oxy_method<=length(PF2.myOxyMethods.cfg.Sections))
            if(oxy_method==0)
                oxy_method=1;
            end
            oxy_method=PF2.myOxyMethods.cfg.Sections{oxy_method};
        end
	end
	
	if(isnumeric(oxy_method))
		error('Unable to find method %i',oxy_method);
	end
end

if(isstring(oxy_method)||ischar(oxy_method))
    processFNIRS2('Oxy_Method',oxy_method);
end