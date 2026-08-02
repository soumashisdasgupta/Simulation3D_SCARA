function scara3d_kinematics(varargin)
%SCARA3D_KINEMATICS  3D SCARA Pick-and-Place Simulator.
%
%       % Custom link lengths & Z limits:
%       L1 250 L2 180 z_min 0 z_max 300
%
%       % Pre-set positions:
%       ix 250 iy 100 iz 50 fx -200 fy 300 fz 200
%
%   Author: Soumashis Dasgupta

% --- Folder on MATLAB path -------------
this_dir = fileparts(mfilename('fullpath'));
if ~contains(path, this_dir)
    addpath(this_dir);
end

p = inputParser();
p.CaseSensitive = false;

addParameter(p, 'L1',    300.0);
addParameter(p, 'L2',    200.0);
addParameter(p, 'z_min',   0.0);
addParameter(p, 'z_max', 400.0);
addParameter(p, 'ix',    300.0);         % initial X (mm)
addParameter(p, 'iy',      0.0);         % initial Y (mm)
addParameter(p, 'iz',     50.0);         % initial Z (mm)
addParameter(p, 'fx',      0.0);         % final X (mm)
addParameter(p, 'fy',    350.0);         % final Y (mm)
addParameter(p, 'fz',    250.0);         % final Z (mm)

parse(p, varargin{:});
r = p.Results;

% --- Building the arm struct -----------------
arm = struct( ...
    'L1',           r.L1, ...
    'L2',           r.L2, ...
    'z_min',        r.z_min, ...
    'z_max',        r.z_max, ...
    'outer_radius', r.L1 + r.L2, ...
    'inner_radius', abs(r.L1 - r.L2));

% ---- Text shown on Commnd Window: ------------------------
fprintf('\n');
fprintf('  ╔═══════════════════════════════════════════════╗\n');
fprintf('  ║   3D SCARA Pick & Place Simulator             ║\n');
fprintf('  ╚═══════════════════════════════════════════════╝\n');
fprintf('  L1 = %.0f mm   L2 = %.0f mm\n', arm.L1, arm.L2);
fprintf('  Z Travel  : %.0f mm to %.0f mm\n', arm.z_min, arm.z_max);
fprintf('  Workspace : %.0f mm (inner) – %.0f mm (outer)\n\n', ...
        arm.inner_radius, arm.outer_radius);

% --Dispatch -------------------------------
Scara3dApp(arm, r.ix, r.iy, r.iz, r.fx, r.fy, r.fz);
end
