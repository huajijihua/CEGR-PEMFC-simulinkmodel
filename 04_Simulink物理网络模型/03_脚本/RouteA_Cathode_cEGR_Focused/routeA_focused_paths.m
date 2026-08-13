function paths = routeA_focused_paths()
% Return paths for the focused cathode-cEGR study asset.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_Cathode_cEGR_Focused');
sharedScriptDir = fullfile(scriptDir, '..', 'RouteA_GasMixture_Derived');
modelName = 'PEMFuelCellSystem_Cathode_cEGR_Focused_v01';

paths = struct();
paths.modelName = string(modelName);
paths.modelDir = string(modelDir);
paths.modelFile = string(fullfile(modelDir, [modelName '.slx']));
paths.sharedScriptDir = string(sharedScriptDir);
paths.sourceModelName = ...
    "PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01";
paths.sourceModelFile = string(fullfile( ...
    modelDir, '..', 'RouteA_GasMixture_Derived', ...
    [char(paths.sourceModelName) '.slx']));
paths.parameterFunction = "routeA_focused_parameter_defaults";
paths.runner = "run_routeA_focused_study";
end
