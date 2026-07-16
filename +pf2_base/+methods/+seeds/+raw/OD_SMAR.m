function p = OD_SMAR()
% OD_SMAR Factory for the "OD_SMAR" raw method (SMAR motion correction)
%
% Builds the shipped "OD_SMAR" raw (Stage 1) processing method as a RawPipeline:
% log transform to optical density, then Sliding-window Motion Artifact
% Rejection (SMAR), which rejects samples whose windowed coefficient of
% variation falls outside acceptable bounds. Used by pf2_initialize and
% pf2.methods.resetDefaults to (re-)seed the default raw methods. Returns a
% pipeline object you can save() to register or run() directly.
%
% Syntax:
%   p = pf2_base.methods.seeds.raw.OD_SMAR()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.RawPipeline named 'OD_SMAR', ready for save() or run()
%
% Example:
%   p = pf2_base.methods.seeds.raw.OD_SMAR();
%   p.save();
%
% See also: pf2_base.methods.seeds.raw.OD_TDDR, pf2.methods.resetDefaults,
%           pf2_base.RawPipeline, pf2_SMAR

p = pf2_base.RawPipeline('OD_SMAR', ...
    'Description', 'Log transform then SMAR (sliding-window motion artifact rejection)');
p = p.add('pf2_Intensity2OD');
p = p.add('pf2_SMAR');
end
