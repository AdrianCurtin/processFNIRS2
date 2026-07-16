function p = OD_TDDR()
% OD_TDDR Factory for the default raw method (Intensity2OD then TDDR)
%
% Builds the shipped "OD_TDDR" raw (Stage 1) processing method as a
% RawPipeline: a log transform to optical density followed by Temporal
% Derivative Distribution Repair (TDDR) motion correction. Used by
% pf2_initialize and pf2.methods.resetDefaults to (re-)seed the default raw
% methods. Returns a pipeline object you can save() to register or run().
%
% Reference:
%   Fishburn, F. A. et al. (2019). Temporal Derivative Distribution Repair
%   (TDDR): A motion correction method for fNIRS. NeuroImage, 184, 171-179.
%   DOI: 10.1016/j.neuroimage.2018.09.025
%
% Syntax:
%   p = pf2_base.methods.seeds.raw.OD_TDDR()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.RawPipeline named 'OD_TDDR', ready for save() or run()
%
% Example:
%   % Build and register the default OD_TDDR raw method
%   p = pf2_base.methods.seeds.raw.OD_TDDR();
%   p.save();
%
% See also: pf2_base.methods.seeds.raw.OD_SMAR, pf2.methods.resetDefaults,
%           pf2_base.RawPipeline, pf2_MotionCorrectTDDR

p = pf2_base.RawPipeline('OD_TDDR', ...
    'Description', 'Log transform then TDDR motion correction');
p = p.add('pf2_Intensity2OD');
p = p.add('pf2_MotionCorrectTDDR');
end
