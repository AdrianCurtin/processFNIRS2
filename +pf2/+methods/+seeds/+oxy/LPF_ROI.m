function p = LPF_ROI()
% LPF_ROI Factory for the default oxy method (low-pass filter then ROI)
%
% Builds the shipped "LPF_ROI" oxy (Stage 3) processing method as an
% OxyPipeline: a 0.1 Hz low-pass filter followed by a nanmean region-of-
% interest (ROI) reduction over the configured channel groups. Used by
% pf2_initialize and pf2.methods.resetDefaults to (re-)seed the default oxy
% methods. Returns a pipeline object you can save() to register or run().
%
% Syntax:
%   p = pf2.methods.seeds.oxy.LPF_ROI()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'LPF_ROI', ready for save() or run()
%
% Example:
%   % Build and register the default LPF_ROI oxy method
%   p = pf2.methods.seeds.oxy.LPF_ROI();
%   p.save();
%
% See also: pf2.methods.seeds.oxy.LPF, pf2.methods.resetDefaults,
%           pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('LPF_ROI', ...
    'Description', 'Low-pass filter at 0.1 Hz; build nanmean ROI from channel groups');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
p = p.add('pf2_build_nanmean_ROI');
end
