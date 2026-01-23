function varargout=process(varargin)
% PROCESS Execute full fNIRS processing pipeline (Raw + OD + Oxy stages)
%
% Wrapper for the main processFNIRS2 function that executes the complete
% three-stage processing pipeline: Raw signal processing, optical density
% conversion via Beer-Lambert law, and hemoglobin concentration processing.
% All input arguments are passed directly to processFNIRS2.
%
% Reference:
%   Internal pf2 implementation. See processFNIRS2 documentation for
%   algorithm details and Scholkmann & Wolf (2013) for DPF calculation.
%
% Syntax:
%   pf2.process.process(data)
%   processed = pf2.process.process(data)
%   processed = pf2.process.process(data, Raw_Method, Oxy_Method)
%   processed = pf2.process.process(data, 'ParameterName', ParameterValue, ...)
%
% Inputs:
%   data       - fNIRS data structure with required fields:
%                  .raw [T x C double] - Raw light intensity data
%                  .time [T x 1 double] - Time vector in seconds
%                  .fs [scalar] - Sampling frequency in Hz
%                Optional fields: .markers, .fchMask, .info
%   Raw_Method - Name of raw processing method (default: 'None')
%                Use pf2.methods.raw.list() to see available methods.
%   Oxy_Method - Name of oxy processing method (default: 'None')
%                Use pf2.methods.oxy.list() to see available methods.
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
%   processed - fNIRS structure with processed data containing:
%                 .HbO [T x C] - Oxygenated hemoglobin
%                 .HbR [T x C] - Deoxygenated hemoglobin
%                 .HbTotal [T x C] - Total hemoglobin (HbO + HbR)
%                 .HbDiff [T x C] - Differential hemoglobin (HbO - HbR)
%                 .CBSI [T x C] - Cerebral blood saturation index
%                 .channels [1 x C] - Channel numbers
%                 .units [string] - Output units ('uM' or 'mM*mm')
%               Plus all original input fields preserved.
%
% Example:
%   % Basic usage with sample data
%   data = pf2.import.sampleData.fNIR2000();
%   processed = pf2.process.process(data);
%
%   % Process with specific methods
%   processed = pf2.process.process(data, 'x2_lpf_smar', 'takizawa_easy');
%
%   % Process with custom parameters
%   processed = pf2.process.process(data, ...
%       'blLength', 5, 'defaultSubjectAge', 30, 'DPFmode', 'Calc');
%
% Notes:
%   - If no output is requested, the GUI will be launched automatically
%   - For partial processing, use ProcessRaw or ProcessOxy instead
%
% See also: pf2.process.processRaw, pf2.process.processOxy, processFNIRS2,
%           pf2.methods.raw.list, pf2.methods.oxy.list

if(nargout>0)

	varargout{1:nargout}=processFNIRS2(varargin{:});

else
	processFNIRS2(varargin{:});
end