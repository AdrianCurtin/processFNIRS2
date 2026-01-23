function varargout=processRaw(varargin)
% PROCESSRAWONLY Execute only Raw and OD stages, skipping Oxy processing
%
% Wrapper for processFNIRS2 that executes raw signal processing and optical
% density (OD) conversion via Beer-Lambert law, but skips the final
% hemoglobin filtering stage. Use this when you need intermediate results
% or plan to apply custom post-processing to the hemoglobin data.
%
% Reference:
%   Internal pf2 implementation. See processFNIRS2 documentation for
%   algorithm details and Scholkmann & Wolf (2013) for DPF calculation.
%
% Syntax:
%   pf2.process.processRaw(data)
%   processed = pf2.process.processRaw(data)
%   processed = pf2.process.processRaw(data, Raw_Method)
%   processed = pf2.process.processRaw(data, 'ParameterName', ParameterValue, ...)
%
% Inputs:
%   data       - fNIRS data structure with required fields:
%                  .raw [T x C double] - Raw light intensity data
%                  .time [T x 1 double] - Time vector in seconds
%                  .fs [scalar] - Sampling frequency in Hz
%                Optional fields: .markers, .fchMask, .info
%   Raw_Method - Name of raw processing method (default: 'None')
%                Use pf2.methods.raw.list() to see available methods.
%
%   Additional name-value parameters (passed to processFNIRS2):
%   'blLength'           - Baseline duration in seconds (default: 10)
%   'blStartTime'        - Baseline start time in seconds (default: 0)
%   'defaultSubjectAge'  - Subject age for DPF calculation (default: 25)
%   'DPFmode'            - DPF mode: 'None', 'Fixed', or 'Calc' (default: 'Calc')
%   'FixedDPF'           - Fixed DPF value when DPFmode='Fixed' (default: 5.93)
%   'UseDeviceCFG'       - Path to device configuration file
%   'ChannelMask'        - Logical mask for channel rejection [1 x C]
%   'ShowGUI'            - Launch GUI after processing (default: false)
%
% Outputs:
%   processed - fNIRS structure with hemoglobin data (unfiltered):
%                 .HbO [T x C] - Oxygenated hemoglobin (no oxy filtering)
%                 .HbR [T x C] - Deoxygenated hemoglobin (no oxy filtering)
%                 .HbTotal [T x C] - Total hemoglobin (HbO + HbR)
%                 .HbDiff [T x C] - Differential hemoglobin (HbO - HbR)
%                 .CBSI [T x C] - Cerebral blood saturation index
%                 .channels [1 x C] - Channel numbers
%                 .units [string] - Output units ('uM' or 'mM*mm')
%               Plus all original input fields preserved.
%
% Example:
%   % Process raw stage only, then apply custom filtering
%   data = pf2.import.sampleData.fNIR2000();
%   intermediate = pf2.process.processRaw(data, 'x2_lpf_smar');
%
%   % Apply custom filtering to HbO
%   intermediate.HbO = myCustomFilter(intermediate.HbO, intermediate.fs);
%
%   % Compare different raw methods before committing to oxy processing
%   result1 = pf2.process.processRaw(data, 'x2_lpf_smar');
%   result2 = pf2.process.processRaw(data, 'x5_TDDR');
%
% Notes:
%   - This function sets 'SkipOxy' to true internally
%   - Output contains HbO/HbR from Beer-Lambert conversion but without
%     any oxy-stage filtering (baseline correction, artifact rejection, etc.)
%   - Use pf2.process.processOxy to apply oxy processing to the output
%
% See also: pf2.process.process, pf2.process.processOxy, processFNIRS2,
%           pf2.methods.raw.list, pf2.methods.raw.setMethod

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:},'SkipOxy',true);

else
	processFNIRS2(varargin{:},'SkipOxy',true);
end