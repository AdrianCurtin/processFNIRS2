function [outFields,alternateSpellings]=pf2_getFNIRSbiomFields()

outFields={'raw','HbO','HbR','HbDiff','HbTotal','CBSI'};

alternateSpellings{1}={outFields{1},'Raw','MES','data'};  % raw light intensity data
alternateSpellings{2}={outFields{2},'hbo','Oxy'};  % delta[HbO]
alternateSpellings{3}={outFields{3},'hbr','Hb','hb','Deoxy'}; %delta[HbR]
alternateSpellings{4}={outFields{4},'hbdiff','deltahb','DiffHb','diffhb'}; %HbO-HbR
alternateSpellings{5}={outFields{5},'total','totalhb','TotalHb','totalHb'}; %HbO+HbR
alternateSpellings{6}={outFields{6},'cbsi'}; %CBSI(HbO,HbR)

