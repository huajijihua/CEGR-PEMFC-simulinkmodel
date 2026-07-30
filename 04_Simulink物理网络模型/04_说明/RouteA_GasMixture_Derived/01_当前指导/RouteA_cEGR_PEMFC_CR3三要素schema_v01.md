# Route A cEGR-PEMFC CR3 三要素 Schema 定义

文件类型：规划设计文件（平台输入规范）  
日期：2026-07-27  
版本：v01  
前置文档：[控制接口汇总表](RouteA_cEGR_PEMFC_控制接口汇总表_v01.md)

---

## 1. 总则

CR3 要求每次计算前必须明确三方面内容：
- **(a) 初始状态**：气路和电堆气体状态的初始值
- **(b) 控制设置**：气路和电堆的具体控制设置
- **(c) 求解器设置**：计算求解器设置

本文件定义标准化 `simCase` 结构体作为统一输入格式，涵盖以上三要素。该结构体可被当前脚本直接使用，也为后续面板设计提供输入接口定义。

---

## 2. 顶层结构

```matlab
simCase = struct(...
    'caseId', '', ...            % [必填] 任务标识，如 'v410_c0'
    'description', '', ...       % [可选] 任务描述
    'initialState', [], ...      % [必填] (a) 初始状态定义
    'controls', [], ...          % [必填] (b) 控制设置
    'solver', []                 % [必填] (c) 求解器设置
);
```

**校验规则：**
- `caseId`：非空字符串，字母数字下划线组合
- `initialState`、`controls`、`solver` 必须为 struct 类型

---

## 3. (a) 初始状态 — `simCase.initialState`

```matlab
simCase.initialState = struct(...
    'mode', 'cold', ...              % 活动 Route A 仅允许 cold
    'source', '', ...                % 保留为空的历史 provenance 字段
    'temperature_C', 20, ...         % 冷态初始温度 [°C]
    'pressure_MPa_abs', 0.101325, ...% 冷态初始压力 [MPa(abs)]
    'o2MoleFraction', 0.21, ...      % 冷态初始 O2 分数 [-]
    'h2oMoleFraction', 0.0115, ...   % 冷态初始 H2O 分数 [-]
    'h2MoleFraction', 0.9997         % 冷态初始 H2 分数 [-]
);
```

### 3.1 模式逻辑

| mode | 行为 | 适用场景 |
|------|------|---------|
| `cold` | 使用默认参数完全冷态初始化，不加载任何 operating point；活动输入显式设置 `LoadInitialState="off"`。 | 全部活动 Route A 基线、面板和正式 runner |

`warm`/`hot` 只保留在历史 schema 和归档脚本中，不属于当前活动 API；`routeA_validate_case` 对这两种模式明确拒绝。

### 3.2 默认值覆盖

- 当 `mode='cold'` 时，`temperature_C`、`pressure_MPa_abs`、`o2MoleFraction`、`h2oMoleFraction`、`h2MoleFraction` 用于设定 Simulink 模型的初始工作区变量
- 当前活动 API 不存在 operating-point 覆盖路径；上述冷态边界字段由平台模型默认值和 case controls 装配。

---

## 4. (b) 控制设置 — `simCase.controls`

```matlab
simCase.controls = struct(...
    'electrical', [], ...    % 电边界控制
    'cathode', [], ...       % 阴极气路控制
    'cegr', [], ...          % cEGR 控制
    'anode', [], ...         % 阳极控制
    'thermal', [], ...       % 热管理控制
    'environment', []        % 环境/边界条件
);
```

### 4.1 电边界控制

```matlab
simCase.controls.electrical = struct(...
    'mode', 'Current', ...           % 'Current' | 'Power' | 'Voltage'
    'profile', [], ...               % [标量或 N×2 矩阵] 时序 [t, value]
    'voltageController', []          % Voltage 模式 PI 参数（可选）
);
```

**profile 格式：**
- 标量：恒值，自动生成 `[0, value; stopTime, value]` 时序
- N×2 矩阵：第 1 列时间，第 2 列值，如 `[0, 0; 0.5, 0; 60.5, 100; 600, 100]`
- 空值（`[]`）：使用默认值（0 A / 0 kW / 427.6 V）

**voltageController 子结构（仅 Voltage 模式需设置）：**

```matlab
simCase.controls.electrical.voltageController = struct(...
    'Kp_A_V', 1, ...           % 比例增益 [A/V]
    'Ki_A_V_s', 0.05, ...      % 积分增益 [A/V/s]
    'currentMin_A', 0, ...     % 电流下限 [A]
    'currentMax_A', 392        % 电流上限 [A]
);
```

### 4.2 阴极气路控制

```matlab
simCase.controls.cathode = struct(...
    'airControlMode', 2, ...             % 1=流量/2=OER/3=直接
    'targetOer', 3.0, ...                % 目标 OER [-]
    'targetMdot_kg_s', 0.005, ...        % 目标质量流量 [kg/s]
    'directCommand', 0, ...              % 空压机归一化执行命令 [0,1]
    'sourcePressure_MPa_abs', 0.15, ...  % 阴极源压力 [MPa(abs)]
    'sourceTemperature_C', 20, ...       % 阴极源温度 [°C]
    'outletPressure_MPa_abs', 0.1613, ...% 阴极出口压力/背压 [MPa(abs)]
    'humidifierRH', 0.9, ...             % 加湿器设定 RH [-]
    'humidifierEnabled', 1               % 加湿器启用 [0/1]
);
```

### 4.3 cEGR 控制

```matlab
simCase.controls.cegr = struct(...
    'enabled', true, ...         % cEGR 启用 [true/false]
    'targetRatio', 0, ...        % 目标 cEGR 比 [-]
    'valveMode', 1, ...          % 阀模式 [1=开度/2=压力]
    'controlMode', 1, ...        % 控制模式 [固定为 1]
    'targetInputMode', 1         % 目标输入模式 [固定为 1]
);
```

### 4.4 阳极控制

```matlab
simCase.controls.anode = struct(...
    'sourcePressure_MPa_abs', 0.3, ...       % 氢源压力 [MPa(abs)]
    'sourceTemperature_C', 20, ...           % 氢源温度 [°C]
    'inletPressure_MPa_abs', 0.15, ...       % 阳极入口压力 [MPa(abs)]
    'humidifierRH', 0.5, ...                 % 阳极加湿 RH [-]
    'recirculationBaseCommand', 0, ...       % 回流基础命令 [-]
    'recirculationCurrentGain_A_inv', 0, ... % 回流电流增益 [1/A]
    'purgeEnabled', 0, ...                   % 吹扫启用 [0/1]
    'purgeOnN2MoleFraction', 0.1, ...        % 吹扫开启 N2 阈值 [-]
    'purgeOffN2MoleFraction', 0.05           % 吹扫关闭 N2 阈值 [-]
);
```

### 4.5 热管理控制

```matlab
simCase.controls.thermal = struct(...
    'stackTemperatureSet_C', 80      % 堆温设定 [°C]
);
```

### 4.6 环境/边界条件

```matlab
simCase.controls.environment = struct(...
    'ambientPressure_MPa_abs', 0.101325, ... % 环境压力 [MPa(abs)]
    'ambientTemperature_C', 20, ...          % 环境温度 [°C]
    'o2MoleFraction', 0.21, ...              % 环境 O2 分数 [-] → env_yO2
    'h2oMoleFraction', 0.0115436, ...        % 环境 H2O 分数 [-] → env_yH20
    'h2MoleFraction', 0.9997                 % 阳极 H2 分数 [-] → tank_yH2
);
```

---

## 5. (c) 求解器设置 — `simCase.solver`

```matlab
simCase.solver = struct(...
    'stopTime_s', 600, ...            % 仿真时长 [s]
    'solver', 'VariableStepAuto', ... % 求解器类型
    'relTol', 1e-3, ...               % 相对容差
    'absTol', 1e-3, ...               % 绝对容差
    'maxStep_s', 5, ...               % 最大步长 [s]
    'signalLogging', 'on', ...        % 信号日志开关
    'signalLoggingName', 'logsout',...% 日志名称
    'simscapeLogType', 'all', ...     % Simscape 日志类型
    'returnWorkspaceOutputs', 'on', ...% 返回工作区输出
    'saveOperatingPoint', 'off', ...  % 是否保存 operating point
    'operatingPointFile', ''          % 保存路径（saveOperatingPoint='on' 时使用）
);
```

---

## 6. 使用示例

### 6.1 最简单的恒电流工况

```matlab
simCase = struct(...
    'caseId', 'current_100A', ...
    'initialState', struct('mode', 'cold'), ...
    'controls', struct(...
        'electrical', struct('mode', 'Current', 'profile', 100)), ...
    'solver', struct('stopTime_s', 100) ...
);
```

### 6.2 恒电压 + cEGR 工况

```matlab
simCase = struct(...
    'caseId', 'v410_c01', ...
    'description', '410V with 10% cEGR', ...
    'initialState', struct('mode', 'cold'), ...
    'controls', struct(...
        'electrical', struct(...
            'mode', 'Voltage', ...
            'profile', 410, ...
            'voltageController', struct(...
                'Kp_A_V', 1, 'Ki_A_V_s', 0.05, ...
                'currentMin_A', 0, 'currentMax_A', 392)), ...
        'cegr', struct('targetRatio', 0.1), ...
        'cathode', struct('targetOer', 3.0)), ...
    'solver', struct('stopTime_s', 600) ...
);
```

### 6.3 恒功率 + 入口组分控制

```matlab
simCase = struct(...
    'caseId', 'p120kw_o2_18', ...
    'description', '120kW power with 18% O2', ...
    'initialState', struct('mode', 'cold'), ...
    'controls', struct(...
        'electrical', struct('mode', 'Power', 'profile', 120), ...
        'environment', struct('o2MoleFraction', 0.18)), ...
    'solver', struct('stopTime_s', 600) ...
);
```

### 6.4 完整时序控制（功率斜坡）

```matlab
% 60s 斜坡从 0 到 40kW
profile = [0, 0; 0.5, 0; 60.5, 40; 600, 40];

simCase = struct(...
    'caseId', 'p40kw_ramp', ...
    'initialState', struct('mode', 'cold'), ...
    'controls', struct(...
        'electrical', struct('mode', 'Power', 'profile', profile), ...
        'cathode', struct('targetOer', 3.0)), ...
    'solver', struct('stopTime_s', 600) ...
);
```

---

## 7. 校验规则（`routeA_validate_case` 函数设计）

建议实现 `routeA_validate_case.m` 函数，对 simCase 进行以下校验：

### 7.1 类型校验

| 字段 | 类型 | 校验 |
|------|------|------|
| `caseId` | char/string | 非空，无特殊字符 |
| `initialState.mode` | char/string | `cold`/`warm`/`hot` 之一 |
| `controls.electrical.mode` | char/string | `Current`/`Power`/`Voltage` 之一 |
| `controls.cathode.airControlMode` | numeric | 1/2/3 之一 |
| `solver.solver` | char/string | 有效 Simulink 求解器名 |

### 7.2 范围校验

| 字段 | 范围 | 越界处理 |
|------|------|---------|
| `controls.cathode.targetOer` | [1.5, 5] | 截断 + 警告 |
| `controls.cegr.targetRatio` | [0, 0.5] | 截断 + 警告 |
| `controls.electrical.voltageController.Kp_A_V` | > 0 | 报错 |
| `controls.cathode.humidifierRH` | [0, 1] | 截断 |
| `solver.relTol` | (0, 1) | 报错 |

### 7.3 互斥校验

| 互斥对 | 规则 |
|--------|------|
| `electrical.mode` + `electrical.voltageController` | Voltage 模式必须提供 voltageController；其他模式不检查 |
| `electrical.mode` + `profile` | 一次计算只选一种电边界 |

### 7.4 默认值填充

`routeA_validate_case` 应负责填充所有未提供字段的默认值，使调用方可以只提供需要变化的字段。

---

## 8. 附录：simCase 模板代码

完整模板代码见 `03_脚本/RouteA_GasMixture_Derived/routeA_simCase_template.m`

---

## 9. 关联文件

- [控制接口汇总表](RouteA_cEGR_PEMFC_控制接口汇总表_v01.md)
- [平台能力建设需求](RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)
- [`routeA_simCase_template.m`](../../../03_脚本/RouteA_GasMixture_Derived/routeA_simCase_template.m)
