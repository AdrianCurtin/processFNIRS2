function [rawName, oxyName, oxyNamePCA] = addDemoPipelines()
% ADDDEMOPIPELINES Create example processing methods for tutorials
%
% Registers ready-to-use processing pipelines for tutorials and examples.
% If the methods already exist they are silently skipped.
%
% Raw pipeline ('demo_TDDR'):
%   1. pf2_Intensity2OD       - convert raw intensity to optical density
%   2. pf2_MotionCorrectTDDR  - Temporal Derivative Distribution Repair
%
% Oxy pipeline ('demo_lpf'):
%   1. pf2_lpf              - Low pass filter (0.1 Hz, FIR1)
%   2. pf2_build_nanmean_ROI - Build ROI signals via nanmean (if ROIs defined)
%
% Oxy pipeline ('demo_lpf_pca'):
%   1. pf2_lpf              - Low pass filter (0.1 Hz, FIR1)
%   2. pf2_build_pca_ROI    - Build ROI signals via PCA 1st component (if ROIs defined)
%
% Syntax:
%   pf2.import.sampleData.addDemoPipelines()
%   [rawName, oxyName] = pf2.import.sampleData.addDemoPipelines()
%   [rawName, oxyName, oxyNamePCA] = pf2.import.sampleData.addDemoPipelines()
%
% Outputs:
%   rawName    - Name of the raw method ('demo_TDDR')
%   oxyName    - Name of the oxy method ('demo_lpf')
%   oxyNamePCA - Name of the PCA oxy method ('demo_lpf_pca')
%
% Example:
%   [rawM, oxyM] = pf2.import.sampleData.addDemoPipelines();
%   ex.settings.rawMethod = rawM;
%   ex.settings.oxyMethod = oxyM;
%   ex.aggregate();
%
% See also: pf2.methods.raw.create, pf2.methods.oxy.create,
%           pf2.import.sampleData.experiment

rawName = 'demo_TDDR';
oxyName = 'demo_lpf';
oxyNamePCA = 'demo_lpf_pca';

rawLib = pf2_base.resolveMethodsLib('raw');
oxyLib = pf2_base.resolveMethodsLib('oxy');

% --- Raw pipeline: OD conversion + TDDR motion correction ---
if ~ismember(rawName, rawLib.cfg.Sections)
    rawFuncs = { ...
        struct('f', 'pf2_Intensity2OD', ...
               'args', {{'x'}}, ...
               'argvals', {{'x'}}, ...
               'output', 'x'), ...
        struct('f', 'pf2_MotionCorrectTDDR', ...
               'args', {{'x', 'fs'}}, ...
               'argvals', {{'x', 'fs'}}, ...
               'output', 'x') ...
    };
    pf2.methods.raw.create(rawName, rawFuncs);
else
    fprintf('Raw method ''%s'' already exists, skipping.\n', rawName);
end

% --- Oxy pipeline: Low pass filter (0.1 Hz) + nanmean ROI ---
if ~ismember(oxyName, oxyLib.cfg.Sections)
    oxyFuncs = { ...
        struct('f', 'pf2_lpf', ...
               'args', {{'x', 'filtType', 'fs', 'freq_cut', 'Nf'}}, ...
               'argvals', {{'x', 1, 'fs', 0.1, 50}}, ...
               'output', 'x'), ...
        struct('f', 'pf2_build_nanmean_ROI', ...
               'args', {{'fNIRstruct'}}, ...
               'argvals', {{'fNIRstruct'}}, ...
               'output', 'ROI') ...
    };
    pf2.methods.oxy.create(oxyName, oxyFuncs);
else
    fprintf('Oxy method ''%s'' already exists, skipping.\n', oxyName);
end

% --- Oxy pipeline: Low pass filter (0.1 Hz) + PCA ROI ---
if ~ismember(oxyNamePCA, oxyLib.cfg.Sections)
    oxyFuncsPCA = { ...
        struct('f', 'pf2_lpf', ...
               'args', {{'x', 'filtType', 'fs', 'freq_cut', 'Nf'}}, ...
               'argvals', {{'x', 1, 'fs', 0.1, 50}}, ...
               'output', 'x'), ...
        struct('f', 'pf2_build_pca_ROI', ...
               'args', {{'fNIRstruct', 'ComponentNumber'}}, ...
               'argvals', {{'fNIRstruct', 1}}, ...
               'output', 'ROI') ...
    };
    pf2.methods.oxy.create(oxyNamePCA, oxyFuncsPCA);
else
    fprintf('Oxy method ''%s'' already exists, skipping.\n', oxyNamePCA);
end

end
