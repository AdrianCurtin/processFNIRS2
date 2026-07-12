function applyLightTheme(fig)
% applyLightTheme  Force light-mode colors on MATLAB GUIDE figures.
%
%   pf2_base.applyLightTheme(fig) walks all uicontrol and uipanel children
%   of figure FIG and sets explicit foreground/background colors so that the
%   GUI remains readable on macOS dark mode.
%
%   Only runs on macOS; returns immediately on other platforms.
%
%   Usage:
%       % In any GUIDE OpeningFcn, after guidata(hObject, handles):
%       pf2_base.applyLightTheme(hObject);

    if ~ismac
        return;
    end

    bgLight  = [0.94 0.94 0.94];   % standard MATLAB light gray
    bgWhite  = [1 1 1];
    fgBlack  = [0 0 0];
    fgPanel  = [0.2 0.2 0.2];      % slightly softer than pure black

    % --- Figure ---
    set(fig, 'Color', bgLight);

    % --- Figure-level axes defaults (survive cla resets) ---
    set(fig, 'defaultAxesColor',  bgWhite, ...
             'defaultAxesXColor', fgBlack, ...
             'defaultAxesYColor', fgBlack, ...
             'defaultAxesZColor', fgBlack, ...
             'defaultAxesColorOrder', get(groot, 'factoryAxesColorOrder'));

    % --- Panels ---
    panels = findall(fig, 'Type', 'uipanel');
    for i = 1:numel(panels)
        set(panels(i), 'BackgroundColor', bgLight, ...
                        'ForegroundColor', fgPanel);
    end

    % --- Button groups ---
    btnGroups = findall(fig, 'Type', 'uibuttongroup');
    for i = 1:numel(btnGroups)
        set(btnGroups(i), 'BackgroundColor', bgLight, ...
                          'ForegroundColor', fgPanel);
    end

    % --- Controls ---
    controls = findall(fig, 'Type', 'uicontrol');
    for i = 1:numel(controls)
        style = get(controls(i), 'Style');
        switch style
            case {'listbox', 'edit', 'popupmenu'}
                set(controls(i), 'BackgroundColor', bgWhite, ...
                                 'ForegroundColor', fgBlack);
            case {'text'}
                set(controls(i), 'BackgroundColor', bgLight, ...
                                 'ForegroundColor', fgBlack);
            case {'checkbox', 'radiobutton'}
                set(controls(i), 'BackgroundColor', bgLight, ...
                                 'ForegroundColor', fgBlack);
            case {'pushbutton', 'togglebutton'}
                % Skip color-swatch buttons whose ForegroundColor is
                % intentionally set to display a color (e.g. gui_color_N).
                tag = get(controls(i), 'Tag');
                if contains(tag, 'gui_color')
                    continue;
                end
                set(controls(i), 'BackgroundColor', bgLight, ...
                                 'ForegroundColor', fgBlack);
        end
    end

    % --- Tables ---
    tables = findall(fig, 'Type', 'uitable');
    for i = 1:numel(tables)
        set(tables(i), 'ForegroundColor', fgBlack, ...
                        'BackgroundColor', bgWhite);
    end

    % --- Axes (plot quadrants) ---
    allAxes = findall(fig, 'Type', 'axes');
    for i = 1:numel(allAxes)
        pf2_base.gui.forceLightAxes(allAxes(i));
    end
end
