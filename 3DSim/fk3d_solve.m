function [x, y, z] = fk3d_solve(sol, arm)
%FK3D_SOLVE  Forward kinematics - end-effector Cartesian (x, y, z).
%
%   x = L1*cos(θ₁) + L2*cos(θ₁+θ₂)
%   y = L1*sin(θ₁) + L2*sin(θ₁+θ₂)
%   z = base_lift (from solution)
%
%   Inputs:
%       sol  - joint struct with fields theta1_rad, theta2_rad, z
%       arm  - robot struct with fields L1, L2
%
%   Outputs:
%       x, y, z - end-effector position in mm

t1 = sol.theta1_rad;
t2 = sol.theta2_rad;
x  = arm.L1 * cos(t1) + arm.L2 * cos(t1 + t2);
y  = arm.L1 * sin(t1) + arm.L2 * sin(t1 + t2);
z  = sol.z;
end
