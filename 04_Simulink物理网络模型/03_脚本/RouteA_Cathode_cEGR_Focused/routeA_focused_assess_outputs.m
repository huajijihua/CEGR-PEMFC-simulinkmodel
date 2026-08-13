function result = routeA_focused_assess_outputs(out, model, context, caseCfg)
% Assess focused-model outputs while excluding removed anode purge gates.

result = routeA_assess_electrical_boundary_outputs( ...
    out, model, context, caseCfg);

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
result.performance = routeA_focused_performance_metrics(result, context);
result.parameterBridge = context.focusedParameterBridge;
result.scope = "focused complete cathode and stack; fixed anode and thermal boundaries";
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
