function mea = routeA_simscape_log_mea(simlog)
% Return the MEA Simscape log node for the current Route A hierarchy.

if isprop(simlog, 'Stack_Core') && ...
        isprop(simlog.Stack_Core, 'Membrane_Electrode_Assembly')
    mea = simlog.Stack_Core.Membrane_Electrode_Assembly;
    return;
end
if isprop(simlog, 'Membrane_Electrode_Assembly')
    mea = simlog.Membrane_Electrode_Assembly;
    return;
end
error('RouteA:MissingMEAInSimscapeLog', ...
    'Membrane Electrode Assembly was not found in the Simscape log.');
end
