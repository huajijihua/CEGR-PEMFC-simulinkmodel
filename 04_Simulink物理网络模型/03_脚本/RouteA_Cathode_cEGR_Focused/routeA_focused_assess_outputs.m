function result = routeA_focused_assess_outputs(out, model, context, caseCfg)
% Assess focused-model outputs while excluding removed anode purge gates.

result = routeA_assess_electrical_boundary_outputs( ...
    out, model, context, caseCfg);
result.cegrSplit = splitFlowMetrics(result.gasClosure);

% Anode purge is outside the focused model boundary, not a failed behavior.
result.purge = struct( ...
    'observed', false, ...
    'status', "not_applicable_focused_anode_boundary", ...
    'tailEventCount', 0);
result.tailPurgeFree = true;
result.periodicAnode.classification = "not_applicable_focused_anode_boundary";

result.localPassed = result.finiteTail && result.boundaryPassed && ...
    result.cegrPassed && result.saturationPassed && result.lambdaPassed && ...
    result.pressureDirectionPassed && result.areaPassed && ...
    result.compressorRpmLookupPassed && ...
    result.compressorMdotTrackingPassed && result.gasClosurePassed && ...
    result.steadyPassed;
result.passed = result.localPassed;
result.failureCategory = focusedFailureCategory(result);

if isfield(result.tail, 'freshAirApprox_kg_s') && ...
        result.tail.freshAirApprox_kg_s.mean > 1e-12
    result.tail.freshBasisRatio = struct( ...
        'mean', result.tail.egrMdot_kg_s.mean / ...
            result.tail.freshAirApprox_kg_s.mean, ...
        'definition', "m_cegr/m_fresh");
else
    result.tail.freshBasisRatio = struct( ...
        'mean', NaN, 'definition', "m_cegr/m_fresh");
end

result.waterObservations = routeA_focused_water_observations( ...
    out, model, context.tailWindow_s);
result.pressureObservations = routeA_focused_pressure_observations( ...
    out, model, context.tailWindow_s);
result.waterBalance = focusedWaterBalance(result.gasClosure, caseCfg);
result.antiCondensation = routeA_focused_anti_condensation_analysis( ...
    result, result.pressureObservations, result.waterObservations, context);
result.performance = routeA_focused_performance_metrics(result, context);
result.parameterBridge = context.focusedParameterBridge;
result.scope = "focused complete cathode and stack; fixed anode and thermal boundaries";
end

function balance = focusedWaterBalance(gasClosure, caseCfg)
% Keep direct vapor flows separate from Faraday-derived MEA water.

balance = struct( ...
    'schemaVersion', "RouteA_Focused_WaterBalance_v01", ...
    'externalWaterInjectionEnableCommand', NaN, ...
    'meaWaterGenerationFaraday_kg_s', NaN, ...
    'recycleWaterVaporMdot_kg_s', NaN, ...
    'outletWaterVaporMdot_kg_s', NaN, ...
    'mixWaterResidual_kg_s', NaN, ...
    'meaWaterStatus', "not_available", ...
    'recycleWaterVaporStatus', "not_available", ...
    'liquidWaterStatus', "not_implemented_L2_gas_phase_only");

if isfield(caseCfg, 'cathode') && isstruct(caseCfg.cathode) && ...
        isfield(caseCfg.cathode, 'humidifierEnabled')
    balance.externalWaterInjectionEnableCommand = ...
        double(caseCfg.cathode.humidifierEnabled);
end

if ~isstruct(gasClosure)
    return;
end

if isfield(gasClosure, 'o2FaradayConsumption_kg_s') && ...
        isfinite(gasClosure.o2FaradayConsumption_kg_s)
    % 2 H2O are produced for every O2 consumed by the cathode reaction.
    balance.meaWaterGenerationFaraday_kg_s = ...
        1.125 * gasClosure.o2FaradayConsumption_kg_s;
    balance.meaWaterStatus = "derived_from_o2_faraday_consumption";
end

if isfield(gasClosure, 'recycleSpeciesMdot_kg_s') && ...
        numel(gasClosure.recycleSpeciesMdot_kg_s) >= 4
    balance.recycleWaterVaporMdot_kg_s = ...
        gasClosure.recycleSpeciesMdot_kg_s(4);
    balance.recycleWaterVaporStatus = ...
        "measured_post_split_return_branch_gas_phase";
end

if isfield(gasClosure, 'outletSpeciesMdot_kg_s') && ...
        numel(gasClosure.outletSpeciesMdot_kg_s) >= 4
    balance.outletWaterVaporMdot_kg_s = ...
        gasClosure.outletSpeciesMdot_kg_s(4);
end
if isfield(gasClosure, 'h2oMixResidual_kg_s')
    balance.mixWaterResidual_kg_s = gasClosure.h2oMixResidual_kg_s;
end
end

function category = focusedFailureCategory(result)
reasons = strings(1, 0);
if ~result.boundaryPassed
    reasons(end + 1) = "electrical_boundary";
end
if ~result.cegrPassed
    reasons(end + 1) = "cegr_tracking";
end
if ~result.saturationPassed
    reasons(end + 1) = "current_saturation";
end
if ~result.lambdaPassed
    reasons(end + 1) = "oxygen_supply";
end
if ~result.gasClosurePassed
    reasons(end + 1) = "gas_closure";
end
if ~result.pressureDirectionPassed
    reasons(end + 1) = "pressure_direction";
end
if ~result.areaPassed
    reasons(end + 1) = "valve_area";
end
if ~result.compressorRpmLookupPassed
    reasons(end + 1) = "compressor_rpm";
end
if ~result.compressorMdotTrackingPassed
    reasons(end + 1) = "compressor_mdot_tracking";
end
if ~result.steadyPassed
    reasons(end + 1) = "not_steady";
end
category = strjoin(reasons, ";");
end

function split = splitFlowMetrics(gasClosure)
split = struct( ...
    'returnMdot_kg_s', NaN, ...
    'exhaustMdot_kg_s', NaN, ...
    'totalMdot_kg_s', NaN, ...
    'ratioTotalMassBasis', NaN, ...
    'ratioDryBasis', NaN, ...
    'basis', "current_return_plus_exhaust_branch_total_mass_flow", ...
    'dryBasisStatus', "not_available_branch_species", ...
    'status', "current_branch_flow_post_separator_unverified");

if ~isstruct(gasClosure) || ...
        ~isfield(gasClosure, 'recycleMdot_kg_s') || ...
        ~isfield(gasClosure, 'exhaustMdot_kg_s')
    return;
end

returnMdot = double(gasClosure.recycleMdot_kg_s);
exhaustMdot = double(gasClosure.exhaustMdot_kg_s);
if ~isscalar(returnMdot) || ~isscalar(exhaustMdot) || ...
        ~isfinite(returnMdot) || ~isfinite(exhaustMdot)
    return;
end

totalMdot = returnMdot + exhaustMdot;
split.returnMdot_kg_s = returnMdot;
split.exhaustMdot_kg_s = exhaustMdot;
split.totalMdot_kg_s = totalMdot;
split.basis = "current_return_plus_exhaust_branch_total_mass_flow";
if totalMdot > 1e-12 && returnMdot >= 0 && exhaustMdot >= 0
    split.ratioTotalMassBasis = returnMdot / totalMdot;
    split.status = "current_branch_flow_post_separator_unverified";
end
end
