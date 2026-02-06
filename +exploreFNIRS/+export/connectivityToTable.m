function T = connectivityToTable(result, varargin)
% CONNECTIVITYTOTABLE Export coupling results as long-format table
%
% Converts connectivity or hyperscanning results into a long-format table
% suitable for export to CSV or use with R/lme4 statistical workflows.
%
% Syntax:
%   T = exploreFNIRS.export.connectivityToTable(result)
%   T = exploreFNIRS.export.connectivityToTable(result, 'IncludeDyads', true)
%
% Inputs:
%   result - One of:
%     - Connectivity result from computeMatrix (single subject)
%     - Group connectivity result from Experiment.connectivity()
%     - Hyperscanning result from Experiment.hyperscanning() or computeGroup
%
% Name-Value Parameters:
%   IncludeDyads  - Include individual dyad-level rows (default: false)
%   IncludeGroup  - Include group summary rows (default: true)
%
% Outputs:
%   T - Table with columns (varies by input type):
%     Common: Method, Biomarker, ChannelA, ChannelB, Coupling, PValue
%     Hyperscanning: SubjectA, SubjectB, DyadID
%     Group: GroupLabel, Mean, SD, SEM, N
%
% Example:
%   result = ex.hyperscanning('Method', 'pearson', 'Biomarker', 'HbO');
%   T = exploreFNIRS.export.connectivityToTable(result, 'IncludeDyads', true);
%   writetable(T, 'hyperscanning_results.csv');
%
% See also: exploreFNIRS.connectivity.computeMatrix,
%   exploreFNIRS.hyperscanning.computeGroup

    ip = inputParser;
    addRequired(ip, 'result', @isstruct);
    addParameter(ip, 'IncludeDyads', false, @islogical);
    addParameter(ip, 'IncludeGroup', true, @islogical);
    parse(ip, result, varargin{:});
    opts = ip.Results;

    T = table();

    if isfield(result, 'dyads') && isfield(result, 'dyadIDs')
        % Hyperscanning group result
        T = exportHyperscanning(result, opts);
    elseif isfield(result, 'matrix') && isfield(result, 'pmatrix')
        % Single connectivity matrix
        T = exportConnectivityMatrix(result);
    elseif isfield(result, 'Mean') && isfield(result, 'matrices')
        % Group connectivity result (from Experiment.connectivity)
        T = exportGroupConnectivity(result, opts);
    else
        error('exploreFNIRS:export:connectivityToTable', ...
            'Unrecognized result format');
    end
end


function T = exportHyperscanning(result, opts)
% Export hyperscanning group result
    rows = {};
    method = result.method;
    bioM = result.biomarker;
    channels = result.channels;

    % Group summary
    if opts.IncludeGroup
        if strcmpi(result.pairing, 'same')
            for c = 1:length(channels)
                row.Method = {method};
                row.Biomarker = {bioM};
                row.ChannelA = channels(c);
                row.ChannelB = channels(c);
                row.Level = {'Group'};
                row.DyadID = {''};
                row.SubjectA = {''};
                row.SubjectB = {''};
                row.Coupling = result.Mean(c);
                row.PValue = result.pvalue(c);
                row.SD = result.SD(c);
                row.SEM = result.SEM(c);
                row.N = result.N(c);
                rows{end+1} = struct2table(row); %#ok<AGROW>
            end
        else
            % 'all' pairing - Ca x Cb matrix
            [nA, nB] = size(result.Mean);
            chA = result.channels;
            chB = result.channels;
            if isfield(result, 'dyads') && ~isempty(result.dyads)
                if isfield(result.dyads{1}, 'channelsB')
                    chB = result.dyads{1}.channelsB;
                end
            end
            for a = 1:nA
                for b = 1:nB
                    row.Method = {method};
                    row.Biomarker = {bioM};
                    row.ChannelA = chA(min(a, length(chA)));
                    row.ChannelB = chB(min(b, length(chB)));
                    row.Level = {'Group'};
                    row.DyadID = {''};
                    row.SubjectA = {''};
                    row.SubjectB = {''};
                    row.Coupling = result.Mean(a, b);
                    row.PValue = result.pvalue(a, b);
                    row.SD = result.SD(a, b);
                    row.SEM = result.SEM(a, b);
                    row.N = result.N(a, b);
                    rows{end+1} = struct2table(row); %#ok<AGROW>
                end
            end
        end
    end

    % Individual dyads
    if opts.IncludeDyads && isfield(result, 'dyads')
        for d = 1:length(result.dyads)
            dRes = result.dyads{d};
            dyadID = result.dyadIDs{d};

            % Get subject IDs from pairs if available
            subjA = '';
            subjB = '';
            if isfield(result, 'pairs') && d <= length(result.pairs)
                if ~isempty(result.pairs(d).subjectIDs)
                    subjA = result.pairs(d).subjectIDs{1};
                    if length(result.pairs(d).subjectIDs) >= 2
                        subjB = result.pairs(d).subjectIDs{2};
                    end
                end
            end

            if strcmpi(dRes.pairing, 'same')
                for c = 1:length(dRes.channelsA)
                    row.Method = {method};
                    row.Biomarker = {bioM};
                    row.ChannelA = dRes.channelsA(c);
                    row.ChannelB = dRes.channelsB(c);
                    row.Level = {'Dyad'};
                    row.DyadID = {dyadID};
                    row.SubjectA = {subjA};
                    row.SubjectB = {subjB};
                    row.Coupling = dRes.values(c);
                    row.PValue = dRes.pvalues(c);
                    row.SD = NaN;
                    row.SEM = NaN;
                    row.N = 1;
                    rows{end+1} = struct2table(row); %#ok<AGROW>
                end
            else
                for a = 1:length(dRes.channelsA)
                    for b = 1:length(dRes.channelsB)
                        row.Method = {method};
                        row.Biomarker = {bioM};
                        row.ChannelA = dRes.channelsA(a);
                        row.ChannelB = dRes.channelsB(b);
                        row.Level = {'Dyad'};
                        row.DyadID = {dyadID};
                        row.SubjectA = {subjA};
                        row.SubjectB = {subjB};
                        row.Coupling = dRes.values(a, b);
                        row.PValue = dRes.pvalues(a, b);
                        row.SD = NaN;
                        row.SEM = NaN;
                        row.N = 1;
                        rows{end+1} = struct2table(row); %#ok<AGROW>
                    end
                end
            end
        end
    end

    if ~isempty(rows)
        T = vertcat(rows{:});
    end
end


function T = exportConnectivityMatrix(result)
% Export single connectivity matrix
    channels = result.channels;
    nCh = length(channels);
    rows = {};

    for i = 1:nCh
        for j = (i+1):nCh
            row.Method = {result.method};
            row.Biomarker = {result.biomarker};
            row.ChannelA = channels(i);
            row.ChannelB = channels(j);
            row.Coupling = result.matrix(i, j);
            row.PValue = result.pmatrix(i, j);
            rows{end+1} = struct2table(row); %#ok<AGROW>
        end
    end

    if ~isempty(rows)
        T = vertcat(rows{:});
    else
        T = table();
    end
end


function T = exportGroupConnectivity(result, opts)
% Export group connectivity results
    rows = {};

    for g = 1:length(result)
        grp = result(g);
        channels = grp.channels;
        nCh = length(channels);

        if opts.IncludeGroup
            for i = 1:nCh
                for j = (i+1):nCh
                    row.GroupLabel = {grp.label};
                    row.Method = {grp.method};
                    row.Biomarker = {grp.biomarker};
                    row.ChannelA = channels(i);
                    row.ChannelB = channels(j);
                    row.Mean = grp.Mean(i, j);
                    row.SD = grp.SD(i, j);
                    row.SEM = grp.SEM(i, j);
                    row.N = grp.N;
                    rows{end+1} = struct2table(row); %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(rows)
        T = vertcat(rows{:});
    else
        T = table();
    end
end
