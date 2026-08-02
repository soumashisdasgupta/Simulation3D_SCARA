function [x, y] = fk_solve_pos(sol, arm)
%FK_SOLVE_POS  Forward kinematics — end-effector Cartesian (x, y).
%
%   x = L1*cos(θ₁) + L2*cos(θ₁+θ₂)
%   y = L1*sin(θ₁) + L2*sin(θ₁+θ₂)
%
%   Inputs:
%       sol  — joint-angle struct with fields theta1_rad, theta2_rad
%       arm  — robot struct with fields L1, L2
%
%   Outputs:
%       x, y — end-effector position in mm

t1 = sol.theta1_rad;
t2 = sol.theta2_rad;
x  = arm.L1 * cos(t1) + arm.L2 * cos(t1 + t2);
y  = arm.L1 * sin(t1) + arm.L2 * sin(t1 + t2);
end
