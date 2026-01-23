function [outputStr] = DescribeCurrentMethods(methodStage)
% DESCRIBECURRENTMETHOD Display details of currently active processing methods
%
% Shows the complete configuration of the currently selected raw and/or oxy
% processing methods. This is a convenience function that calls the
% DescribeMethod functions for both processing stages. Useful for verifying
% which methods are active before processing data.
%
% Syntax:
%   pf2.Methods.DescribeCurrentMethods()
%   pf2.Methods.DescribeCurrentMethods(methodStage)
%   outputStr = pf2.Methods.DescribeCurrentMethods(...)
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
%   pf2.Methods.DescribeCurrentMethods();
%
%   % Display only the raw method
%   pf2.Methods.DescribeCurrentMethods('raw');
%   pf2.Methods.DescribeCurrentMethods(1);  % Equivalent
%
%   % Display only the oxy method
%   pf2.Methods.DescribeCurrentMethods('oxy');
%   pf2.Methods.DescribeCurrentMethods(2);  % Equivalent
%
%   % Get descriptions as string for logging or display
%   desc = pf2.Methods.DescribeCurrentMethods();
%   fprintf('Current processing configuration:\n%s\n', desc);
%
%   % Typical workflow: check methods before processing
%   pf2.Methods.Raw.SetMethod('x2_lpf_smar');
%   pf2.Methods.Oxy.SetMethod('takizawa_easy_lpf');
%   pf2.Methods.DescribeCurrentMethods();  % Verify settings
%   processed = processFNIRS2(data);
%
% See also: pf2.Methods.Raw.DescribeMethod, pf2.Methods.Oxy.DescribeMethod,
%           pf2.Methods.Raw.SetMethod, pf2.Methods.Oxy.SetMethod

if(nargout==0)
    
if(nargin==0)
    pf2.Methods.Raw.DescribeMethod();
    pf2.Methods.Oxy.DescribeMethod();
else

    switch methodStage
        case 1
            pf2.Methods.Raw.DescribeMethod();
        case 'raw'
            pf2.Methods.Raw.DescribeMethod();
        case 2
            pf2.Methods.Oxy.DescribeMethod();
        case 'oxy'
            pf2.Methods.Oxy.DescribeMethod();
    end

end

elseif(nargout>0)
    if(nargin==0)
        outputStr=pf2.Methods.Raw.DescribeMethod();
        outputStr=sprintf('%s\n%s',outputStr,pf2.Methods.Oxy.DescribeMethod());
    else

        switch methodStage
            case 1
                outputStr=pf2.Methods.Raw.DescribeMethod();
            case 'raw'
                outputStr=pf2.Methods.Raw.DescribeMethod();
            case 2
                outputStr=pf2.Methods.Oxy.DescribeMethod();
            case 'oxy'
                outputStr=pf2.Methods.Oxy.DescribeMethod();
        end

    end
    
end

