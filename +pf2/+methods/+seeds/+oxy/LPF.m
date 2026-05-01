function p = LPF()
% LPF Default oxy method: 0.1 Hz low-pass filter.
%
% Returns:
%   p - pf2_base.OxyPipeline ready for save() or run()

p = pf2_base.OxyPipeline('LPF', ...
    'Description', 'Low-pass filter at 0.1 Hz on hemoglobin signals');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
end
