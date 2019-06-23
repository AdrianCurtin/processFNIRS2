function mappedData=mapROIvaluesToCh(ROIinfo,data2map)

mappedData=nan(1,length(data2map(:)));
for i=1:size(ROIinfo,1)
    curChSet=ROIinfo.Optodes{i};
    mappedData(curChSet)=data2map(i);
end

mappedData=reshape(mappedData,size(data2map,1),size(data2map,2));

end