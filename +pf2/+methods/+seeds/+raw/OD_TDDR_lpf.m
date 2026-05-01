function p = OD_TDDR_lpf()
% OD_TDDR_LPF Default raw method: log transform, TDDR motion correction,
% and a 0.1 Hz low-pass filter.
%
% Returns:
%   p - pf2_base.RawPipeline ready for save() or run()

p = pf2_base.RawPipeline('OD_TDDR_lpf', ...
    'Description', 'Log transform, TDDR motion correction, low-pass filter at 0.1 Hz');
p = p.add('pf2_Intensity2OD');
p = p.add('pf2_MotionCorrectTDDR');
p = p.add('pf2_lpf', 'freq_cut', 0.1);
end
