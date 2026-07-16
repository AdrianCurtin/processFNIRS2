function p = HPF()
% HPF Factory for the "HPF" oxy method (0.01 Hz high-pass filter)
%
% Builds the shipped "HPF" oxy (Stage 3) processing method as an OxyPipeline: a
% single 0.01 Hz high-pass filter applied to hemoglobin signals to remove slow
% drift. Used by pf2_initialize and pf2.methods.resetDefaults to (re-)seed the
% default oxy methods. Returns a pipeline object you can save() to register or
% run() directly.
%
% Syntax:
%   p = pf2_base.methods.seeds.oxy.HPF()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'HPF', ready for save() or run()
%
% Example:
%   p = pf2_base.methods.seeds.oxy.HPF();
%   p.save();
%
% See also: pf2_base.methods.seeds.oxy.LPF, pf2_base.methods.seeds.oxy.BPF,
%           pf2.methods.resetDefaults, pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('HPF', ...
    'Description', 'High-pass filter at 0.01 Hz on hemoglobin signals (drift removal)');
p = p.add('pf2_hpf', 'freq_cut', 0.01);
end
