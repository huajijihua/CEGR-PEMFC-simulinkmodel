function simCase = routeA_simCase_template()
% Return a fully populated simCase template with default values.
%
% The simCase struct is the standard input format for all Route A
% simulation tasks, covering CR3 three elements:
%   (a) initialState  - initial state of gas paths and stack
%   (b) controls      - electrical boundary, gas path, cEGR, thermal
%   (c) solver        - solver configuration
%
% Usage:
%   simCase = routeA_simCase_template();
%   simCase.caseId = 'my_case';
%   simCase.controls.electrical.mode = 'Power';
%   simCase.controls.electrical.profile = 40;
%   simCase = routeA_validate_case(simCase);  % fill defaults + validate
%
% See also: routeA_validate_case

%#ok<*NASGU>  % template file, intentional unused assignments

%% (a) 初始状态
initialState = struct(...
    'mode', 'cold', ...               % 'cold' | 'warm' | 'hot'
    'source', '', ...                  % 初态文件路径（warm/hot 时使用）
    'temperature_C', 20, ...           % 冷态初始温度 [degC]
    'pressure_MPa_abs', 0.101325, ...  % 冷态初始压力 [MPa(abs)]
    'o2MoleFraction', 0.21, ...        % 冷态初始 O2 分数
    'h2oMoleFraction', 0.0115436, ...  % 冷态初始 H2O 分数
    'h2MoleFraction', 0.9997           % 冷态初始 H2 分数
);

%% (b) 控制设置
% 电边界控制
electrical = struct(...
    'mode', 'Current', ...             % 'Current' | 'Power' | 'Voltage'
    'profile', [], ...                 % 标量或 Nx2 矩阵 [t, value]
    'voltageController', []            % Voltage 模式 PI 参数（可选）
);

% Voltage 模式 PI 控制器参数（默认值）
voltageController = struct(...
    'Kp_A_V', 1, ...                   % 比例增益 [A/V]
    'Ki_A_V_s', 0.05, ...              % 积分增益 [A/V/s]
    'currentMin_A', 0, ...             % 电流下限 [A]
    'currentMax_A', 392                % 电流上限 [A]
);

% 阴极气路控制
cathode = struct(...
    'airControlMode', 2, ...           % 1=流量/2=OER/3=直接
    'targetOer', 3.0, ...              % 目标 OER
    'targetMdot_kg_s', 0.005, ...      % 目标质量流量 [kg/s]
    'directCommand', 0, ...            % 直接命令
    'sourcePressure_MPa_abs', 0.15, ...% 阴极源压力 [MPa(abs)]
    'sourceTemperature_C', 20, ...     % 阴极源温度 [degC]
    'outletPressure_MPa_abs', 0.1613,...% 阴极出口压力/背压 [MPa(abs)]
    'humidifierRH', 0.9, ...           % 加湿器设定 RH
    'humidifierEnabled', 1             % 加湿器启用 [0/1]
);

% cEGR 控制
cegr = struct(...
    'enabled', true, ...               % cEGR 启用
    'targetRatio', 0, ...              % 目标 cEGR 比
    'valveMode', 1, ...                % 阀模式 [1=开度/2=压力]
    'controlMode', 1, ...              % 控制模式
    'targetInputMode', 1               % 目标输入模式
);

% 阳极控制
anode = struct(...
    'sourcePressure_MPa_abs', 0.3, ... % 氢源压力 [MPa(abs)]
    'sourceTemperature_C', 20, ...     % 氢源温度 [degC]
    'inletPressure_MPa_abs', 0.15, ... % 阳极入口压力 [MPa(abs)]
    'humidifierRH', 0.5, ...           % 阳极加湿 RH
    'recirculationBaseCommand', 0, ... % 回流基础命令
    'recirculationCurrentGain_A_inv', 0, ... % 回流电流增益 [1/A]
    'purgeEnabled', 0, ...             % 吹扫启用 [0/1]
    'purgeOnN2MoleFraction', 0.1, ...  % 吹扫开启 N2 阈值
    'purgeOffN2MoleFraction', 0.05     % 吹扫关闭 N2 阈值
);

% 热管理控制
thermal = struct(...
    'stackTemperatureSet_C', 80        % 堆温设定 [degC]
);

% 环境/边界条件
environment = struct(...
    'ambientPressure_MPa_abs', 0.101325, ... % 环境压力 [MPa(abs)]
    'ambientTemperature_C', 20, ...          % 环境温度 [degC]
    'o2MoleFraction', 0.21, ...              % 环境 O2 分数 [-] -> env_yO2
    'h2oMoleFraction', 0.0115436, ...        % 环境 H2O 分数 [-] -> env_yH20
    'h2MoleFraction', 0.9997                 % 阳极 H2 分数 [-] -> tank_yH2
);

% 组合 controls
controls = struct(...
    'electrical', electrical, ...
    'cathode', cathode, ...
    'cegr', cegr, ...
    'anode', anode, ...
    'thermal', thermal, ...
    'environment', environment ...
);

%% (c) 求解器设置
solver = struct(...
    'stopTime_s', 600, ...             % 仿真时长 [s]
    'solver', 'VariableStepAuto', ...  % 求解器类型
    'relTol', 1e-3, ...                % 相对容差
    'absTol', 1e-3, ...                % 绝对容差
    'maxStep_s', 5, ...                % 最大步长 [s]
    'signalLogging', 'on', ...         % 信号日志
    'signalLoggingName', 'logsout', ...% 日志名称
    'simscapeLogType', 'all', ...      % Simscape 日志类型
    'returnWorkspaceOutputs', 'on', ...% 返回工作区输出
    'saveOperatingPoint', 'off', ...   % 保存 operating point
    'operatingPointFile', ''           % 保存路径
);

%% 组合顶层 simCase
simCase = struct(...
    'caseId', '', ...
    'description', '', ...
    'initialState', initialState, ...
    'controls', controls, ...
    'solver', solver ...
);

end