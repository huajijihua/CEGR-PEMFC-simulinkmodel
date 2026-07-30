function [contract, report] = routeA_model_contract(paths, options)
% Build and read back the active Route A model contract.
%
% The contract joins the CR3 input schema, model-facing block paths,
% workspace variables, parameter registry, observation registry, and initial
% state policy. It does not modify or save the model.

if nargin < 1 || isempty(paths)
    paths = routeA_project_paths();
end
if nargin < 2 || isempty(options)
    options = struct();
end
options = fillOptions(options);

model = char(paths.modelName);
blockPaths = routeA_block_paths(model);
profileSchema = routeA_command_profile_schema();

contract = struct();
contract.schemaVersion = "RouteA_Model_Contract_v01";
contract.modelName = string(model);
contract.modelFile = string(paths.modelFile);
contract.parameterLayer = "platform_default";
contract.externalCaseEnabled = false;
contract.blockPaths = blockPaths;
contract.profileSchema = profileSchema;
contract.parameterRegistry = routeA_parameter_registry(paths);
contract.observationRegistry = routeA_observation_registry(paths);
contract.inputs = inputContract();
contract.initialState = struct( ...
    'defaultMode', "cold", ...
    'policy', "cold_start_only", ...
    'historicalBundleStatus', "retired_outside_active_tree", ...
    'historicalBundleFile', string(paths.retiredHotStartBundle), ...
    'legacySourceConditionerContract', false, ...
    'runtimeRule', "Active runs start from model defaults with LoadInitialState=off.", ...
    'assetRule', "Retired operating-point assets are not active inputs or contract checks.");

report = reportTemplate();
report.model = string(model);
report.modelFile = string(paths.modelFile);

if options.loadModel && ~bdIsLoaded(model)
    load_system(paths.modelFile);
end

if options.readBack
    if ~bdIsLoaded(model)
        report = addCheck(report, 'model_loaded', false, 'error', ...
            "The Route A model is not loaded for contract read-back.");
    else
        report = addCheck(report, 'model_loaded', true, 'info', ...
            "The Route A model is loaded.");
        report = checkBlockPaths(report, blockPaths);
        report = checkWorkspaceVariables(report, model, profileSchema);
        report = checkProfileAlignment(report, model, profileSchema);
        report = checkModelWorkspaceSource(report, model, paths);
    end
else
    report = addCheck(report, 'model_read_back', true, 'info', ...
        "Model read-back was disabled by the caller.");
end

report = checkInitialStateStatus(report, paths);
contract.readBack = report;

if options.strict && ~isempty(report.errors)
    report.passed = false;
end
end

function options = fillOptions(options)
defaults = struct('loadModel', true, 'readBack', true, 'strict', true);
names = fieldnames(defaults);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(options, name) || isempty(options.(name))
        options.(name) = defaults.(name);
    end
end
end

function contract = inputContract()
contract = struct();
contract.u = struct( ...
    'electrical', ["I_cmd", "Power", "Voltage"], ...
    'cathode', ["air_flow_cmd", "air_oer_cmd", "air_direct_command", ...
        "p_ca_out_cmd", "RH_ca_cmd"], ...
    'cegr', ["cegr_ratio_cmd", "cegr_valve_cmd"], ...
    'anode', ["p_h2_cmd", "T_h2_cmd", "y_h2_cmd", "recirc_cmd", "purge_cmd"], ...
    'thermal', "T_stack_cmd");
contract.w = ["ambient pressure/temperature", "fixed inlet composition", ...
    "external backpressure", "initial operating condition"];
contract.y = ["stack electrical", "cathode gas", "cEGR", "anode gas", "thermal"];
contract.z = ["species flow", "inventory", "pressure drop", "heat flow", ...
    "conservation residual", "fault state"];
end

function report = checkBlockPaths(report, paths)
required = { ...
    'control', 'fcu', 'measurements', 'electricalLoad', ...
    'currentCommand', 'powerCommand', 'voltageReference', ...
    'voltagePI', 'voltageCurrentCommand'};
optional = { ...
    'airIntake', 'compressor', 'cathodeGas', 'anodeGas', 'egrValve', ...
    'egrPipe', 'coolingSystem'};

for idx = 1:numel(required)
    field = required{idx};
    path = paths.(field);
    exists = getSimulinkBlockHandle(path) > 0;
    report = addCheck(report, "required_block:" + string(field), exists, ...
        'error', "Required Route A block path is unavailable: " + string(path));
end
for idx = 1:numel(optional)
    field = optional{idx};
    path = paths.(field);
    exists = getSimulinkBlockHandle(path) > 0;
    report = addCheck(report, "optional_block:" + string(field), exists, ...
        'warning', "Optional contract block path is unavailable: " + string(path));
end
end

function report = checkWorkspaceVariables(report, model, ~)
mw = get_param(model, 'ModelWorkspace');
required = { ...
    'routeA_command_profile_fields', ...
    'routeA_command_profile_baseline', ...
    'routeA_air_control_mode_id', ...
    'routeA_cegr_enabled', ...
    'routeA_cegr_valve_mode_id', ...
    'routeA_egr_control_mode_id', ...
    'routeA_egr_target_input_mode_id', ...
    'routeA_egr_control_Kp_area', ...
    'routeA_egr_control_Ki_area', ...
    'routeA_egr_valve_actuator_tau', ...
    'stack_num_cells', ...
    'stack_area', ...
    'stack_iL', ...
    'stack_io', ...
    'env_yO2', ...
    'env_yH20'};
for idx = 1:numel(required)
    name = required{idx};
    [exists, detail] = modelWorkspaceVariableExists(mw, name);
    report = addCheck(report, "workspace_variable:" + string(name), ...
        exists, 'error', detail);
end

% PI variables are required by the Voltage branch and are reported as errors
% because the current panel supports Voltage mode.
voltageVariables = { ...
    'routeA_voltage_pi_Kp', ...
    'routeA_voltage_pi_Ki', ...
    'routeA_voltage_current_min_A', ...
    'routeA_voltage_current_max_A'};
for idx = 1:numel(voltageVariables)
    name = voltageVariables{idx};
    [exists, detail] = modelWorkspaceVariableExists(mw, name);
    report = addCheck(report, "voltage_workspace_variable:" + string(name), ...
        exists, 'error', detail);
end
end

function report = checkProfileAlignment(report, model, schema)
    mw = get_param(model, 'ModelWorkspace');
    fields = mw.getVariable('routeA_command_profile_fields');
    fields = string(fields(:));
    expected = string(schema.names(:));
    baseline = mw.getVariable('routeA_command_profile_baseline');
    baseline = double(baseline(:));
    aligned = isequal(fields, expected) && numel(baseline) == schema.count && ...
        all(isfinite(baseline));
    report = addCheck(report, 'command_profile_alignment', aligned, 'error', ...
        "The model workspace command-profile fields and baseline do not match the active schema.");
    if aligned
        params = routeA_platform_default_parameters();
        criticalNames = ["air_target_oer"; ...
            "cathode_outlet_pressure_MPa_abs"];
        criticalValues = [params.controls.target_oer.value; ...
            params.controls.backpressure_MPa_abs.value];
        for idx = 1:numel(criticalNames)
            fieldIndex = find(fields == criticalNames(idx), 1);
            matches = ~isempty(fieldIndex) && ...
                abs(baseline(fieldIndex) - criticalValues(idx)) <= ...
                1e-12 * max([1, abs(criticalValues(idx))]);
            if matches
                detail = "The active command-profile baseline matches platform_default for " + ...
                    criticalNames(idx) + ".";
            else
                detail = "The active command-profile baseline does not match platform_default for " + ...
                    criticalNames(idx) + ".";
            end
            report = addCheck(report, ...
                "platform_default_baseline:" + criticalNames(idx), ...
                matches, 'error', detail);
        end
    end
end

function report = checkModelWorkspaceSource(report, model, paths)
mw = get_param(model, 'ModelWorkspace');
source = string(mw.DataSource);
report = addCheck(report, 'model_workspace_source', source == "MATLAB File", ...
    'warning', "The model workspace is not using its MATLAB source file.");
sourceExists = isfile(paths.modelWorkspaceSource);
report = addCheck(report, 'model_workspace_source_files', sourceExists, ...
    'error', "The model workspace MATLAB source file is missing.");
end

function report = checkInitialStateStatus(report, ~)
% Operating-point files are retired assets. Their presence or absence must not
% change the active cold-start contract or create a preflight warning.
report = addCheck(report, 'initialization_policy', true, 'info', ...
    "Active Route A initialization is cold_start_only; retired hot-start assets are outside the active contract.");
end

function [exists, detail] = modelWorkspaceVariableExists(mw, name)
try
    mw.getVariable(name);
    exists = true;
    detail = "";
catch
    exists = false;
    detail = "Required model workspace variable is unavailable: " + string(name);
end
end

function report = addCheck(report, name, passed, severity, detail)
check = struct( ...
    'name', string(name), ...
    'passed', logical(passed), ...
    'severity', string(severity), ...
    'detail', string(detail));
report.checks(end + 1) = check;
if ~passed
    if string(severity) == "error"
        report.passed = false;
        report.errors(end + 1, 1) = string(detail);
    elseif string(severity) == "warning"
        report.warnings(end + 1, 1) = string(detail);
    end
end
end

function report = reportTemplate()
report = struct();
report.schemaVersion = "RouteA_Model_Contract_Report_v01";
report.passed = true;
report.model = "";
report.modelFile = "";
report.errors = strings(0, 1);
report.warnings = strings(0, 1);
report.checks = repmat(struct( ...
    'name', "", ...
    'passed', false, ...
    'severity', "", ...
    'detail', ""), 0, 1);
end
