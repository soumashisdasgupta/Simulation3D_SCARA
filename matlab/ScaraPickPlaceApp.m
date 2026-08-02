classdef ScaraPickPlaceApp < handle
%SCARAPICKPLACEAPP  Interactive SCARA Pick-and-Place Simulator — MATLAB GUI.
%
%   Dark-themed, fully interactive GUI that mirrors the Python matplotlib
%   version using MATLAB's uifigure / uiaxes / uislider / uibutton stack.
%
%   Usage (normally launched via scara_kinematics.m):
%       arm = struct('L1',300,'L2',200,'outer_radius',500,'inner_radius',100);
%       app = ScaraPickPlaceApp(arm, 300, 0, 0, 350);
%
%   Features:
%       · X/Y sliders + numeric edit fields  — live arm preview
%       · Fx/Fy edit fields                  — set final target
%       · PLACE button                        — sine-eased animation (60 fr)
%       · Ghost arm at final position         — dashed green preview
%       · Persistent green dots at past targets
%       · Live info panel (joint angles, r, reachability)
%       · Reset button
%
%   Author : Soumashis Dasgupta (MATLAB port)

% ── Constants ────────────────────────────────────────────────────────────
properties (Constant, Access = private)
    % Colours  (RGB, normalised [0,1])
    BG_DARK        = [0.051, 0.067, 0.090]
    SIDEBAR_BG     = [0.086, 0.106, 0.133]
    PANEL_BTN_BG   = [0.129, 0.149, 0.176]
    GRID_COLOR     = [0.129, 0.149, 0.176]
    WORKSPACE_FILL = [0.086, 0.106, 0.133]
    WORKSPACE_EDGE = [0.188, 0.212, 0.239]
    COLOR_INIT     = [0.345, 0.651, 1.000]   % blue
    COLOR_FINAL    = [0.247, 0.729, 0.314]   % green
    COLOR_TGT_I    = [0.345, 0.651, 1.000]
    COLOR_TGT_F    = [0.890, 0.702, 0.255]   % gold
    COLOR_BASE     = [0.973, 0.318, 0.286]   % red
    COLOR_ANIM     = [0.647, 0.839, 1.000]   % light blue
    COLOR_TEXT     = [0.788, 0.820, 0.851]
    COLOR_DIM      = [0.282, 0.310, 0.345]
    COLOR_GOOD     = [0.247, 0.729, 0.314]
    COLOR_ERR      = [0.973, 0.318, 0.286]
    COLOR_BTN      = [0.137, 0.525, 0.212]   % button green

    JOINT_RADIUS   = 8.0
    ANIM_FRAMES    = 60
    ANIM_PERIOD    = 0.018    % seconds — ~55 fps
    SLIDE_MARGIN   = 1.05     % slider range = outer_radius × this
    FIG_W          = 1400
    FIG_H          = 900
    SB_W           = 390      % sidebar width (px)
end

% ── State & GUI handles ──────────────────────────────────────────────────
properties (Access = private)
    arm                        % robot struct: L1, L2, outer_radius, inner_radius

    init_x  = 300.0
    init_y  =   0.0
    final_x =   0.0
    final_y = 350.0

    % Figure / layout
    fig
    panel_sb
    ax_main

    % Sidebar widgets
    sl_ix, sl_iy               % initial sliders
    sl_fx, sl_fy               % final sliders
    ef_ix, ef_iy               % init edit fields
    ef_fx, ef_fy               % final edit fields
    btn_place, btn_reset
    txt_info                   % uitextarea for live info
    overlay_h = []             % text handle for Done/Error overlay

    % Plot handle pools  (cell arrays — heterogeneous patch/line/text)
    arm_h     = {}
    ghost_h   = {}
    marker_h  = {}
    anim_h    = {}
    visited_h = {}

    % Animation
    animating  = false
    anim_frame = 0
    anim_timer = []
    sol_i      = []
    sol_f      = []
end

% ── Public API ────────────────────────────────────────────────────────────
methods
    function app = ScaraPickPlaceApp(arm, init_x, init_y, final_x, final_y)
        app.arm     = arm;
        app.init_x  = init_x;
        app.init_y  = init_y;
        app.final_x = final_x;
        app.final_y = final_y;

        app.build_figure();
        app.build_sidebar();
        app.build_main_axes();
        app.full_redraw();
    end

    function delete(app)
        % Clean up timer if figure is closed externally.
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            stop(app.anim_timer);
            delete(app.anim_timer);
        end
    end
end

% ── Private implementation ────────────────────────────────────────────────
methods (Access = private)

    % ════════════════════════════════════════════════════════════════════════
    %  Figure & layout
    % ════════════════════════════════════════════════════════════════════════

    function build_figure(app)
        ss = get(0, 'ScreenSize');
        cx = round((ss(3) - app.FIG_W) / 2);
        cy = round((ss(4) - app.FIG_H) / 2);

        app.fig = uifigure( ...
            'Name',              'SCARA — Pick & Place Simulator (MATLAB)', ...
            'Position',          [cx, cy, app.FIG_W, app.FIG_H], ...
            'Color',             app.BG_DARK, ...
            'Resize',            'off', ...
            'CloseRequestFcn',   @(~,~) app.on_close());

        % Sidebar panel
        app.panel_sb = uipanel(app.fig, ...
            'Position',        [0, 0, app.SB_W, app.FIG_H], ...
            'BackgroundColor', app.SIDEBAR_BG, ...
            'BorderType',      'none');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Sidebar construction
    % ════════════════════════════════════════════════════════════════════════

    function build_sidebar(app)
        p   = app.panel_sb;
        pw  = app.SB_W;
        ph  = app.FIG_H;
        arm = app.arm;
        pad = 18;
        cw  = pw - 2*pad;
        s_lim = arm.outer_radius * app.SLIDE_MARGIN;

        % ── Header ───────────────────────────────────────────────────────
        uilabel(p, 'Text', '[ Pick & Place Control ]', ...
            'Position', [pad, ph-48, cw, 38], ...
            'FontSize', 13, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'FontColor', app.COLOR_TEXT, ...
            'BackgroundColor', app.SIDEBAR_BG);

        uilabel(p, 'Text', sprintf('L1 = %.0f mm   |   L2 = %.0f mm', arm.L1, arm.L2), ...
            'Position', [pad, ph-72, cw, 20], ...
            'FontSize', 9, 'HorizontalAlignment', 'center', ...
            'FontColor', app.COLOR_DIM, ...
            'BackgroundColor', app.SIDEBAR_BG);

        app.sb_divider(p, ph-82);

        % ── INITIAL POSITION ─────────────────────────────────────────────
        uilabel(p, 'Text', 'INITIAL POSITION', ...
            'Position', [pad, ph-108, cw, 22], ...
            'FontSize', 10.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'FontColor', app.COLOR_INIT, 'BackgroundColor', app.SIDEBAR_BG);

        uilabel(p, 'Text', 'X  (mm)', ...
            'Position', [pad, ph-133, 60, 18], ...
            'FontSize', 9, 'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.SIDEBAR_BG);
        app.sl_ix = uislider(p, ...
            'Limits', [-s_lim, s_lim], 'Value', app.init_x, ...
            'Position', [pad, ph-168, cw-85, 3], ...
            'MajorTicksMode', 'manual', 'MajorTicks', [], 'MinorTicks', [], ...
            'FontColor', app.COLOR_TEXT);
        app.ef_ix = uieditfield(p, 'numeric', ...
            'Value', app.init_x, ...
            'Position', [pw-pad-72, ph-172, 72, 22], ...
            'FontSize', 9, ...
            'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.PANEL_BTN_BG);

        uilabel(p, 'Text', 'Y  (mm)', ...
            'Position', [pad, ph-202, 60, 18], ...
            'FontSize', 9, 'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.SIDEBAR_BG);
        app.sl_iy = uislider(p, ...
            'Limits', [-s_lim, s_lim], 'Value', app.init_y, ...
            'Position', [pad, ph-237, cw-85, 3], ...
            'MajorTicksMode', 'manual', 'MajorTicks', [], 'MinorTicks', [], ...
            'FontColor', app.COLOR_TEXT);
        app.ef_iy = uieditfield(p, 'numeric', ...
            'Value', app.init_y, ...
            'Position', [pw-pad-72, ph-241, 72, 22], ...
            'FontSize', 9, ...
            'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.PANEL_BTN_BG);

        app.sb_divider(p, ph-258);

        % ── FINAL POSITION ────────────────────────────────────────────────
        uilabel(p, 'Text', 'FINAL POSITION', ...
            'Position', [pad, ph-282, cw, 22], ...
            'FontSize', 10.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'FontColor', app.COLOR_TGT_F, 'BackgroundColor', app.SIDEBAR_BG);

        uilabel(p, 'Text', 'Fx  (mm)', ...
            'Position', [pad, ph-305, 70, 18], ...
            'FontSize', 9, 'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.SIDEBAR_BG);
        app.sl_fx = uislider(p, ...
            'Limits', [-s_lim, s_lim], 'Value', app.final_x, ...
            'Position', [pad, ph-342, cw-85, 3], ...
            'MajorTicksMode', 'manual', 'MajorTicks', [], 'MinorTicks', [], ...
            'FontColor', app.COLOR_TEXT);
        app.ef_fx = uieditfield(p, 'numeric', ...
            'Value', app.final_x, ...
            'Position', [pw-pad-72, ph-346, 72, 22], ...
            'FontSize', 9, ...
            'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.PANEL_BTN_BG);

        uilabel(p, 'Text', 'Fy  (mm)', ...
            'Position', [pad, ph-372, 70, 18], ...
            'FontSize', 9, 'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.SIDEBAR_BG);
        app.sl_fy = uislider(p, ...
            'Limits', [-s_lim, s_lim], 'Value', app.final_y, ...
            'Position', [pad, ph-409, cw-85, 3], ...
            'MajorTicksMode', 'manual', 'MajorTicks', [], 'MinorTicks', [], ...
            'FontColor', app.COLOR_TEXT);
        app.ef_fy = uieditfield(p, 'numeric', ...
            'Value', app.final_y, ...
            'Position', [pw-pad-72, ph-413, 72, 22], ...
            'FontSize', 9, ...
            'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.PANEL_BTN_BG);

        app.sb_divider(p, ph-430);

        % ── PLACE button ──────────────────────────────────────────────────
        app.btn_place = uibutton(p, ...
            'Text', 'PLACE', ...
            'Position', [pad, ph-507, cw, 62], ...
            'FontSize', 16, 'FontWeight', 'bold', ...
            'FontColor', [1, 1, 1], ...
            'BackgroundColor', app.COLOR_BTN, ...
            'ButtonPushedFcn', @(~,~) app.cb_place());

        app.sb_divider(p, ph-520);

        % ── Live Info ─────────────────────────────────────────────────────
        uilabel(p, 'Text', 'Live Info', ...
            'Position', [pad, ph-544, cw, 20], ...
            'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'FontColor', app.COLOR_DIM, 'BackgroundColor', app.SIDEBAR_BG);

        app.txt_info = uitextarea(p, ...
            'Value', '', ...
            'Position', [pad, ph-725, cw, 155], ...
            'FontSize', 8.5, 'FontName', 'Courier New', ...
            'FontColor', app.COLOR_TEXT, ...
            'BackgroundColor', app.SIDEBAR_BG, ...
            'Editable', 'off', ...
            'WordWrap', 'off', ...
            'HorizontalAlignment', 'left');

        app.sb_divider(p, ph-735);

        % ── Reset button ──────────────────────────────────────────────────
        app.btn_reset = uibutton(p, ...
            'Text', 'Reset to defaults', ...
            'Position', [pad+25, 14, cw-50, 28], ...
            'FontSize', 9, ...
            'FontColor', app.COLOR_DIM, ...
            'BackgroundColor', app.PANEL_BTN_BG, ...
            'ButtonPushedFcn', @(~,~) app.cb_reset());

        % ── Wire callbacks ────────────────────────────────────────────────
        app.sl_ix.ValueChangingFcn = @(~, evt) app.cb_sl_ix(evt.Value);
        app.sl_iy.ValueChangingFcn = @(~, evt) app.cb_sl_iy(evt.Value);
        app.sl_fx.ValueChangingFcn = @(~, evt) app.cb_sl_fx(evt.Value);
        app.sl_fy.ValueChangingFcn = @(~, evt) app.cb_sl_fy(evt.Value);
        app.sl_ix.ValueChangedFcn  = @(src, ~)  app.cb_sl_ix(src.Value);
        app.sl_iy.ValueChangedFcn  = @(src, ~)  app.cb_sl_iy(src.Value);
        app.sl_fx.ValueChangedFcn  = @(src, ~)  app.cb_sl_fx(src.Value);
        app.sl_fy.ValueChangedFcn  = @(src, ~)  app.cb_sl_fy(src.Value);
        app.ef_ix.ValueChangedFcn  = @(src, ~)  app.cb_ef_ix(src.Value);
        app.ef_iy.ValueChangedFcn  = @(src, ~)  app.cb_ef_iy(src.Value);
        app.ef_fx.ValueChangedFcn  = @(src, ~)  app.cb_ef_fx(src.Value);
        app.ef_fy.ValueChangedFcn  = @(src, ~)  app.cb_ef_fy(src.Value);
    end

    function sb_divider(~, parent, y_bottom)
        pw = parent.Position(3);
        uipanel(parent, ...
            'Position', [12, y_bottom, pw-24, 1], ...
            'BackgroundColor', [0.188, 0.212, 0.239], ...
            'BorderType', 'none');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Main axes — static elements
    % ════════════════════════════════════════════════════════════════════════

    function build_main_axes(app)
        margin = 5;
        ax_left   = app.SB_W + margin;
        ax_bottom = margin;
        ax_w      = app.FIG_W - app.SB_W - 2*margin;
        ax_h      = app.FIG_H - 2*margin;

        app.ax_main = uiaxes(app.fig, ...
            'Position',   [ax_left, ax_bottom, ax_w, ax_h], ...
            'Color',      app.BG_DARK, ...
            'XColor',     app.COLOR_DIM, ...
            'YColor',     app.COLOR_DIM, ...
            'GridColor',  app.GRID_COLOR, ...
            'GridAlpha',  0.7, ...
            'FontSize',   8);

        ax  = app.ax_main;
        arm = app.arm;
        lim = arm.outer_radius * 1.18;

        ax.XLim = [-lim, lim];
        ax.YLim = [-lim, lim];
        ax.DataAspectRatio    = [1, 1, 1];
        ax.PlotBoxAspectRatio = [1, 1, 1];
        grid(ax, 'on');
        ax.Box = 'on';
        ax.XLabel.String  = 'X  (mm)';
        ax.YLabel.String  = 'Y  (mm)';
        ax.XLabel.Color   = app.COLOR_DIM;
        ax.YLabel.Color   = app.COLOR_DIM;
        ax.Title.String   = sprintf('SCARA Pick & Place Simulator   |   L1=%.0f mm   L2=%.0f mm', arm.L1, arm.L2);
        ax.Title.Color    = app.COLOR_TEXT;
        ax.Title.FontSize = 11;
        ax.Title.FontWeight = 'bold';

        hold(ax, 'on');

        % Workspace annulus (static)
        app.draw_workspace_annulus();

        % Axis centre lines
        xline(ax, 0, 'Color', app.GRID_COLOR, 'LineWidth', 0.8, 'HandleVisibility', 'off');
        yline(ax, 0, 'Color', app.GRID_COLOR, 'LineWidth', 0.8, 'HandleVisibility', 'off');

        % Base joint (permanent)
        app.draw_circle(0, 0, app.JOINT_RADIUS * 1.4, app.COLOR_BASE, 1.0);
        text(ax, app.JOINT_RADIUS * 2.5, app.JOINT_RADIUS * 2.5, 'Base', ...
            'Color', app.COLOR_BASE, 'FontSize', 8, 'FontWeight', 'bold');

        % Legend entries (text-based, lower right)
        legend_x  = lim * 0.35;
        legend_y0 = -lim * 0.80;
        dy        = lim * 0.08;
        entries = { ...
            app.COLOR_INIT,  'Initial arm (blue)'; ...
            app.COLOR_TGT_F, 'Final target (gold)'; ...
            app.COLOR_FINAL, 'Ghost arm (green dashed)'; ...
            app.COLOR_BASE,  'Base / Shoulder (red)'; ...
        };
        for k = 1:size(entries,1)
            text(ax, legend_x, legend_y0 + (k-1)*dy, ['\bullet ', entries{k,2}], ...
                'Color', entries{k,1}, 'FontSize', 8);
        end

        % Overlay text object (hidden until needed)
        app.overlay_h = text(ax, 0, 0, '', ...
            'Units', 'normalized', ...
            'Position', [0.5, 0.06, 0], ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'middle', ...
            'FontSize', 14, 'FontWeight', 'bold', ...
            'Color',       app.COLOR_GOOD, ...
            'BackgroundColor', app.BG_DARK, ...
            'EdgeColor',   app.COLOR_GOOD, ...
            'Margin', 10, ...
            'Visible', 'off');
    end

    function draw_workspace_annulus(app)
        ax  = app.ax_main;
        arm = app.arm;
        th  = linspace(0, 2*pi, 361);
        xo  = arm.outer_radius * cos(th);
        yo  = arm.outer_radius * sin(th);
        xi  = arm.inner_radius * cos(th);
        yi  = arm.inner_radius * sin(th);
        patch(ax, [xo, fliplr(xi), xo(1)], [yo, fliplr(yi), yo(1)], ...
            app.WORKSPACE_FILL, ...
            'EdgeColor', app.WORKSPACE_EDGE, 'LineWidth', 1.2, ...
            'HandleVisibility', 'off');
        text(ax, arm.outer_radius*0.63, arm.outer_radius*0.63, ...
            sprintf('R=%.0f mm', arm.outer_radius), ...
            'Color', app.COLOR_DIM, 'FontSize', 7.5, 'HorizontalAlignment', 'center');
        text(ax, arm.inner_radius*0.4, arm.inner_radius*0.4, ...
            sprintf('r=%.0f mm', arm.inner_radius), ...
            'Color', app.COLOR_DIM, 'FontSize', 7.5, 'HorizontalAlignment', 'center');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Redraw pipeline
    % ════════════════════════════════════════════════════════════════════════

    function full_redraw(app)
        if app.animating; return; end
        app.clear_h(app.anim_h);
        app.anim_h = {};
        app.hide_overlay();
        app.draw_initial_arm();
        app.draw_final_ghost();
        app.draw_markers();
        app.update_info();
        drawnow;
    end

    function draw_initial_arm(app)
        app.clear_h(app.arm_h);
        app.arm_h = {};
        sol = best_solution(app.init_x, app.init_y, app.arm);
        if ~isempty(sol)
            app.arm_h = app.draw_arm_artists(sol, app.COLOR_INIT, 1.0, 4.5, 3.5, '-');
        end
    end

    function draw_final_ghost(app)
        app.clear_h(app.ghost_h);
        app.ghost_h = {};
        sol = best_solution(app.final_x, app.final_y, app.arm);
        if ~isempty(sol)
            app.ghost_h = app.draw_arm_artists(sol, app.COLOR_FINAL, 0.28, 3.5, 2.5, '--');
        end
    end

    function draw_markers(app)
        app.clear_h(app.marker_h);
        app.marker_h = {};
        if is_reachable(app.init_x, app.init_y, app.arm)
            app.marker_h = [app.marker_h, ...
                app.draw_crosshair(app.init_x, app.init_y, app.COLOR_TGT_I, 'Initial')];
        end
        if is_reachable(app.final_x, app.final_y, app.arm)
            app.marker_h = [app.marker_h, ...
                app.draw_crosshair(app.final_x, app.final_y, app.COLOR_TGT_F, 'Final')];
        end
    end

    function update_info(app)
        li = app.pos_info_lines(app.init_x,  app.init_y,  'INIT ');
        lf = app.pos_info_lines(app.final_x, app.final_y, 'FINAL');
        all_lines = [li, {''}, lf];
        app.txt_info.Value = all_lines;
    end

    function lines = pos_info_lines(app, x, y, tag)
        r     = hypot(x, y);
        reach = is_reachable(x, y, app.arm);
        sol   = best_solution(x, y, app.arm);
        if reach
            rstr = 'OK';
        else
            rstr = 'OUT OF REACH';
        end
        lines = { ...
            sprintf('%s:  (%+7.1f, %+7.1f) mm', tag, x, y), ...
            sprintf('  r = %.1f mm   %s', r, rstr) };
        if ~isempty(sol)
            lines{end+1} = sprintf('  t1=%+6.1f\x00b0   t2=%+6.1f\x00b0', ...
                rad2deg(sol.theta1_rad), rad2deg(sol.theta2_rad));
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Animation
    % ════════════════════════════════════════════════════════════════════════

    function cb_place(app)
        if app.animating; return; end

        app.sol_i = best_solution(app.init_x,  app.init_y,  app.arm);
        app.sol_f = best_solution(app.final_x, app.final_y, app.arm);

        if isempty(app.sol_i)
            app.show_overlay('Initial position is unreachable!', app.COLOR_ERR);
            drawnow; return;
        end
        if isempty(app.sol_f)
            app.show_overlay('Final position is unreachable!', app.COLOR_ERR);
            drawnow; return;
        end

        % Hide static elements during animation
        app.set_visible(app.arm_h,    'off');
        app.set_visible(app.ghost_h,  'off');
        app.set_visible(app.marker_h, 'off');
        app.hide_overlay();

        app.animating  = true;
        app.anim_frame = 0;

        app.anim_timer = timer( ...
            'Period',         app.ANIM_PERIOD, ...
            'ExecutionMode',  'fixedRate', ...
            'TasksToExecute', app.ANIM_FRAMES, ...
            'TimerFcn',       @(~,~) app.anim_tick(), ...
            'StopFcn',        @(~,~) app.on_anim_done());
        start(app.anim_timer);
    end

    function anim_tick(app)
        % Guard: figure may have been closed
        if ~isvalid(app.fig) || ~isvalid(app.ax_main); return; end

        app.anim_frame = app.anim_frame + 1;
        N      = app.ANIM_FRAMES;
        t      = (app.anim_frame - 1) / max(N - 1, 1);
        t_ease = 0.5 - 0.5 * cos(pi * t);   % sine ease in-out

        t1_i = app.sol_i.theta1_rad;  t2_i = app.sol_i.theta2_rad;
        t1_f = app.sol_f.theta1_rad;  t2_f = app.sol_f.theta2_rad;
        th1  = t1_i + t_ease * (t1_f - t1_i);
        th2  = t2_i + t_ease * (t2_f - t2_i);

        interp_sol = struct('theta1_rad', th1, 'theta2_rad', th2, 'config', 'anim');
        col = app.lerp_color(app.COLOR_ANIM, app.COLOR_FINAL, t_ease);

        app.clear_h(app.anim_h);
        app.anim_h = app.draw_arm_artists(interp_sol, col, 1.0, 4.5, 3.5, '-');
        drawnow limitrate;
    end

    function on_anim_done(app)
        app.animating = false;

        % Clean up timer object
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            delete(app.anim_timer);
            app.anim_timer = [];
        end

        if ~isvalid(app.fig); return; end   % figure was closed during animation

        app.clear_h(app.anim_h);   app.anim_h  = {};
        app.clear_h(app.ghost_h);  app.ghost_h = {};

        % Persistent green dot at completed final position
        h = app.draw_circle(app.final_x, app.final_y, app.JOINT_RADIUS * 0.6, app.COLOR_FINAL, 0.85);
        app.visited_h = [app.visited_h, {h}];

        % Restore marker crosshairs
        app.set_visible(app.marker_h, 'on');
        app.show_overlay('Done!   Enter new targets.', app.COLOR_GOOD);
        app.update_info();
        drawnow;
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Slider / edit field callbacks
    % ════════════════════════════════════════════════════════════════════════

    function cb_sl_ix(app, val)
        app.init_x    = round(val, 1);
        app.ef_ix.Value = app.init_x;
        app.full_redraw();
    end

    function cb_sl_iy(app, val)
        app.init_y    = round(val, 1);
        app.ef_iy.Value = app.init_y;
        app.full_redraw();
    end

    function cb_sl_fx(app, val)
        app.final_x   = round(val, 1);
        app.ef_fx.Value = app.final_x;
        app.full_redraw();
    end

    function cb_sl_fy(app, val)
        app.final_y   = round(val, 1);
        app.ef_fy.Value = app.final_y;
        app.full_redraw();
    end

    function cb_ef_ix(app, val)
        app.init_x = val;
        % Clamp slider within its range
        app.sl_ix.Value = max(app.sl_ix.Limits(1), min(app.sl_ix.Limits(2), val));
        app.full_redraw();
    end

    function cb_ef_iy(app, val)
        app.init_y = val;
        app.sl_iy.Value = max(app.sl_iy.Limits(1), min(app.sl_iy.Limits(2), val));
        app.full_redraw();
    end

    function cb_ef_fx(app, val)
        app.final_x = val;
        app.sl_fx.Value = max(app.sl_fx.Limits(1), min(app.sl_fx.Limits(2), val));
        app.full_redraw();
    end

    function cb_ef_fy(app, val)
        app.final_y = val;
        app.sl_fy.Value = max(app.sl_fy.Limits(1), min(app.sl_fy.Limits(2), val));
        app.full_redraw();
    end

    function cb_reset(app)
        if app.animating; return; end
        app.clear_h(app.visited_h);
        app.visited_h = {};
        app.init_x  = 300;  app.init_y  = 0;
        app.final_x = 0;    app.final_y = 350;
        app.sl_ix.Value = app.init_x;
        app.sl_iy.Value = app.init_y;
        app.sl_fx.Value = app.final_x;
        app.sl_fy.Value = app.final_y;
        app.ef_ix.Value = app.init_x;
        app.ef_iy.Value = app.init_y;
        app.ef_fx.Value = app.final_x;
        app.ef_fy.Value = app.final_y;
        app.full_redraw();
    end

    function on_close(app)
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            stop(app.anim_timer);
            delete(app.anim_timer);
        end
        if isvalid(app.fig)
            delete(app.fig);
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Drawing helpers
    % ════════════════════════════════════════════════════════════════════════

    function handles = draw_arm_artists(app, sol, color, alpha, lw_u, lw_l, ls)
        %DRAW_ARM_ARTISTS  Draw upper link, lower link, elbow and EE circles.
        %   Returns a cell array of graphics handles.
        ax  = app.ax_main;
        arm = app.arm;
        [ex,  ey]   = fk_elbow_pos(sol, arm);
        [eex, eey]  = fk_solve_pos(sol, arm);

        c4 = [color, alpha];   % 4-element RGBA (R2017b+)
        h1 = plot(ax, [0, ex],   [0, ey],   ls, 'Color', c4, 'LineWidth', lw_u);
        h2 = plot(ax, [ex, eex], [ey, eey], ls, 'Color', c4, 'LineWidth', lw_l);
        h3 = app.draw_circle(ex,  ey,  app.JOINT_RADIUS,        color, alpha);
        h4 = app.draw_circle(eex, eey, app.JOINT_RADIUS * 0.75, color, alpha);
        handles = {h1, h2, h3, h4};
    end

    function h = draw_circle(app, cx, cy, r, color, alpha)
        %DRAW_CIRCLE  Draw a filled circle (patch) on ax_main.
        if nargin < 6, alpha = 1.0; end
        th = linspace(0, 2*pi, 50);
        h = fill(app.ax_main, ...
            cx + r*cos(th), cy + r*sin(th), color, ...
            'EdgeColor', 'none', 'FaceAlpha', alpha);
    end

    function handles = draw_crosshair(app, x, y, color, label)
        %DRAW_CROSSHAIR  Crosshair + dot + annotation at (x,y).
        ax    = app.ax_main;
        arm   = app.arm;
        cross = arm.outer_radius * 0.028;
        c4    = [color, 1.0];
        h1 = plot(ax, [x-cross, x+cross], [y, y], '-', 'Color', c4, 'LineWidth', 1.8);
        h2 = plot(ax, [x, x], [y-cross, y+cross], '-', 'Color', c4, 'LineWidth', 1.8);
        h3 = app.draw_circle(x, y, cross * 0.4, color, 1.0);
        h4 = text(ax, x + cross*2.5, y + cross*2.5, ...
            sprintf(' %s\n (%.0f, %.0f) mm', label, x, y), ...
            'Color', color, 'FontSize', 8);
        handles = {h1, h2, h3, h4};
    end

    function show_overlay(app, msg, color)
        if ~isvalid(app.overlay_h); return; end
        app.overlay_h.String    = msg;
        app.overlay_h.Color     = color;
        app.overlay_h.EdgeColor = color;
        app.overlay_h.Visible   = 'on';
    end

    function hide_overlay(app)
        if ~isempty(app.overlay_h) && isvalid(app.overlay_h)
            app.overlay_h.Visible = 'off';
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Utility
    % ════════════════════════════════════════════════════════════════════════

    function clear_h(~, handles)
        %CLEAR_H  Delete all graphics objects in a cell array of handles.
        for k = 1:numel(handles)
            h = handles{k};
            if isvalid(h)
                delete(h);
            end
        end
    end

    function set_visible(~, handles, vis)
        %SET_VISIBLE  Set Visible property on all handles in a cell array.
        for k = 1:numel(handles)
            h = handles{k};
            if isvalid(h)
                h.Visible = vis;
            end
        end
    end

    function c = lerp_color(~, c1, c2, t)
        %LERP_COLOR  Linear RGB interpolation between c1 and c2.
        c = max(0, min(1, c1 + t * (c2 - c1)));
    end

end % methods (Access = private)
end % classdef
