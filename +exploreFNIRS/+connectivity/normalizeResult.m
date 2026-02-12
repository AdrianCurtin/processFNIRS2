function result = normalizeResult(result)
% NORMALIZERESULT Map group connectivity result to plot-compatible format
%
% Group-level results from Experiment.connectivity() / interROI() store
% averaged matrices in .Mean, while plot functions expect .matrix.
% This utility copies .Mean → .matrix when .matrix is absent, making
% group results directly plottable without manual struct wrapping.
%
% Single-subject results (which already have .matrix) pass through
% unchanged.
%
% Syntax:
%   result = exploreFNIRS.connectivity.normalizeResult(result)
%
% Inputs:
%   result - Connectivity result struct (single-subject or group)
%
% Outputs:
%   result - Struct with .matrix guaranteed to exist
%
% See also: exploreFNIRS.connectivity.plotMatrix,
%   exploreFNIRS.connectivity.plotChord

    if isfield(result, 'matrix')
        return;
    end

    if isfield(result, 'Mean')
        result.matrix = result.Mean;
        if ~isfield(result, 'pmatrix')
            result.pmatrix = [];
        end
    end
end
