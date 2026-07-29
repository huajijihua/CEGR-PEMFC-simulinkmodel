function app = launch_routeA_panel()
% Start the Route A panel from any MATLAB current folder.
%
% This is the supported user entry point. It resolves paths from its own
% location, performs dependency and model-contract checks, and only then
% creates the existing programmatic panel.

paths = routeA_project_paths(mfilename('fullpath'));
addpath(paths.scriptDir);
addpath(paths.modelDir);

dependencyReport = routeA_check_dependencies(paths, true);
if ~dependencyReport.passed
    error('RouteA:DependencyCheckFailed', '%s', ...
        strjoin(cellstr(dependencyReport.errors), newline));
end

[~, contractReport] = routeA_model_contract(paths, ...
    struct('loadModel', true, 'strict', true));
if ~contractReport.passed
    error('RouteA:ModelContractCheckFailed', '%s', ...
        strjoin(cellstr(contractReport.errors), newline));
end

app = RouteA_Panel_v01();
end
