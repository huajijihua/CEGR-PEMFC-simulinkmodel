function routeA_apply_constant_current_step(model, initialCurrentA, targetCurrentA)
% Apply an explicit constant-current scenario after selecting an operating point.
%
% initialCurrentA holds the command compatible with the saved state until the
% 0.5 s step. targetCurrentA is a study input and may differ from the saved
% state's provenance current.

validateattributes(initialCurrentA, {'numeric'}, {'scalar', 'real', ...
    'finite', 'nonnegative'}, mfilename, 'initialCurrentA');
validateattributes(targetCurrentA, {'numeric'}, {'scalar', 'real', ...
    'finite', 'nonnegative'}, mfilename, 'targetCurrentA');

loadPath = Simulink.ID.getFullName([model ':368']);
stepPath = Simulink.ID.getFullName([model ':878']);
set_param(loadPath, 'input_type', 'Step');
set_param(stepPath, ...
    'Time', '0.5', ...
    'Before', sprintf('%.16g', initialCurrentA), ...
    'After', sprintf('%.16g', targetCurrentA));
end
