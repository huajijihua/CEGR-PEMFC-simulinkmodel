function results = run_pemfc_cegr_core_scenario_audit_v01()
%RUN_PEMFC_CEGR_CORE_SCENARIO_AUDIT_V01 Smoke-test scenarios for the core model.
%   The script drives the Simulink/Simscape model and extracts KPI values
%   from y_main/z_debug. It does not duplicate the plant equations.

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
modelName = "PEMFC_cEGR_Core_Physical_v01";
modelFile = fullfile(projectRoot, "04_Simulink物理网络模型", "01_模型", modelName + ".slx");
paramFile = fullfile(projectRoot, "04_Simulink物理网络模型", "02_参数");

addpath(paramFile);
open_system(modelFile);

scenarioNames = ["no_egr_base", "egr_low", "egr_mid", "bp_sensitivity"];
stopTime = "10";

egrBlock = modelName + "/EGRCmd_NoEGR_Const";
currentBlock = modelName + "/Icmd_NoEGR_Const";
exhaustReservoirBlock = modelName + "/CathodeBackPressureExhaust/ExhaustReservoir_FC";
originalEgr = get_param(egrBlock, "Value");
originalCurrent = get_param(currentBlock, "Value");
originalExhaustPressure = get_param(exhaustReservoirBlock, "p0");

cleanup = onCleanup(@() restoreBlocks(egrBlock, originalEgr, ...
    currentBlock, originalCurrent, exhaustReservoirBlock, originalExhaustPressure));

rows = repmat(emptyRow(), numel(scenarioNames), 1);
for idx = 1:numel(scenarioNames)
    P_pemfc_cEGR = PEMFC_cEGR_params_v01(scenarioNames(idx));
    active = P_pemfc_cEGR.active;

    set_param(egrBlock, "Value", num2str(active.egr_valve_cmd, "%.15g"));
    set_param(currentBlock, "Value", num2str(active.i_cmd_A, "%.15g"));
    set_param(exhaustReservoirBlock, "p0", num2str(active.p_exhaust_Pa, "%.15g"));

    simOut = sim(modelName, "StopTime", stopTime, "ReturnWorkspaceOutputs", "on");
    [yLast, zLast] = extractLastOutputs(simOut);

    row = emptyRow();
    row.scenario = scenarioNames(idx);
    row.egr_cmd = active.egr_valve_cmd;
    row.i_cmd_A = active.i_cmd_A;
    row.V_stack_V = yLast(1);
    row.P_load_W = yLast(2);
    row.Q_stack_W = yLast(3);
    row.ca_in_p_Pa = yLast(4);
    row.ca_in_T_K = yLast(5);
    row.ca_in_yO2 = yLast(7);
    row.ca_in_yH2O = yLast(9);
    row.ca_out_p_Pa = yLast(10);
    row.ca_out_T_K = yLast(11);
    row.ca_out_yO2 = yLast(13);
    row.ca_out_yH2O = yLast(15);
    row.egr_mdot_kg_s = yLast(16);
    row.egr_ratio = yLast(17);
    row.T_stack_K = yLast(18);
    row.z_egr_mdot_kg_s = zLast(1);
    row.z_egr_ratio = zLast(2);
    rows(idx) = row;
end

results = struct2table(rows);
disp(results);
end

function row = emptyRow()
row = struct( ...
    "scenario", strings(1), ...
    "egr_cmd", NaN, ...
    "i_cmd_A", NaN, ...
    "V_stack_V", NaN, ...
    "P_load_W", NaN, ...
    "Q_stack_W", NaN, ...
    "ca_in_p_Pa", NaN, ...
    "ca_in_T_K", NaN, ...
    "ca_in_yO2", NaN, ...
    "ca_in_yH2O", NaN, ...
    "ca_out_p_Pa", NaN, ...
    "ca_out_T_K", NaN, ...
    "ca_out_yO2", NaN, ...
    "ca_out_yH2O", NaN, ...
    "egr_mdot_kg_s", NaN, ...
    "egr_ratio", NaN, ...
    "T_stack_K", NaN, ...
    "z_egr_mdot_kg_s", NaN, ...
    "z_egr_ratio", NaN);
end

function [yLast, zLast] = extractLastOutputs(simOut)
yData = simOut.yout.get(1).Values.Data;
zData = simOut.yout.get(2).Values.Data;

if ndims(yData) == 3
    yLast = squeeze(yData(:, 1, end));
else
    yLast = squeeze(yData(end, :)).';
end

if ndims(zData) == 3
    zLast = squeeze(zData(:, 1, end));
else
    zLast = squeeze(zData(end, :)).';
end
end

function restoreBlocks(egrBlock, egrValue, currentBlock, currentValue, ...
    exhaustReservoirBlock, exhaustPressureValue)
set_param(egrBlock, "Value", egrValue);
set_param(currentBlock, "Value", currentValue);
set_param(exhaustReservoirBlock, "p0", exhaustPressureValue);
end
