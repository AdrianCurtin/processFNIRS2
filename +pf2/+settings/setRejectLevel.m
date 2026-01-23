function setRejectLevel(rejectionLevel)
% SETREJECTLEVEL Set channel rejection threshold for fNIRS processing
%
% Configures the threshold used to reject channels based on their quality
% mask values. Channels with fchMask values below this threshold will be
% excluded from processing. This is a wrapper for the 'RejectLevel'
% argument in processFNIRS2.
%
% Channel mask values are typically assigned as:
%   1.0 = clean/good channel
%   0.5 = noisy/questionable channel
%   0.0 = bad/rejected channel
%
% Setting a higher rejection level excludes more channels (stricter),
% while a lower level includes more channels (more permissive).
%
% Syntax:
%   pf2.settings.setRejectLevel()
%   pf2.settings.setRejectLevel(rejectionLevel)
%
% Inputs:
%   rejectionLevel - Threshold value for channel rejection [double]
%                    Must be >= 0 and < 1.
%                    Channels with fchMask < rejectionLevel are excluded.
%                    (default: displays current rejection level)
%
% Example:
%   % Check current rejection level
%   pf2.settings.setRejectLevel();
%
%   % Include only clean channels (strict)
%   pf2.settings.setRejectLevel(0.9);
%
%   % Include clean and noisy channels (permissive)
%   pf2.settings.setRejectLevel(0.3);
%
%   % Include all non-bad channels
%   pf2.settings.setRejectLevel(0.1);
%
% Notes:
%   - Called without arguments, displays the current rejection level
%   - The rejection level persists across processing calls until changed
%
% See also: pf2.data.applyChannelMask, pf2.data.editChannelMaskGUI, processFNIRS2

if(nargin<1)
    global PF2
    
    if(~isfield(PF2,'RejectLevel'))
       pf2_base.pf2_initialize(); 
    end
    
    fprintf('Current Rejection Level is %.2f\n',PF2.RejectLevel);
    return;
end

if(~isnumeric(rejectionLevel)||rejectionLevel<0||rejectionLevel>=1)
	error('Please provide a valid rejection level, must be >=0 and <1');
end

processFNIRS2('RejectLevel',rejectionLevel);

fprintf('Rejection Level set to %.2f\n',rejectionLevel);
