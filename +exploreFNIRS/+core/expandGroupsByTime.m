function expandedGroups = expandGroupsByTime(groups)
% EXPANDGROUPSBYTIME Expand groups by time bins for bar/scatter plotting
%
% When gbyGrandBarFlat has multiple time bins, splits each group into
% N sub-groups (one per time bin). Labels are appended with the bin
% start time (e.g., "Older" becomes "Older [0s]", "Older [10s]").
%
% Creates matching single-timepoint gbyGrand so plotBar/plotAuxBar
% can read data correctly. Returns groups unchanged if only 1 time bin.
%
% Syntax:
%   expanded = exploreFNIRS.core.expandGroupsByTime(groups)
%
% Input:
%   groups - Struct array from Experiment.groups (after aggregate)
%
% Output:
%   expandedGroups - Expanded struct array with one time bin per group

    % Check if expansion needed
    if isempty(groups) || isempty(groups(1).gbyGrandBarFlat) || ...
            ~isfield(groups(1).gbyGrandBarFlat, 'time')
        expandedGroups = groups;
        return;
    end

    barTimes = groups(1).gbyGrandBarFlat.time;
    nTimes = length(barTimes);

    if nTimes <= 1
        expandedGroups = groups;
        return;
    end

    nGroups = length(groups);
    biomarkers = {'HbO', 'HbR', 'HbTotal', 'HbDiff', 'CBSI'};

    % Compute bin size from bar times
    binSize = barTimes(2) - barTimes(1);

    % Build expanded groups: group-major ordering
    % (all time bins within each group, matching GUI layout)
    expandedGroups = repmat(groups(1), 1, nTimes * nGroups);
    idx = 0;

    for g = 1:nGroups
        ga = groups(g).gbyGrand;
        barFlat = groups(g).gbyGrandBarFlat;
        origTime = ga.time;

        for t = 1:nTimes
            idx = idx + 1;
            expandedGroups(idx) = groups(g);
            expandedGroups(idx).label = sprintf('%s [%gs]', ...
                groups(g).label, barTimes(t));

            % Time mask for slicing gbyGrand temporal data
            binStart = barTimes(t);
            binEnd = barTimes(t) + binSize;
            tMask = origTime >= binStart & origTime < binEnd;
            if ~any(tMask)
                [~, ci] = min(abs(origTime - barTimes(t)));
                tMask = false(size(origTime));
                tMask(ci) = true;
            end

            % --- Slice gbyGrandBarFlat to single time bin ---
            newBarFlat = barFlat;
            newBarFlat.time = barFlat.time(t);

            for b = 1:length(biomarkers)
                bio = biomarkers{b};
                if isfield(barFlat, bio) && ~isempty(barFlat.(bio)) && ...
                        isfield(barFlat.(bio), 'data')
                    newBarFlat.(bio).data = barFlat.(bio).data(t, :, :);
                end
            end

            % Slice ROI in barFlat if present
            if isfield(barFlat, 'ROI') && isstruct(barFlat.ROI)
                rfs = fieldnames(barFlat.ROI);
                for r = 1:length(rfs)
                    rf = rfs{r};
                    if strcmp(rf, 'info'), continue; end
                    if isstruct(barFlat.ROI.(rf)) && ...
                            isfield(barFlat.ROI.(rf), 'data')
                        newBarFlat.ROI.(rf).data = ...
                            barFlat.ROI.(rf).data(t, :, :);
                    end
                end
            end

            % Slice Aux in barFlat if present
            if isfield(barFlat, 'Aux') && isstruct(barFlat.Aux)
                afs = fieldnames(barFlat.Aux);
                for a = 1:length(afs)
                    if isstruct(barFlat.Aux.(afs{a})) && ...
                            isfield(barFlat.Aux.(afs{a}), 'data')
                        newBarFlat.Aux.(afs{a}).data = ...
                            barFlat.Aux.(afs{a}).data(t, :, :);
                    end
                end
            end

            expandedGroups(idx).gbyGrandBarFlat = newBarFlat;

            % --- Create matching single-timepoint gbyGrand ---
            newGrand = ga;
            newGrand.time = barFlat.time(t);

            % Biomarkers: compute stats from barFlat slice
            for b = 1:length(biomarkers)
                bio = biomarkers{b};
                if isfield(barFlat, bio) && ~isempty(barFlat.(bio)) && ...
                        isfield(barFlat.(bio), 'data')
                    sd = barFlat.(bio).data(t, :, :);
                    newGrand.(bio).Mean = mean(sd, 3, 'omitnan');
                    nV = sum(~isnan(sd), 3);
                    newGrand.(bio).SEM = std(sd, 0, 3, 'omitnan') ./ ...
                        sqrt(max(nV, 1));
                    newGrand.(bio).N = nV;
                    newGrand.(bio).data = sd;
                end
            end

            % Aux: slice from gbyGrand temporal data
            if isfield(ga, 'Aux') && isstruct(ga.Aux)
                afs = fieldnames(ga.Aux);
                for a = 1:length(afs)
                    af = afs{a};
                    if ~isstruct(ga.Aux.(af)) || ~isfield(ga.Aux.(af), 'Mean')
                        continue;
                    end
                    newGrand.Aux.(af) = sliceTemporalStruct( ...
                        ga.Aux.(af), tMask);
                end
            end

            % ROI: slice from gbyGrand temporal data
            if isfield(ga, 'ROI') && isstruct(ga.ROI)
                rfs = fieldnames(ga.ROI);
                for r = 1:length(rfs)
                    rf = rfs{r};
                    if strcmp(rf, 'info'), continue; end
                    if ~isstruct(ga.ROI.(rf)) || ~isfield(ga.ROI.(rf), 'Mean')
                        continue;
                    end
                    newGrand.ROI.(rf) = sliceTemporalStruct( ...
                        ga.ROI.(rf), tMask);
                end
            end

            expandedGroups(idx).gbyGrand = newGrand;

            % Add Time column to gbyTables
            T = groups(g).gbyTables;
            T.Time = repmat(barTimes(t), height(T), 1);
            expandedGroups(idx).gbyTables = T;
        end
    end
end


function sliced = sliceTemporalStruct(src, tMask)
% Slice a temporal data struct (Mean/SEM/N/data) to a single time bin
    sliced = src;
    if isfield(src, 'data') && ~isempty(src.data)
        sliced.data = mean(src.data(tMask, :, :), 1, 'omitnan');
        sliced.Mean = mean(sliced.data, 3, 'omitnan');
        nV = sum(~isnan(sliced.data), 3);
        sliced.SEM = std(sliced.data, 0, 3, 'omitnan') ./ sqrt(max(nV, 1));
        sliced.N = nV;
    else
        sliced.Mean = mean(src.Mean(tMask, :), 1, 'omitnan');
        if isfield(src, 'SEM') && isfield(src, 'N')
            % Pool SEM across time points: SEM_pooled = sqrt(mean(SEM^2))
            % (root-mean-square, not arithmetic mean of SEMs)
            sliced.SEM = sqrt(mean(src.SEM(tMask, :).^2, 1, 'omitnan'));
        elseif isfield(src, 'SEM')
            sliced.SEM = sqrt(mean(src.SEM(tMask, :).^2, 1, 'omitnan'));
        end
        if isfield(src, 'N')
            sliced.N = round(mean(src.N(tMask, :), 1, 'omitnan'));
        end
    end
end
