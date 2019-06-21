function SetRejectLevel(rejectionLevel)
% This function is a wrapper for the 'RejectionLevel' argument in processFNIRS2
% Alows the rejectionLevel to be set conservatively in the probeCheckGUI
% and more liberally for questionable channels

% default is clean channels = 1 with noisy channels = 0.5 and bad channels = 0
%   Inceasing the rejectlevel will lower the number of remaining channels

if(nargin<1)
    global PF2
    fprintf('Current Rejection Level is %.2\n',PF2.RejectLevel);
    return;
end

if(~isnumeric(rejectionLevel)||rejectionLevel<0||rejectionLevel>=1)
	error('Please provide a valid rejection level, must be >=0 and <1');
end

processFNIRS2('RejectLevel',rejectionLevel);