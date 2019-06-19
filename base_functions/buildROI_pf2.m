function roi_out=buildROI_pf2(fNIR,funcString,varargin)
% pf2_buildROI is a warpper function for the pf2_base.fNIR.buildROI function
%   this function takes an fNIR struct and extracts already assigned values from 
%	the .ROI field

%	A welldefined ROI field will have a table with the names of each ROI in the rownames
% 	and a single column with the Optodes for each ROI

%	ex:	
%	fNIR.info=table({[1,2,3,4];[2,3,4]},'VariableNames',{'Optodes'},'RowNames',{'MyROI1','MyROI2'});

%	ex2:
%	myOptodes={[1,2,3,4],[10,11,12]};
%	myROInames={'thisROI','thatROI'};
%	fNIR.info=table(myOptodex,'VariableNames',{'Optode'},'RowNames',myROInames);

%	Weaklydefined ROIs can also be used
%		a cell array of optode numbers will be interpreted as each optode
%		and automatically converted to a table format with names ROI1,ROI2,...ROIn
%	ex: fNIR.info=cell({1,2,3,4},[7,8,9,10]};

%   myfuncString can either be a handle to a function or string for a function itself
%		if used as varargin, the inputs can be modified according to the functions needs

if(nargin<2)
    roi_func_handle=@nanmean; % a default function here
elseif(ischar(funcString)||isstring(funcString))
    roi_func_handle=str2func(funcString);
else
    roi_func_handle=funcString;
end

if(~isfield(fNIR,'ROI'))
    fNIR.ROI=[]; % return a blank thing if there wasn't a field
end


if(pf2_base.isnestedfield(fNIR,'ROI.info'))
	% Unpack ROI information into channel and roi names
	if(istable(fNIR.ROI.info))
		roi_names=fNIR.ROI.info.Properties.RowNames;
		ch_index=fNIR.ROI.info{:,1};
	elseif(iscell(fNIR.ROI.info)||isnumeric(fNIR.ROI.info))
		ch_index=fNIR.ROI.info;
		
		if(isnumeric(ch_index))
			ch_index={ch_index};
		end
		
		roi_names=[];
	end
else
	% no ROI information is present
	%warning('No ROI information is present');
	roi_out=fNIR;
   
	return;
end

if(isstruct(fNIR)&&isfield(fNIR,'HbO')&&~isempty(fNIR.HbO))
	
    if(~isempty(varargin))
        roi_out=buildROI(fNIR,ch_index,roi_names,'oxy',roi_func_handle,varargin{:});
    else
        roi_out=buildROI(fNIR,ch_index,roi_names,'oxy',roi_func_handle);
    end
else
	% no HbO/HbR information is present to calculate ROIs from
	%warning('No Oxy information is present');
	roi_out=fNIR;
	return;
end

end
