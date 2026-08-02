function result = is_reachable(x, y, arm)
%IS_REACHABLE  True if (x,y) lies inside the SCARA reachable workspace annulus.
%
%   Inner dead-zone radius : arm.inner_radius = |L1 - L2|
%   Outer reach radius     : arm.outer_radius = L1 + L2
%
%   Usage:
%       ok = is_reachable(300, 150, arm);

r_sq = x^2 + y^2;
result = (arm.inner_radius^2 <= r_sq) && (r_sq <= arm.outer_radius^2);
end
