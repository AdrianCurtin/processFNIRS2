function info = list(stage)
% LIST Enumerate available seed methods for the given stage.
%
% Syntax:
%   info = pf2_base.methods.seeds.list()        % both stages
%   info = pf2_base.methods.seeds.list('raw')   % raw stage only
%   info = pf2_base.methods.seeds.list('oxy')   % oxy stage only
%
% Inputs:
%   stage - (optional) 'raw' | 'oxy' (default: '' = both)
%
% Outputs:
%   info - struct array with fields:
%       .name  - method name (matches the .m filename)
%       .stage - 'raw' | 'oxy'
%       .file  - absolute path to the seed factory function
%
% Discovery: each seed package (+pf2_base/+methods/+seeds/+raw and .../+oxy)
% contributes one entry per .m file found there. The .m file must be a
% zero-argument function returning a Pipeline / RawPipeline / OxyPipeline.
%
% Example:
%   info = pf2_base.methods.seeds.list('raw');
%   for k = 1:numel(info)
%       p = feval(['pf2_base.methods.seeds.raw.' info(k).name]);
%       disp(p);
%   end
%
% See also: pf2.methods.resetDefaults

if nargin < 1, stage = ''; end
stage = lower(char(stage));

info = struct('name', {}, 'stage', {}, 'file', {});

stages = {'raw', 'oxy'};
if ~isempty(stage), stages = {stage}; end

baseDir = fileparts(mfilename('fullpath'));
for s = 1:numel(stages)
    stg = stages{s};
    pkgDir = fullfile(baseDir, ['+' stg]);
    if ~isfolder(pkgDir), continue; end
    files = dir(fullfile(pkgDir, '*.m'));
    for f = 1:numel(files)
        [~, name] = fileparts(files(f).name);
        info(end+1) = struct(...
            'name',  name, ...
            'stage', stg, ...
            'file',  fullfile(files(f).folder, files(f).name)); %#ok<AGROW>
    end
end
end
