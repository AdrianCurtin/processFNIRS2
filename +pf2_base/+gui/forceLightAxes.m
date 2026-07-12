function forceLightAxes(ax)
% FORCELIGHTAXES Force light-mode colors on an axes handle.
%
%   pf2_base.gui.forceLightAxes(ax) sets white background and black
%   foreground (tick labels, axis labels, title) on the given axes.
%   Call after cla() since cla resets axes properties.

    set(ax, 'Color', [1 1 1], ...
            'XColor', [0 0 0], ...
            'YColor', [0 0 0], ...
            'ZColor', [0 0 0]);
    if ~isempty(ax.Title)
        set(ax.Title, 'Color', [0 0 0]);
    end
end
