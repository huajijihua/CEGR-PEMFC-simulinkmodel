function paths = routeA_block_paths(model)
% Return the stable Route A block paths after A10.2 hierarchy closure.
% Keep model-facing paths here so audit scripts do not encode layout details.

paths = struct();
paths.model = model;

paths.stack = [model '/Stack_Core'];
paths.cathodeAir = [model '/Cathode_Air_cEGR_BOP'];
paths.cathodeExhaust = [model '/Cathode_Exhaust_Backpressure_Water'];
paths.anode = [model '/Anode_Hydrogen_BOP'];
paths.thermal = [model '/Thermal_Management_BOP'];
paths.control = [model '/System_Control_Observability'];
paths.fcu = [paths.control '/FCU_BoP_Control'];
paths.measurements = [paths.control '/Measurements'];
paths.electricalLoad = [paths.control '/Electrical Load'];
paths.currentDemand = [paths.electricalLoad '/Inputs/Current Demand'];
paths.currentCommand = [paths.currentDemand '/Current Demand'];
paths.powerDemand = [paths.electricalLoad '/Inputs/Power Demand'];
paths.powerCommand = [paths.powerDemand '/From Workspace'];
paths.voltageDemand = [paths.electricalLoad '/Inputs/Voltage Demand'];
paths.voltageReference = [paths.voltageDemand '/Voltage Reference'];
paths.voltageMeasurement = [paths.voltageDemand '/Voltage Measurement'];
paths.voltageError = [paths.voltageDemand '/Voltage Error'];
paths.voltagePI = [paths.voltageDemand '/Voltage PI'];
paths.voltageRawPID = [paths.voltageDemand '/Raw PI Diagnostic'];
paths.voltageSaturationStatus = [paths.voltageDemand '/Saturation Status'];
paths.voltageCurrentDynamics = [paths.voltageDemand ...
    '/Current Command Dynamics'];
paths.voltageCurrentCommand = [paths.voltageDemand '/Current Command'];
paths.voltageReferenceVariable = 'drive_cycle_voltage';
paths.currentReferenceVariable = 'drive_cycle_current';
paths.powerReferenceVariable = 'drive_cycle_power';
paths.referenceTimeVariable = 'drive_cycle_time';

paths.anodeGas = [paths.stack '/Anode Gas Channels'];
paths.cathodeGas = [paths.stack '/Cathode Gas Channels'];
paths.outletChamber = [paths.stack '/CathodeOutletChamber'];
paths.outletResistance = [paths.stack '/CathodeOutletResistance'];
paths.outletChamberInsulator = [paths.stack ...
    '/CathodeOutletChamberInsulator'];

paths.oxygen = [paths.cathodeAir '/Oxygen Source'];
paths.compressorControl = [paths.oxygen '/Compressor Control'];
paths.airIntake = [paths.oxygen '/Air Intake'];
paths.compressorInletMixer = [paths.oxygen '/CompressorInletMixer'];
paths.compressorInletMixerInsulator = [paths.oxygen ...
    '/CompressorInletMixerInsulator'];
paths.compressor = [paths.oxygen '/Compressor'];
paths.compressorVolume = [paths.oxygen '/Compressor Volume'];
paths.oxygenMassFlowSensor = [paths.oxygen ...
    '/Mass Flow Rate Sensor (FC)'];
paths.intercooler = [paths.oxygen '/Intercooler_L2_Interface'];
paths.compressorFlowConverter = [paths.oxygen '/PS-Simulink Converter'];
paths.compressorInletPressureConverter = [paths.oxygen '/CompInletP_Converter'];
paths.compressorInletTemperatureConverter = [paths.oxygen ...
    '/CompInletT_Converter'];
paths.compressorInletCompositionConverter = [paths.oxygen ...
    '/CompInletYi_Converter'];
paths.compressorInletDiagnostics = [paths.oxygen '/CompInletDiagnostics'];
paths.compressorCommandSwitch = [paths.compressorControl ...
    '/A98_CompressorCmd_ModeSwitch'];
paths.compressorRpmCommand = [paths.compressorControl ...
    '/A98_CompressorRpmCmd'];
paths.airControlError = [paths.compressorControl '/Sum'];
paths.airMdotSetSwitch = [paths.compressorControl ...
    '/A98_MdotSet_ModeSwitch'];
paths.oerSetpoint = [paths.oxygen '/Oxygen Excess Ratio'];
paths.cathodeHumidifier = [paths.cathodeAir '/Cathode Humidifier'];
paths.cathodeRHSetpoint = [paths.cathodeHumidifier '/Relative Humidity'];
paths.cathodeHumidifierBypass = [paths.cathodeHumidifier ...
    '/CathodeHumidifierBypass'];
paths.cathodeHumidifierConverter = [paths.cathodeHumidifier ...
    '/PS-Simulink Converter2'];
paths.cathodeRHInWorkspace = [paths.cathodeHumidifier ...
    '/RH_ca_in_ToWorkspace'];

paths.egrValve = [paths.cathodeAir '/EGRValveRestriction'];
paths.egrValveClosed = [paths.egrValve '/Closed'];
paths.egrValveOpen = [paths.egrValve '/Open'];
paths.egrPipe = [paths.cathodeAir '/EGRPipe'];
paths.egrValveUpSensor = [paths.cathodeAir '/EGRValveUpPTSensor'];
paths.egrValveUpReference = [paths.cathodeAir '/EGRValveUpPTRef'];
paths.egrValveDownSensor = [paths.cathodeAir '/EGRValveDownPTSensor'];
paths.egrValveDownReference = [paths.cathodeAir '/EGRValveDownPTRef'];
paths.egrValveUpPConverter = [paths.cathodeAir '/EGRValveUpP_Converter'];
paths.egrValveDownPConverter = [paths.cathodeAir ...
    '/EGRValveDownP_Converter'];

paths.cathodeExhaustBlock = [paths.cathodeExhaust '/Cathode Exhaust'];
paths.egrMassFlowSensor = [paths.cathodeExhaust '/EGRMassFlowSensor'];
paths.egrMassFlowConverter = [paths.cathodeExhaust '/EGR_mdot_Converter'];
paths.exhaustMassFlowSensor = [paths.cathodeExhaust ...
    '/ExhaustMassFlowSensor'];
paths.exhaustMassFlowConverter = [paths.cathodeExhaust ...
    '/Exhaust_mdot_Converter'];
paths.outletHumiditySensor = [paths.cathodeExhaust ...
    '/OutletHumiditySensor'];
paths.outletPConverter = [paths.cathodeExhaust '/OutletP_Converter'];
paths.outletRHConverter = [paths.cathodeExhaust '/OutletRH_Converter'];
paths.outletTConverter = [paths.cathodeExhaust '/OutletT_Converter'];
paths.outletYiConverter = [paths.cathodeExhaust '/OutletYi_Converter'];
paths.separatorObserver = [paths.cathodeExhaust '/SeparatorOrCondensation'];
paths.waterSepWorkspace = [paths.control '/WaterSep_ToWorkspace'];
paths.rhOutWorkspace = [paths.control '/RH_ca_out_ToWorkspace'];
paths.exhaustMdotWorkspace = [paths.control '/Exhaust_mdot_ToWorkspace'];
paths.exhaustDiagnostics = [paths.control '/RouteA_ExhaustMdot_Diagnostics'];
paths.egrDiagnostics = [paths.control '/RouteA_cEGRMdot_Diagnostics'];
paths.pressureChainDiagnostics = [paths.control ...
    '/RouteA_PressureChain_Diagnostics'];
paths.outletPTDiagnostics = [paths.control '/RouteA_CathodeOutlet_PT'];
paths.outletCompositionDiagnostics = [paths.control ...
    '/OutletCompositionDiagnostics'];
paths.outletTemperatureDiagnostics = [paths.control ...
    '/RouteA_CathodeOutlet_PT'];

paths.hydrogenSource = [paths.anode '/Hydrogen Source'];
paths.anodeInletPressureSetpoint = [paths.hydrogenSource '/Stack Pressure'];
paths.anodeWaterSeparator = [paths.anode '/AnodeWaterSeparator_FC'];
paths.anodeExhaust = [paths.anode '/Anode Exhaust'];
paths.recirculation = [paths.anode '/Recirculation'];
paths.anodeRecirculationControl = [paths.recirculation '/Feedforward Control'];
paths.anodeRecirculationBaseCommand = [paths.anodeRecirculationControl '/Constant'];
paths.anodeRecirculationCurrentGain = [paths.anodeRecirculationControl '/Gain'];
paths.anodeHumidifier = [paths.anode '/Anode Humidifier'];
paths.anodeRHSetpoint = [paths.anodeHumidifier '/Relative Humidity'];
paths.anodePurgeRelay = [paths.anodeExhaust '/Relay'];

paths.coolingSystem = [paths.thermal '/Cooling System'];
paths.coolingPump = [paths.coolingSystem '/Pump'];
paths.coolingPumpControl = [paths.coolingSystem '/Pump Control'];
paths.heatDissipation = [paths.thermal '/Heat Dissipation'];
paths.stackTemperature = [paths.coolingSystem '/Stack Temperature'];
end
