function addProcessingInfoTitle(fNIR, fig)
% ADDPROCESSINGINFOTITLE Add informative figure title from processingInfo
%
% Displays device name, processing method, and key settings as a figure
% title when processingInfo is available in the fNIRS data structure.
%
% Syntax:
%   pf2_base.plot.addProcessingInfoTitle(fNIR, fig)
%
% Inputs:
%   fNIR - fNIRS data structure (may contain processingInfo field)
%   fig  - Figure handle to add title to
%
% Example:
%   pf2_base.plot.addProcessingInfoTitle(data, gcf());
%
% See also: processFNIRS2, pf2.data.plot.oxy

if ~isfield(fNIR, 'processingInfo')
    return;
end

pInfo = fNIR.processingInfo;
titleParts = {};

% Device name
if isfield(pInfo, 'deviceName') && ~isempty(pInfo.deviceName)
    titleParts{end+1} = pInfo.deviceName;
end

% Processing method
if isfield(pInfo, 'rawMethod') && ~isempty(pInfo.rawMethod) && ~strcmpi(pInfo.rawMethod, 'None')
    titleParts{end+1} = pInfo.rawMethod;
end

% DPF mode
if isfield(pInfo, 'dpfMode')
    if strcmpi(pInfo.dpfMode, 'Calc') && isfield(pInfo, 'subjectAge')
        titleParts{end+1} = sprintf('DPF(age=%d)', pInfo.subjectAge);
    elseif strcmpi(pInfo.dpfMode, 'Fixed') && isfield(pInfo, 'dpfValue')
        titleParts{end+1} = sprintf('DPF=%.2f', pInfo.dpfValue);
    elseif strcmpi(pInfo.dpfMode, 'None')
        titleParts{end+1} = 'No DPF';
    end
end

if ~isempty(titleParts)
    pf2_base.external.suptitle(fig, strjoin(titleParts, ' | '));
end

end
