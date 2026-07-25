function routeA_apply_constant_current_step( ...
    model, initialCurrentA, targetCurrentA, stepTime_s)
% Apply a legacy constant-current step through the Current profile branch.
%
% initialCurrentA holds the command compatible with the saved state until the
% 0.5 s step. targetCurrentA is a study input and may differ from the saved
% state's provenance current.

if nargin < 4 || isempty(stepTime_s)
    stepTime_s = 0.5;
end

validateattributes(initialCurrentA, {'numeric'}, {'scalar', 'real', ...
    'finite', 'nonnegative'}, mfilename, 'initialCurrentA');
validateattributes(targetCurrentA, {'numeric'}, {'scalar', 'real', ...
    'finite', 'nonnegative'}, mfilename, 'targetCurrentA');
validateattributes(stepTime_s, {'numeric'}, {'scalar', 'real', ...
    'finite', 'nonnegative'}, mfilename, 'stepTime_s');

paths = routeA_block_paths(model);
set_param(paths.electricalLoad, 'input_type', 'Current');
currentPath = paths.currentDemand;
set_param([currentPath '/Current Demand'], 'VariableName', ...
    '[drive_cycle_time, drive_cycle_current]');
mw = get_param(model, 'ModelWorkspace');
finalTime_s = max(stepTime_s, 1);
if stepTime_s == finalTime_s
    mw.assignin('drive_cycle_time', [0; finalTime_s]);
    mw.assignin('drive_cycle_current', [initialCurrentA; targetCurrentA]);
    return;
end
mw.assignin('drive_cycle_time', [0; stepTime_s; finalTime_s]);
mw.assignin('drive_cycle_current', ...
    [initialCurrentA; initialCurrentA; targetCurrentA]);
end
