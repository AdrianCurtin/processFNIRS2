function [outFields,alternateSpellings]=pf2_getFNIRSfields()
% units: contains information related to the units of the HbO fields, mmol,
%           mmol x cm, umol etc
% channels: contains the channel numbers in the probe corresponding to col
%           number
%           if multiple probes, sometimes channel numbers may not match col
% info: information field for any extra information that could be present
%           Has default fields for Group, Subgroup, Trial, Block,
%           Condition, Age and Sex
% DPF_factor: number by which loglight (OD) is multiplied during Beer
%           Lambert conversion, necessary to convert between HbO units
% markers: matrix or table of marker values
%       Must follow format [time,markervalue,textlabel]
% fchMask:   Channel Mask by which original data was marked, compared
%       against PF2.RejectLevel to reject. 1 is a good channel 0 is a bad
%       channel.
% time: time in seconds, must match length of raw or Hb fields
% Aux:  Auxillary temporal data field, signals here can be processed
%       similarly to fNIRS files, (time averaged and grand averaged)
% probeinfo: struct containing information related to probe structure
% fs:   sampling frequency of fields, automatically calculated
% ftimeChMask:  time x channel mask for fields, fields are rejected if 0
% ROI:  field which contains .info detailing its channel structure and
%       structs for each calculated biomarker
% segmentTimes: specifies the time periods when resampled 
%        [start of sample, period, mid, and end]

outFields={'units','channels','info','DPF_factor','markers','fchMask','time','Aux','probeinfo','fs','ftimeChMask','ROI','segmentTimes'};

alternateSpellings={};