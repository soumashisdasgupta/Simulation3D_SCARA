function demo_grid(arm)
%DEMO_GRID  Plot a 3-column grid of IK solutions for 7 representative targets.
%
%   Each subplot shows elbow-up (blue solid) and elbow-down (green dashed)
%   solutions overlaid on the workspace annulus.
%
%   Usage:
%       arm = struct('L1',300,'L2',200,'outer_radius',500,'inner_radius',100);
%       demo_grid(arm);

% ── Demo targets (same as Python DEMO_TARGETS) ────────────────────────────
DEMO_TARGETS = [
     350,   0;
     300, 150;
       0, 400;
    -200, 300;
     150, 250;
     480,  50;
     110,  20;
];

% ── Colour palette ────────────────────────────────────────────────────────
BG_DARK        = [0.051, 0.067, 0.090];
COLOR_TEXT     = [0.788, 0.820, 0.851];
COLOR_DIM      = [0.282, 0.310, 0.345];
GRID_COLOR     = [0.129, 0.149, 0.176];
COLOR_INIT     = [0.345, 0.651, 1.000];
COLOR_FINAL    = [0.247, 0.729, 0.314];
COLOR_TGT_F    = [0.890, 0.702, 0.255];
COLOR_BASE     = [0.973, 0.318, 0.286];
WORKSPACE_FILL = [0.086, 0.106, 0.133];
WORKSPACE_EDGE = [0.188, 0.212, 0.239];
JOINT_RADIUS   = 6.0;

n    = size(DEMO_TARGETS, 1);
cols = 3;
rows = ceil(n / cols);

fig = figure('Color', BG_DARK, ...
             'Name', 'SCARA IK — Demo Target Grid', ...
             'NumberTitle', 'off', ...
             'Position', [50, 50, cols*370, rows*370]);

for idx = 1:n
    tx = DEMO_TARGETS(idx, 1);
    ty = DEMO_TARGETS(idx, 2);

    ax = subplot(rows, cols, idx);
    set(ax, 'Color', BG_DARK, ...
            'XColor', COLOR_DIM, 'YColor', COLOR_DIM, ...
            'GridColor', GRID_COLOR, 'GridAlpha', 0.5);
    hold(ax, 'on');

    lim = arm.outer_radius * 1.15;
    ax.XLim = [-lim, lim];
    ax.YLim = [-lim, lim];
    axis(ax, 'equal');
    grid(ax, 'on');
    ax.FontSize = 7;

    % ── Workspace annulus ────────────────────────────────────────────
    th  = linspace(0, 2*pi, 361);
    xo  = arm.outer_radius * cos(th);
    yo  = arm.outer_radius * sin(th);
    xi  = arm.inner_radius * cos(th);
    yi  = arm.inner_radius * sin(th);
    patch(ax, [xo, fliplr(xi), xo(1)], [yo, fliplr(yi), yo(1)], ...
        WORKSPACE_FILL, 'EdgeColor', WORKSPACE_EDGE, 'LineWidth', 0.8);

    % ── IK solutions ─────────────────────────────────────────────────
    [sol_eu, sol_ed] = ik_solve(tx, ty, arm);
    if ~isempty(sol_eu)
        draw_arm_on(ax, sol_eu, arm, COLOR_INIT,  1.0, 3.5, 2.5, '-',  JOINT_RADIUS);
    end
    if ~isempty(sol_ed)
        draw_arm_on(ax, sol_ed, arm, COLOR_FINAL, 0.55, 3.0, 2.0, '--', JOINT_RADIUS);
    end

    % ── Target marker ────────────────────────────────────────────────
    plot(ax, tx, ty, '+', ...
        'Color', COLOR_TGT_F, 'MarkerSize', 14, 'LineWidth', 2.0);

    % ── Base circle ──────────────────────────────────────────────────
    th_c = linspace(0, 2*pi, 50);
    fill(ax, JOINT_RADIUS*cos(th_c), JOINT_RADIUS*sin(th_c), ...
        COLOR_BASE, 'EdgeColor', 'none');

    % ── Reachability label ───────────────────────────────────────────
    if isempty(sol_eu) && isempty(sol_ed)
        reach_str = 'UNREACHABLE';
        tc = [0.973, 0.318, 0.286];
    else
        r = hypot(tx, ty);
        reach_str = sprintf('r=%.0f mm', r);
        tc = COLOR_DIM;
    end
    text(ax, 0, -lim*0.88, reach_str, ...
        'Color', tc, 'FontSize', 6.5, 'HorizontalAlignment', 'center');

    title(ax, sprintf('(%+.0f, %+.0f) mm', tx, ty), ...
        'Color', COLOR_TEXT, 'FontSize', 8.5, 'FontWeight', 'bold');
end

% ── Hide unused subplots ──────────────────────────────────────────────────
for idx = n+1 : rows*cols
    ax = subplot(rows, cols, idx);
    ax.Visible = 'off';
end

sgtitle(fig, ...
    sprintf('SCARA IK — Demo Target Grid\nL1=%.0f mm  |  L2=%.0f mm', arm.L1, arm.L2), ...
    'Color', COLOR_TEXT, 'FontSize', 13, 'FontWeight', 'bold');
end


% ── Local helper: draw a single arm on the given axes ────────────────────
function draw_arm_on(ax, sol, arm, color, alpha, lw_u, lw_l, ls, jr)
[ex, ey]    = fk_elbow_pos(sol, arm);
[ee_x, ee_y] = fk_solve_pos(sol, arm);
c4 = [color, alpha];
plot(ax, [0,  ex],   [0,  ey],   ls, 'Color', c4, 'LineWidth', lw_u);
plot(ax, [ex, ee_x], [ey, ee_y], ls, 'Color', c4, 'LineWidth', lw_l);
th = linspace(0, 2*pi, 40);
fill(ax, ex  + jr*cos(th), ey  + jr*sin(th), color, ...
    'EdgeColor', 'none', 'FaceAlpha', alpha);
fill(ax, ee_x + jr*0.75*cos(th), ee_y + jr*0.75*sin(th), color, ...
    'EdgeColor', 'none', 'FaceAlpha', alpha);
end
