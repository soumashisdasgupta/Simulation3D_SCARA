function [sol_eu, sol_ed] = ik_solve(x, y, arm)
%IK_SOLVE  Analytical 2-link planar inverse kinematics.
%
%   Solves for joint angles (θ₁, θ₂) given end-effector target (x, y):
%
%       cos(θ₂) = (x² + y² − L1² − L2²) / (2·L1·L2)
%       θ₁      = atan2(y,x) − atan2(L2·sin θ₂,  L1 + L2·cos θ₂)
%
%   Returns both solutions:
%       sol_eu — elbow-up   (θ₂ > 0)
%       sol_ed — elbow-down (θ₂ < 0)
%
%   Either output is [] if the corresponding solution violates joint limits
%   or if the target is outside the reachable workspace.
%
%   Joint limits: θ₁ ∈ [−150°, 150°],  θ₂ ∈ [−150°, 150°]

JOINT1_LIM_DEG = [-150.0,  150.0];
JOINT2_LIM_DEG = [-150.0,  150.0];

sol_eu = [];
sol_ed = [];

% ── Reachability guard ────────────────────────────────────────────────────
if ~is_reachable(x, y, arm)
    return;
end

% ── Law of cosines → θ₂ ──────────────────────────────────────────────────
c2 = (x^2 + y^2 - arm.L1^2 - arm.L2^2) / (2.0 * arm.L1 * arm.L2);
c2 = max(-1.0, min(1.0, c2));   % clamp for floating-point safety at boundaries

% ── Solve both elbow configurations ──────────────────────────────────────
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
        'config',     config_labels{i});
end

sol_eu = results{1};
sol_ed = results{2};
end
