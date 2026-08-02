function [x, y] = fk_elbow_pos(sol, arm)
%FK_ELBOW_POS  Forward kinematics — elbow joint Cartesian (x, y).
%
%   x = L1 * cos(θ₁)
%   y = L1 * sin(θ₁)
%
%   Inputs:
%       sol  — joint-angle struct with field theta1_rad
%       arm  — robot struct with field L1
%
%   Outputs:
%       x, y — elbow position in mm

x = arm.L1 * cos(sol.theta1_rad);
y = arm.L1 * sin(sol.theta1_rad);
end
