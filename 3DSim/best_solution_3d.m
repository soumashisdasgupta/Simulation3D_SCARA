function sol = best_solution_3d(x, y, z, arm)
%BEST_SOLUTION_3D  Return the preferred IK solution for a given target (x, y, z).
%
%   Policy: elbow-up is preferred; fall back to elbow-down when elbow-up
%   violates joint limits or the target is unreachable.
%
%   Returns [] if both solutions are infeasible.

[sol_eu, sol_ed] = ik3d_solve(x, y, z, arm);
if ~isempty(sol_eu)
    sol = sol_eu;
else
    sol = sol_ed;   % may also be [] if both infeasible
end
end
