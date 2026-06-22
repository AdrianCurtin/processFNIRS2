function versInfoString=versInfo()
% VERSINFO Return exploreFNIRS version information
%
% Returns the current version string for the exploreFNIRS GUI application.
% If called without output arguments, prints version to console.
%
% Syntax:
%   versInfoString = versInfo()
%   versInfo()  % Prints to console
%
% Inputs:
%   None
%
% Outputs:
%   versInfoString - Version string (e.g., 'Explore fNIRS v1.0.0')
%                    Only returned if output argument is requested.
%
% Example:
%   % Display version in console
%   versInfo();
%
%   % Store version string
%   ver = versInfo();
%   disp(['Using ' ver]);
%
% See also: pf2version, exploreFNIRS

vers='1.0.0';
versInfo=sprintf('Explore fNIRS v%s\n',vers);

if(nargout==0)
   fprintf(versInfo);
else
    versInfoString=versInfo;
end