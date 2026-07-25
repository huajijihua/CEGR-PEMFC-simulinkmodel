function metadata = routeA_promote_platform_default_initial_state(modelDir)
% Compatibility entry point for the atomic Current/Power/Voltage promotion.

if nargin < 1 || strlength(string(modelDir)) == 0
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
        'RouteA_GasMixture_Derived');
end
metadata = routeA_promote_platform_default_initial_state_bundle(modelDir);
end
