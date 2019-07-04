function [filename] = LoadEx(filename)
%SAVEEX Summary of this function goes here
%   Detailed explanation goes here
pathname='';

if(nargin<1)
    [filename, pathname] = uigetfile({'*.mat';'*.*'},'Load Explore FNIRS experiment');
    if(isempty(filename)||~ischar(filename)||(isnumeric(filename)&&filename==0))
        return
    end
end

if(~isempty(pathname))
    filename=sprintf('%s/%s',pathname,filename);
end


tempLoadEx=load(filename,'ExFNIRS');


if(~isfield(tempLoadEx,'ExFNIRS')||isempty(tempLoadEx))
    error('No data found');
end




global ExFNIRS

fieldsToKeep={'settings','data','dataHierarchy','dataTable','currentROI'};

for f=1:length(fieldsToKeep)
    if(isfield(tempLoadEx.ExFNIRS,fieldsToKeep{f}))
        ExFNIRS.(fieldsToKeep{f})=tempLoadEx.ExFNIRS.(fieldsToKeep{f});
    end
end

ExFNIRS.UpdateNeeded=4;

end

