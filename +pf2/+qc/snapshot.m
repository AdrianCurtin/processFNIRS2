function report = snapshot(data, varargin)
% SNAPSHOT One-call headless QC visual summary saved to disk
%
% Runs the QC pipeline and writes a set of quality-control figures to a
% directory in a single headless call — no GUI required. Produces the
% 4-panel QC dashboard, a per-channel power-spectrum grid, and (when the
% sampling rate allows) an SCI bar chart. Intended as the fast, scriptable
% counterpart to the interactive pf2.qc.ChannelCheck app.
%
% Syntax:
%   report = pf2.qc.snapshot(data)
%   report = pf2.qc.snapshot(data, 'SaveDir', 'qc_out')
%   report = pf2.qc.snapshot(data, 'SaveDir', dir, 'Prefix', 'sub01_')
%   report = pf2.qc.snapshot(data, 'SaveDir', dir, 'SCIThreshold', 0.8)
%
% Name-Value Parameters:
%   'SaveDir' - Output directory (default: fullfile(tempdir,'pf2_qc_snapshot')).
%               Created if it does not exist.
%   'Prefix'  - Filename prefix for the saved PNGs (default: '').
%   'DPI'     - Resolution for saved figures (default: 150).
%   Any other name-value pairs (e.g. 'Checks', 'SCIThreshold', 'CoVThreshold')
%   are forwarded to pf2.qc.pipeline.assess.
%
% Inputs:
%   data - Raw fNIRS data struct (.raw, .fs, .time, .fchMask).
%
% Outputs:
%   report - The QC report struct from pf2.qc.pipeline.assess, with an added
%            report.snapshot.files field listing the saved figure paths.
%
% Files written (under SaveDir, with Prefix):
%   <prefix>qc_dashboard.png - SCI / cardiac / CoV / Takizawa dashboard
%   <prefix>qc_psd.png       - Per-channel power spectra (tiled)
%   <prefix>qc_sci.png       - SCI bar chart (only if SCI is not skipped)
%
% Example:
%   data = pf2.import.sampleData.fNIR2000();
%   report = pf2.qc.snapshot(data, 'SaveDir', '/tmp/qc');
%   pf2.qc.pipeline.report(report);   % also print the text summary
%
% See also: pf2.qc.pipeline.assess, pf2.qc.pipeline.plotReport,
%           pf2.qc.powerSpectrum, pf2.qc.plotQuality, pf2.qc.ChannelCheck

p = inputParser;
p.FunctionName = 'pf2.qc.snapshot';
p.KeepUnmatched = true;
addRequired(p, 'data', @isstruct);
addParameter(p, 'SaveDir', fullfile(tempdir, 'pf2_qc_snapshot'), @(x) ischar(x) || isstring(x));
addParameter(p, 'Prefix', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'DPI', 150, @(x) isnumeric(x) && isscalar(x));
parse(p, data, varargin{:});

saveDir = char(p.Results.SaveDir);
prefix = char(p.Results.Prefix);
dpi = p.Results.DPI;
assessArgs = iLocalUnmatched(p.Unmatched);

if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

    function fp = outPath(name)
        fp = fullfile(saveDir, [prefix name]);
    end

files = struct();

% 1. Assess + dashboard
report = pf2.qc.pipeline.assess(data, assessArgs{:});
dashPath = outPath('qc_dashboard.png');
fig = pf2.qc.pipeline.plotReport(report, 'Visible', 'off', ...
    'SavePath', dashPath, 'Title', 'QC Snapshot');
if isgraphics(fig), close(fig); end
files.dashboard = dashPath;

% 2. Power spectrum grid (tiled)
try
    psd = pf2.qc.powerSpectrum(data, 'Signal', 'raw');
    psdPath = outPath('qc_psd.png');
    fig = pf2.qc.plotQuality(psd, 'Layout', 'tiled', 'Visible', 'off', ...
        'SavePath', psdPath);
    if isgraphics(fig), close(fig); end
    files.psd = psdPath;
catch ME
    warning('pf2:qc:snapshot:psdFailed', ...
        'Power-spectrum figure skipped: %s', ME.message);
end

% 3. SCI bar chart (only meaningful when SCI was actually computed)
try
    sciResult = pf2.qc.sci(data);
    if ~isfield(sciResult, 'skipped') || ~sciResult.skipped
        sciPath = outPath('qc_sci.png');
        fig = pf2.qc.plotQuality(sciResult, 'Visible', 'off', 'SavePath', sciPath);
        if isgraphics(fig), close(fig); end
        files.sci = sciPath;
    end
catch ME
    warning('pf2:qc:snapshot:sciFailed', ...
        'SCI figure skipped: %s', ME.message);
end

report.snapshot = struct('dir', saveDir, 'dpi', dpi, 'files', files);

fnames = fieldnames(files);
fprintf('QC snapshot saved %d figure(s) to %s:\n', numel(fnames), saveDir);
for i = 1:numel(fnames)
    fprintf('  %s\n', files.(fnames{i}));
end

end


function c = iLocalUnmatched(s)
% Convert an inputParser Unmatched struct back to a name-value cell array.
fn = fieldnames(s);
c = cell(1, 2 * numel(fn));
for i = 1:numel(fn)
    c{2*i - 1} = fn{i};
    c{2*i}     = s.(fn{i});
end
end
