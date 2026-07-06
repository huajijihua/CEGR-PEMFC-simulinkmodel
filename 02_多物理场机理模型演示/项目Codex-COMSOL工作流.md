# Agent 工作流矩阵

本文件定义本项目可用的 Agent 工作流类型、适用场景和选择规则。Claude Code 与 Codex 作为对等 Agent，共享同一套核心工作流边界。

## 核心理念

1. 因地制宜：根据任务的真实目标选择最直接、最高效、最轻量的工作流，不引入不需要的工具层。
2. 先选路线再动手：先判断是纯系统级、纯 COMSOL、纯 AMEsim，还是需要协同外循环，再开始建模或标定。
3. 正式模型保持洁净：不要为了一次拟合或一次调试，把临时外部文件依赖挂进正式模型。

## 工作流矩阵

```text
                         ┌─ agent-matlab/simulink ───── 纯 Simulink 建模、控制策略、系统级审计
                         │
                         ├─ agent-comsol ────────────── 纯 COMSOL 多物理场建模、核查、重建
Claude Code / Codex ─────┤
                         ├─ agent-amesim ────────────── 纯 AMEsim 一维系统
                         │
                         ├─ agent-comsol-matlab/simulink ─ COMSOL + MATLAB 协同标定与外循环优化
                         │
                         └─ agent-amesim-matlab/simulink ─ AMEsim + MATLAB 协同
```

## 各工作流详解

### 1. agent-matlab/simulink

| 项目 | 内容 |
|------|------|
| 链路 | Agent -> 对应专用 MATLAB MCP GUI -> MATLAB/Simulink |
| 适用 | Simulink 系统建模、控制策略、参数扫描、数据后处理、台架数据审计 |
| 本项目入口 | `01_自吸方案/03_台架测试_10kW_简化版/` |

### 2. agent-comsol

| 项目 | 内容 |
|------|------|
| 链路 | Agent -> Python/mph -> COMSOL Server（共享 GUI 会话） |
| 适用 | 纯多物理场建模、结构核查、组件重建、几何修改、物理场接口、边界条件、网格、Study、Solver、只读盘点、单步 smoke test |
| 本项目入口 | `02_多物理场机理模型演示/` |
| 当前最稳路线 | 从源模型插入函数和组件结构，优先 `func.insert()` + `component.insert()` |
| 默认边界 | 不经过 MATLAB 中转；默认不保存 `.mph`；最终保存由用户 GUI 执行 |

### 3. agent-amesim

| 项目 | 内容 |
|------|------|
| 链路 | Agent -> Bash 或 Python -> AMEPython |
| 适用 | 一维系统建模、BoP 部件匹配、热流体、气动、液压网络 |
| 本项目入口 | `03_AMEsim系统模型/`（当前仅放引用说明） |

### 4. agent-comsol-matlab/simulink

| 项目 | 内容 |
|------|------|
| 链路 | Agent -> 对应专用 MATLAB MCP GUI -> MATLAB LiveLink (`mphstart`) -> COMSOL Server |
| 适用 | COMSOL 参数辨识、外循环优化、多参数非线性拟合、实验数据驱动标定、Simulink-COMSOL 协同 |
| 本项目入口 | `02_多物理场机理模型演示/02_脚本/fit_comsol_echem_polarization_stage1.m` |
| 默认边界 | 参数标定走这条路线，不用临时 CSV 或乱搭外部文件依赖去驱动正式 COMSOL 模型 |

#### 固定启动纪律

1. `start_codex_matlab_gui.ps1` 与 `start_claude_matlab_gui.ps1` 不再只是启动 plain MATLAB；它们会显式设置 COMSOL LiveLink bootstrap 环境变量。
2. MATLAB 启动后，`startup.m` 会在 agent 会话内调用 `bootstrap_agent_comsol_livelink`，把 `D:\COMSOL63\Multiphysics\mli` 加入路径，并默认尝试连接 `127.0.0.1:2036`。
3. 本项目协同标定仍以“共享 GUI Server + MATLAB LiveLink attach” 为准，不把开始菜单里的 `COMSOL Multiphysics 6.3 with MATLAB` 快捷方式直接当作本项目默认链路；该快捷方式可作为 LiveLink 基线参考，但本项目正式入口仍是 agent 专用 launcher。
4. 若命令窗口未显示 MCP session 标题、COMSOL bootstrap 信息或 `mphstart` 路径，先修复启动链路，不进入参数辨识。

#### 当前稳态极化默认辨识入口

- 拟合点：`case_idx = [1, 5, 9, 13, 19]`
- 验证点：`case_idx = [3, 11, 16]`
- 先动参数：`i0_ref_c`, `alpha_a_c`, `R_contact_c_area`
- `Av_c` 不纳入这条极化拟合脚本，保持模型内固定值
- 后备参数：`sigma_pem_correction`
- 默认行为：先回放初值，再进入优化；`evaluateOnly=true` 时只回放不优化

### 5. agent-amesim-matlab/simulink

| 项目 | 内容 |
|------|------|
| 链路 | Agent -> 对应专用 MATLAB MCP GUI -> AMEsim（通过 `interface_contract`） |
| 适用 | AMEsim 系统模型需要 MATLAB 参数标定或后处理 |
| 本项目现状 | 暂无正式实例 |

## MATLAB MCP 会话边界

1. 普通 MATLAB 不注册 MCP，不作为 agent 会话。
2. Codex 使用 `C:\Users\ADMIN\Desktop\MATLAB_Agent_Launcher.hta` 中的 `Codex MCP MATLAB` 或 `start_codex_matlab_gui.ps1`。
3. Claude 使用同一面板的 `Claude MCP MATLAB` 或 `start_claude_matlab_gui.ps1`。
4. 两个 agent 同时使用 MATLAB 时打开两个 GUI；各自只 attach 命令窗口显示自己角色的 session。
5. Codex 和 Claude 使用不同 MCP session 根目录，因为 `shareMATLABSession()` 会在根目录下写单个 `sessionDetails.json`。Codex 为 `C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Codex`，Claude 为 `C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude`；`startup.m` 通过 `register_agent_matlab_mcp_session.m` 写入对应根目录，不修改 MATLAB 的 `APPDATA`。
6. 客户端配置更新后需要重启或刷新 agent 客户端/session，让正式 MCP 工具重新加载。不要把临时 MCP 探针脚本当作常规工作流。
7. MCP attach 失败或工具未暴露时先修复会话，不用 `matlab.exe -batch` 冒充 MCP 交互链路。batch 只用于可脱离 agent 的长时间脚本任务，结束后再由 agent 读取结果并审计。

## COMSOL 已验证路线与当前边界

### 已验证可靠

1. 共享 GUI 会话下连接 COMSOL Server。
2. 只读盘点模型结构与真实标签。
3. `func.insert(source_file, tag_list, [])` 导入函数体系。
4. `component.insert(source_file, ['comp1'], [])` 导入组件结构及其几何、物理场、材料、变量、网格、探针等。
5. `exp_*` 等函数作为模型内部函数链的一部分可保留。

### 当前边界

1. 纯 Python/mph 从零稳定创建一个可直接挂复杂多物理场并可靠求解的完整 2D component，当前不视为已闭环验证能力。
2. 因此，若任务是空模型重建，优先采用“源模型插入路线”而不是把“从零纯 API 搭完整 2D 多物理场组件”当作默认能力。
3. 若任务进入参数辨识、外循环优化、多参数拟合，应切换到 `agent-comsol-matlab/simulink`。

## COMSOL 模型纪律

1. `exp_*`、piecewise、interpolation 等若已存在于 `.mph` 内部函数体系，默认视为模型内资产，不因名称像表格函数就误判为外部依赖。
2. 禁止把 `.codex_temp`、`case_*.csv`、临时导出表格、调试 CSV、临时 table 文件接入正式 COMSOL 模型。
3. COMSOL 正式模型默认不由脚本保存；最终保存由用户通过 GUI 执行。
4. 审计时必须显式核查 `filename`、`sourcefile` 等属性，区分模型内资产与外部依赖污染。
5. FC 模块中 `icph1`、`h2gasph1`、`o2gasph1` 在 UI 中显示“所有域”，不直接等于错误；必须结合实际适用域自动过滤结果、具体子特征和求解 KPI 判断。

## COMSOL 推荐核查顺序

1. 结构层：组件、几何、材料、物理场、多物理场、变量、选择集、Study、Solver。
2. 外部依赖层：`.codex_temp`、`case_*.csv`、失效 `sourcefile`、异常 `filename`。
3. 物理语义与 KPI 层：边界条件、源项、耦合、材料、关键派生量与求解结果。
4. 洁净度层：无意义残留节点、污染性中间对象、冗余求解链、误导性函数源。

## 工作流选择规则

```text
需要 COMSOL 高保真物理场？
  ├─ 否 -> 需要 AMEsim 专业部件？
  │         ├─ 否 -> agent-matlab/simulink
  │         └─ 是 -> agent-amesim
  └─ 是 -> 需要 MATLAB 做参数辨识、外循环优化或协同后处理？
            ├─ 否 -> agent-comsol
            └─ 是 -> agent-comsol-matlab/simulink
```

## 禁止规则

1. 禁止为用而用：不需要 COMSOL 时不要引入 COMSOL，不需要 MATLAB 优化时不要引入 MATLAB。
2. 禁止链路混用：选择了 `agent-comsol` 就不要走 MATLAB LiveLink；选择了 `agent-comsol-matlab/simulink` 就按协同路线执行。
3. 禁止 Python 替代 MATLAB 交付：如果任务明确要求 MATLAB 或 Simulink 交付，不能用 Python 重写。
4. 禁止未经确认切换工作流：当前任务已有既定路线时，不要擅自改线。
5. 禁止把临时外部 CSV 依赖接进正式 COMSOL 模型。

## 配套文档关系

1. `00_支撑材料/项目协作建模归档与重要经验_v01.md` 与 `COMSOL建模核查归档与重要经验_v01.md` 负责沉淀案例化经验、背景、失败模式和已验证路线。
2. 本文件负责沉淀路线矩阵、适用场景、已验证路线和当前边界，不承载完整案例细节。
3. 若本文件与归档文档有冲突，以当前规则文件和项目级规则文件中明确写出的执行边界为准，再回头修订归档叙述。
