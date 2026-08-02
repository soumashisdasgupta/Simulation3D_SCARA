classdef Scara3dApp < handle
%SCARA3DAPP  Interactive 3D SCARA Pick-and-Place Simulator.
%
%   Base-lift configuration: The Z-axis translation occurs at the base.
%   Arms L1 and L2 always remain in the same horizontal plane.

properties (Constant, Access = private)
    BG_DARK        = [0.051, 0.067, 0.090]
    SIDEBAR_BG     = [0.086, 0.106, 0.133]
    PANEL_BTN_BG   = [0.129, 0.149, 0.176]
    GRID_COLOR     = [0.150, 0.170, 0.200]
    COLOR_INIT     = [0.345, 0.651, 1.000]
    COLOR_FINAL    = [0.247, 0.729, 0.314]
    COLOR_TGT_I    = [0.345, 0.651, 1.000]
    COLOR_TGT_F    = [0.890, 0.702, 0.255]
    COLOR_BASE     = [0.150, 0.150, 0.180]
    COLOR_ARM1     = [0.700, 0.700, 0.750]
    COLOR_ARM2     = [0.850, 0.850, 0.900]
    COLOR_JOINT    = [0.200, 0.200, 0.250]
    COLOR_CYAN     = [0.000, 0.850, 1.000]
    COLOR_ORANGE   = [1.000, 0.600, 0.000]
    COLOR_WHITE    = [0.950, 0.950, 0.950]
    COLOR_ANIM     = [0.647, 0.839, 1.000]
    COLOR_TEXT     = [0.788, 0.820, 0.851]
    COLOR_DIM      = [0.400, 0.450, 0.500]
    COLOR_GOOD     = [0.247, 0.729, 0.314]
    COLOR_ERR      = [0.973, 0.318, 0.286]
    COLOR_BTN      = [0.137, 0.525, 0.212]

    JOINT_RADIUS   = 16.0
    ARM_WIDTH      = 22.0
    ARM_THICK      = 18.0
    ANIM_FRAMES    = 60
    ANIM_PERIOD    = 0.018
    SLIDE_MARGIN   = 1.05
    FIG_W          = 1400
    FIG_H          = 900
    SB_W           = 390
end

properties (Access = private)
    arm
    init_x; init_y; init_z;
    final_x; final_y; final_z;

    fig; panel_sb; ax_main; ax_triad;
    sl_ix; sl_iy; sl_iz;
    sl_fx; sl_fy; sl_fz;
    ef_ix; ef_iy; ef_iz;
    ef_fx; ef_fy; ef_fz;
    btn_place; btn_reset; txt_info; overlay_h;

    arm_h = {}; ghost_h = {}; marker_h = {}; anim_h = {}; visited_h = {};
    animating = false; anim_frame = 0; anim_timer = [];
    sol_i = []; sol_f = [];
    cam_link; % Property to hold linkprop instance so link stays active
end

methods
    function app = Scara3dApp(arm, ix, iy, iz, fx, fy, fz)
        app.arm = arm;
        app.init_x = ix; app.init_y = iy; app.init_z = iz;
        app.final_x = fx; app.final_y = fy; app.final_z = fz;
        app.build_figure();
        app.build_sidebar();
        app.build_main_axes();
        app.full_redraw();
    end

    function delete(app)
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            stop(app.anim_timer); delete(app.anim_timer);
        end
    end
end

methods (Access = private)
    function build_figure(app)
        ss = get(0, 'ScreenSize');
        cx = round((ss(3) - app.FIG_W) / 2);
        cy = round((ss(4) - app.FIG_H) / 2);
        app.fig = uifigure('Name', '3D SCARA Simulator', 'Position', [cx, cy, app.FIG_W, app.FIG_H], ...
            'Color', app.BG_DARK, 'Resize', 'on', 'AutoResizeChildren', 'off', ...
            'SizeChangedFcn', @(src,~) app.on_resize(src), ...
            'CloseRequestFcn', @(~,~) app.on_close());
        app.panel_sb = uipanel(app.fig, 'Position', [0, 0, app.SB_W, app.FIG_H], ...
            'BackgroundColor', app.SIDEBAR_BG, 'BorderType', 'none');
    end

    function build_sidebar(app)
        p = app.panel_sb; pw = app.SB_W; ph = app.FIG_H; pad = 18; cw = pw - 2*pad;
        s_lim = app.arm.outer_radius * app.SLIDE_MARGIN;

        % Header
        uilabel(p, 'Text', '[ 3D Pick & Place ]', 'Position', [pad, ph-48, cw, 38], 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', app.COLOR_TEXT);
        
        % INITIAL POSITION
        y = ph - 108;
        uilabel(p, 'Text', 'INITIAL POSITION', 'Position', [pad, y, cw, 22], 'FontSize', 10.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', app.COLOR_INIT);
        
        [app.sl_ix, app.ef_ix] = app.make_slider('X  (mm)', pad, y-50, cw, pw, -s_lim, s_lim, app.init_x);
        [app.sl_iy, app.ef_iy] = app.make_slider('Y  (mm)', pad, y-105, cw, pw, -s_lim, s_lim, app.init_y);
        [app.sl_iz, app.ef_iz] = app.make_slider('Z  (mm)', pad, y-160, cw, pw, app.arm.z_min, app.arm.z_max, app.init_z);
        
        app.sb_divider(y-180);

        % FINAL POSITION
        y = y - 200;
        uilabel(p, 'Text', 'FINAL POSITION', 'Position', [pad, y, cw, 22], 'FontSize', 10.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', app.COLOR_TGT_F);
        
        [app.sl_fx, app.ef_fx] = app.make_slider('Fx (mm)', pad, y-50, cw, pw, -s_lim, s_lim, app.final_x);
        [app.sl_fy, app.ef_fy] = app.make_slider('Fy (mm)', pad, y-105, cw, pw, -s_lim, s_lim, app.final_y);
        [app.sl_fz, app.ef_fz] = app.make_slider('Fz (mm)', pad, y-160, cw, pw, app.arm.z_min, app.arm.z_max, app.final_z);
        
        app.sb_divider(y-180);

        % BUTTONS
        app.btn_place = uibutton(p, 'Text', 'PLACE', 'Position', [pad, y-260, cw, 60], 'FontSize', 16, 'FontWeight', 'bold', ...
            'FontColor', [1,1,1], 'BackgroundColor', app.COLOR_BTN, 'ButtonPushedFcn', @(~,~) app.cb_place());
            
        app.txt_info = uitextarea(p, 'Value', '', 'Position', [pad, y-410, cw, 130], 'FontSize', 8.5, 'FontName', 'Courier New', ...
            'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.SIDEBAR_BG, 'Editable', 'off');

        app.btn_reset = uibutton(p, 'Text', 'Reset', 'Position', [pad+25, 14, cw-50, 28], 'FontSize', 9, ...
            'FontColor', app.COLOR_DIM, 'BackgroundColor', app.PANEL_BTN_BG, 'ButtonPushedFcn', @(~,~) app.cb_reset());

        % Callbacks
        app.sl_ix.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'ix'); app.sl_ix.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'ix');
        app.sl_iy.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'iy'); app.sl_iy.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'iy');
        app.sl_iz.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'iz'); app.sl_iz.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'iz');
        
        app.sl_fx.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'fx'); app.sl_fx.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'fx');
        app.sl_fy.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'fy'); app.sl_fy.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'fy');
        app.sl_fz.ValueChangingFcn = @(~,e) app.cb_sl(e.Value, 'fz'); app.sl_fz.ValueChangedFcn = @(s,~) app.cb_sl(s.Value, 'fz');
        
        app.ef_ix.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'ix'); app.ef_iy.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'iy'); app.ef_iz.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'iz');
        app.ef_fx.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'fx'); app.ef_fy.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'fy'); app.ef_fz.ValueChangedFcn = @(s,~) app.cb_ef(s.Value, 'fz');
    end

    function [sl, ef] = make_slider(app, lbl, pad, y, cw, pw, vmin, vmax, val)
        uilabel(app.panel_sb, 'Text', lbl, 'Position', [pad, y+23, 60, 18], 'FontSize', 9, 'FontColor', app.COLOR_TEXT);
        sl = uislider(app.panel_sb, 'Limits', [vmin, vmax], 'Value', val, 'Position', [pad, y-5, cw-85, 3], ...
            'MajorTicksMode', 'manual', 'MajorTicks', [], 'MinorTicks', [], 'FontColor', app.COLOR_TEXT);
        ef = uieditfield(app.panel_sb, 'numeric', 'Value', val, 'Position', [pw-pad-72, y-9, 72, 22], ...
            'FontSize', 9, 'FontColor', app.COLOR_TEXT, 'BackgroundColor', app.PANEL_BTN_BG);
    end

    function sb_divider(app, y)
        uipanel(app.panel_sb, 'Position', [0, y, app.SB_W, 1], 'BackgroundColor', app.PANEL_BTN_BG, 'BorderType', 'none');
    end

    function build_main_axes(app)
        margin = 15;
        ax_left = app.SB_W + margin; ax_bottom = margin;
        ax_w = app.FIG_W - app.SB_W - 2*margin; ax_h = app.FIG_H - 2*margin;
        
        % Main axes
        app.ax_main = uiaxes(app.fig, 'Position', [ax_left, ax_bottom, ax_w, ax_h], ...
            'Color', app.BG_DARK, 'FontSize', 8);
        
        ax = app.ax_main;
        lim = app.arm.outer_radius * 1.25;
        zlim_max = max(app.arm.z_max * 1.2, 50);
        
        ax.XLim = [-lim, lim]; ax.YLim = [-lim, lim]; ax.ZLim = [0, zlim_max];
        ax.DataAspectRatio = [1, 1, 1];
        
        % Remove standard axes box
        axis(ax, 'off');
        view(ax, 35, 30);
        hold(ax, 'on');
        
        % Draw custom planar floor grid
        step = 100;
        grid_col = [app.GRID_COLOR, 0.4];
        for x = -lim:step:lim
            plot3(ax, [x, x], [-lim, lim], [0, 0], 'Color', grid_col, 'LineWidth', 1);
        end
        for y = -lim:step:lim
            plot3(ax, [-lim, lim], [y, y], [0, 0], 'Color', grid_col, 'LineWidth', 1);
        end
        
        % --- Adding a Faint Workspace Boundary Mesh ---------------------
        [bX_out, bY_out, bZ_out] = cylinder(app.arm.outer_radius, 32);
        mesh(ax, bX_out, bY_out, bZ_out*app.arm.z_max, ...
            'FaceColor', 'none', 'EdgeColor', [0.30, 0.40, 0.50], 'EdgeAlpha', 0.15, 'LineWidth', 0.6);

        if app.arm.inner_radius > 0
            [bX_in, bY_in, bZ_in] = cylinder(app.arm.inner_radius, 32);
            mesh(ax, bX_in, bY_in, bZ_in*app.arm.z_max, ...
                'FaceColor', 'none', 'EdgeColor', [0.30, 0.40, 0.50], 'EdgeAlpha', 0.15, 'LineWidth', 0.6);
        end
        
        % Base pedestal and column
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 3.5, 32);
        surf(ax, cX, cY, cZ*20, 'FaceColor', app.COLOR_BASE*0.8, 'EdgeColor', 'none', 'FaceAlpha', 1.0); % Pedestal
        fill3(ax, cX(2,:), cY(2,:), cZ(2,:)*20, app.COLOR_BASE*0.8, 'EdgeColor', 'none');
        
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 1.5, 32);
        surf(ax, cX, cY, cZ*app.arm.z_max, 'FaceColor', app.COLOR_BASE, 'EdgeColor', 'none', 'FaceAlpha', 1.0); % Column
        fill3(ax, cX(2,:), cY(2,:), cZ(2,:)*app.arm.z_max, app.COLOR_BASE, 'EdgeColor', 'none');
        
        % Cyan ring at top of base column 
        plot3(ax, cX(2,:), cY(2,:), repmat(app.arm.z_max, 1, 33), 'Color', app.COLOR_CYAN, 'LineWidth', 3);
        
        % Overlay Text
        app.overlay_h = text(ax, 0, 0, 0, '', 'Units', 'normalized', 'Position', [0.5, 0.05, 0], ...
            'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', 'Visible', 'off');
            
        % ── Top-Right Fixed Orientation Gizmo (Triad Axes) ───────────────
        app.ax_triad = uiaxes(app.fig, 'Position', [ax_left + ax_w - 120, ax_bottom + ax_h - 120, 100, 100], ...
            'Color', 'none');
        axis(app.ax_triad, 'off');
        app.ax_triad.XLim = [-1.2, 1.2]; app.ax_triad.YLim = [-1.2, 1.2]; app.ax_triad.ZLim = [-1.2, 1.2];
        app.ax_triad.DataAspectRatio = [1, 1, 1];
        view(app.ax_triad, 35, 30);
        hold(app.ax_triad, 'on');
        
        col_xyz = [0.95, 0.25, 0.25];
        quiver3(app.ax_triad, 0,0,0, 0.8,0,0, 0, 'Color', col_xyz, 'LineWidth', 2.5, 'MaxHeadSize', 0.5);
        quiver3(app.ax_triad, 0,0,0, 0,0.8,0, 0, 'Color', col_xyz, 'LineWidth', 2.5, 'MaxHeadSize', 0.5);
        quiver3(app.ax_triad, 0,0,0, 0,0,0.8, 0, 'Color', col_xyz, 'LineWidth', 2.5, 'MaxHeadSize', 0.5);
        text(app.ax_triad, 1.05, 0, 0, 'X', 'Color', col_xyz, 'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center');
        text(app.ax_triad, 0, 1.05, 0, 'Y', 'Color', col_xyz, 'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center');
        text(app.ax_triad, 0, 0, 1.05, 'Z', 'Color', col_xyz, 'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center');
        
        % Permanently link camera orientation between main view and gizmo viewport
        app.cam_link = linkprop([app.ax_main, app.ax_triad], 'View');
    end

    function full_redraw(app)
        if app.animating; return; end
        app.clear_h(app.arm_h); app.arm_h = {};
        app.clear_h(app.ghost_h); app.ghost_h = {};
        app.clear_h(app.marker_h); app.marker_h = {};
        app.overlay_h.Visible = 'off';
        
        app.sol_i = best_solution_3d(app.init_x, app.init_y, app.init_z, app.arm);
        app.sol_f = best_solution_3d(app.final_x, app.final_y, app.final_z, app.arm);
        
        h_m1 = plot3(app.ax_main, app.init_x, app.init_y, app.init_z, '+', 'Color', app.COLOR_TGT_I, 'MarkerSize', 12, 'LineWidth', 2);
        h_m2 = plot3(app.ax_main, app.final_x, app.final_y, app.final_z, 'x', 'Color', app.COLOR_TGT_F, 'MarkerSize', 12, 'LineWidth', 2);
        app.marker_h = {h_m1, h_m2};
        
        if ~isempty(app.sol_f)
            app.ghost_h = app.draw_arm_artists(app.sol_f, app.COLOR_FINAL, 0.25);
        end
        if ~isempty(app.sol_i)
            app.arm_h = app.draw_arm_artists(app.sol_i, [], 1.0); % Uses default block colors
        end
        app.update_info();
    end

    function handles = draw_3d_block(app, ax, x1, y1, x2, y2, z, color, alpha)
        % Draws a 3D rounded rectangular arm in the horizontal plane
        dx = x2 - x1; dy = y2 - y1; len = hypot(dx, dy);
        ux = dx/len; uy = dy/len; nx = -uy; ny = ux;
        hw = app.ARM_WIDTH / 2; ht = app.ARM_THICK / 2;
        
        px = [x1 + nx*hw, x2 + nx*hw, x2 - nx*hw, x1 - nx*hw];
        py = [y1 + ny*hw, y2 + ny*hw, y2 - ny*hw, y1 - ny*hw];
        
        handles = {};
        handles{end+1} = fill3(ax, px, py, z+ht + zeros(1,4), color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = fill3(ax, px, py, z-ht + zeros(1,4), color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        
        for i=1:4
            i2 = mod(i,4)+1;
            sx = [px(i), px(i2), px(i2), px(i)];
            sy = [py(i), py(i2), py(i2), py(i)];
            sz = [z+ht, z+ht, z-ht, z-ht];
            handles{end+1} = fill3(ax, sx, sy, sz, color * 0.85, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        end
        
        % Cylindrical end caps
        [cX, cY, cZ] = cylinder(hw, 24);
        cZ = (cZ - 0.5) * app.ARM_THICK;
        handles{end+1} = surf(ax, cX+x1, cY+y1, cZ+z, 'FaceColor', color*0.85, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = surf(ax, cX+x2, cY+y2, cZ+z, 'FaceColor', color*0.85, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = fill3(ax, cX(1,:)+x1, cY(1,:)+y1, cZ(1,:)+z, color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = fill3(ax, cX(2,:)+x1, cY(2,:)+y1, cZ(2,:)+z, color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = fill3(ax, cX(1,:)+x2, cY(1,:)+y2, cZ(1,:)+z, color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        handles{end+1} = fill3(ax, cX(2,:)+x2, cY(2,:)+y2, cZ(2,:)+z, color, 'EdgeColor', 'none', 'FaceAlpha', alpha);
    end

    function handles = draw_arm_artists(app, sol, force_color, alpha)
        ax = app.ax_main;
        [ex, ey, ez] = fk3d_solve(struct('theta1_rad', sol.theta1_rad, 'theta2_rad', 0, 'z', sol.z), app.arm);
        [eex, eey, eez] = fk3d_solve(sol, app.arm);
        z = sol.z;
        
        c1 = app.COLOR_ARM1; c2 = app.COLOR_ARM2; cJ = app.COLOR_JOINT;
        c_cyan = app.COLOR_CYAN; c_orange = app.COLOR_ORANGE; c_white = app.COLOR_WHITE;
        
        if ~isempty(force_color)
            c1 = force_color; c2 = force_color; cJ = force_color;
            c_cyan = force_color; c_orange = force_color; c_white = force_color;
        end
        
        handles = {};
        
        % 1. Base slider joint sleeve
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 1.6, 24);
        handles{end+1} = surf(ax, cX, cY, (cZ - 0.5)*40 + z, 'FaceColor', cJ, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        % Cyan accent ring on top of sleeve
        handles{end+1} = plot3(ax, cX(2,:), cY(2,:), repmat(z + 20, 1, 25), 'Color', c_cyan, 'LineWidth', 2.5);
        
        % 2. Arm 1
        h1 = app.draw_3d_block(ax, 0, 0, ex, ey, z + 8, c1, alpha);
        handles = [handles, h1];
        
        % 3. Elbow joint cylinder
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 1.1, 24);
        handles{end+1} = surf(ax, cX+ex, cY+ey, (cZ - 0.5)*30 + z, 'FaceColor', cJ, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        % Cyan accent ring on top of elbow joint
        handles{end+1} = plot3(ax, cX(2,:)+ex, cY(2,:)+ey, repmat(z + 15, 1, 25), 'Color', c_cyan, 'LineWidth', 2.5);
        % White sphere cap on center top of elbow joint
        [sX, sY, sZ] = sphere(16);
        handles{end+1} = surf(ax, sX*app.JOINT_RADIUS*0.4 + ex, sY*app.JOINT_RADIUS*0.4 + ey, sZ*app.JOINT_RADIUS*0.4 + z + 15, ...
            'FaceColor', c_white, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        
        % 4. Arm 2
        h2 = app.draw_3d_block(ax, ex, ey, eex, eey, z - 8, c2, alpha);
        handles = [handles, h2];
        
        % 5. Wrist / End-effector joint cap
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 0.9, 24);
        handles{end+1} = surf(ax, cX+eex, cY+eey, (cZ - 0.5)*26 + z, 'FaceColor', cJ, 'EdgeColor', 'none', 'FaceAlpha', alpha);
        % Cyan accent ring
        handles{end+1} = plot3(ax, cX(2,:)+eex, cY(2,:)+eey, repmat(z + 13, 1, 25), 'Color', c_cyan, 'LineWidth', 2.5);
        % Orange accent ring below cyan ring
        handles{end+1} = plot3(ax, cX(2,:)*0.95+eex, cY(2,:)*0.95+eey, repmat(z + 9, 1, 25), 'Color', c_orange, 'LineWidth', 2.5);
        % White sphere cap on center top of wrist joint
        handles{end+1} = surf(ax, sX*app.JOINT_RADIUS*0.4 + eex, sY*app.JOINT_RADIUS*0.4 + eey, sZ*app.JOINT_RADIUS*0.4 + z + 13, ...
            'FaceColor', c_white, 'EdgeColor', 'none', 'FaceAlpha', alpha);

        % 6. End-effector tool shaft
        [cX, cY, cZ] = cylinder(app.JOINT_RADIUS * 0.35, 16);
        handles{end+1} = surf(ax, cX+eex, cY+eey, (cZ - 1.0)*30 + z, 'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none', 'FaceAlpha', alpha);
        
        % 7. Tool tip sphere
        handles{end+1} = surf(ax, sX*app.JOINT_RADIUS*0.5 + eex, sY*app.JOINT_RADIUS*0.5 + eey, sZ*app.JOINT_RADIUS*0.5 + z - 30, ...
            'FaceColor', [0.95, 0.95, 0.95], 'EdgeColor', 'none', 'FaceAlpha', alpha);
    end

    function cb_sl(app, val, id)
        val = round(val, 1);
        switch id
            case 'ix', app.init_x = val; app.ef_ix.Value = val;
            case 'iy', app.init_y = val; app.ef_iy.Value = val;
            case 'iz', app.init_z = val; app.ef_iz.Value = val;
            case 'fx', app.final_x = val; app.ef_fx.Value = val;
            case 'fy', app.final_y = val; app.ef_fy.Value = val;
            case 'fz', app.final_z = val; app.ef_fz.Value = val;
        end
        app.full_redraw();
    end

    function cb_ef(app, val, id)
        switch id
            case 'ix', app.init_x = val; app.sl_ix.Value = max(app.sl_ix.Limits(1), min(app.sl_ix.Limits(2), val));
            case 'iy', app.init_y = val; app.sl_iy.Value = max(app.sl_iy.Limits(1), min(app.sl_iy.Limits(2), val));
            case 'iz', app.init_z = val; app.sl_iz.Value = max(app.sl_iz.Limits(1), min(app.sl_iz.Limits(2), val));
            case 'fx', app.final_x = val; app.sl_fx.Value = max(app.sl_fx.Limits(1), min(app.sl_fx.Limits(2), val));
            case 'fy', app.final_y = val; app.sl_fy.Value = max(app.sl_fy.Limits(1), min(app.sl_fy.Limits(2), val));
            case 'fz', app.final_z = val; app.sl_fz.Value = max(app.sl_fz.Limits(1), min(app.sl_fz.Limits(2), val));
        end
        app.full_redraw();
    end

    function cb_place(app)
        if app.animating; return; end
        if isempty(app.sol_i) || isempty(app.sol_f)
            app.show_overlay('ERROR: Target unreachable!', app.COLOR_ERR);
            return;
        end
        app.animating = true; app.anim_frame = 0;
        
        for i=1:numel(app.marker_h); if isgraphics(app.marker_h{i}); app.marker_h{i}.Visible = 'off'; end; end
        app.overlay_h.Visible = 'off';
        
        app.anim_timer = timer('Period', app.ANIM_PERIOD, 'ExecutionMode', 'fixedRate', ...
            'TasksToExecute', app.ANIM_FRAMES, 'TimerFcn', @(~,~) app.anim_tick(), 'StopFcn', @(~,~) app.on_anim_done());
        start(app.anim_timer);
    end

    function anim_tick(app)
        if isempty(app.fig) || ~isgraphics(app.fig); return; end
        app.anim_frame = app.anim_frame + 1;
        t = (app.anim_frame - 1) / max(app.ANIM_FRAMES - 1, 1);
        t_ease = 0.5 - 0.5 * cos(pi * t);
        
        th1 = app.sol_i.theta1_rad + t_ease * (app.sol_f.theta1_rad - app.sol_i.theta1_rad);
        th2 = app.sol_i.theta2_rad + t_ease * (app.sol_f.theta2_rad - app.sol_i.theta2_rad);
        z = app.sol_i.z + t_ease * (app.sol_f.z - app.sol_i.z);
        
        interp_sol = struct('theta1_rad', th1, 'theta2_rad', th2, 'z', z, 'config', 'anim');
        
        app.clear_h(app.anim_h);
        for i=1:numel(app.arm_h); if isgraphics(app.arm_h{i}); app.arm_h{i}.Visible = 'off'; end; end
        
        app.anim_h = app.draw_arm_artists(interp_sol, app.COLOR_ANIM, 1.0);
        drawnow limitrate;
    end

    function on_anim_done(app)
        app.animating = false;
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            delete(app.anim_timer); app.anim_timer = [];
        end
        if isempty(app.fig) || ~isgraphics(app.fig); return; end
        
        app.clear_h(app.anim_h); app.anim_h = {};
        app.clear_h(app.ghost_h); app.ghost_h = {};
        app.clear_h(app.arm_h); app.arm_h = {};
        
        h = plot3(app.ax_main, app.final_x, app.final_y, app.final_z, '.', 'Color', app.COLOR_FINAL, 'MarkerSize', 25);
        app.visited_h{end+1} = h;
        
        app.init_x = app.final_x; app.init_y = app.final_y; app.init_z = app.final_z;
        app.sl_ix.Value = app.init_x; app.ef_ix.Value = app.init_x;
        app.sl_iy.Value = app.init_y; app.ef_iy.Value = app.init_y;
        app.sl_iz.Value = app.init_z; app.ef_iz.Value = app.init_z;
        
        for i=1:numel(app.marker_h); if isgraphics(app.marker_h{i}); app.marker_h{i}.Visible = 'on'; end; end
        app.show_overlay('Done!', app.COLOR_GOOD);
        app.full_redraw();
    end

    function update_info(app)
        lines = {};
        lines{end+1} = sprintf('INITIAL TARGET : [%.1f, %.1f, %.1f]', app.init_x, app.init_y, app.init_z);
        if isempty(app.sol_i)
            lines{end+1} = 'STATUS         : UNREACHABLE';
        else
            lines{end+1} = sprintf('JOINTS (deg)   : T1=%5.1f | T2=%5.1f | Z=%5.1f', rad2deg(app.sol_i.theta1_rad), rad2deg(app.sol_i.theta2_rad), app.sol_i.z);
        end
        lines{end+1} = '------------------------------------------';
        lines{end+1} = sprintf('FINAL TARGET   : [%.1f, %.1f, %.1f]', app.final_x, app.final_y, app.final_z);
        if isempty(app.sol_f)
            lines{end+1} = 'STATUS         : UNREACHABLE';
        else
            lines{end+1} = sprintf('JOINTS (deg)   : T1=%5.1f | T2=%5.1f | Z=%5.1f', rad2deg(app.sol_f.theta1_rad), rad2deg(app.sol_f.theta2_rad), app.sol_f.z);
        end
        app.txt_info.Value = lines;
    end

    function show_overlay(app, msg, color)
        app.overlay_h.String = msg;
        app.overlay_h.Color = color;
        app.overlay_h.Visible = 'on';
    end

    function clear_h(~, handles)
        for i = 1:numel(handles)
            if isgraphics(handles{i}); delete(handles{i}); end
        end
    end

    function cb_reset(app)
        if app.animating; return; end
        app.clear_h(app.visited_h); app.visited_h = {};
        app.init_x = 300; app.init_y = 0; app.init_z = 50;
        app.final_x = 0; app.final_y = 350; app.final_z = 250;
        app.sl_ix.Value = app.init_x; app.sl_iy.Value = app.init_y; app.sl_iz.Value = app.init_z;
        app.sl_fx.Value = app.final_x; app.sl_fy.Value = app.final_y; app.sl_fz.Value = app.final_z;
        app.ef_ix.Value = app.init_x; app.ef_iy.Value = app.init_y; app.ef_iz.Value = app.init_z;
        app.ef_fx.Value = app.final_x; app.ef_fy.Value = app.final_y; app.ef_fz.Value = app.final_z;
        app.full_redraw();
    end

    function on_resize(app, src)
        if nargin < 2 || isempty(src) || ~isgraphics(src)
            src = app.fig;
        end
        if isempty(src) || ~isgraphics(src); return; end
        
        pos = src.Position;
        fw = pos(3); fh = pos(4);
        
        if isgraphics(app.panel_sb)
            app.panel_sb.Position(4) = fh;
        end
        
        margin = 15;
        ax_left = app.SB_W + margin; ax_bottom = margin;
        ax_w = max(100, fw - app.SB_W - 2*margin);
        ax_h = max(100, fh - 2*margin);
        
        if isgraphics(app.ax_main)
            app.ax_main.Position = [ax_left, ax_bottom, ax_w, ax_h];
        end
        
        if isgraphics(app.ax_triad)
            app.ax_triad.Position = [ax_left + ax_w - 120, ax_bottom + ax_h - 120, 100, 100];
        end
    end

    function on_close(app)
        if ~isempty(app.anim_timer) && isvalid(app.anim_timer)
            stop(app.anim_timer); delete(app.anim_timer);
        end
        if isgraphics(app.fig); delete(app.fig); end
    end
end
end
