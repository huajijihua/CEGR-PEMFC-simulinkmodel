# PEMFC-cEGR 项目 Codex 补充规则

## 跨客户端项目入口

1. 本文件是本项目唯一项目级 agent 入口。Codex、Claude Code for VSCode、OpenCode 进入本目录后都应先读取本文件。
2. 不在本项目根目录新增或维护 `CLAUDE.md`、`OPENCODE.md`、`SHARED_CONTEXT.md` 等重复规则文件；客户端差异由全局配置处理。
3. 全局模型/API/provider 切换统一通过 `CCswitch`，不要在本项目内创建额外切换脚本或临时密钥文件。

本仓库是阴极尾气循环 PEMFC 系统建模与验证工作区。Codex 的职责是先明确研究问题、模型边界、保真度和验证方式，再选择 MATLAB、Simulink、COMSOL 或协同路线中的最小足够方案。

## 建模指导思想与路线总纲

1. 本项目默认以系统级 PEMFC-cEGR 模型为主线，高保真 COMSOL 模型用于局部机理、几何、多物理场、边界条件和关键部件校核。
2. MATLAB 或 Simulink 负责系统动态、控制逻辑、参数扫描、优化、拟合、数据处理和结果审计；COMSOL 负责空间分布、多物理场和局部响应。
3. 三方协同时必须先固定接口：参数名、单位、输入工况、边界变量、输出变量、探针或派生值、模型版本、数据格式和验收指标。
4. 不用 COMSOL 替代系统级主模型，也不用 Simulink 经验拟合替代高保真机理；两者通过参数、边界、探针、代理模型或降阶模型互相支撑。
5. 建模推进顺序优先为问题定义、系统级基线、局部高保真校核、参数或代理或 ROM 回灌、系统级复验和风险边界说明。
6. 当前 Simulink 主线是 Route A 官方 Gas Mixture PEMFC 派生平台，核心原则是“剥离”：公司/历史/台架参数只能作为 `external_case` 背景或显式启用的外部案例，不进入默认平台参数、默认模型架构或默认验收标准。
7. Route A 默认参数必须来自 `platform_default` 语义，即官方案例、文献量级和工程经验自洽匹配；功率等级迁移采用 `scaling_rule`；10 kW 台架、DQ60、旧标定结果和公司临时资料均不得作为默认参数真源。
8. “剥离”不是剥离 MathWorks 官方案例、官方库块或官方示例参数；恰恰相反，Route A 应优先复用官方系统级 PEMFC 案例、官方组件和官方 solver/工作区设置。手工自建只用于 cEGR 特有支路、接口补丁和官方资产覆盖不到的最小必要部分。

9. 当前 Route A 处于“工程化系统模型规格与资产治理”阶段。进入新的 `.slx` 结构或保真度改动前，先以 `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_工程化建模规格_v01.md` 作为规划真源，并以同目录按日期/阶段分卷的实施记录作为变更证据；A6-A10、A11/A12 等阶段编号仅保留为历史实现证据或候选配置，不构成当前硬性推进顺序。
10. 对 Route A，工程化目标是形成可复用的系统集成平台，而非立即宣称为产品数字孪生。每个 BOP 模块必须明确其官方物理复用、L2 接口、待标定或产品替换状态；不得把长期高保真目标误解为单轮建模的强制范围。

## 目录职责

| 位置 | 唯一职责 |
|---|---|
| 根目录 `AGENTS.md` | 项目级唯一入口、跨工具规则和当前主线定位；根目录不放并行的当前建模说明。 |
| `00_支撑材料/` | 官方示例、文献、候选组件和材料池；只提供来源与复用依据，不定义当前模型要求。 |
| `04_Simulink物理网络模型/` | 当前 Route A Simulink 工作树：模型、运行脚本、现行工程化规格和本目录索引。 |
| `99_历史归档/` | 项目唯一历史归档根目录；旧模型、旧 runner、阶段审计和旧规划均在此集中保存，活动目录内不得再建立嵌套 `99_历史归档`。 |

## 模型矩阵

| 分支 | 路径 | 状态 | 保真度 | 结构特征 |
|------|------|------|--------|----------|
| 车载系统 v3 | 原路径 `01_自吸方案/01_车载系统_10kW_GZS60_v3/` | 已外置归档 | L2 标定型 | 有 GZS60 膜加湿器，含中冷器和空压机 BOP；仅作历史背景 |
| 台架测试 v1 | 原路径 `01_自吸方案/02_台架测试_10kW/` | 已外置归档 | L2 标定型 | 无加湿器，DQ60 空压机等效；仅作历史背景 |
| 简化台架 v1 | 原路径 `01_自吸方案/03_台架测试_10kW_简化版/` | 已外置归档/外部案例 | L2 标定型 | 无空压机和加湿器 BOP，直接以台架入堆条件为边界；不在当前默认工作树内 |
| Route A 通用平台 | `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/` | 当前 Simulink 主线 | L2/L3 之间的系统级物理网络 | 官方 Gas Mixture PEMFC 派生母版，新增 cathode-cEGR 支路 |
| COMSOL 机理 | 原路径 `02_多物理场机理模型演示/` | 已外置归档 | L3 高保真 | 2D PEMFC + cEGR，用于局部机理研究和参数校核；当前 Route A 不依赖其文件 |

## 外部案例资产入口

简化台架 v1 不再作为通用平台主线或默认参数来源。相关资产已移出当前工作树，原路径为 `01_自吸方案/03_台架测试_10kW_简化版/`；如需回放，只能从外部归档或 Git 历史恢复，并作为 `external_case`、历史审计和边界语义参考：

| 用途 | 入口 | 说明 |
|------|------|------|
| 参数默认值 | `init_testbench_10kw_simplified_defaults.m` | 返回 P 结构体，含物性、标定参数、冷却曲线 |
| 工况装配 | `init_testbench_10kw_simplified_egr(caseIndex, dataMode)` | 从 `combined_noegr_cegr_fit_points.csv` 读取稳态点 |
| 电压标定 | `calibrate_testbench_10kw_simplified_egr.m` | 五参数活化 + 膜电导率修正 |
| 压力标定 | `calibrate_testbench_10kw_simplified_pressure.m` | 阴极和阳极出口导纳与库存体积 |
| 温度标定 | `calibrate_testbench_10kw_simplified_temperature.m` | 冷却流量和换热曲线 |
| 批量审计 | `run_core_fix_v01_audit.m` | 回放全部 29 个统一工况点 |
| 自定义进气 | `run_testbench_10kw_simplified_custom_inlet_study.m` | 新鲜空气 EGR 扫描 |
| 模型本体 | `../01_模型/CEGR_TestBench_10kW_SimplifiedEGR_v01.slx` | 7 个 MATLAB Function 模块 |

这些 CSV 和 workbook 只对旧台架外部案例成立，不是 Route A 通用平台默认参数真源。Route A 默认初始化链不得读取 `simplified_*.csv`、`combined_noegr_cegr_fit_points.csv`、DQ60 map 或 10 kW workbook；若后续需要回放旧台架，必须先显式恢复外部案例资产，再通过专用 `external_case` 脚本和手动开关启用。

## 工具链验证入口

1. MATLAB MCP：SATK 工具应可调用，仿真通过 `evaluate_matlab_code` 调用 `sim()`。
2. COMSOL Server：本项目默认共享会话端口 `2036`。
   - `agent-comsol`：`Python/mph` 直连，入口 `mph.Client(host='127.0.0.1', port=2036)`。
   - `agent-comsol-matlab/simulink`：MATLAB LiveLink，入口 `mphstart('localhost', 2036)`。
3. AMEsim：入口 `D:\amesimsoft\Simcenter_Amesim_2511\Amesim\AMEPython.bat`，主工作区 `E:\agentwork_AMEsim_0625`。

## Agent MATLAB 会话分离

1. 普通 MATLAB 不绑定任何 agent，不自动注册 MCP。
2. Codex 使用 MATLAB 时，通过桌面 `C:\Users\ADMIN\Desktop\MATLAB_Agent_Launcher.hta` 的 `Codex MCP MATLAB` 按钮启动专用 GUI。
3. Claude 使用 MATLAB 时，通过同一桌面面板的 `Claude MCP MATLAB` 按钮启动另一套专用 GUI。
4. 两个 agent 同时用 MATLAB 时必须打开两个 GUI；Codex 只 attach 命令窗口显示 `CODEX` 的 MCP session，不复用 Claude session。
5. Codex 和 Claude 使用不同 MCP session 根目录，因为 `shareMATLABSession()` 会在根目录下写单个 `sessionDetails.json`。Codex 为 `C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Codex`，Claude 为 `C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude`；`startup.m` 通过 `register_agent_matlab_mcp_session.m` 写入对应根目录，不修改 MATLAB 的 `APPDATA`。
6. 客户端配置或启动脚本更新后，应重启或刷新 agent 客户端/session，让正式 MCP 工具重新加载。不要把临时 MCP 探针脚本当作常规工作流。
7. MATLAB MCP 默认采用 existing session attach；若工具未暴露或 attach 失败，先修复会话/配置，不用 `matlab.exe -batch` 冒充 MCP 交互链路。batch 只用于已通过下述长任务门禁、且确实可脱离 agent 交互的固定脚本任务，结束后再由 agent 读取结果并审计。
8. “可能超过 agent 交互超时”不是用户交接条件；完整准入条件见下方“MATLAB GUI 离线长任务门禁”。不得通过 MCP 启动后阻塞等待、轮询，或因工具超时而中断计算。
9. v10 低负载物理热初态的生成、三分支提升、兼容性审计和必要短 smoke 属于当前阶段的必要实现任务，由 agent 自己完成；不得仅因预计耗时较长就交给用户。用户 GUI 交接只适用于已通过上一条门禁的正式大规模研究任务。
10. 用户确认长计算完成后，agent 只读取约定的结果摘要、KPI、失败栈或输出文件继续审计。除非用户明确要求，不得重复运行同一长计算，也不得以缩短正式工况、减少案例或降低精度替代正式结果。

## 工作流选择规则

### MATLAB GUI 离线长任务门禁

“可能超过 agent 交互超时”不是用户交接条件。只有同时满足以下条件，才允许把 MATLAB/Simulink 任务交给用户在 MATLAB GUI 命令窗口离线执行：流程、输入输出契约和验收判据已经固定；agent 已使用同一模型、参数链和求解器设置亲自完成代表性 case 的端到端运行并确认无 MATLAB/Simulink 报错；预计运行约 `30 min` 以上或数小时，且通常涉及 `10` 个以上工况或等量级正式矩阵/敏感性扫描；命令无需用户临时改脚本即可粘贴执行。Code Analyzer、`model_check` 或脚本装配无报错不能替代亲自运行证据。未同时满足这些条件时，由 agent 继续执行或拆分为 agent 可验证的步骤，不得以超时为由转交。

v10 低负载物理热初态的生成、Current/Power/Voltage 三分支提升、兼容性审计和必要短 smoke 属于当前实施任务，由 agent 自己完成；GUI 交接只适用于已通过上述门禁的正式大规模研究任务。

1. 纯 Simulink 系统建模、控制策略、参数扫描、数据处理、结果审计，走 `agent-matlab/simulink`。
2. 纯 COMSOL 建模、结构核查、组件重建、几何与物理场配置、边界条件与求解器检查，走 `agent-comsol`。
3. 只要任务进入参数辨识、外循环优化、多参数拟合、实验数据驱动的 COMSOL 标定，默认走 `agent-comsol-matlab/simulink`。
4. 不需要 MATLAB 优化器时，不要为了“统一脚本”把纯 COMSOL 任务抬升为协同路线。
5. 不需要 COMSOL 高保真时，不要为了“看起来高级”引入 COMSOL。

## MATLAB/Simulink 项目规则

1. 读取模型优先使用 `model_overview`、`model_read(depth=0/1)`、`model_query_params` 和 `model_resolve_params`。
2. 结构或参数修改优先使用 `model_edit`、MATLAB 或 Simulink API、受控脚本，不直接修改 `.slx` 内部文件。
3. 结构性修改后优先运行 `model_check`，再做 read-back verification。
4. 行为验证使用最小必要工况、已有脚本、`sim()`、`model_test` 或 MATLAB 单元测试。
5. 无法闭环验证时，必须在结论中明确写出未验证原因和剩余风险。
6. Route A 默认参数以官方示例参数脚本和后续 `platform_default` 参数层为准；旧 `init_*_defaults.m` 中的 P 结构体只对对应外部案例或历史模型有效，不得自动上升为通用平台真源。
7. 优先复用官方模型和组件，减少从零手搓。新增自定义内容必须能说明为何官方 Gas Mixture PEMFC 示例、官方 FuelCell 库块或相近官方 BOP 示例不能直接覆盖。

## COMSOL 自动建模工作流

### 基本纪律

1. 本机 COMSOL 入口固定为 `D:\COMSOL63\Multiphysics`；GUI 使用 `bin\win64\comsol.exe`，Server 使用 `bin\win64\comsolmphserver.exe`，MATLAB LiveLink 使用 `mli`。
2. 本项目 COMSOL 历史模型原位于 `02_多物理场机理模型演示`，当前已外置归档；如需继续 COMSOL 工作，应先从外部归档恢复或重新建立受控工作副本。不得直接按二进制、XML 或文本方式修改 `.mph`；必须通过 COMSOL GUI、COMSOL API、MATLAB LiveLink 或受控脚本访问。
3. COMSOL 任务先区分新建模型、增量修改、模型审查和仿真验证。新建模型先形成模型规格和构建计划；增量修改先只读盘点当前模型；模型审查只输出证据链、风险和建议，不默认修改。
4. 默认采用共享 server 会话：用户在 GUI 中打开目标 `.mph`，Codex 连接同一个 `localhost:2036` COMSOL Server。
5. 脚本默认不得保存 `.mph`；最终保存由用户通过 GUI 执行。只有在用户明确授权且保存目标、文件名和原因都明确时，脚本才可保存。
6. 同一模型默认只允许一条 Codex 控制链路，避免多个 Python/mph、MATLAB LiveLink 或后台脚本并发修改同一 server 会话。

### 本项目两条 COMSOL 路线

1. `agent-comsol`
   - 适用：纯建模、结构核查、会话内重建、几何修改、物理场配置、边界条件、网格、Study、Solver、只读盘点、单步 smoke test。
   - 链路：`Python/mph -> COMSOL Server`。
   - 当前最稳路线：从源模型插入函数和组件结构，优先使用 `func.insert(source_file, tag_list, [])` 与 `component.insert(source_file, ['comp1'], [])`。
2. `agent-comsol-matlab/simulink`
   - 适用：COMSOL 参数辨识、外循环优化、实验数据驱动标定、多参数非线性拟合、系统级优化器驱动 COMSOL。
   - 链路：`MATLAB LiveLink -> COMSOL Server`。
   - 默认原则：参数标定老老实实走协同路线，不引入临时 CSV 或乱搭外部文件依赖去驱动正式 COMSOL 模型。

### 外部依赖边界

1. `exp_*`、piecewise、interpolation 等函数若已存在于 `.mph` 内部函数体系，默认视为 COMSOL 模型内资产，应保留，不因其表现为分段或插值函数就误判为外部依赖。
2. 依赖核查必须显式检查函数节点或其他节点上的 `filename`、`sourcefile` 等属性。
3. 禁止把 `.codex_temp`、`case_*.csv`、临时导出表格、调试 CSV、临时 table 文件接入正式 COMSOL 模型。
4. 若发现正式模型挂接了外部临时文件，应先拆分“模型内资产”和“外部依赖污染”，不要把两者混为一谈。

### 核查顺序

1. 结构层：组件、几何、材料、物理场、多物理场、变量、选择集、Study、Solver 是否完整且可追溯。
2. 外部依赖层：是否挂接了 `.codex_temp`、`case_*.csv`、失效 `sourcefile`、异常 `filename` 或其他临时文件。
3. 物理语义与 KPI 层：边界条件、源项、耦合、材料、关键派生量和求解结果是否满足物理意义。
4. 洁净度层：是否存在无意义残留节点、污染性中间对象、冗余求解链、误导性函数源。

### 物理语义核查纠偏

1. FC 模块中的 `icph1`、`h2gasph1`、`o2gasph1` 在 UI 中显示“所有域”，不直接等于建模错误。COMSOL 会对不适用域自动过滤，界面可显示“不适用”。
2. 对 FC 模块，不能只凭“所有域”表面显示就下结论，必须结合具体子特征、实际适用域和求解 KPI 判断。
3. 对 Brinkman、多孔介质、入口出口、壁面、反应、源项等显式受域或边界控制的特征，仍需逐项核查真实选择与物理意义。
4. 父 physics 节点设置不能替代具体 feature 证据；涉及边界条件、反应、材料、初始值时，必须追到实际 feature 节点和 API 路径。

### Python/mph 能力边界

1. 已验证可靠：
   - 连接共享会话。
   - 只读盘点模型结构。
   - 读取真实标签和节点属性。
   - `func.insert()` 导入函数体系。
   - `component.insert()` 导入组件结构以及其几何、物理场、材料、变量、网格、探针等。
2. 当前未闭环验证能力：
   - 纯 Python/mph 从零稳定创建一个可直接挂复杂多物理场并可靠求解的完整 2D component。
3. 因此，本项目当前优先采用“源模型插入路线”，而不是把“从零纯 API 搭完整 2D 多物理场组件”当作默认能力。

## MATLAB/Simulink-COMSOL 协同自动建模

1. 协同任务先形成 `interface_contract`，明确 MATLAB 或 Simulink 传给 COMSOL 的参数、工况、边界条件，以及 COMSOL 返回的探针、派生值、场量摘要或代理模型参数。
2. 优先用 Simulink 完成快速系统级扫描和控制策略筛选，只把强敏感、强耦合、强约束或需要空间分布证据的局部问题交给 COMSOL。
3. COMSOL 结果回灌到系统级模型时必须保留单位、适用范围、插值或拟合边界、误差指标和物理解释，不能只回灌黑箱系数。
4. 协同验证至少包含接口读回、单工况 smoke test、关键 KPI 对照和失败栈摘要；长时间批量计算必须先通过小样本闭环。

## AMEsim 协同说明

1. 后续 AMEsim 正式建模主工作区为 `E:\agentwork_AMEsim_0625`，本项目中的 `03_AMEsim系统模型` 不作为 AMEsim 主开发目录。
2. 本项目需要 AMEsim 协同时，只引用 `E:\agentwork_AMEsim_0625` 中的模型资产、接口结果、KPI 摘要和审计报告。
3. AMEsim 结果回灌到 PEMFC-cEGR 系统模型时，必须附单位、适用范围、误差指标、变量语义和物理解释。

## Token 与产物控制

1. 不默认导出图片、CSV、报告、模型副本或大批量中间文件。
2. 必须生成中间产物时，放入任务专用输出目录，并使用可识别命名。
3. MATLAB 本地完成计算和筛选，只向 Codex 返回 KPI、摘要、失败栈、关键变量和必要证据。
4. 不把完整日志、完整 timeseries、完整模型树、Simulink 缓存或工作区 dump 塞进上下文。
5. COMSOL 任务不默认回传完整模型树、完整 Java dump、完整变量表、完整求解日志或批量导出图；只回传 KPI、必要错误栈、关键变量、证据路径和结论。
6. 任务结束前说明保留了哪些生成文件及用途。Simulink/Simscape 生成的 `slprj/`、`.slxc` 与当前模型运行缓存属于建模迭代环境，默认保留且不纳入 Git；只有用户明确要求、缓存损坏或需要专项释放空间时才清理。其他确无保留价值的临时文件，清理前应先说明范围并请求确认。
