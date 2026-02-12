function [outFields,alternateSpellings]=pf2_getFNIRSfields()
% PF2_GETFNIRSFIELDS Return standard fNIRS data structure field names
%
% Returns the list of standard metadata and auxiliary field names used in
% the processFNIRS2 fNIRS data structure. These fields are distinct from
% biomarker fields (HbO, HbR, etc.) and contain supporting information such
% as time vectors, channel masks, markers, and probe geometry.
%
% Reference:
%   Internal pf2 implementation. Field definitions follow processFNIRS2
%   data structure conventions documented in CLAUDE.md.
%
% Syntax:
%   outFields = pf2_getFNIRSfields()
%   [outFields, alternateSpellings] = pf2_getFNIRSfields()
%
% Inputs:
%   None
%
% Outputs:
%   outFields          - Cell array of standard field names {1 x 17 cell}
%                        Contains: 'units', 'channels', 'info', 'DPF_factor',
%                        'markers', 'fchMask', 'time', 'Aux', 'probeinfo',
%                        'fs', 'ftimeChMask', 'ROI', 'segmentTimes', 't0',
%                        'datetime', 'blocks', 'device'
%   alternateSpellings - Cell array of alternate field name mappings
%                        (currently empty, reserved for future use)
%
% Field Descriptions:
%   units         - Units of HbO fields (mmol, mmol*cm, umol, etc.)
%   channels      - Channel numbers in probe corresponding to column number
%   info          - Metadata struct (Group, Subgroup, Trial, Block, etc.)
%   DPF_factor    - Differential pathlength factor used in Beer-Lambert
%   markers       - Event markers [time, markervalue, textlabel]
%   fchMask       - Channel mask (1=good, 0=bad), compared to RejectLevel
%   time          - Time vector in seconds, matches length of data fields
%   Aux           - Auxiliary temporal data (can be time/grand averaged)
%   probeinfo     - Probe geometry and optode positions
%   fs            - Sampling frequency in Hz (auto-calculated)
%   ftimeChMask   - Time x channel mask [T x C], 0 = rejected sample
%   ROI           - Region of interest data with .info and biomarker fields
%   segmentTimes  - Resampled time periods [start, period, mid, end]
%   t0            - Reference time point (baseline start)
%   datetime      - Recording date and time
%   blocks        - Block definition struct array from defineBlocks
%   device        - pf2.Device object (immutable device configuration)
%
% Example:
%   % Get list of metadata fields
%   fields = pf2_base.pf2_getFNIRSfields();
%   disp(fields);
%
%   % Check if a struct has all required fields
%   fields = pf2_base.pf2_getFNIRSfields();
%   hasAllFields = all(isfield(myStruct, fields));
%
% See also: pf2_getFNIRSbiomFields, pf2_initialize, processFNIRS2

outFields={'units','channels','info','DPF_factor','markers','fchMask','time','Aux','probeinfo','fs','ftimeChMask','ROI','segmentTimes','t0','datetime','blocks','device'};

alternateSpellings={};