function p = LPF_ROI()
% LPF_ROI Default oxy method: low-pass filter then build a nanmean ROI.
%
% Returns:
%   p - pf2_base.OxyPipeline ready for save() or run()

p = pf2_base.OxyPipeline('LPF_ROI', ...
    'Description', 'Low-pass filter at 0.1 Hz; build nanmean ROI from channel groups');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
p = p.add('pf2_build_nanmean_ROI');
end
