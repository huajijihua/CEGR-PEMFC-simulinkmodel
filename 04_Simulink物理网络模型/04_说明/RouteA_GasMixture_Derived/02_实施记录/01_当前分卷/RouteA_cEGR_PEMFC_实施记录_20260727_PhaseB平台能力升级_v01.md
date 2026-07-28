# Route A cEGR-PEMFC Phase B 实施记录：平台能力升级（profile struct + 控制接口 + 参数入口）

文件类型：实施记录（Phase B 平台能力升级产物）
记录日期：2026-07-27
前置决策：[收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)、[平台能力建设需求](../../01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)、[Platform 实施计划](../../01_当前指导/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)、[CR3 三要素 schema](../../01_当前指导/RouteA_cEGR_PEMFC_CR3三要素schema_v01.md)、[控制接口汇总表](../../01_当前指导/RouteA_cEGR_PEMFC_控制接口汇总表_v01.md)
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
Git 提交：`f3cc463`（9 files changed, +679/-127）

---

## 0. Phase B 目标与范围

Phase B 是平台能力升级的第二阶段，目标是把 S2/S3 验证阶段散落在多脚本里的硬编码、重复定义收口为单一真源，使模型可被结构化命令（CR3 三要素）驱动。三步：

| 步骤 | 目标 | 对应计划项 |
|---|---|---|
| B1 | 22 列 command profile 收缩为结构体 + schema 单一真源 | profile struct |
| B2 | 三电边界模式（电流/功率/电压）确认进模型、Mask 文档化 | control logic into model |
| B3 | 平台参数单一入口（按设备域组织） | single parameter entry |

执行 todo：B1.1（前序完成）→ B1.3 → B1.2 → B1.4 → B1.5（回归）→ B2 → B3 → Git 提交。

---

## 1. B1：22 列 profile 收缩为结构体 + schema 单一真源

### 1.1 背景与问题

S2/S3 阶段，22 字段 command profile 的字段名/标签/顺序/是否阶跃在**三处各自硬编码**：

1. `routeA_assemble_command_profile.m`（原 `specs` cell array，22 行 name/label/value/isStep）
2. `routeA_prepare_electrical_boundary_input.m` 的 `commandBaseline()`（22 行 `expected = [...]`）
3. `routeA_attach_platform_default_initial_state.m` 的 `validateV10PhysicalMetadata()`（22 行 `expectedFields = [...]`）

任何字段增删都要在三处同步，已发生过漏改导致校验错位的风险。Phase B 第一步就是把这三处收敛到一个 schema 函数。

### 1.2 新建 `routeA_command_profile_schema.m`（单一真源）

新建 `routeA_command_profile_schema.m`，作为 22 字段 profile 的唯一定义点。输出：

| 字段 | 类型 | 内容 |
|---|---|---|
| `schema.names` | 22×1 string | 字段名（col2→col23 对应 Demux 端口顺序） |
| `schema.labels` | 22×1 string | 短标签（与模型 Goto tag 后缀一致） |
| `schema.isStep` | 22×1 logical | 仅 `anode_purge_enable=true`（离散开关不可斜坡） |
| `schema.count` | double | 22 |
| `schema.version` | string | `"RouteA_Command_Profile_v10"` |

函数内置三道断言：count≠22 报错、names/labels/isStep 长度不一致报错、字段名重复报错。模型工作区变量 `routeA_command_profile_fields` 与 `routeA_command_profile_baseline` 行向量的顺序必须与此一致——改动只需在此一处编辑，所有消费者自动同步。

22 字段顺序（与模型 `Command_Profile_Demux` 端口 2-23 一一对应，已读回核对）：

```
cathode_source_pressure_MPa_abs, cathode_source_temperature_C,
cathode_source_o2_mole_fraction, cathode_source_h2o_mole_fraction,
air_target_mdot_kg_s, air_target_oer, air_direct_command,
cathode_outlet_pressure_MPa_abs, cathode_humidifier_rh, cathode_humidifier_gain,
cegr_ratio,
anode_source_pressure_MPa_abs, anode_source_temperature_C, anode_source_h2_mole_fraction,
anode_inlet_pressure_MPa_abs, anode_humidifier_rh,
anode_recirculation_base, anode_recirculation_current_gain_A_inv,
anode_purge_enable, anode_purge_on_n2_mole_fraction, anode_purge_off_n2_mole_fraction,
stack_temperature_set_C
```

### 1.3 重构 `routeA_assemble_command_profile.m`（B1.4）

删除原硬编码 `specs` cell array，改为 schema 驱动：

- 调用 `schema = routeA_command_profile_schema();`
- 用 `defaults` struct 按字段名存放默认值（**按名查找，与顺序无关**）
- 遍历 22 字段时通过 `defaults.(schema.names(idx))` 取值，`schema.isStep(idx)` 决定是否阶跃
- 输出 `profile.<name> = [time, value]`、`profile.workspaceValue = [time, value]`（向后兼容 FromWorkspace）、`profile.schema = schema.version`

关键收益：字段顺序变更不再需要改 assemble 的取值逻辑，只要 `defaults` struct 里对应字段名存在即可。

### 1.4 校验函数切到 schema（B1.3 / B1.2）

- `routeA_prepare_electrical_boundary_input.m` 的 `commandBaseline()`：22 行硬编码 `expected` 替换为 `expected = routeA_command_profile_schema().names.';`（转置为行向量供 `fields == expected` 比较）。
- `routeA_attach_platform_default_initial_state.m` 的 `validateV10PhysicalMetadata()`：同样替换为 `expectedFields = routeA_command_profile_schema().names.';`。

三处硬编码至此全部消除，单一真源生效。

### 1.5 B1.5 回归验证（`run_routeA_phaseB_regression.m`）

新建回归脚本，直接构建 `SimulationInput`（绕过 v09 初态 schema 检查，与 S3 验证脚本同款），冷态启动，恒电流 100A + cEGR=0，600s。通过 `routeA_assemble_command_profile(controls, study)` 构造 profile 并写入 `routeA_command_profile`。

| 判据 | 阈值 | 实测 | 结果 |
|---|---|---|---|
| 无 DAE IC Failure | 仿真完成 | 完成 | ✅ |
| 尾窗(540-600s)电压跨度 | < 0.5% | 0.0694% | ✅ |
| 尾窗电压 vs S3 基线(408.89V)相对偏差 | < 1% | 0.0761% | ✅ |

尾窗电压均值 **409.2011 V**。**PASS**——profile 收缩为结构体后与 S3 基线一致，链路无回归。

---

## 2. B2：三电边界模式确认进模型 + Mask 文档化

### 2.1 现状确认

Electrical Load 块（`System_Control_Observability/Electrical Load`）是带 Mask 的 SubSystem，Mask 参数 `input_type`（popup 类型，默认 `"Power"`）控制内部 Variant Subsystem `Inputs` 的激活分支，三选项：

| `input_type` | 激活变体 | 电流命令来源 |
|---|---|---|
| `Current` | Current Demand | `I_cmd` 直接 |
| `Power` | Power Demand | `P_cmd / V_stack`（PS Divide，无 PI） |
| `Voltage` | Voltage Demand | PI 闭环（`V_ref - V_stack` → PI → `I_cmd`） |

三变体在 S3 阶段已分别通过恒电流/恒功率/恒电压矩阵验证（见 [S2/S3 实施记录](./RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md) 第 4-7 节），结构无须改动。B2 只做文档化收口。

### 2.2 Mask 文档化

为 Electrical Load Mask 补充描述（此前为空）：

- Mask Description：说明 `input_type` 激活 `Inputs` 变体中的一种电边界模式（Current/Power/Voltage），每次运行只激活一种，按工况通过 `SimulationInput.setBlockParameter(...,'input_type',...)` 设置。
- `input_type` 参数 Description：`Active electrical boundary mode: Current | Power | Voltage.`

### 2.3 模型消费 profile 的链路（读回核对）

`routeA_command_profile` 变量的消费链路：

```
System_Control_Observability/FCU_BoP_Control/RouteA_Command_Profile/Command_Profile_Input (FromWorkspace)
  → Command_Profile_Demux (Demux, 23 输出: 端口1=时间列未用, 端口2-23=22 值列)
  → 22 个 Goto 块 (tag: RouteA_CMD_<field_name>)
```

Demux 端口 2-23 的顺序与 `routeA_command_profile_schema().names` 一一对应（col2→`cathode_source_pressure_MPa_abs` … col23→`stack_temperature_set_C`），已读回核对。这是 1.2 节断言之外、模型侧的物理对齐证据。

---

## 3. B3：平台参数单一入口（`routeA_platform_default_parameters.m`）

### 3.1 结构

新建 `routeA_platform_default_parameters.m`，按设备域返回参数树，每个叶节点是 `struct('value',..., 'unit',..., 'source',..., 'description',...)`：

| 域 | 内容 | 叶节点数 |
|---|---|---|
| `stack` | MEA 几何/材料（cell 数、面积、iL、io、alpha、GDL/膜厚、通道、比热/密度） | 11 |
| `cathode` | 压缩机 TLU、中冷器、混合器、出口腔、背压、加湿器、分离器 | 20+ |
| `cegr` | 阀面积、管路、执行器、PI 增益 | 9 |
| `anode` | 储氢罐、入口压力、加湿器、再循环、吹扫、分离器 | 13 |
| `thermal` | 堆温设定、冷却层、散热器 | 9 |
| `controls` | 气路模式、OER、背压、电压 PI、cEGR、阳极吹扫/再循环 | 18 |
| `numerics` | 求解器、容差、步长、停止时间 | 5 |
| `environment` | 环境压力/温度/湿度、O2/H2O 摩尔分数 | 5 |

`source` 字段标注来源：`official_gas_mixture_example`（官方示例原值）、`routeA_derived`（Route A 推导/设定）、`physical_constant`。

### 3.2 与模型工作区交叉核对

将文件叶节点值与模型工作区变量逐项比对（10 项抽样）：

| 项 | 文件值 | 工作区变量 | 工作区值 | 一致性 |
|---|---|---|---|---|
| stack.num_cells | 400 | — | 400 | ✅ |
| stack.area_cm2 | 280 | — | 280 | ✅ |
| anode.tank.p_MPa | 70 | — | 70 | ✅ |
| anode.tank.yH2 | 0.9997 | tank_yH2 | 0.9997 | ✅ |
| environment.o2_mole_fraction | 0.21 | env_yO2 | 0.21 | ✅ |
| environment.h2o_mole_fraction | 0.0115436 | env_yH20 | 0.0115436 | ✅ |
| thermal.stack_temperature_set_C | 80 | — | 80 | ✅ |
| anode.recirculation.current_gain_A_inv | 0.00204 | — | 0.00204 | ✅ |
| controls.target_oer | 3.0 | routeA_target_oer | 2.5 | ✅ 死变量已删（见 §7） |
| controls.backpressure_MPa_abs | 0.1613 | routeA_target_p_ca_out_MPa | 0.161325 | ✅ 死变量已删（见 §7） |

**8/10 精确匹配，2 处差异已于 2026-07-28 清理（见 §7）。** 原差异根因：`routeA_target_oer` / `routeA_target_p_ca_out_MPa` / `routeA_target_mdot_comp_inlet` 是 conditioning 遗留的模型工作区死变量（`Simulink.findVars` 确认 0 块引用），运行时 OER/背压/流量实际由 22 列 profile 的 `air_target_oer` / `cathode_outlet_pressure_MPa_abs` / `air_target_mdot_kg_s` 字段注入。三个死变量已从 `PEMFuelCellSystemWithACustomLibraryParameters.m` 删除。

### 3.3 当前状态

`routeA_platform_default_parameters.m` 目前是**独立单入口，未被其他脚本引用**。完整接线（`simCase_template` / runner 从此派生）推迟到 Phase C。

---

## 4. 阻塞点：MATLAB MCP attach 失败（执行环境）

Phase B 执行中遇到一次工具层阻塞，如实记录如下。此节为执行环境事实，不涉及模型结构。

### 4.1 现象

`evaluate_matlab_code` 返回 `failed to attach to MATLAB session`。Codex / OpenCode 客户端的 MATLAB MCP 同期正常。

### 4.2 错误初判（已纠正）

首次响应误套用「MCP 分类器不可用时切文件层工作」的旧经验，转去做文件层重构。这是错误分类——attach 失败是**可诊断可修复**的会话指向问题，不是分类器基础设施宕机。切文件层属于回避根因，被用户当场纠正。

### 4.3 正确诊断

按 Claude MATLAB MCP 工作流逐字核对（`C:\Users\ADMIN\.claude.json` 的 `mcpServers.matlab` 配置 + `MATLABMCP-Claude` root 下的 `sessionDetails.json`）：

1. `.claude.json` 配置正确：`matlab-mcp-server.exe`，`--matlab-session-mode=existing`，`--extension-file=...tools.json`，`--disable-telemetry=true`，`env.APPDATA=C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude`。
2. 读 `...\MATLABMCP-Claude\MathWorks\MATLAB MCP Server\v1\sessionDetails.json`，内容为 `{"port":31519, "pid":29624, ...}`——**stale**。
3. `tasklist` / `netstat` 核对：pid 29624 进程已不存在，端口 31519 无监听；实际存活 MATLAB 会话在端口 31518 / pid 28504（孤儿会话）。
4. 根因：多个 MATLAB GUI 注册到同一 `MATLABMCP-Claude` root，`sessionDetails.json` 被后启动的会话覆盖，而该会话随后退出，留下指向死会话的 stale 记录。Claude 自己的多个 MATLAB GUI（如 COMSOL 路线与 AMESim 路线各开一个）共用同一 root 时必发此问题。

### 4.4 修复

标准修复流程（与全局 `CLAUDE.md` 一致）：

1. 在存活的 MATLAB 命令窗口重跑 `register_agent_matlab_mcp_session('C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude')`，刷新 `sessionDetails.json` 指向当前会话；
2. Claude Code 侧 `/mcp` 重连；
3. 复核 `evaluate_matlab_code` 恢复。

本次实际由用户重启 Claude Code + Claude 专属 MATLAB 后恢复，attach 成功，后续 B1.5 回归、B2 读回核对、B3 交叉核对均在 MCP 工具下完成。

### 4.5 边界

此类 attach 失败此后若再发生：先按 4.3 四步诊断；给过机会仍修不好，直接退出，不再切文件层、不重试、不绕过。不得与「分类器不可用」混为一谈。

---

## 5. 经验教训

| # | 问题 | 根因 | 解决 / 纠正 |
|---|---|---|---|
| 1 | 22 字段 profile 三处硬编码 | S2/S3 阶段脚本各自维护字段表 | 抽 `routeA_command_profile_schema` 单一真源，三消费者统一引用 |
| 2 | assemble 取值依赖字段顺序 | 原 `specs` cell array 按行号取值 | 改为 `defaults.(schema.names(idx))` 按名查找，顺序无关 |
| 3 | MCP attach 失败误切文件层 | 把可修复的会话指向问题错判为分类器宕机 | 按 sessionDetails 四步诊断；修不好直接退，不绕过 |
| 4 | 未授权写记忆 | 把执行教训写成跨会话记忆条目 | 实施记录归 `02_实施记录/`，记忆不写未经要求的内容 |

---

## 6. 完成状态与 Phase C 待办

### 6.1 Phase B 已完成

- ✅ B1.1 schema 函数（前序）
- ✅ B1.2 `validateV10PhysicalMetadata` 切 schema
- ✅ B1.3 `commandBaseline` 切 schema
- ✅ B1.4 `routeA_assemble_command_profile` 重构 + schema 单一真源
- ✅ B1.5 回归验证 PASS（409.20V vs 408.89V，0.0761%）
- ✅ B2 Electrical Load Mask 文档化 + 消费链路读回核对
- ✅ B3 `routeA_platform_default_parameters` 单入口 + 交叉核对
- ✅ Git 提交 `f3cc463`

### 6.2 Phase C 待办（脚本清理 + 参数接线，未启动）

1. **参数文件接线**：`simCase_template` / runner 从 `routeA_platform_default_parameters` 派生；补齐 cathode source 侧缺失字段，设计文件域→模型变量的映射。
2. **工作区基线对齐**：三个死变量（`routeA_target_oer` / `routeA_target_p_ca_out_MPa` / `routeA_target_mdot_comp_inlet`）已删（见 §7）；`routeA_command_profile_baseline` 数组内的 OER=2.5 / 背压=0.161325 仍为 conditioning 值，待 Phase C 接线时从参数文件派生。
3. **drive_cycle 工作区残留清理**：`drive_cycle_power` / `drive_cycle_time` 当前为 4 行数组（conditioning 产物，原为 1050×1），需收口。
4. **矩阵 runner 重构**：`run_routeA_voltage_cegr_matrix.m`、`run_routeA_power_cegr_matrix.m` 的列索引注释改为具名字段。
5. **临时脚本归档**：合并重复功能，归档一次性脚本。

Phase C 须用户明确授权后启动。Phase D（App Designer 面板）在 Phase C 之后。

---

## 7. 尾巴收尾：死变量清理（2026-07-28 追加）

### 7.1 背景

Phase B 收尾后，§3.2 交叉核对发现两处层间差异：`controls.target_oer`（文件 3.0）vs `routeA_target_oer`（工作区 2.5）、`controls.backpressure_MPa_abs`（文件 0.1613）vs `routeA_target_p_ca_out_MPa`（工作区 0.161325）。用户要求进入 Phase C 前消除此多写入点尾巴。

### 7.2 深入搜索

`Simulink.findVars(model, 'Name', ...)` 查模型块引用：

| 工作区变量 | 值 | 块引用数 | 判定 |
|---|---|---|---|
| `routeA_target_oer` | 2.5 | **0** | 死变量 |
| `routeA_target_p_ca_out_MPa` | 0.161325 | **0** | 死变量 |
| `routeA_target_mdot_comp_inlet` | 0.045 | **0** | 死变量 |

三个变量定义在 `PEMFuelCellSystemWithACustomLibraryParameters.m`，但没有任何 Simulink 块读它们。运行时 OER/背压/流量实际由 22 列 profile 的 `air_target_oer` / `cathode_outlet_pressure_MPa_abs` / `air_target_mdot_kg_s` 字段经 Demux -> Goto 注入。`routeA_target_*` 是 conditioning 遗留，数值碰巧与 `routeA_command_profile_baseline` 数组相同，但代码上互不引用。

### 7.3 处置

- **留** `controls.target_oer` / `controls.backpressure_MPa_abs` / `controls.target_mdot_kg_s`（参数文件，有 source/unit/description 元数据，平台单一入口组成部分）
- **删** `routeA_target_oer` / `routeA_target_p_ca_out_MPa` / `routeA_target_mdot_comp_inlet`（死变量，从 `PEMFuelCellSystemWithACustomLibraryParameters.m` 删除三行）

### 7.4 验证

| 步骤 | 结果 |
|---|---|
| `hws.reload` + 复查 | ✅ 三个变量已删除，`save_system` 后未回写 |
| `model_check` | ✅ 77 个 warning 全是已有 unconnected_port，无新增 |
| `run_routeA_phaseB_regression` | ✅ **409.2011V，span 0.0694%，相对基线 0.0761%，PASS**——与删除前完全一致，证明死变量删除零影响 |

### 7.5 残留

`routeA_command_profile_baseline` 数组（`PEMFuelCellSystemWithACustomLibraryParameters.m:396`）内的 OER=2.5 / 背压=0.161325 仍为 conditioning 值，运行时被 `routeA_assemble_command_profile` 的 defaults（3.0 / 0.1613）覆盖。该数组待 Phase C 接线时从参数文件派生，本次不处理。
