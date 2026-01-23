function [outputStr] = describeCurrentMethods(methodStage)
% DESCRIBECURRENTMETHOD Display details of currently active processing methods
%
% Shows the complete configuration of the currently selected raw and/or oxy
% processing methods. This is a convenience function that calls the
% DescribeMethod functions for both processing stages. Useful for verifying
% which methods are active before processing data.
%
% Syntax:
%   pf2.methods.describeCurrentMethods()
%   pf2.methods.describeCurrentMethods(methodStage)
%   outputStr = pf2.methods.describeCurrentMethods(...)
%
% Inputs:
%   methodStage - Processing stage to describe (optional):
%                 - 1 or 'raw': Show only raw method (Stage 1)
%                 - 2 or 'oxy': Show only oxy method (Stage 3)
%                 If omitted, shows both raw and oxy methods.
%
% Outputs:
%   outputStr - String containing the formatted method description(s)
%               If not requested, description prints to console.
%
% Example:
%   % Display both current methods to console
%   pf2.methods.describeCurrentMethods();
%
%   % Display only the raw method
%   pf2.methods.describeCurrentMethods('raw');
%   pf2.methods.describeCurrentMethods(1);  % Equivalent
%
%   % Display only the oxy method
%   pf2.methods.describeCurrentMethods('oxy');
%   pf2.methods.describeCurrentMethods(2);  % Equivalent
%
%   % Get descriptions as string for logging or display
%   desc = pf2.methods.describeCurrentMethods();
%   fprintf('Current processing configuration:\n%s\n', desc);
%
%   % Typical workflow: check methods before processing
%   pf2.methods.raw.setMethod('x2_lpf_smar');
%   pf2.methods.oxy.setMethod('takizawa_easy_lpf');
%   pf2.methods.describeCurrentMethods();  % Verify settings
%   processed = processFNIRS2(data);
%
% See also: pf2.methods.raw.describeMethod, pf2.methods.oxy.describeMethod,
%           pf2.methods.raw.setMethod, pf2.methods.oxy.setMethod

if(nargout==0)
    
if(nargin==0)
    pf2.methods.raw.describeMethod();
    pf2.methods.oxy.describeMethod();
else

    switch methodStage
        case 1
            pf2.methods.raw.describeMethod();
        case 'raw'
            pf2.methods.raw.describeMethod();
        case 2
            pf2.methods.oxy.describeMethod();
        case 'oxy'
            pf2.methods.oxy.describeMethod();
    end

end

elseif(nargout>0)
    if(nargin==0)
        outputStr=pf2.methods.raw.describeMethod();
        outputStr=sprintf('%s\n%s',outputStr,pf2.methods.oxy.describeMethod());
    else

        switch methodStage
            case 1
                outputStr=pf2.methods.raw.describeMethod();
            case 'raw'
                outputStr=pf2.methods.raw.describeMethod();
            case 2
                outputStr=pf2.methods.oxy.describeMethod();
            case 'oxy'
                outputStr=pf2.methods.oxy.describeMethod();
        end

    end
    
end

