function handles = PF2Analyze_sampleCallback(fNIR, handlesIn)
%PF2ANALYZE_SAMPLECALLBACK Sample callback for PF2Analyze button
%   Template function demonstrating how to create custom analysis callbacks
%   for the processFNIRS2 GUI. Copy and modify this file to add custom
%   visualization or analysis beyond the standard oxy filtering.
%
%   Inputs:
%       fNIR      - Processed fNIRS struct
%       handlesIn - Optional figure handle to reuse
%
%   Outputs:
%       handles   - Figure handle for the analysis window

if nargin < 2 || isempty(handlesIn)
    handles = figure(505);
else
    handles = handlesIn;
    if isvalid(handles)
        set(0, 'CurrentFigure', handles);
    else
        handles = figure(505);
    end
end

% Add your custom analysis code here
% Example:
%   plot(fNIR.time, fNIR.HbO(:,1));
%   xlabel('Time (s)');
%   ylabel('HbO (mM*mm)');
%   title('Custom Analysis');

end
