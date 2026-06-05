function P = prepare_vehicle_10kw_gzs60_v3_model_run(modelName)
%PREPARE_VEHICLE_10KW_GZS60_V3_MODEL_RUN Initialize model workspace for UI Run.
%
% Simulink direct Run resolves variables from the model workspace before the
% base workspace. This helper refreshes the model workspace so saved stale
% parameter vectors do not shadow the current calibrated vectors.

if nargin < 1 || strlength(string(modelName)) == 0
    modelName = bdroot;
else
    modelName = char(modelName);
end

scriptDir = fileparts(mfilename('fullpath'));
if ~contains(path, scriptDir)
    addpath(scriptDir);
end

P = init_vehicle_10kw_gzs60_v3("current");
mw = get_param(modelName, 'ModelWorkspace');

assignin(mw, 'P_v2', P);
assignin(mw, 'EnvParam_v2', P.EnvParam);
assignin(mw, 'CompressorParam_v2', P.CompressorParam);
assignin(mw, 'IntercoolerParam_v2', P.IntercoolerParam);
assignin(mw, 'HumidifierParam_v2', P.HumidifierParam);
assignin(mw, 'StackParam_v2', P.StackParam);
assignin(mw, 'SeparatorParam_v2', P.SeparatorParam);
assignin(mw, 'TailGasParam_v2', P.TailGasParam);
assignin(mw, 'EGRValveParam_v2', P.EGRValveParam);
assignin(mw, 'BackPressureValveParam_v2', P.BackPressureValveParam);
assignin(mw, 'EGRReturnPipeParam_v2', P.EGRReturnPipeParam);
assignin(mw, 'I_stack_cmd_A', P.I_stack_default_A);
assignin(mw, 'egr_fraction_cmd', 0.0);
assignin(mw, 'EGRInitialNode_v2', P.egr_initial_node);
assignin(mw, 'WetInitialNode_v2', P.wet_initial_node);
assignin(mw, 'StackInitialState_v2', P.stack_initial_state);
assignin(mw, 'StackInitialStateAudit_v3', P.stack_initial_state_audit);
assignin(mw, 'CathodeOutletManifoldParam_v3', P.CathodeOutletManifoldParam);
assignin(mw, 'AnodeOutletManifoldParam_v3', P.AnodeOutletManifoldParam);
assignin(mw, 'CathodeOutletManifoldInitialState_v3', P.ca_manifold_initial_state);
assignin(mw, 'AnodeOutletManifoldInitialState_v3', P.an_manifold_initial_state);
assignin(mw, 'TailGasManifoldInitialState_v3', P.tailgas_manifold_initial_state);
assignin(mw, 'AnodeTailDownstreamPressure_v3', P.p_anode_tail_downstream_kPa);

fprintf('Prepared %s model workspace for direct Run. StackParam_v2 length = %d.\n', ...
    modelName, numel(P.StackParam));
end
