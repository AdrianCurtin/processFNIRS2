function p = BPF()
% BPF Factory for the "BPF" oxy method (0.01-0.1 Hz Butterworth band-pass)
%
% Builds the shipped "BPF" oxy (Stage 3) processing method as an OxyPipeline: a
% single Butterworth band-pass filter (0.01-0.1 Hz) applied to hemoglobin
% signals, isolating the typical task-hemodynamic band while removing slow drift
% and high-frequency noise. Used by pf2_initialize and pf2.methods.resetDefaults
% to (re-)seed the default oxy methods. Returns a pipeline object you can save()
% to register or run() directly.
%
% Syntax:
%   p = pf2_base.methods.seeds.oxy.BPF()
%
% Inputs:
%   None
%
% Outputs:
%   p - pf2_base.OxyPipeline named 'BPF', ready for save() or run()
%
% Example:
%   p = pf2_base.methods.seeds.oxy.BPF();
%   p.save();
%
% See also: pf2_base.methods.seeds.oxy.LPF, pf2_base.methods.seeds.oxy.HPF,
%           pf2.methods.resetDefaults, pf2_base.OxyPipeline

p = pf2_base.OxyPipeline('BPF', ...
    'Description', 'Butterworth band-pass filter (0.01-0.1 Hz) on hemoglobin signals');
p = p.add('pf2_bpf_butter', 'lowF', 0.01, 'highF', 0.1);
end
