% cd 'C:\Users\zackg\OneDrive\Ayaz Lab\KernelFlow_Analysis\Homer3'
% setpaths
% C:\Users\zackg\OneDrive\Ayaz Lab\KernelFlow_Analysis\processFNIRS2

% load SNIRF file contents
%snirf = SnirfLoad('C:\Kernel\participants\participant_01\flow_data\session_1001\Cog1_S001_2163c20_5.snirf');
metaDataTags = snirf.metaDataTags.tags;
dataTimeSeries = snirf.data.dataTimeSeries;
time = snirf.data.time;

measurementList = snirf.data.measurementList;

num_data_channels = length(measurementList);
dataTypeArr = {zeros(num_data_channels)};
dataTypeLabelArr = {zeros(num_data_channels)};

for i=1:length(measurementList)
    dataTypeArr{i} = measurementList(i).GetDataType();
    dataTypeLabelArr{i} = measurementList(i).GetDataTypeLabel();
end

% determine unique data type and data type labels
uniDataTypes = unique(cellfun(@num2str, dataTypeArr, 'uni', 0));
uniDataTypeLabels = unique(cellfun(@num2str, dataTypeLabelArr, 'uni', 0));

sprintf('Unique Data Types: %s', sprintf(' %s ', uniDataTypes{:}))
sprintf('Unique Data Type Labels: %s', sprintf(' %s ', uniDataTypeLabels{:}))

% determine detector and source index counts
% TODO