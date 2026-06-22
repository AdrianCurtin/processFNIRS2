function fNIR = defineROI(fNIR,optodeList,ROI_names)
% DEFINEROI Define regions of interest (ROIs) for fNIRS analysis
%
% Creates or appends ROI definitions to an fNIRS data structure. ROIs group
% multiple channels together for region-based analysis, enabling averaging
% across channels and statistical comparisons between brain regions. The
% ROI definitions are stored in fNIR.ROI.info as a table with optode lists.
%
% Reference:
%   Internal pf2 implementation for ROI-based fNIRS analysis.
%
% Syntax:
%   fNIR = defineROI(fNIR, optodeList)
%   fNIR = defineROI(fNIR, optodeList, ROI_names)
%   allData = defineROI(allData, optodeList, ROI_names)  % cell array input
%
% Inputs:
%   fNIR       - fNIRS data structure, or a cell array of fNIRS structs.
%                When a cell array is passed, the same ROI definition is
%                applied to every element and the cell array is returned.
%   optodeList - Cell array of optode/channel numbers for each ROI
%                {[1,2,3], [4,5,6]} defines 2 ROIs with 3 channels each.
%                Can also be [N_roi x N_opt] numeric matrix, but cell array
%                is preferred to avoid ambiguity.
%   ROI_names  - Cell array or string array of names for each ROI (optional)
%                Default: Auto-generated as 'ROI1', 'ROI2', etc.
%                If ROI already exists with same name, it will be overwritten.
%
% Outputs:
%   fNIR - Updated fNIRS structure (or cell array) with ROI.info field
%          containing:
%          - 'Optodes' column: Cell array of optode numbers for each ROI
%          - Row names: ROI names for identification
%
% Example:
%   % Define three ROIs for left, center, right prefrontal regions
%   data = pf2.import.sampleData.fNIR2000();
%   processed = processFNIRS2(data);
%   processed = pf2.probe.roi.defineROI(processed, ...
%       {[1,2,3,4,5,6], [7,8,9,10,11,12], [13,14,15,16,17,18]}, ...
%       {'Left_PFC', 'Center_PFC', 'Right_PFC'});
%
%   % Cell array: apply same ROIs to all subjects at once
%   allData = pf2.probe.roi.defineROI(allData, ...
%       {[1:6], [7:12], [13:18]}, {'Left', 'Center', 'Right'});
%
%   % Add additional ROI to existing definitions
%   processed = pf2.probe.roi.defineROI(processed, {[1,7,13]}, {'Anterior'});
%
%   % Auto-generate ROI names
%   processed = pf2.probe.roi.defineROI(processed, {[2,8,14], [6,12,18]});
%   % Creates 'ROI4' and 'ROI5' (continuing from existing ROIs)
%
% Notes:
%   - Pass optodeList as cell array to avoid ambiguity with numeric arrays
%   - If numeric matrix provided, assumes N_roi x N_opt dimensions
%   - Existing ROIs with same name will be overwritten with warning
%   - ROI definitions are required for ROI plotting and analysis functions
%
% See also: pf2_base.fnirs.buildROI, pf2_base.fnirs.ezBuildROI,
%           pf2.probe.plot.imageROIvalues, pf2.probe.plot.interpolateROIvalues

% Cell array support: apply same ROI definition to every element
if iscell(fNIR)
    for ci = 1:numel(fNIR)
        if nargin < 3
            fNIR{ci} = pf2.probe.roi.defineROI(fNIR{ci}, optodeList);
        else
            fNIR{ci} = pf2.probe.roi.defineROI(fNIR{ci}, optodeList, ROI_names);
        end
    end
    return;
end

if(nargin<3)
    autoGen_names=true;
else
    autoGen_names=false;

    ROI_names=cellstr(ROI_names);
end

if(nargin<2)
    error('pf2:probe:defineROI:noOptodeList', 'No optode list provided!');
end

if(isempty(optodeList))
    warning('Optode List is empty');
end

if(~iscell(optodeList))
    disp('Pass optode list as a cell array to avoid ambiguity with numeric arrays\n');
    disp('Otherwise ensure passing N_roi x N_opt as optode list');

    num_ROI=size(optodeList,1);

    optodeListTemp=cell(num_ROI,1);

    for i=1:num_ROI
        optodeListTemp{i}=optodeList(i,:);
    end
    optodeList=optodeListTemp;
end

num_ROI=length(optodeList);
optodeList = optodeList(:);  % ensure column for table row alignment

hasInfo=pf2_base.isnestedfield(fNIR,'ROI.info');

if ~hasInfo||(hasInfo&&isempty(fNIR.ROI.info))
    if(autoGen_names)
        ROI_names=cell(1,length(optodeList));
        for i=1:length(optodeList)
            ROI_names{i}=sprintf('ROI%i',i);
        end
    end
    fNIR.ROI.info=table(optodeList,'VariableNames',{'Optodes'},'RowNames',ROI_names);
else
    num_existing_ROI=size(fNIR.ROI.info,1);

    if(autoGen_names)
        ROI_names=cell(1,num_ROI);
        for i=1:num_ROI
            ROI_names{i}=sprintf('ROI%i',i+num_existing_ROI);
        end
        fNIR.ROI.info=[fNIR.ROI.info;table(optodeList,'VariableNames',{'Optodes'},'RowNames',ROI_names)];
    else
        existing_roi_names=fNIR.ROI.info.Properties.RowNames;
        for i=1:num_ROI
            if(contains(ROI_names{i},existing_roi_names))
                warning('ROI %s already exists!, overwriting', ROI_names{i});
                fNIR.ROI.info(ROI_names{i},:)=[table(optodeList(i),'VariableNames',{'Optodes'})];
            else
                fNIR.ROI.info=[fNIR.ROI.info;table(optodeList(i),'VariableNames',{'Optodes'},'RowNames',ROI_names(i))];
            end
        end
    end
end
    
end