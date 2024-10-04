function mappedData=mapROIvaluesToCh(ROIinfo,data2map)

mappedData=nan(1,length(data2map(:)));

roiNums = unique(ROIinfo.index);
for i=1:size(ROIinfo,1)
    curChSet=ROIinfo.Optodes{i};
    if(size(curChSet)==size(data2map(ROIinfo.index(i))))
        mappedData(curChSet)=data2map(ROIinfo.index(i));
    end
end

mappedData=reshape(mappedData,size(data2map,1),size(data2map,2));

end