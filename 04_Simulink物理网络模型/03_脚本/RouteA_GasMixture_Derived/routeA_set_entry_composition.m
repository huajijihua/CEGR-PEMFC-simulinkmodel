function in = routeA_set_entry_composition(in, model, o2MoleFrac, h2oMoleFrac)
% Set cathode entry gas composition for a SimulationInput.
%
% Controls the Air Intake Reservoir (FC) y0 parameter via workspace variables
% env_yO2 and env_yH20.
%
% Usage:
%   in = routeA_set_entry_composition(in, modelName, 0.18, 0.03);
%   % --> O2=18%, H2O=3%, balance N2=79%
%
% Default values (fresh air at 20C, 50% RH):
%   env_yO2  = 0.21
%   env_yH20 = 0.0115436377169313
%
% Inputs:
%   in          - Simulink.SimulationInput to modify
%   model       - Model name string
%   o2MoleFrac  - O2 mole fraction [0, 1], e.g. 0.18 for 18% O2
%   h2oMoleFrac - H2O mole fraction [0, 1], e.g. 0.03 for 3% H2O
%
% Notes:
%   - N2 mole fraction is computed as 1 - o2MoleFrac - h2oMoleFrac
%   - H2 mole fraction is fixed at 0 (cathode side)
%   - The composition is set at compile time, not during simulation
%   - For anode side: use tank_yH2 variable instead

% Validate
validateattributes(o2MoleFrac, {'numeric'}, {'scalar', 'nonnegative', '<=', 1});
validateattributes(h2oMoleFrac, {'numeric'}, {'scalar', 'nonnegative', '<=', 1});
if o2MoleFrac + h2oMoleFrac > 1
    error('RouteA:EntryComposition', ...
        'Sum of O2 (%g) and H2O (%g) exceeds 1.', o2MoleFrac, h2oMoleFrac);
end

% Set workspace variables
in = in.setVariable('env_yO2', o2MoleFrac, 'Workspace', char(model));
in = in.setVariable('env_yH20', h2oMoleFrac, 'Workspace', char(model));

% Also update the 22-column profile fields for consistency
% (col 3 = cathode_source_o2, col 4 = cathode_source_h2o)
% This is done via the routeA_command_profile variable in the runner script
% The profile Goto blocks are terminated, but maintaining consistency is good practice

end