# Route A cEGR-PEMFC 仿真工具链与协同接口约束

文件类型：当前指导（项目专属工具链与接口）  
适用范围：Route A 系统级建模、局部 COMSOL 校核、AMESim 外部协同与结果回灌。

## 1. 路线分工

1. MATLAB/Simulink 是 Route A 的系统级主线，负责模型修改、系统动态、控制、参数研究、优化、数据处理和结果审计。
2. COMSOL 仅承担局部几何、多物理场、空间分布、边界条件和关键部件校核；不替代系统级主模型。
3. AMESim 正式资产位于 `E:\agentwork_AMEsim_0625`。本项目只接收带单位、适用范围、误差指标、变量语义和物理解释的接口结果。
4. 具体客户端 MCP session、工具命名空间和启动方式由 CCswitch 投影与相应 workflow skill 决定，不在本文件重复定义。

## 2. COMSOL 项目约束

1. 当前历史 COMSOL 模型已外置归档。继续工作前，先恢复外部归档或建立受控工作副本；不得按二进制、XML 或文本方式修改 `.mph`。
2. 项目默认共享 COMSOL Server 端口为 `2036`。同一模型只允许一条 agent 控制链路；脚本默认不保存 `.mph`，除非用户明确授权保存目标、文件名和原因。
3. 纯结构核查、增量建模、边界条件、网格、Study、Solver 与单步 smoke 使用 COMSOL 路线；参数辨识、外循环优化和实验数据驱动标定使用 MATLAB LiveLink 协同路线。
4. 模型内 `exp_*`、piecewise、interpolation 等函数应先判定为内部资产。显式检查 `filename`、`sourcefile` 等属性，禁止将 `.codex_temp`、`case_*.csv`、临时 table 或调试导出接入正式模型。

## 3. 协同接口契约

任何 MATLAB/Simulink、COMSOL 或 AMESim 间数据交换必须定义 `interface_contract`，至少包括：

- 参数名、物理意义、单位、来源与适用范围；
- 输入工况、边界变量、模型版本和数据格式；
- 输出变量、探针或派生量、后处理方法与误差指标；
- 回灌位置、插值或拟合边界、验收 KPI 和物理解释。

协同验证至少包含接口读回、单工况 smoke、关键 KPI 对照与失败栈摘要。批量计算前必须先完成小样本闭环；不得只回灌无单位、无适用范围或无法解释的黑箱系数。

## 4. Route A 结果与保存边界

1. 当前 Route A 使用正式 runner、`SimulationInput`/`sim` 输入装配和可追溯的 `platform_default`/`external_case` 分层。
2. COMSOL 或 AMESim 结果回灌后，必须在系统级模型中复验其适用工况和 KPI；局部校核不自动构成系统级结论。
3. 结构修改后的保存、`Dirty=off`、实施记录和 Git 收口以项目根 `AGENTS.md` 及 `02_实施记录/README.md` 为准。
