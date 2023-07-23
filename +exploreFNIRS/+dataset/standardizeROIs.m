function [uROI,uROInames,ExFNIRS_data]=standardizeROIs(ExFNIRS_data)

fprintf('Scanning ROI fields...\n');
% searches for all unique ROI per device, one name allowed per d
uROI={};
standardDevRoiNames={};
standardROInames={};
numROIadded=0;
for i=1:length(ExFNIRS_data)
    if(pf2_base.isnestedfield(ExFNIRS_data{i},'ROI.info'))
        deviceName = ExFNIRS_data{i}.info.probename;
        curROInames=ExFNIRS_data{i}.ROI.info.Properties.RowNames;

        % if any name is empty, rename as auto_i, where i is
        % the index of the unnamed roi

        numROI = height(ExFNIRS_data{i}.ROI.info);

        if(isempty(curROInames))
            curROInames=cellstr(strcat('auto',num2str([1:numROI]')));
            ExFNIRS_data{i}.ROI.info.Properties.RowNames=curROInames;
        end

        ExFNIRS_data{i}.ROI.info.DeviceCfg(:)={ExFNIRS_data{i}.info.probename};
        ExFNIRS_data{i}.ROI.info.name=curROInames;
        

        deviceROInames= strcat(curROInames,'$',deviceName);

        ExFNIRS_data{i}.ROI.info.Properties.RowNames=deviceROInames;

        
        if(any(~ismember(deviceROInames,standardDevRoiNames)))
            for roiNum=1:numROI
                curROIname= ExFNIRS_data{i}.ROI.info.name{roiNum};
                curDevROIname=deviceROInames{roiNum};
                if(~ismember(curDevROIname,standardDevRoiNames))
                    % if roi does not have a name, give it a
                    % number instead
                   
                    standardDevRoiNames=[standardDevRoiNames,curDevROIname];
                    uROI=[uROI;ExFNIRS_data{i}.ROI.info(roiNum,:)];
                    fprintf('ROI: %s added\r\n',curDevROIname);
                    numROIadded=numROIadded+1;

                    if(~ismember(curROIname,standardROInames))
                        standardROInames=[standardROInames,curROIname];
                    end
                end
            end
        end
    end
end

%if(initROI) % standaradize all ROIs on first load
numUROI=length(standardROInames);
numDevROI = length(standardDevRoiNames);
[~,b,c]=unique(standardDevRoiNames);
if(height(b)>numDevROI)
    % This shouldnt be called because we only add ROI names
    % when they are not members of current or currentDevNames
    error('duplicate ROI names present');
end

% Assign linear index to all ROIs with same original name
uROI.index(:)=-1;
for r = 1: numUROI
    cur_u_roi_name= standardROInames{r};
    cur_u_roi_idx = strcmp(uROI.name,cur_u_roi_name);
    if(any(cur_u_roi_idx))
        uROI(cur_u_roi_idx,:).index(:)=r;
    end
end

roiIndex = standardROInames;

uROInames=standardDevRoiNames(b);
uROI=uROI(b,:);
uROI.Properties.RowNames=uROInames;

fprintf(2,'************\nOverwriting all ROI fields with standardized device specific versions..\n********\n');
for i=1:length(ExFNIRS_data)
    if(pf2_base.isnestedfield(ExFNIRS_data{i},'raw')&&~isempty(ExFNIRS_data{i}))
        deviceName = ExFNIRS_data{i}.info.probename;

        devROIs= uROI(strcmp(deviceName,uROI.DeviceCfg),:);
        devROIs.Properties.RowNames=devROIs.name;

        [a,s_idx] = sort(devROIs.index);
        ExFNIRS_data{i}.ROI.info=devROIs(s_idx,:);
    end
end

uROInames=standardROInames;

%end
 fprintf(2,'************\Standardization Complete!\n********\n');

