function sol = best_solution(x, y, arm)
%BEST_SOLUTION  Return the preferred IK solution for a given target (x, y).
%
%   Policy: elbow-up is preferred; fall back to elbow-down when elbow-up
%   violates joint limits or the target is unreachable.
%
%   Returns [] if both solutions are infeasible.

[sol_eu, sol_ed] = ik_solve(x, y, arm);
if ~isempty(sol_eu)
    sol = sol_eu;
else
    sol = sol_ed;   % may also be [] if both infeasible
end
end
