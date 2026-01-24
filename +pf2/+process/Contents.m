% pf2.process - Processing pipeline functions
% processFNIRS2 v0.8
%
% Full Processing:
%   process       - Full processing pipeline (alias for processFNIRS2)
%
% Stage-Specific Processing:
%   processRaw    - Stage 1 only: Raw -> Optical Density
%   processOxy    - Stage 3 only: Hemoglobin post-processing
%
% Processing Stages:
%   Stage 1 (Raw -> OD):    Motion correction, filtering
%   Stage 2 (OD -> Hb):     Beer-Lambert conversion (automatic)
%   Stage 3 (Hb -> Final):  Artifact rejection, baseline correction
%
% Example:
%   % Full processing
%   processed = pf2.process(data);
%
%   % Stage-specific (advanced use)
%   rawProcessed = pf2.process.processRaw(data);
%   oxyProcessed = pf2.process.processOxy(data);
%
% See also: processFNIRS2, pf2.methods
