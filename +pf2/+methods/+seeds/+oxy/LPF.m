function p = LPF()
% LPF Factory for the default oxy method (0.1 Hz low-pass filter)
%
% Builds the shipped "LPF" oxy (Stage 3) processing method as an OxyPipeline:
% a single 0.1 Hz low-pass filter applied to hemoglobin signals. Used by
% pf2_initialize and pf2.methods.resetDefaults to (re-)seed the default oxy
% methods. Returns a pipeline object you can save() to register or run()
% directly.
%
% Syntax:
%   p = pf2.methods.seeds.oxy.LPF()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'LPF', ready for save() or run()
%
% Example:
%   % Build and register the default LPF oxy method
%   p = pf2.methods.seeds.oxy.LPF();
%   p.save();
%
% See also: pf2.methods.seeds.oxy.LPF_ROI, pf2.methods.resetDefaults,
%           pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('LPF', ...
    'Description', 'Low-pass filter at 0.1 Hz on hemoglobin signals');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
end
