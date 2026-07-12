function roi_out=pf2_build_pca_ROI(fNIR,component_number)
% PF2_BUILD_PCA_ROI Build ROI signals using principal component analysis
%
% Constructs Region of Interest (ROI) time series by extracting the first
% (or specified) principal component from the channels belonging to each
% ROI. This captures the dominant shared variance across channels, which
% can be more robust than simple averaging when channels have different
% noise levels.
%
% The function reads ROI definitions from the fNIR.ROI.info field and
% applies PCA (SVD algorithm) across the channels belonging to each ROI,
% returning the temporal score for the requested component.
%
% Syntax:
%   roi_out = pf2_build_pca_ROI(fNIR)
%   roi_out = pf2_build_pca_ROI(fNIR, component_number)
%
% Inputs:
%   fNIR             - fNIRS data structure containing:
%                      .HbO, .HbR, .HbTotal, .HbDiff - Hemoglobin [T x C]
%                      .ROI.info - Table defining ROI channel assignments
%   component_number - Which principal component to extract (default: 1)
%                      Component 1 captures the most shared variance.
%
% Outputs:
%   roi_out - fNIRS structure with ROI fields populated:
%             .ROI.HbO, .ROI.HbR, etc. - [T x R] where R = number of ROIs
%             Each column is the PCA score for that ROI.
%
% Example:
%   fNIR.ROI.info = table({[1,2,3,4]; [5,6,7,8]}, ...
%                        'VariableNames', {'Optodes'}, ...
%                        'RowNames', {'LeftPFC', 'RightPFC'});
%   fNIR = pf2_build_pca_ROI(fNIR);
%   plot(fNIR.time, fNIR.ROI.HbO);
%
% Notes:
%   - Returns the temporal score (not spatial loadings) for the component
%   - If PCA fails (e.g., all NaN), returns NaN column for that ROI
%   - For simple averaging, use pf2_build_nanmean_ROI instead
%
% See also: pf2_build_nanmean_ROI, pf2_base.fnirs.ezBuildROI, pca

	if(nargin<2)
		component_number=1;
	end

	roi_out=pf2_base.fnirs.ezBuildROI(fNIR,@getPCAcomponent,component_number);

end


% ROI calculation handle here
function outSig=getPCAcomponent(x,componentNumber)

	if(nargin<2)
		componentNumber=1;
	end

	fprintf('Calculating PCA...\n');
	[~,score,~,~,explained]=pf2_base.compat.pca(x,'Algorithm','svd');

    if(~isempty(score) && size(score,2) >= componentNumber)
        outSig=score(:,componentNumber);

        fprintf('Variance in component %i explains %.1f%% variability in %i Channels\n',componentNumber,(explained(componentNumber)),size(x,2));

        if(isnan(explained(componentNumber)))
           outSig=nan(size(x,1),1);
        end
    else
           outSig=nan(size(x,1),1);
    end

end
    
