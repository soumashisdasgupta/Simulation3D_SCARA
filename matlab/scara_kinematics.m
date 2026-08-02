function scara_kinematics(varargin)
%SCARA_KINEMATICS  Phase-1 SCARA Pick-and-Place Simulator — MATLAB port.
%
%   Equivalent to the Python `scara_kinematics.py` entry point.
%   Adds the matlab/ directory to the MATLAB path automatically.
%
%   Usage:
%       scara_kinematics                          % Interactive GUI (default)
%       scara_kinematics workspace                % Workspace heatmap
%       scara_kinematics demo                     % 7-target IK demo grid
%
%       % Custom link lengths:
%       scara_kinematics L1 250 L2 180
%
%       % Pre-set positions:
%       scara_kinematics ix 250 iy 100 fx -200 fy 300
%
%       % Full example:
%       scara_kinematics L1 300 L2 200 ix 300 iy 0 fx 0 fy 350
%
%   Author: Soumashis Dasgupta (MATLAB port)

% ── Ensure this folder is on the MATLAB path ─────────────────────────────
this_dir = fileparts(mfilename('fullpath'));
if ~contains(path, this_dir)
    addpath(this_dir);
end

% ── Parse arguments ───────────────────────────────────────────────────────
p = inputParser();
p.CaseSensitive = false;

addOptional(p,  'mode', 'gui');          % 'gui' | 'workspace' | 'demo'
addParameter(p, 'L1',   300.0);
addParameter(p, 'L2',   200.0);
addParameter(p, 'ix',   300.0);         % initial X (mm)
addParameter(p, 'iy',     0.0);         % initial Y (mm)
addParameter(p, 'fx',     0.0);         % final X (mm)
addParameter(p, 'fy',   350.0);         % final Y (mm)

parse(p, varargin{:});
r = p.Results;

% ── Build arm struct ──────────────────────────────────────────────────────
arm = struct( ...
    'L1',           r.L1, ...
    'L2',           r.L2, ...
    'outer_radius', r.L1 + r.L2, ...
    'inner_radius', abs(r.L1 - r.L2));

% ── Banner ────────────────────────────────────────────────────────────────
fprintf('\n');
fprintf('  ╔═══════════════════════════════════════════════╗\n');
fprintf('  ║   SCARA Pick & Place Simulator — MATLAB Port  ║\n');
fprintf('  ╚═══════════════════════════════════════════════╝\n');
fprintf('  L1 = %.0f mm   L2 = %.0f mm\n', arm.L1, arm.L2);
fprintf('  Workspace : %.0f mm (inner) – %.0f mm (outer)\n', ...
        arm.inner_radius, arm.outer_radius);
fprintf('  Mode      : %s\n\n', upper(r.mode));

% ── Dispatch ──────────────────────────────────────────────────────────────
switch lower(r.mode)
    case 'workspace'
        plot_workspace(arm);

    case 'demo'
        demo_grid(arm);

    otherwise   % 'gui'
        ScaraPickPlaceApp(arm, r.ix, r.iy, r.fx, r.fy);
end
end
