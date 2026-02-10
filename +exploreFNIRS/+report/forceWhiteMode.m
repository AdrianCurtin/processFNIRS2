function forceWhiteMode(fig)
% FORCEWHITEMODE Override MATLAB dark mode colors for report output
%
% Forces all figure elements to use light-mode colors (white backgrounds,
% black text) regardless of the user's MATLAB theme. Call after creating
% or styling a figure that will be saved for reports.
%
% Syntax:
%   exploreFNIRS.report.forceWhiteMode(fig)
%
% Inputs:
%   fig - Figure handle
%
% See also: exploreFNIRS.report.Pipeline, exploreFNIRS.report.generate

    if isempty(fig) || ~isvalid(fig)
        return;
    end

    set(fig, 'Color', 'w');
    set(fig, 'InvertHardcopy', 'on');

    % --- Axes ---
    axList = findall(fig, 'Type', 'axes');
    for a = 1:length(axList)
        ax = axList(a);
        set(ax, 'Color', 'w');
        set(ax, 'XColor', 'k', 'YColor', 'k');
        if isprop(ax, 'ZColor')
            set(ax, 'ZColor', 'k');
        end
        if isprop(ax, 'GridColor')
            set(ax, 'GridColor', [0.15 0.15 0.15]);
        end

        % Title and labels
        if ~isempty(ax.Title),  set(ax.Title, 'Color', 'k');  end
        if ~isempty(ax.XLabel), set(ax.XLabel, 'Color', 'k'); end
        if ~isempty(ax.YLabel), set(ax.YLabel, 'Color', 'k'); end
        if isprop(ax, 'ZLabel') && ~isempty(ax.ZLabel)
            set(ax.ZLabel, 'Color', 'k');
        end
    end

    % --- Legends ---
    legList = findall(fig, 'Type', 'legend');
    for l = 1:length(legList)
        leg = legList(l);
        set(leg, 'Color', 'w');
        set(leg, 'TextColor', 'k');
        set(leg, 'EdgeColor', [0.5 0.5 0.5]);
        set(leg, 'Box', 'on');
    end

    % --- All text objects (catches subplot titles, tick labels, etc.) ---
    txtList = findall(fig, 'Type', 'text');
    for t = 1:length(txtList)
        set(txtList(t), 'Color', 'k');
    end

    % --- Sgtitle: lives in a hidden SubplotText or on a separate axes ---
    % findall with '-depth' catches all children including hidden
    allChildren = findall(fig);
    for c = 1:length(allChildren)
        obj = allChildren(c);
        cls = class(obj);
        % SubplotText is the sgtitle container in R2018b+
        if contains(cls, 'SubplotText') || contains(cls, 'subplottext')
            try
                set(obj, 'Color', 'k');
            catch
            end
            % Also fix children of the SubplotText
            try
                kids = allobj_text(obj);
                for k = 1:length(kids)
                    set(kids(k), 'Color', 'k');
                end
            catch
            end
        end
        % Annotation textboxes
        if contains(cls, 'Annotation') || contains(cls, 'textbox')
            try
                if isprop(obj, 'Color')
                    set(obj, 'Color', 'k');
                end
                if isprop(obj, 'BackgroundColor')
                    set(obj, 'BackgroundColor', 'none');
                end
            catch
            end
        end
    end

    % --- Brute force: any object with a Color property set to light gray ---
    % This catches sgtitle and other dark-mode themed elements
    for c = 1:length(allChildren)
        obj = allChildren(c);
        try
            if isprop(obj, 'Color') && ~ischar(get(obj, 'Color'))
                clr = get(obj, 'Color');
                if isnumeric(clr) && numel(clr) == 3
                    % If it's a light/medium gray (dark mode text color),
                    % force to black
                    brightness = mean(clr);
                    if brightness > 0.5 && brightness < 0.99
                        set(obj, 'Color', 'k');
                    end
                end
            end
        catch
        end
        % Fix any white-on-dark boxes
        try
            if isprop(obj, 'BackgroundColor') && ~ischar(get(obj, 'BackgroundColor'))
                bg = get(obj, 'BackgroundColor');
                if isnumeric(bg) && numel(bg) == 3 && mean(bg) < 0.3
                    set(obj, 'BackgroundColor', 'w');
                end
            end
        catch
        end
    end
end


function txts = allobj_text(parent)
% Find all text objects inside a parent (recursive)
    try
        txts = findall(parent, 'Type', 'text');
    catch
        txts = [];
    end
end
