function matrix = routeA_p1_panel_capability_matrix(paths)
% Return the executable P1 panel/model capability matrix.
%
% The parameter and observation registries own names, units, status, and
% validation metadata. This matrix adds the panel property, simCase path,
% SimulationInput write point, result path, and next-stage ownership.

if nargin < 1 || isempty(paths)
    paths = routeA_project_paths();
end

parameterRegistry = routeA_parameter_registry(paths);
observationRegistry = routeA_observation_registry(paths);
activeMask = arrayfun(@(entry) entry.status == "active", ...
    parameterRegistry.entries);
activeEntries = parameterRegistry.entries(activeMask);

parameterTemplate = struct( ...
    'domain', "", 'canonicalName', "", 'displayName', "", ...
    'uiProperty', "", 'panelExposure', "", 'simCasePath', "", ...
    'writePath', "", 'runtimeOrCompileTime', "", 'applyAction', "", ...
    'unit', "", 'validationGate', "", 'observationLinks', strings(0, 1), ...
    'status', "", 'trustStatus', "pending_audit", ...
    'modelWorkspaceVariable', "", 'blockParameter', "", ...
    'owner', "", 'nextPhase', "", ...
    'unresolvedReason', "", 'defaultText', "");
parameters = repmat(parameterTemplate, numel(activeEntries), 1);
for idx = 1:numel(activeEntries)
    entry = activeEntries(idx);
    contract = parameterContract(entry.canonicalName);
    parameters(idx).domain = entry.domain;
    parameters(idx).canonicalName = entry.canonicalName;
    parameters(idx).displayName = entry.displayName;
    parameters(idx).uiProperty = contract.uiProperty;
    parameters(idx).panelExposure = entry.panelExposure;
    parameters(idx).simCasePath = contract.simCasePath;
    parameters(idx).writePath = contract.writePath;
    parameters(idx).runtimeOrCompileTime = contract.runtimeOrCompileTime;
    parameters(idx).applyAction = entry.applyAction;
    parameters(idx).unit = entry.unit;
    parameters(idx).validationGate = entry.validationGate;
    parameters(idx).observationLinks = contract.observationLinks;
    parameters(idx).status = "mapped";
    parameters(idx).trustStatus = "pending_audit";
    parameters(idx).modelWorkspaceVariable = entry.modelWorkspaceVariable;
    parameters(idx).blockParameter = entry.blockParameter;
    parameters(idx).owner = "RouteA_P1";
    parameters(idx).nextPhase = "P1";
    parameters(idx).unresolvedReason = contract.unresolvedReason;
    parameters(idx).defaultText = valueText(entry.defaultValue);
end

observationTemplate = struct( ...
    'domain', "", 'canonicalName', "", 'displayName', "", ...
    'signalName', "", 'unit', "", 'sourceType', "", ...
    'producerPath', "", 'resultPath', "", 'timeRangeSource', "", ...
    'acceptanceAllowed', false, 'status', "", 'trustStatus', "pending_audit", ...
    'owner', "", 'nextPhase', "", 'unresolvedReason', "");
observations = repmat(observationTemplate, observationRegistry.count, 1);
for idx = 1:observationRegistry.count
    entry = observationRegistry.entries(idx);
    contract = observationContract(entry.canonicalName);
    observations(idx).domain = entry.domain;
    observations(idx).canonicalName = entry.canonicalName;
    observations(idx).displayName = entry.displayName;
    observations(idx).signalName = entry.signalName;
    observations(idx).unit = entry.unit;
    observations(idx).sourceType = entry.sourceType;
    observations(idx).producerPath = entry.producerPath;
    observations(idx).resultPath = contract.resultPath;
    observations(idx).timeRangeSource = contract.timeRangeSource;
    observations(idx).acceptanceAllowed = false;
    observations(idx).status = entry.status;
    observations(idx).trustStatus = entry.trustStatus;
    if entry.status == "unresolved"
        observations(idx).owner = "RouteA_P3";
        observations(idx).nextPhase = "P3";
        observations(idx).unresolvedReason = entry.unsupportedReason;
    elseif entry.status == "optional"
        observations(idx).owner = "RouteA_P1";
        observations(idx).nextPhase = "P3";
        observations(idx).unresolvedReason = contract.unresolvedReason;
    else
        observations(idx).owner = "RouteA_P1";
        observations(idx).nextPhase = "P1";
        observations(idx).unresolvedReason = contract.unresolvedReason;
    end
end

unresolvedParameterCount = sum(arrayfun(@(entry) ...
    strlength(entry.unresolvedReason) > 0, parameters));
unresolvedObservationCount = sum(arrayfun(@(entry) ...
    entry.status == "unresolved", observations));
resultObservationCount = sum(arrayfun(@(entry) ...
    entry.panelExposure == "result", observationRegistry.entries));
statusOnlyObservationCount = sum(arrayfun(@(entry) ...
    entry.panelExposure == "status_only", observationRegistry.entries));

matrix = struct();
matrix.schemaVersion = "RouteA_P1_Panel_Capability_v01";
matrix.status = "implemented_not_user_approved";
matrix.model = string(paths.modelName);
matrix.modelFile = string(paths.modelFile);
matrix.parameters = parameters;
matrix.observations = observations;
matrix.counts = struct( ...
    'activeParameterCount', numel(parameters), ...
    'legacyPlanBaselineActiveCount', 25, ...
    'extendedP1ControlCount', max(0, numel(parameters) - 25), ...
    'resultObservationCount', resultObservationCount, ...
    'statusOnlyObservationCount', statusOnlyObservationCount, ...
    'unresolvedParameterCount', unresolvedParameterCount, ...
    'unresolvedObservationCount', unresolvedObservationCount);
matrix.gates = struct( ...
    'W0_G0', "matrix_frozen_in_code", ...
    'W1_G1', "panel_single_file_with_domain_shell", ...
    'W2_G2', "ui_to_simCase_to_validation_to_SimulationInput", ...
    'W3_G3', "thermal_humidity_water_capability_explicit", ...
    'W4', "cegr_diagnostic_status_classification", ...
    'W5_G4', "compact_and_full_result_contract", ...
    'W6_G5', "pending_consolidated_runtime_evidence", ...
    'G6', "pending_user_joint_review");
matrix.notes = [ ...
    "The registries define active names and observation status; this matrix defines the panel binding."; ...
    "The current active count is read from the registry. The legacy plan count of 25 is retained for traceability."; ...
    "Unresolved anode and coolant observations remain status-only and are owned by P3."; ...
    "P1 keeps one electrical boundary command and one cEGR target-ratio input path." ];
matrix.generatedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function contract = parameterContract(name)
contract = struct('uiProperty', "", 'simCasePath', "", ...
    'writePath', "", 'runtimeOrCompileTime', "", ...
    'observationLinks', strings(0, 1), 'unresolvedReason', "");
switch string(name)
    case "electrical.mode"
        contract.uiProperty = "BoundaryModeDropDown|AdvancedBoundaryModeDropDown";
        contract.simCasePath = "controls.electrical.mode";
        contract.writePath = "routeA_panel_build_simulation_input -> boundary.type -> electricalLoad.input_type";
        contract.runtimeOrCompileTime = "compile-time block parameter";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case {"electrical.current.profile", "electrical.power.profile", ...
            "electrical.voltage.profile"}
        contract.uiProperty = "BoundaryCommandEditField|AdvancedBoundaryCommandEditField|AdvancedCommandProfileEditField";
        contract.simCasePath = "controls.electrical.profile";
        contract.writePath = "SimulationInput.setVariable(drive_cycle_*); routeA_command_profile";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "electrical.voltageController.Kp_A_V"
        contract.uiProperty = "AdvancedKpEditField";
        contract.simCasePath = "controls.electrical.voltageController.Kp_A_V";
        contract.writePath = "SimulationInput.setVariable(routeA_voltage_pi_Kp)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "electrical.voltageController.Ki_A_V_s"
        contract.uiProperty = "AdvancedKiEditField";
        contract.simCasePath = "controls.electrical.voltageController.Ki_A_V_s";
        contract.writePath = "SimulationInput.setVariable(routeA_voltage_pi_Ki)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "electrical.voltageController.currentMin_A"
        contract.uiProperty = "AdvancedCurrentMinEditField";
        contract.simCasePath = "controls.electrical.voltageController.currentMin_A";
        contract.writePath = "SimulationInput.setVariable(routeA_voltage_current_min_A)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "electrical.voltageController.currentMax_A"
        contract.uiProperty = "AdvancedCurrentMaxEditField";
        contract.simCasePath = "controls.electrical.voltageController.currentMax_A";
        contract.writePath = "SimulationInput.setVariable(routeA_voltage_current_max_A)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "cathode.airControlMode"
        contract.uiProperty = "AirControlModeDropDown|AdvancedAirControlModeDropDown";
        contract.simCasePath = "controls.cathode.airControlMode";
        contract.writePath = "SimulationInput.setVariable(routeA_air_control_mode_id)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["cathode.compressorInletMassFlow"; "cegr.actualRatio"];
    case "cathode.targetOer"
        contract.uiProperty = "OerEditField|AdvancedOerEditField";
        contract.simCasePath = "controls.cathode.targetOer";
        contract.writePath = "routeA_command_profile.air_target_oer";
        contract.runtimeOrCompileTime = "runtime profile";
        % Validate OER at the cathode inlet. RH is a humidification
        % consequence and cannot prove that the OER controller consumed this input.
        contract.observationLinks = ["cathode.inletOxygenStoich"; ...
            "cathode.compressorInletMassFlow"];
    case "cathode.targetMdot_kg_s"
        contract.uiProperty = "TargetMdotEditField|AdvancedTargetMdotEditField";
        contract.simCasePath = "controls.cathode.targetMdot_kg_s";
        contract.writePath = "routeA_command_profile.air_target_mdot_kg_s";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = "cathode.compressorInletMassFlow";
    case "cathode.directCommand"
        contract.uiProperty = "DirectCommandEditField|AdvancedDirectCommandEditField";
        contract.simCasePath = "controls.cathode.directCommand";
        contract.writePath = "routeA_command_profile.air_direct_command";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = "cathode.compressorInletMassFlow";
    case {"cathode.sourcePressure_MPa_abs", "cathode.sourceTemperature_C", ...
            "cathode.outletPressure_MPa_abs", "cathode.humidifierRH", ...
            "cathode.humidifierEnabled"}
        contract.simCasePath = "controls.cathode." + ...
            strrep(string(name), "cathode.", "");
        contract.writePath = "routeA_command_profile.cathode_*";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = ["cathode.compressorInletPressure"; ...
            "cathode.outletPressure"; "cathode.outletTemperature"; ...
            "cathode.inletRelativeHumidity"; "cathode.outletRelativeHumidity"];
        switch string(name)
            case "cathode.sourcePressure_MPa_abs"
                contract.uiProperty = "AdvancedSourcePressureEditField";
            case "cathode.sourceTemperature_C"
                contract.uiProperty = "AdvancedSourceTemperatureEditField";
            case "cathode.outletPressure_MPa_abs"
                contract.uiProperty = "BackpressureEditField|AdvancedBackpressureEditField";
            case "cathode.humidifierRH"
                contract.uiProperty = "HumidifierRHEditField|AdvancedHumidifierRHEditField";
            case "cathode.humidifierEnabled"
                contract.uiProperty = "HumidifierEnabledCheckBox|AdvancedHumidifierEnabledCheckBox";
        end
    case "cathode.o2MoleFraction"
        contract.uiProperty = "AdvancedO2EditField";
        contract.simCasePath = "controls.cathode.o2MoleFraction";
        contract.writePath = "SimulationInput.setVariable(env_yO2)";
        contract.runtimeOrCompileTime = "compile-time model workspace variable";
        contract.observationLinks = ["cathode.inletComposition"; "cathode.inletSpeciesMassFlow"];
    case "cathode.h2oMoleFraction"
        contract.uiProperty = "AdvancedH2OEditField";
        contract.simCasePath = "controls.cathode.h2oMoleFraction";
        contract.writePath = "SimulationInput.setVariable(env_yH20)";
        contract.runtimeOrCompileTime = "compile-time model workspace variable";
        contract.observationLinks = ["cathode.inletComposition"; "cathode.inletRelativeHumidity"];
    case "cegr.enabled"
        contract.uiProperty = "CegrEnabledCheckBox|AdvancedCegrEnabledCheckBox";
        contract.simCasePath = "controls.cegr.enabled";
        contract.writePath = "SimulationInput.setVariable(routeA_cegr_enabled)";
        contract.runtimeOrCompileTime = "compile-time control variable";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.massFlow"];
    case "cegr.targetRatio"
        contract.uiProperty = "CegrRatioEditField|AdvancedCegrRatioEditField";
        contract.simCasePath = "controls.cegr.targetRatio";
        contract.writePath = "routeA_command_profile.cegr_ratio";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.controlError"; "cegr.massFlow"];
    case "cegr.valveMode"
        contract.uiProperty = "ParameterCatalogTable (read-only)";
        contract.simCasePath = "controls.cegr.valveMode (fixed=1)";
        contract.writePath = "SimulationInput.setVariable(routeA_cegr_valve_mode_id=1)";
        contract.runtimeOrCompileTime = "fixed compile-time model variant";
        contract.observationLinks = ["cegr.valveAreaCommand"; ...
            "cegr.valveUpstreamPressure"; "cegr.valveDownstreamPressure"];
    case "cegr.controlMode"
        contract.uiProperty = "AdvancedCegrControlModeDropDown";
        contract.simCasePath = "controls.cegr.controlMode";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_control_mode_id)";
        contract.runtimeOrCompileTime = "compile-time control variable";
        contract.observationLinks = "cegr.controlError";
    case "cegr.targetInputMode"
        contract.uiProperty = "AdvancedCegrTargetInputModeDropDown";
        contract.simCasePath = "controls.cegr.targetInputMode";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_target_input_mode_id)";
        contract.runtimeOrCompileTime = "compile-time control variable";
        contract.observationLinks = "cegr.actualRatio";
    case "cegr.controller.Kp_area"
        contract.uiProperty = "AdvancedCegrKpEditField";
        contract.simCasePath = "controls.cegr.controller.Kp_area";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_control_Kp_area)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.controlError"; ...
            "cegr.valveAreaCommand"];
    case "cegr.controller.Ki_area"
        contract.uiProperty = "AdvancedCegrKiEditField";
        contract.simCasePath = "controls.cegr.controller.Ki_area";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_control_Ki_area)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.controlError"; ...
            "cegr.valveAreaCommand"];
    case "cegr.actuatorTau_s"
        contract.uiProperty = "DeviceCegrActuatorTauEditField";
        contract.simCasePath = "controls.cegr.controller.actuatorTau_s";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_valve_actuator_tau)";
        contract.runtimeOrCompileTime = "compile-time actuator variable";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.massFlow"; ...
            "cegr.valveAreaCommand"];
    case "stack.numCells"
        contract.uiProperty = "DeviceStackNumCellsEditField";
        contract.simCasePath = "controls.stack.numCells";
        contract.writePath = "SimulationInput.setVariable(stack_num_cells)";
        contract.runtimeOrCompileTime = "compile-time stack variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "stack.area_cm2"
        contract.uiProperty = "DeviceStackAreaEditField";
        contract.simCasePath = "controls.stack.area_cm2";
        contract.writePath = "SimulationInput.setVariable(stack_area)";
        contract.runtimeOrCompileTime = "compile-time stack variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "stack.iL_A_cm2"
        contract.uiProperty = "DeviceStackIEditField";
        contract.simCasePath = "controls.stack.iL_A_cm2";
        contract.writePath = "SimulationInput.setVariable(stack_iL)";
        contract.runtimeOrCompileTime = "compile-time stack variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case "stack.io_A_cm2"
        contract.uiProperty = "DeviceStackIoEditField";
        contract.simCasePath = "controls.stack.io_A_cm2";
        contract.writePath = "SimulationInput.setVariable(stack_io)";
        contract.runtimeOrCompileTime = "compile-time stack variable";
        contract.observationLinks = ["stack.current"; "stack.voltage"; "stack.power"];
    case {"device.stack.alpha", "device.stack.meaCp_J_kgK", ...
            "device.stack.meaRho_kg_m3", "device.stack.gdlThickness_um", ...
            "device.stack.membraneThickness_um", ...
            "device.cathode.intercoolerMdotNominal_kg_s", ...
            "device.cathode.intercoolerDpNominal_MPa", ...
            "device.cathode.intercoolerArea_m2", ...
            "device.cathode.intercoolerLaminarFraction", ...
            "device.cathode.separatorMdotNominal_kg_s", ...
            "device.cathode.separatorDpNominal_MPa", ...
            "device.cathode.separatorArea_m2", ...
            "device.cathode.separatorLaminarFraction", ...
            "device.cathode.mixerVolume_L", ...
            "device.cathode.outletChamberVolume_L", ...
            "device.cathode.compressorMap.rpm_TLU", ...
            "device.cathode.compressorMap.p_ratio_TLU", ...
            "device.cathode.compressorMap.mdot_corr_TLU", ...
            "device.cegr.valveMaxArea_m2", "device.cegr.pipeLength_m", ...
            "device.cegr.pipeDiameter_m", "device.cegr.pipeRoughness_m", ...
            "device.cegr.condensationTau_s", ...
            "device.cegr.inletMixerPressure_MPa_abs", ...
            "device.cegr.outletChamberPressure_MPa_abs", ...
            "device.cegr.pipeExtraLength_m", ...
            "device.cegr.pipePressure_MPa_abs", ...
            "device.cegr.valveOpenMinArea_m2", ...
            "device.anode.tankPressure_MPa", "device.anode.tankVolume_L", ...
            "device.anode.tankTemperature_C", ...
            "device.anode.separatorArea_m2", ...
            "device.anode.separatorLaminarFraction", ...
            "device.anode.separatorMdotNominal_kg_s", ...
            "device.anode.separatorDpNominal_MPa", ...
            "device.thermal.coolantGeometry.channelWidth_cm", ...
            "device.thermal.coolantGeometry.numLayers", ...
            "device.thermal.coolantGeometry.numPasses", ...
            "device.thermal.coolantGeometry.tubeDiameter_m", ...
            "device.thermal.radiatorCore.length_m", ...
            "device.thermal.radiatorCore.width_m", ...
            "device.thermal.radiatorCore.height_m", ...
            "device.thermal.radiatorCore.tubeCount", ...
            "device.thermal.radiatorCore.tubeHeight_m", ...
            "device.thermal.radiatorCore.finSpacing_m", ...
            "device.thermal.radiatorCore.finEfficiency", ...
            "device.thermal.radiatorCore.wallThickness_m", ...
            "device.thermal.radiatorCore.density_kg_m3", ...
            "device.thermal.radiatorCore.specificHeat_J_kgK"}
        contract = deviceParameterContract(name);
    case "anode.h2MoleFraction"
        contract.uiProperty = "AnodeH2EditField";
        contract.simCasePath = "controls.anode.h2MoleFraction";
        contract.writePath = ...
            "SimulationInput.setVariable(tank_yH2) + routeA_command_profile.anode_source_h2_mole_fraction";
        contract.runtimeOrCompileTime = "compile-time model workspace variable + runtime profile";
        contract.observationLinks = "anode.inletComposition";
    case "anode.sourcePressure_MPa_abs"
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode.sourcePressure_MPa_abs";
        contract.writePath = "SimulationInput.setVariable(tank_p) when source pressure differs from platform default";
        contract.runtimeOrCompileTime = "pre-simulation Fuel Tank override";
        contract.observationLinks = "anode.sourcePressure";
    case "anode.inletPressure_MPa_abs"
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode.inletPressure_MPa_abs";
        contract.writePath = "routeA_command_profile.anode_inlet_pressure_MPa_abs";
        contract.runtimeOrCompileTime = "runtime pressure-reducer setpoint";
        contract.observationLinks = "anode.inletPressure";
    case "anode.sourceTemperature_C"
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode.sourceTemperature_C";
        contract.writePath = "SimulationInput.setVariable(tank_T)";
        contract.runtimeOrCompileTime = "pre-simulation tank override";
        contract.observationLinks = "anode.sourceTemperature";
    case "anode.humidifierRH"
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode.humidifierRH";
        contract.writePath = "routeA_command_profile.anode_humidifier_rh";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = "anode.inletRelativeHumidity";
    case {"anode.recirculationBaseCommand", "anode.recirculationCurrentGain_A_inv"}
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode." + strrep(string(name), "anode.", "");
        contract.writePath = "routeA_command_profile.anode_recirculation_*";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = "anode.inletPressure";
    case {"anode.purgeEnabled", "anode.purgeOnN2MoleFraction", "anode.purgeOffN2MoleFraction"}
        contract.uiProperty = anodeUiProperty(name);
        contract.simCasePath = "controls.anode." + strrep(string(name), "anode.", "");
        contract.writePath = "routeA_command_profile.anode_purge_*";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = ["anode.purgeState"; "anode.outletComposition"];
    case "thermal.stackTemperatureSet_C"
        contract.uiProperty = ...
            "StackTemperatureEditField|SourceTemperatureEditField|AdvancedStackTemperatureEditField";
        contract.simCasePath = "controls.thermal.stackTemperatureSet_C";
        contract.writePath = "routeA_command_profile.stack_temperature_set_C";
        contract.runtimeOrCompileTime = "runtime profile";
        contract.observationLinks = "stack.temperature";
    case "environment.ambientTemperature_C"
        contract.uiProperty = "AdvancedAmbientTemperatureEditField";
        contract.simCasePath = "controls.environment.ambientTemperature_C";
        contract.writePath = "SimulationInput.setVariable(env_T)";
        contract.runtimeOrCompileTime = "compile-time environment variable";
        contract.observationLinks = ["stack.temperature"; "cathode.outletTemperature"];
    case "environment.ambientPressure_MPa_abs"
        contract.uiProperty = "ParameterCatalogTable (read-only)";
        contract.simCasePath = "controls.environment.ambientPressure_MPa_abs (fixed)";
        contract.writePath = "SimulationInput.setVariable(env_p=platform_default)";
        contract.runtimeOrCompileTime = "fixed compile-time platform boundary";
        contract.observationLinks = ["cathode.compressorInletPressure"; "cathode.outletPressure"];
    case "cathode.airController.Kp"
        contract.uiProperty = "AdvancedAirPidKpEditField";
        contract.simCasePath = "controls.cathode.airController.Kp";
        contract.writePath = "SimulationInput.setVariable(routeA_air_pid_Kp)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["cathode.compressorInletMassFlow"; "stack.power"];
    case "cathode.airController.Ki"
        contract.uiProperty = "AdvancedAirPidKiEditField";
        contract.simCasePath = "controls.cathode.airController.Ki";
        contract.writePath = "SimulationInput.setVariable(routeA_air_pid_Ki)";
        contract.runtimeOrCompileTime = "compile-time controller variable";
        contract.observationLinks = ["cathode.compressorInletMassFlow"; "stack.power"];
    case "cegr.directValveArea_m2"
        contract.uiProperty = "AdvancedCegrDirectAreaEditField";
        contract.simCasePath = "controls.cegr.directValveArea_m2";
        contract.writePath = "SimulationInput.setVariable(routeA_egr_valve_area_direct)";
        contract.runtimeOrCompileTime = "compile-time direct cEGR variable";
        contract.observationLinks = ["cegr.valveAreaCommand"; "cegr.actualRatio"];
    case "cegr.directTargetRatio"
        contract.uiProperty = "AdvancedCegrDirectTargetEditField";
        contract.simCasePath = "controls.cegr.directTargetRatio";
        contract.writePath = "SimulationInput.setVariable(routeA_target_egr_ratio_comp_in)";
        contract.runtimeOrCompileTime = "compile-time direct cEGR variable";
        contract.observationLinks = ["cegr.actualRatio"; "cegr.massFlow"];
    case "solver.stopTime_s"
        contract.uiProperty = "StopTimeEditField|AdvancedStopTimeEditField";
        contract.simCasePath = "solver.stopTime_s";
        contract.writePath = "SimulationInput.setModelParameter(StopTime)";
        contract.runtimeOrCompileTime = "study control";
    case "solver.solver"
        contract.uiProperty = "AdvancedSolverDropDown";
        contract.simCasePath = "solver.solver";
        contract.writePath = "SimulationInput.setModelParameter(Solver)";
        contract.runtimeOrCompileTime = "study control";
    case "solver.relTol"
        contract.uiProperty = "AdvancedRelTolEditField";
        contract.simCasePath = "solver.relTol";
        contract.writePath = "SimulationInput.setModelParameter(RelTol)";
        contract.runtimeOrCompileTime = "study control";
    case "solver.absTol"
        contract.uiProperty = "AdvancedAbsTolEditField";
        contract.simCasePath = "solver.absTol";
        contract.writePath = "SimulationInput.setModelParameter(AbsTol)";
        contract.runtimeOrCompileTime = "study control";
    case "solver.maxStep_s"
        contract.uiProperty = "AdvancedMaxStepEditField";
        contract.simCasePath = "solver.maxStep_s";
        contract.writePath = "SimulationInput.setModelParameter(MaxStep)";
        contract.runtimeOrCompileTime = "study control";
    otherwise
        contract.unresolvedReason = "No P1 UI and SimulationInput mapping is registered for this active parameter.";
end
end

function contract = deviceParameterContract(name)
contract = struct('uiProperty', "", 'simCasePath', "", ...
    'writePath', "", 'runtimeOrCompileTime', "compile-time device variable", ...
    'observationLinks', strings(0, 1), 'unresolvedReason', "");
contract.simCasePath = "controls." + strrep(string(name), "device.", "devices.");
contract.uiProperty = deviceUiProperty(name);
contract.writePath = "SimulationInput.setVariable(" + deviceWorkspaceVariable(name) + ")";
switch string(name)
    case {"device.stack.alpha", "device.stack.meaCp_J_kgK", ...
            "device.stack.meaRho_kg_m3", "device.stack.gdlThickness_um", ...
            "device.stack.membraneThickness_um"}
        contract.observationLinks = ["stack.voltage"; "stack.power"; ...
            "stack.temperature"];
    case {"device.cathode.intercoolerMdotNominal_kg_s", ...
            "device.cathode.intercoolerDpNominal_MPa", ...
            "device.cathode.intercoolerArea_m2", ...
            "device.cathode.intercoolerLaminarFraction", ...
            "device.cathode.separatorMdotNominal_kg_s", ...
            "device.cathode.separatorDpNominal_MPa", ...
            "device.cathode.separatorArea_m2", ...
            "device.cathode.separatorLaminarFraction", ...
            "device.cathode.mixerVolume_L", ...
            "device.cathode.outletChamberVolume_L"}
        contract.observationLinks = ["cathode.compressorInletPressure"; ...
            "cathode.compressorInletMassFlow"; "cathode.outletPressure"];
    case {"device.cathode.compressorMap.rpm_TLU", ...
            "device.cathode.compressorMap.p_ratio_TLU", ...
            "device.cathode.compressorMap.mdot_corr_TLU"}
        contract.writePath = "routeA_validate_compressor_map -> SimulationInput.setVariable(comp_rpm_TLU, comp_p_ratio_TLU, comp_mdot_corr_TLU)";
        contract.runtimeOrCompileTime = "compile-time lookup table, atomic three-array apply";
        contract.observationLinks = ["cathode.compressorInletMassFlow"; ...
            "cathode.compressorInletPressure"; "stack.power"];
    case {"device.cegr.valveMaxArea_m2", "device.cegr.pipeLength_m", ...
            "device.cegr.pipeDiameter_m", "device.cegr.pipeRoughness_m", ...
            "device.cegr.condensationTau_s", ...
            "device.cegr.inletMixerPressure_MPa_abs", ...
            "device.cegr.outletChamberPressure_MPa_abs", ...
            "device.cegr.pipeExtraLength_m", ...
            "device.cegr.pipePressure_MPa_abs", ...
            "device.cegr.valveOpenMinArea_m2"}
        contract.observationLinks = ["cegr.actualRatio"; "cegr.massFlow"; ...
            "cegr.valveAreaCommand"];
        if string(name) == "device.cegr.pipeDiameter_m"
            contract.writePath = ...
                "SimulationInput.setVariable(cegr_pipe_D, cegr_pipe_area=pi*D^2/4)";
        end
    case {"device.anode.tankPressure_MPa", "device.anode.tankVolume_L", ...
            "device.anode.tankTemperature_C", ...
            "device.anode.separatorArea_m2", ...
            "device.anode.separatorLaminarFraction", ...
            "device.anode.separatorMdotNominal_kg_s", ...
            "device.anode.separatorDpNominal_MPa"}
        contract.observationLinks = ["stack.power"; "stack.temperature"];
    case {"device.thermal.coolantGeometry.channelWidth_cm", ...
            "device.thermal.coolantGeometry.numLayers", ...
            "device.thermal.coolantGeometry.numPasses", ...
            "device.thermal.coolantGeometry.tubeDiameter_m", ...
            "device.thermal.radiatorCore.length_m", ...
            "device.thermal.radiatorCore.width_m", ...
            "device.thermal.radiatorCore.height_m", ...
            "device.thermal.radiatorCore.tubeCount", ...
            "device.thermal.radiatorCore.tubeHeight_m", ...
            "device.thermal.radiatorCore.finSpacing_m", ...
            "device.thermal.radiatorCore.finEfficiency", ...
            "device.thermal.radiatorCore.wallThickness_m", ...
            "device.thermal.radiatorCore.density_kg_m3", ...
            "device.thermal.radiatorCore.specificHeat_J_kgK"}
        contract.observationLinks = ["stack.temperature"; "stack.power"];
        if contains(string(name), "radiatorCore.height_m") || ...
                contains(string(name), "radiatorCore.finSpacing_m")
            contract.writePath = "SimulationInput.setVariable(derived radiator air areas and tube equivalent length)";
        end
end
end

function propertyName = deviceUiProperty(name)
switch string(name)
    case "device.stack.alpha", propertyName = "DeviceStackAlphaEditField";
    case "device.stack.meaCp_J_kgK", propertyName = "DeviceStackMcpEditField";
    case "device.stack.meaRho_kg_m3", propertyName = "DeviceStackMrhoEditField";
    case "device.stack.gdlThickness_um", propertyName = "DeviceStackGdlEditField";
    case "device.stack.membraneThickness_um", propertyName = "DeviceStackMembraneEditField";
    case "device.cathode.intercoolerMdotNominal_kg_s", propertyName = "DeviceIntercoolerMdotEditField";
    case "device.cathode.intercoolerDpNominal_MPa", propertyName = "DeviceIntercoolerDpEditField";
    case "device.cathode.intercoolerArea_m2", propertyName = "DeviceIntercoolerAreaEditField";
    case "device.cathode.intercoolerLaminarFraction", propertyName = "DeviceIntercoolerLaminarEditField";
    case "device.cathode.separatorMdotNominal_kg_s", propertyName = "DeviceCathodeSeparatorMdotEditField";
    case "device.cathode.separatorDpNominal_MPa", propertyName = "DeviceCathodeSeparatorDpEditField";
    case "device.cathode.separatorArea_m2", propertyName = "DeviceCathodeSeparatorAreaEditField";
    case "device.cathode.separatorLaminarFraction", propertyName = "DeviceCathodeSeparatorLaminarEditField";
    case "device.cathode.mixerVolume_L", propertyName = "DeviceCathodeMixerVolumeEditField";
    case "device.cathode.outletChamberVolume_L", propertyName = "DeviceCathodeOutletVolumeEditField";
    case {"device.cathode.compressorMap.rpm_TLU", ...
            "device.cathode.compressorMap.p_ratio_TLU", ...
            "device.cathode.compressorMap.mdot_corr_TLU"}
        propertyName = "CompressorMapEditorButton";
    case "device.cegr.valveMaxArea_m2", propertyName = "DeviceCegrValveMaxAreaEditField";
    case "device.cegr.pipeLength_m", propertyName = "DeviceCegrPipeLengthEditField";
    case "device.cegr.pipeDiameter_m", propertyName = "DeviceCegrPipeDEditField";
    case "device.cegr.pipeRoughness_m", propertyName = "DeviceCegrPipeRoughnessEditField";
    case "device.cegr.condensationTau_s", propertyName = "DeviceCegrCondTauEditField";
    case "device.cegr.inletMixerPressure_MPa_abs", propertyName = "DeviceCegrInletMixerP0EditField";
    case "device.cegr.outletChamberPressure_MPa_abs", propertyName = "DeviceCegrOutletP0EditField";
    case "device.cegr.pipeExtraLength_m", propertyName = "DeviceCegrPipeExtraLengthEditField";
    case "device.cegr.pipePressure_MPa_abs", propertyName = "DeviceCegrPipeP0EditField";
    case "device.cegr.valveOpenMinArea_m2", propertyName = "DeviceCegrValveMinAreaEditField";
    case "device.anode.tankPressure_MPa", propertyName = "DeviceAnodeTankPressureEditField";
    case "device.anode.tankVolume_L", propertyName = "DeviceAnodeTankVolumeEditField";
    case "device.anode.tankTemperature_C", propertyName = "DeviceAnodeTankTemperatureEditField";
    case "device.anode.separatorArea_m2", propertyName = "DeviceAnodeSeparatorAreaEditField";
    case "device.anode.separatorLaminarFraction", propertyName = "DeviceAnodeSeparatorLaminarEditField";
    case "device.anode.separatorMdotNominal_kg_s", propertyName = "DeviceAnodeSeparatorMdotEditField";
    case "device.anode.separatorDpNominal_MPa", propertyName = "DeviceAnodeSeparatorDpEditField";
    case "device.thermal.coolantGeometry.channelWidth_cm", propertyName = "DeviceCoolantChannelWidthEditField";
    case "device.thermal.coolantGeometry.numLayers", propertyName = "DeviceCoolantNumLayersEditField";
    case "device.thermal.coolantGeometry.numPasses", propertyName = "DeviceCoolantNumPassesEditField";
    case "device.thermal.coolantGeometry.tubeDiameter_m", propertyName = "DeviceCoolantTubeDEditField";
    case "device.thermal.radiatorCore.length_m", propertyName = "DeviceRadiatorLengthEditField";
    case "device.thermal.radiatorCore.width_m", propertyName = "DeviceRadiatorWidthEditField";
    case "device.thermal.radiatorCore.height_m", propertyName = "DeviceRadiatorHeightEditField";
    case "device.thermal.radiatorCore.tubeCount", propertyName = "DeviceRadiatorTubeCountEditField";
    case "device.thermal.radiatorCore.tubeHeight_m", propertyName = "DeviceRadiatorTubeHeightEditField";
    case "device.thermal.radiatorCore.finSpacing_m", propertyName = "DeviceRadiatorFinSpacingEditField";
    case "device.thermal.radiatorCore.finEfficiency", propertyName = "DeviceRadiatorFinEfficiencyEditField";
    case "device.thermal.radiatorCore.wallThickness_m", propertyName = "DeviceRadiatorWallThicknessEditField";
    case "device.thermal.radiatorCore.density_kg_m3", propertyName = "DeviceRadiatorDensityEditField";
    case "device.thermal.radiatorCore.specificHeat_J_kgK", propertyName = "DeviceRadiatorSpecificHeatEditField";
    otherwise
        error('RouteA:DeviceUiProperty', 'Unknown device UI parameter %s.', name);
end
end

function variable = deviceWorkspaceVariable(name)
switch string(name)
    case "device.stack.alpha", variable = "stack_alpha";
    case "device.stack.meaCp_J_kgK", variable = "stack_mea_cp";
    case "device.stack.meaRho_kg_m3", variable = "stack_mea_rho";
    case "device.stack.gdlThickness_um", variable = "stack_t_gdl";
    case "device.stack.membraneThickness_um", variable = "stack_t_membrane";
    case "device.cathode.intercoolerMdotNominal_kg_s", variable = "intercooler_mdot_nominal";
    case "device.cathode.intercoolerDpNominal_MPa", variable = "intercooler_dp_nominal";
    case "device.cathode.intercoolerArea_m2", variable = "intercooler_area";
    case "device.cathode.intercoolerLaminarFraction", variable = "intercooler_laminar_fraction";
    case "device.cathode.separatorMdotNominal_kg_s", variable = "cathode_separator_mdot_nominal";
    case "device.cathode.separatorDpNominal_MPa", variable = "cathode_separator_dp_nominal";
    case "device.cathode.separatorArea_m2", variable = "cathode_separator_area";
    case "device.cathode.separatorLaminarFraction", variable = "cathode_separator_laminar_fraction";
    case "device.cathode.mixerVolume_L", variable = "comp_inlet_mixer_V";
    case "device.cathode.outletChamberVolume_L", variable = "cathode_outlet_chamber_V";
    case "device.cathode.compressorMap.rpm_TLU", variable = "comp_rpm_TLU";
    case "device.cathode.compressorMap.p_ratio_TLU", variable = "comp_p_ratio_TLU";
    case "device.cathode.compressorMap.mdot_corr_TLU", variable = "comp_mdot_corr_TLU";
    case "device.cegr.valveMaxArea_m2", variable = "cegr_valve_max_area";
    case "device.cegr.pipeLength_m", variable = "cegr_pipe_length";
    case "device.cegr.pipeDiameter_m", variable = "cegr_pipe_D";
    case "device.cegr.pipeRoughness_m", variable = "cegr_pipe_roughness";
    case "device.cegr.condensationTau_s", variable = "cegr_cond_tau";
    case "device.cegr.inletMixerPressure_MPa_abs", variable = "cegr_inlet_mixer_p0";
    case "device.cegr.outletChamberPressure_MPa_abs", variable = "cegr_outlet_chamber_p0";
    case "device.cegr.pipeExtraLength_m", variable = "cegr_pipe_extra_length";
    case "device.cegr.pipePressure_MPa_abs", variable = "cegr_pipe_p0";
    case "device.cegr.valveOpenMinArea_m2", variable = "cegr_valve_open_min_area";
    case "device.anode.tankPressure_MPa", variable = "tank_p";
    case "device.anode.tankVolume_L", variable = "tank_V";
    case "device.anode.tankTemperature_C", variable = "tank_T";
    case "device.anode.separatorArea_m2", variable = "anode_separator_area";
    case "device.anode.separatorLaminarFraction", variable = "anode_separator_laminar_fraction";
    case "device.anode.separatorMdotNominal_kg_s", variable = "anode_separator_mdot_nominal";
    case "device.anode.separatorDpNominal_MPa", variable = "anode_separator_dp_nominal";
    case "device.thermal.coolantGeometry.channelWidth_cm", variable = "coolant_w_channels";
    case "device.thermal.coolantGeometry.numLayers", variable = "coolant_num_layers";
    case "device.thermal.coolantGeometry.numPasses", variable = "coolant_num_passes";
    case "device.thermal.coolantGeometry.tubeDiameter_m", variable = "coolant_tube_D";
    case "device.thermal.radiatorCore.length_m", variable = "radiator_L";
    case "device.thermal.radiatorCore.width_m", variable = "radiator_W";
    case "device.thermal.radiatorCore.height_m", variable = "radiator_air_area_primary";
    case "device.thermal.radiatorCore.tubeCount", variable = "radiator_N_tubes";
    case "device.thermal.radiatorCore.tubeHeight_m", variable = "radiator_tube_H";
    case "device.thermal.radiatorCore.finSpacing_m", variable = "radiator_air_area_fins";
    case "device.thermal.radiatorCore.finEfficiency", variable = "radiator_eta_fin";
    case "device.thermal.radiatorCore.wallThickness_m", variable = "radiator_t_wall";
    case "device.thermal.radiatorCore.density_kg_m3", variable = "radiator_rho";
    case "device.thermal.radiatorCore.specificHeat_J_kgK", variable = "radiator_cp";
    otherwise
        error('RouteA:DeviceContractName', 'Unknown device parameter %s.', name);
end
end

function propertyName = anodeUiProperty(name)
switch string(name)
    case "anode.sourcePressure_MPa_abs"
        propertyName = "AnodeSourcePressureEditField";
    case "anode.sourceTemperature_C"
        propertyName = "AnodeSourceTemperatureEditField";
    case "anode.inletPressure_MPa_abs"
        propertyName = "AnodeInletPressureEditField";
    case "anode.humidifierRH"
        propertyName = "AnodeHumidifierRHEditField";
    case "anode.recirculationBaseCommand"
        propertyName = "AnodeRecirculationBaseEditField";
    case "anode.recirculationCurrentGain_A_inv"
        propertyName = "AnodeRecirculationGainEditField";
    case "anode.purgeEnabled"
        propertyName = "AnodePurgeEnabledCheckBox";
    case "anode.purgeOnN2MoleFraction"
        propertyName = "AnodePurgeOnN2EditField";
    case "anode.purgeOffN2MoleFraction"
        propertyName = "AnodePurgeOffN2EditField";
    otherwise
        propertyName = "";
end
end

function contract = observationContract(name)
contract = struct('resultPath', "", 'timeRangeSource', "", ...
    'unresolvedReason', "");
switch string(name)
    case "stack.current"
        contract.resultPath = "results.domains.stack.current_A";
    case "stack.voltage"
        contract.resultPath = "results.domains.stack.voltage_V";
    case "stack.power"
        contract.resultPath = "results.domains.stack.power_kW";
    case "stack.temperature"
        contract.resultPath = "results.domains.stack.temperature_C";
    case "cathode.compressorInletMassFlow"
        contract.resultPath = "results.domains.cathode.compressorInletMassFlow_kg_s";
    case "cathode.compressorInletPressure"
        contract.resultPath = "results.domains.cathode.compressorInletPressure_Pa";
    case "cathode.compressorInletTemperature"
        contract.resultPath = "results.domains.cathode.compressorInletTemperature_K";
    case "cathode.inletSpeciesMassFlow"
        contract.resultPath = "results.domains.cathode.inletSpeciesMassFlow_kg_s";
    case "cathode.inletOxygenStoich"
        contract.resultPath = "results.domains.cathode.inletOxygenStoich";
    case "anode.inletPressure"
        contract.resultPath = "results.domains.anode.inletPressure_MPa";
    case "anode.sourcePressure"
        contract.resultPath = "results.domains.anode.sourcePressure_MPa";
    case "anode.inletTemperature"
        contract.resultPath = "results.domains.anode.inletTemperature_C";
    case "anode.sourceTemperature"
        contract.resultPath = "results.domains.anode.sourceTemperature_C";
    case "anode.inletComposition"
        contract.resultPath = "results.domains.anode.inletCompositionMoleFraction";
    case "anode.inletRelativeHumidity"
        contract.resultPath = "results.domains.anode.inletRelativeHumidity";
    case "anode.outletComposition"
        contract.resultPath = "results.domains.anode.outletCompositionMoleFraction";
    case "anode.purgeState"
        contract.resultPath = "results.domains.anode.purgeState";
    case "cathode.inletComposition"
        contract.resultPath = "results.domains.cathode.inletCompositionMassFraction";
    case "cathode.outletComposition"
        contract.resultPath = "results.domains.cathode.outletCompositionMassFraction";
    case "cathode.inletRelativeHumidity"
        contract.resultPath = "results.domains.cathode.inletRelativeHumidity";
    case "cathode.outletRelativeHumidity"
        contract.resultPath = "results.domains.cathode.outletRelativeHumidity";
    case "cathode.outletPressure"
        contract.resultPath = "results.domains.cathode.cathodeOutletPressure_MPa";
    case "cathode.outletTemperature"
        contract.resultPath = "results.domains.cathode.cathodeOutletTemperature_K";
    case "cathode.exhaustMassFlow"
        contract.resultPath = "results.observationReport.present[routeA_exhaust_mdot_ts]";
        contract.unresolvedReason = "Optional exhaust mass-flow signal is registered but not a required P1 KPI.";
    case "cathode.waterSeparationRate"
        contract.resultPath = "results.domains.cathode.waterSeparationRate_kg_s";
    case "cegr.actualRatio"
        contract.resultPath = "results.domains.cegr.actualRatio";
    case "cegr.controlError"
        contract.resultPath = "results.domains.cegr.control";
    case "cegr.massFlow"
        contract.resultPath = "results.domains.cegr.massFlow_kg_s";
    case "cegr.valveUpstreamPressure"
        contract.resultPath = "results.domains.cegr.valveUpstreamPressure_Pa";
    case "cegr.valveDownstreamPressure"
        contract.resultPath = "results.domains.cegr.valveDownstreamPressure_Pa";
    case "cegr.valveAreaCommand"
        contract.resultPath = "results.domains.cegr.valveArea_m2";
        contract.unresolvedReason = "Optional valve area command is not required for the P1 acceptance gate.";
    otherwise
        contract.unresolvedReason = "No P1 result field mapping is registered.";
end
if strlength(contract.resultPath) > 0
    contract.timeRangeSource = "signalManifest.timeRange_s from registered source";
end
end

function text = valueText(value)
if ischar(value) || isstring(value)
    text = string(value);
elseif isnumeric(value) && isscalar(value)
    text = string(sprintf('%.12g', double(value)));
elseif islogical(value) && isscalar(value)
    text = string(logical(value));
else
    text = "struct_or_unavailable";
end
end
