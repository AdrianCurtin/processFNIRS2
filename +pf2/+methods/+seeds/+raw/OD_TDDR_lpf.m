function p = OD_TDDR_lpf()
% OD_TDDR_LPF Factory for the default raw method (OD, TDDR, low-pass)
%
% Builds the shipped "OD_TDDR_lpf" raw (Stage 1) processing method as a
% RawPipeline: a log transform to optical density, Temporal Derivative
% Distribution Repair (TDDR) motion correction, then a 0.1 Hz low-pass
% filter. Used by pf2_initialize and pf2.methods.resetDefaults to (re-)seed
% the default raw methods. Returns a pipeline object to save() or run().
%
% Reference:
%   Fishburn, F. A. et al. (2019). Temporal Derivative Distribution Repair
%   (TDDR): A motion correction method for fNIRS. NeuroImage, 184, 171-179.
%   DOI: 10.1016/j.neuroimage.2018.09.025
%
% Syntax:
%   p = pf2.methods.seeds.raw.OD_TDDR_lpf()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.RawPipeline named 'OD_TDDR_lpf', ready for save() or run()
%
% Example:
%   % Build and register the default OD_TDDR_lpf raw method
%   p = pf2.methods.seeds.raw.OD_TDDR_lpf();
%   p.save();
%
% See also: pf2.methods.seeds.raw.OD_TDDR, pf2.methods.resetDefaults,
%           pf2_base.RawPipeline, pf2_MotionCorrectTDDR, pf2_lpf

p = pf2_base.RawPipeline('OD_TDDR_lpf', ...
    'Description', 'Log transform, TDDR motion correction, low-pass filter at 0.1 Hz');
p = p.add('pf2_Intensity2OD');
p = p.add('pf2_MotionCorrectTDDR');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
end
