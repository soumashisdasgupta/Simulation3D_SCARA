function result = is_reachable_3d(x, y, z, arm)
%IS_REACHABLE_3D  True if (x,y,z) lies inside the 3D SCARA reachable workspace.
%
%   WorkSpace shape: Annular Cylinder:
%   Inner dead-zone radius : arm.inner_radius = |L1 - L2|
%   Outer reach radius     : arm.outer_radius = L1 + L2
%   Vertical travel        : arm.z_min <= z <= arm.z_max
%
%   Usage:
%       ok = is_reachable_3d(300, 150, 50, arm);

r_sq = x^2 + y^2;
xy_ok = (arm.inner_radius^2 <= r_sq) && (r_sq <= arm.outer_radius^2);
z_ok  = (z >= arm.z_min) && (z <= arm.z_max);

result = xy_ok && z_ok;
end
