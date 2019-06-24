function roi_out=pf2_build_pca_ROI(fNIR,component_number)
% pf2_build_nanmean_ROI uses the buildROI_pf2 wrapper
%   this function takes an fNIR struct and extracts already assigned values from 
%	the .ROI field

%	A welldefined ROI field will have a table with the names of each ROI in the rownames
% 	and a single column with the Optodes for each ROI

%	ex:	
%	fNIR.ROI.info=table([[1,2,3,4];[2,3,4]},'VariableNames',{'Optodes'},'RowNames',{'MyROI1','MyROI2'});

%	ex2:
%	myOptodes={[1,2,3,4];[10,11,12]};
%	myROInames={'thisROI','thatROI'};
%	fNIR.ROI.info=table(myOptodex,'VariableNames',{'Optode'},'RowNames',myROInames);

%	Weaklydefined ROIs can also be used
%		a cell array of optode numbers will be interpreted as each optode
%		and automatically converted to a table format with names ROI1,ROI2,...ROIn
%	ex: fNIR.ROI.info=cell({1,2,3,4};[7,8,9,10]};

%   myfuncString can either be a handle to a function or string for a function itself
%		if used as varargin, the inputs can be modified according to the functions needs


roi_out=pf2_base.fnirs.ezBuildROI(fNIR,@nanmean);

end
