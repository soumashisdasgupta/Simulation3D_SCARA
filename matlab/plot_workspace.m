function plot_workspace(arm)
%PLOT_WORKSPACE  Render the SCARA reachable workspace as a filled contour heatmap.
%
%   Usage:
%       arm = struct('L1',300,'L2',200,'outer_radius',500,'inner_radius',100);
%       plot_workspace(arm);

% ── Colour palette ────────────────────────────────────────────────────────
BG_DARK        = [0.051, 0.067, 0.090];
COLOR_TEXT     = [0.788, 0.820, 0.851];
COLOR_DIM      = [0.282, 0.310, 0.345];
GRID_COLOR     = [0.129, 0.149, 0.176];
WORKSPACE_FILL = [0.086, 0.106, 0.133];
REACH_COLOR    = [0.122, 0.435, 0.922];

% ── Grid ──────────────────────────────────────────────────────────────────
resolution = 180;
lim  = arm.outer_radius * 1.1;
[X, Y] = meshgrid(linspace(-lim, lim, resolution));

R_SQ      = X.^2 + Y.^2;
reachable = double( ...
    (R_SQ >= arm.inner_radius^2) & ...
    (R_SQ <= arm.outer_radius^2));

% ── Figure ────────────────────────────────────────────────────────────────
fig = figure('Color', BG_DARK, ...
             'Name', 'SCARA — Reachable Workspace', ...
             'NumberTitle', 'off');
ax = axes(fig, ...
    'Color',      BG_DARK, ...
    'XColor',     COLOR_DIM, ...
    'YColor',     COLOR_DIM, ...
    'GridColor',  GRID_COLOR, ...
    'GridAlpha',  0.6, ...
    'FontSize',   9);
hold(ax, 'on');

% ── Contour fill ──────────────────────────────────────────────────────────
contourf(ax, X, Y, reachable, 1, 'LineWidth', 1.5);
colormap(ax, [WORKSPACE_FILL; REACH_COLOR]);
colorbar(ax, 'off');

% ── Annulus boundary circles (decorative) ────────────────────────────────
th    = linspace(0, 2*pi, 360);
x_out = arm.outer_radius * cos(th);
y_out = arm.outer_radius * sin(th);
x_in  = arm.inner_radius * cos(th);
y_in  = arm.inner_radius * sin(th);
plot(ax, x_out, y_out, '--', 'Color', [COLOR_TEXT, 0.5], 'LineWidth', 1.0);
plot(ax, x_in,  y_in,  '--', 'Color', [COLOR_TEXT, 0.5], 'LineWidth', 1.0);

% ── Annotations ───────────────────────────────────────────────────────────
text(ax, arm.outer_radius * 0.63, arm.outer_radius * 0.63, ...
    sprintf('Outer: %.0f mm', arm.outer_radius), ...
    'Color', COLOR_TEXT, 'FontSize', 9, 'HorizontalAlignment', 'center', ...
    'BackgroundColor', BG_DARK, 'EdgeColor', GRID_COLOR, 'Margin', 4);
text(ax, arm.inner_radius * 0.35, arm.inner_radius * 0.35, ...
    sprintf('Inner: %.0f mm', arm.inner_radius), ...
    'Color', COLOR_TEXT, 'FontSize', 9, 'HorizontalAlignment', 'center', ...
    'BackgroundColor', BG_DARK, 'EdgeColor', GRID_COLOR, 'Margin', 4);

% Base marker
plot(ax, 0, 0, 'o', 'MarkerFaceColor', [0.973,0.318,0.286], ...
    'MarkerEdgeColor', 'none', 'MarkerSize', 10);

% ── Formatting ────────────────────────────────────────────────────────────
axis(ax, 'equal');
grid(ax, 'on');
ax.XLim = [-lim, lim];
ax.YLim = [-lim, lim];
ax.Title.String  = sprintf('SCARA Reachable Workspace\nL1=%.0f mm  |  L2=%.0f mm  |  R: %.0f\x2013%.0f mm', ...
                           arm.L1, arm.L2, arm.inner_radius, arm.outer_radius);
ax.Title.Color   = COLOR_TEXT;
ax.Title.FontWeight = 'bold';
ax.Title.FontSize   = 11;
ax.XLabel.String = 'X  (mm)';
ax.YLabel.String = 'Y  (mm)';
ax.XLabel.Color  = COLOR_DIM;
ax.YLabel.Color  = COLOR_DIM;

fig.Position(3:4) = [720, 720];
end
