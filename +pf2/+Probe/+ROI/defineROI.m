function fNIR = defineROI(fNIR,optodeList,ROI_names)

% defineROI creates a new ROI.info or appends to ROI.info the list of
% optodes and ROI names used by pf2 to process ROI regions
% optodeList should be a cell array of optode numbers and ROI_names should
% contain the associated name for each cell region

if(nargin<3)
    autoGen_names=true;
else
    autoGen_names=false;

    ROI_names=cellstr(ROI_names);
end

if(nargin<2)
    error('No optode list provided!');
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
                warning('ROI %s already exists!, overwriting');
                fNIR.ROI.info(ROI_names{i},:)=[table(optodeList(i),'VariableNames',{'Optodes'})];
            else
                fNIR.ROI.info=[fNIR.ROI.info;table(optodeList(i),'VariableNames',{'Optodes'},'RowNames',ROI_names(i))];
            end
        end
    end
end
    
end