function roi_out=buildROI(x,ch_index,roi_names,fieldToUse,removeNanChannels,roi_func_handle,varargin)
% buildROI is a basic matlab function which performs roi calculations based
%   on the specified function handle and returns the values in column x
%	fieldToUse is either oxy or raw, but will have to take into account channel numbers and wavelengths for raw (does not do this yet)
%  varargin will take arguments for function, for example:
%   buildROI(x,[1,2,3,4],'oxy',@mean,'includenan') will pass the include
%       nan argument to mean
if(nargin<4)
    fieldToUse='oxy';
end

if(nargin<5)
    roi_func_handle=@nanmean;
end

if(nargin<3)
   roi_names=cell(0,0); 
end

if(isstring(roi_names)|ischar(roi_names))
   roi_names=cellstr(roi_names);
end

if(isempty(roi_names)||iscell(ch_index)&&length(roi_names)<length(ch_index))
    if(isnumeric(ch_index))
        roi_names={'ROI1'};
    elseif(iscell(ch_index))
       for n=length(roi_names)+1:length(ch_index)
          roi_names{n}=sprintf('ROI%i',n); 
       end
    end
end

if(isnumeric(x))
    if(nargin<2)
        roi_out=roi_func_handle(x);
    end

    if(nargin<1)
       error('No data provided'); 
    end

    if(~isempty(x))
		if(isnumeric(ch_index))
			x=x(:,ch_index);
			roi_out=mergeAndRun(roi_func_handle,x',removeNanChannels,varargin);
		elseif(iscell(ch_index))
			for roi_ind=1:length(ch_index)
				x_roi=x(:,ch_index{roi_ind});
				roi_out(:,roi_ind)=mergeAndRun(roi_func_handle,x_roi',removeNanChannels,varargin);
			end
		end
    end
elseif(isstruct(x)&&strcmpi(fieldToUse,'OD')&&isfield(x,'raw')&&~isempty(x.raw))
    if(isfield(x,'probe'))
        devinfo=x.probe;
    else
        devinfo=[];
    end
    if(isempty(devinfo))
        global setF;
        if(pf2_base.isnestedfield(setF,'device.Probe'))
            
            x.probe=setF.device.Probe{1}; 
            devinfo=x.probe;
        
        else
            warning('Unable to find channel information, attempting raw indexing');
            devinfo=[];
        end
    end
    
    if(~isempty(devinfo))
        roi_out=x;
        chN=devinfo.ChannelNumbers;
        chWv=devinfo.Wavelength;
        chMerge=[chN;chWv];
        totalROIcols=0;
        roi_out.ROI.roi_num=[];
        if(isnumeric(ch_index))
            roi_ch_idx=ismember(chN,ch_index);
            x_roi=x.raw(:,roi_ch_idx);
            chWvSelect=round(chWv(roi_ch_idx));
            [~,uWvFirst,uWvIdx]=unique(chWvSelect);
                uWvSelect=chWvSelect(sort(uWvFirst));
            for wv_idx=1:length(uWvSelect)
                totalROIcols=totalROIcols+1;
                roi_out.ROI.raw(:,totalROIcols)=roi_func_handle(x_roi(:,uWvIdx==wv_idx)');
            end
            roi_out.ROI.roi_num=ones(size(uWvSelect));
            roi_out.ROI.info=table({ch_index},{'raw'},{uWvSelect},{ones(size(uWvSelect))},'RowNames',roi_names,'VariableNames',{'Channels','Type','Wavelengths','Index'});
        elseif(iscell(ch_index))
            for roi_ind=1:length(ch_index)
                roi_ch_idx=ismember(chN,ch_index{roi_ind});
                x_roi=x.raw(:,roi_ch_idx);
                chWvSelect=round(chWv(roi_ch_idx));
                [~,uWvFirst,uWvIdx]=unique(chWvSelect);
                uWvSelect=chWvSelect(sort(uWvFirst));
                
                for wv_idx=1:length(uWvSelect)
                    totalROIcols=totalROIcols+1;
                    roi_out.ROI.raw(:,totalROIcols)=roi_func_handle(x_roi(:,uWvIdx==wv_idx)');
                end
                roi_out.ROI.roi_num(end+1:end+length(uWvSelect))=repmat(roi_ind,1,length(uWvSelect));
                if(roi_ind==1)
                    roi_out.ROI.info=table(ch_index(roi_ind),{'raw'},{uWvSelect},{repmat(roi_ind,1,length(uWvSelect))},'RowNames',roi_names(roi_ind),'VariableNames',{'Channels','Type','Wavelengths','Index'});
                else
                    roi_out.ROI.info=[roi_out.ROI.info;table(ch_index(roi_ind),{'raw'},{uWvSelect},{repmat(roi_ind,1,length(uWvSelect))},'RowNames',roi_names(roi_ind),'VariableNames',{'Channels','Type','Wavelengths','Index'})];
                end
            end
        end
        
    else
        roi_out=x;
        if(isnumeric(ch_index))
            x_roi=x.raw(:,ch_index);
            roi_out.ROI.raw=mergeAndRun(roi_func_handle,x_roi',varargin);
            roi_out.ROI.info=table({ch_index},{'oxy'},'RowNames',roi_names,'VariableNames',{'Channels','Type'});
        elseif(iscell(ch_index))
            for roi_ind=1:length(ch_index)
                x_roi=x.raw(:,ch_index{roi_ind});
                roi_out.ROI.raw(:,roi_ind)=mergeAndRun(roi_func_handle,x_roi',varargin);
                
                if(roi_ind==1)
                    roi_out.ROI.info=table(ch_index(roi_ind),{'oxy'},'RowNames',roi_names(roi_ind),'VariableNames',{'Optodes','Type'});
                else
                    roi_out.ROI.info=[roi_out.ROI.info;table(ch_index(roi_ind),{'oxy'},'RowNames',roi_names(roi_ind),'VariableNames',{'Optodes','Type'})];
                end
            end
        end  
    end
    
elseif(isstruct(x)&&strcmpi(fieldToUse,'oxy')&&isfield(x,'HbO')&&~isempty(x.HbO))
    validFields={'HbO','HbR','HbTotal','HbDiff','CBSI'};
    x.ROI=[];
    roi_out=x;

    if(isnumeric(ch_index))
        for field_ind=1:length(validFields)
			if(isfield(x,(validFields{field_ind}))&&~isempty(x.(validFields{field_ind})))
				x_roi=x.(validFields{field_ind})(:,ch_index);
				roi_out.ROI.(validFields{field_ind})=mergeAndRun(roi_func_handle,x_roi',removeNanChannels,varargin);
            else
               error('invalid fields'); 
            end
        end
        roi_out.ROI.info=table({ch_index},{'oxy'},'RowNames',roi_names,'VariableNames',{'Optodes','Type'});
    elseif(iscell(ch_index))
        for roi_ind=1:length(ch_index)
            for field_ind=1:length(validFields)
				if(isfield(x,(validFields{field_ind}))&&~isempty(x.(validFields{field_ind})))
					x_roi=x.(validFields{field_ind})(:,ch_index{roi_ind});
					roi_out.ROI.(validFields{field_ind})(:,roi_ind)=mergeAndRun(roi_func_handle,x_roi',removeNanChannels,varargin);
				else
                   error('invalid fields'); 
                end
            end
            if(roi_ind==1)
                roi_out.ROI.info=table(ch_index(roi_ind),{'oxy'},'RowNames',roi_names(roi_ind),'VariableNames',{'Optodes','Type'});
            else
                roi_out.ROI.info=[roi_out.ROI.info;table(ch_index(roi_ind),{'oxy'},'RowNames',roi_names(roi_ind),'VariableNames',{'Optodes','Type'})];
            end
        end
    end
end

end

function out=mergeAndRun(func_handle,x_roi,removeNanChannels,varg)

    len_x_roi=size(x_roi,2);

    if(removeNanChannels)
        %Removed NAN vals before processing
        nnz_x=sum(~isnan(x_roi),2)==0;
        rm_ch=sum(nnz_x);
        x_roi=x_roi(~nnz_x,:);
        
        if(rm_ch>0)
            fprintf('Removed %i channels from ROI\n',rm_ch);
        end
        
    end

    
    if(size(x_roi,1)==0) % if all rows removed
        out=nan(1,len_x_roi);
        return;
    end

    if(size(x_roi,1)==1)
       warning('Only single channel present in ROI, returning just the one channel');
       out=x_roi; 
       return;
    end
    
    
    
    if(isempty(varg)||(length(varg)==1&&isempty(varg{1})))
        out=func_handle(x_roi);
    else
        out=func_handle(x_roi,varg{:});
    end
    
    if(len_x_roi~=length(out))
       warning('Size mismatch during ROI calculation\n');
       if(length(out)<=1||isempty(out))
          out=nan(1,len_x_roi); 
       end
    end


end