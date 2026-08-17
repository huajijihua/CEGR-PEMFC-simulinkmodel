function paths = routeA_focused_paths(modelId)
% Return paths for the focused cathode-cEGR study asset.

if nargin < 1 || strlength(string(modelId)) == 0
    modelId = "focused_legacy";
end
modelId = lower(string(modelId));

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_Cathode_cEGR_Focused');
sharedScriptDir = fullfile(scriptDir, '..', 'RouteA_GasMixture_Derived');
switch modelId
    case "focused_legacy"
        modelName = 'PEMFuelCellSystem_Cathode_cEGR_Focused_v01';
    case "self_humidifying"
        modelName = 'PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01';
    case "ejector_self_humidifying"
        modelName = 'PEMFuelCellSystem_Cathode_cEGR_Ejector_SelfHumidifying_v01';
    case "external_membrane_humidifier"
        modelName = 'PEMFuelCellSystem_Cathode_cEGR_ExternalMembraneHumidifier_v01';
    otherwise
        error('RouteA:FocusedModelId', ...
            'Unsupported focused modelId: %s.', modelId);
end

paths = struct();
paths.modelId = modelId;
paths.modelName = string(modelName);
paths.modelDir = string(modelDir);
paths.modelFile = string(fullfile(modelDir, [modelName '.slx']));
paths.sharedScriptDir = string(sharedScriptDir);
if modelId == "ejector_self_humidifying"
    paths.sourceModelName = ...
        "PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01";
else
    paths.sourceModelName = ...
        "PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01";
end
paths.sourceModelFile = string(fullfile( ...
    modelDir, '..', 'RouteA_GasMixture_Derived', ...
    [char(paths.sourceModelName) '.slx']));
paths.parameterFunction = "routeA_focused_parameter_defaults";
paths.runner = "run_routeA_focused_study";
end
