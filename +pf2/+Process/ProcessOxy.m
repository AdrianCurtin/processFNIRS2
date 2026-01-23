function varargout=ProcessOxy(varargin)
% PROCESSOXY Execute only the hemoglobin (Oxy) processing stage
%
% Wrapper for processFNIRS2 that skips the raw processing stage and
% executes only the hemoglobin concentration processing. Use this when
% input data has already been processed through the raw stage (optical
% density conversion complete) or when reprocessing with different oxy
% methods without repeating raw-stage computations.
%
% Reference:
%   Internal pf2 implementation. See processFNIRS2 documentation for
%   algorithm details.
%
% Syntax:
%   pf2.Process.ProcessOxy(data)
%   processed = pf2.Process.ProcessOxy(data)
%   processed = pf2.Process.ProcessOxy(data, Raw_Method, Oxy_Method)
%   processed = pf2.Process.ProcessOxy(data, 'ParameterName', ParameterValue, ...)
%
% Inputs:
%   data       - fNIRS data structure containing hemoglobin data:
%                  .HbO [T x C double] - Oxygenated hemoglobin
%                  .HbR [T x C double] - Deoxygenated hemoglobin
%                  .time [T x 1 double] - Time vector in seconds
%                  .fs [scalar] - Sampling frequency in Hz
%                Note: Raw stage is skipped, so .raw field is not required.
%   Oxy_Method - Name of oxy processing method (default: 'None')
%                Use pf2.Methods.Oxy.List() to see available methods.
%
%   Additional name-value parameters (passed to processFNIRS2):
%   'blLength'           - Baseline duration in seconds (default: 10)
%   'blStartTime'        - Baseline start time in seconds (default: 0)
%   'ChannelMask'        - Logical mask for channel rejection [1 x C]
%   'ShowGUI'            - Launch GUI after processing (default: false)
%
% Outputs:
%   processed - fNIRS structure with processed hemoglobin data:
%                 .HbO [T x C] - Filtered oxygenated hemoglobin
%                 .HbR [T x C] - Filtered deoxygenated hemoglobin
%                 .HbTotal [T x C] - Total hemoglobin (HbO + HbR)
%                 .HbDiff [T x C] - Differential hemoglobin (HbO - HbR)
%                 .CBSI [T x C] - Cerebral blood saturation index
%               Plus all original input fields preserved.
%
% Example:
%   % First run full processing
%   data = pf2.Import.SampleData.fNIR2000();
%   processed = pf2.Process.Process(data, 'x2_lpf_smar', 'None');
%
%   % Then reprocess with different oxy method (faster than full pipeline)
%   reprocessed = pf2.Process.ProcessOxy(processed, [], 'takizawa_hard_car');
%
%   % Process imported SNIRF data that already has hemoglobin values
%   snirfData = pf2.Import.ImportSNIRF('preprocessed.snirf');
%   result = pf2.Process.ProcessOxy(snirfData, [], 'car');
%
% Notes:
%   - This function sets 'SkipRaw' to true internally
%   - Input data must already contain HbO/HbR fields (not raw intensity)
%   - Raw_Method parameter is ignored since raw stage is skipped
%
% See also: pf2.Process.Process, pf2.Process.ProcessRaw, processFNIRS2,
%           pf2.Methods.Oxy.List, pf2.Methods.Oxy.SetMethod

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:},'SkipRaw',true);

else
	processFNIRS2(varargin{:},'SkipRaw',true);
end