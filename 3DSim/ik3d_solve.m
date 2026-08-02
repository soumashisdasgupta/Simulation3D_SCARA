function [sol_eu, sol_ed] = ik3d_solve(x, y, z, arm)
%IK3D_SOLVE  Analytical 3-link planar inverse kinematics (with Z lift).
%
%   Solves for joint angles (θ₁, θ₂) and base lift (z) given target (x, y, z).
%   The Z-axis is decoupled from the X-Y planar kinematics.
%
%   Returns both solutions:
%       sol_eu — elbow-up   (θ₂ > 0)
%       sol_ed — elbow-down (θ₂ < 0)
%
%   Either output is [] if the corresponding solution violates joint limits
%   or if the target is outside the reachable workspace.

JOINT1_LIM_DEG = [-150.0,  150.0];
JOINT2_LIM_DEG = [-150.0,  150.0];

sol_eu = [];
sol_ed = [];

% ---- Reachability guard -----------------------
if ~is_reachable_3d(x, y, z, arm)
    return;
end

% ---------Law of cosines -> θ₂ ---------------------
c2 = (x^2 + y^2 - arm.L1^2 - arm.L2^2) / (2.0 * arm.L1 * arm.L2);
c2 = max(-1.0, min(1.0, c2));   % clamp for floating-point safety at boundaries

% ---- Solve both elbow configurations ----------------------
theta2_candidates = [ +acos(c2),  -acos(c2)  ];
config_labels     = {'elbow_up', 'elbow_down'};
results           = {[],          []          };

for i = 1:2
    theta2 = theta2_candidates(i);
    k1     = arm.L1 + arm.L2 * cos(theta2);
    k2     = arm.L2 * sin(theta2);
    theta1 = atan2(y, x) - atan2(k2, k1);

    t1_deg = rad2deg(theta1);
    t2_deg = rad2deg(theta2);

    % Joint limit checks
    if t1_deg < JOINT1_LIM_DEG(1) || t1_deg > JOINT1_LIM_DEG(2); continue; end
    if t2_deg < JOINT2_LIM_DEG(1) || t2_deg > JOINT2_LIM_DEG(2); continue; end

    results{i} = struct( ...
        'theta1_rad', theta1, ...
        'theta2_rad', theta2, ...
        'z',          z, ...
        'config',     config_labels{i});
end

sol_eu = results{1};
sol_ed = results{2};
end
