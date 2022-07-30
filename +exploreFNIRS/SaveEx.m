function [filename] = SaveEx(filename)
%SAVEEX Summary of this function goes here
%   Detailed explanation goes here
pathname='';

if(nargin<1)
    [filename, pathname] = uiputfile({'*_exf.mat';'*.mat';'*.*'},'Save Explore FNIRS experiment');
    if(isempty(filename)||~ischar(filename)||(isnumeric(filename)&&filename==0))
        return
    end
end



global ExFNIRS

if(~isfield(ExFNIRS,'data'))
    error('No data present in ExFNIRS');
end

if(~isempty(pathname))
    filename=sprintf('%s/%s',pathname,filename);
end

fprintf('Saving experiment to %s...\n',filename);

save(filename,'ExFNIRS','-v7.3');

fprintf('Done!\n');



end

