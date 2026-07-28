# Route A cEGR-PEMFC Phase A 实施记录：设计基础（控制接口 + CR3 schema + 平台需求）

文件类型：实施记录（Phase A 平台能力升级产物）
记录日期：2026-07-27（补写 2026-07-28）
前置决策：[平台能力建设需求](../../01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
Git 提交：`ec6dcec`（5 files changed, +655/-1），前置需求 `be52a35`（2 files, +140）

---

## 0. Phase A 目标

Phase A 是平台能力升级的第一阶段，在 S2/S3 验证完成之后。目标是为后续模型优化和平台化工作建立**设计基础**——明确平台的输入规范、控制接口全貌、以及后续工作的原则和路线图。Phase A 不修改模型本体，不新增脚本运行逻辑。

---

## 1. 平台能力建设需求（`be52a35`）

用户确认 S2/S3 稳态验证全部完成后，进入新阶段。核心定位：将现有模型从"科研脚本集合"升级为"工程师可操作、可扩展的通用仿真平台"。

### 1.1 三个建设维度

| 维度 | 内涵 |
|---|---|
| 结构集成 | 一个 Simulink 模型，派生官方案例，含完整系统拓扑、控制方法、cEGR 技术 |
| 参数匹配 | 参数与结构解耦，参数可独立维护、可追溯来源 |
| 工具化/可视化/扩展化 | 从脚本调用升级为 MATLAB 面板，工程师可操作 |

### 1.2 核心原则

| 原则 | 内容 | 对后续工作影响 |
|---|---|---|
| 模型优先 | 模型是核心，脚本和面板是辅助 | Phase B 先管模型 profile 收缩，Phase D 才做面板 |
| 鲁棒性 > 极简 | 功能不重复，但具备通用性 | 不强制脚本极简化 |
| 不纠结热启动 | v09 初态能解决就解决，不能就冷态 | 初态门槛从阻断降为偏好 |
| 22 列 profile 必须清理 | 趁本次任务彻底收缩为结构体 | B1 的起点 |
| 模型唯一 | 一个 `.slx`，所有模式在模型内切换 | B2 只做文档化，不修改变体结构 |

### 1.3 文件管理规则（首次确立说明文件分类）

| 规则 | 内容 |
|---|---|
| 唯一模型 | 整个平台只有一个 `.slx` |
| 脚本最小化 | 脚本不承担计算功能，仅辅助 Simulink。禁止因多策略/多工况导致脚本爆炸。临时脚本使用后立即归档 |
| 说明文件分类 | 规划设计类（覆盖式更新）和实施记录类（增量式更新）。禁止无限制叠加重复内容。阶段性任务完成后更新所有相关文件 |

最后一条建立了说明文件的二分类，为后续 Phase B-D 的文档纪律奠定基础。

---

## 2. 控制接口汇总表（Phase A 第一交付件）

### 2.1 内容

在 [控制接口汇总表_v01.md](../../01_当前指导/RouteA_cEGR_PEMFC_控制接口汇总表_v01.md) 中，以表格形式明确定义了 Route A 平台所有控制接口。文件本身标注为「规划设计文件（平台能力清单）」。

**主动控制量**（用户/脚本可设定）：

| 域 | 控制量数 | 实现方式 | 备注 |
|---|---|---|---|
| 电边界 | 8（模式+电流/功率/电压命令+PI 参数+限幅） | `setBlockParameter` + workspace 变量 | 一次计算只选一种模式 |
| 阴极气路 | 11（控制模式、OER、流量、源压力/温度/组分、出口压力、加湿器） | workspace 变量 | O2/H2O 组分编译时固定 |
| cEGR | 5（启用、阀模式、控制模式、目标比、直接面积） | workspace 变量 | 编译时 + 时序 |
| 阳极 | 12（源压力/温度/组分、入口压力、加湿器、再循环、吹扫） | workspace 变量 | 部分编译时、部分时序 |
| 热管理 | 3（堆温设定、环境温度/压力） | workspace 变量 | 编译时 |
| 求解器 | 5（类型、容差、最大步长、停止时间） | `setModelParameter` | 编译时 |

**响应量**：堆电压/电流/功率/温度、cEGR 率/阀面积、空气流量/OER、阴极/阳极压力/温度/湿度、水账本、气体组分、电效率等 30+ 信号，均可通过 `logsout` 观测。

### 2.2 与后续工作的衔接

- 控制接口汇总表是 Phase B `routeA_assemble_command_profile` 的字段默认值来源
- 是 Phase B `routeA_platform_default_parameters.params.controls` 域的直接映射依据
- 是 Phase C simCase 接线的对照表
- 是 Phase D 面板可设置参数清单的基础

---

## 3. CR3 三要素 schema（Phase A 第二交付件）

### 3.1 内容

在 [CR3三要素schema_v01.md](../../01_当前指导/RouteA_cEGR_PEMFC_CR3三要素schema_v01.md) 中定义了标准化 `simCase` 结构体，作为计算输入的统一格式。文件本身标注为「规划设计文件（平台输入规范）」。

CR3 三要素 = 每次计算开始前必须明确的三方面内容：

```
simCase
├── caseId / description       — 任务标识（必填）
├── initialState               — (a) 初始状态：命名模式(cold/warm/hot) + 源文件 + 物理初值
├── controls                   — (b) 控制设置：电边界+阴极+cegr+阳极+热管理的分域 struct
└── solver                     — (c) 求解器设置：类型/容差/步长/停止时间
```

**关键设计决策**：
- `initialState` 保留 warm/hot 模式定义，但 Phase B 确定冷态默认可用，不强制要求 v10 初态
- `controls` 按设备域分 struct（`electrical`、`cathode`、`cegr`、`anode`、`thermal`），与控制接口汇总表的域划分一脉相承
- `solver` 与 `platform_default_parameters.params.numerics` 默认值对应，为后续参数文件接线留接口

### 3.2 `simCase_template` 代码实现

新建 [routeA_simCase_template.m](../../../03_脚本/RouteA_GasMixture_Derived/routeA_simCase_template.m)（131 行），返回标准化 simCase 结构体模板，包含所有字段的默认值和内联文档。这是一个纯规范函数，不运行仿真，不修改模型。它实现了 CR3 schema 的 MATLAB 代码化表达。

**与后续工作的衔接**：
- Phase B 的 `routeA_assemble_command_profile` 输入 `controls` 直接复刻了 `simCase.controls` 的域结构（`electrical`、`cathode`、`cegr`、`anode`、`thermal`）
- Phase B 回归脚本 `run_routeA_phaseB_regression.m` 的 `controls` 构造即是对 simCase 格式的手工实例化

---

## 4. 阻塞点

Phase A 仅生产说明文件和模板代码，不涉及仿真运行，无 MCP/MATLAB 阻塞点。

---

## 5. 经验教训

| # | 问题 | 根因 | 解决 |
|---|---|---|---|
| 1 | 未及时写实施记录 | 项目 02_实施记录/README.md 缺少"每阶段完成必须增补实施记录"的触发规则 | 本文件补写；脉冲项目规范已移植到 CEGR-PEMFC 项目 |

---

## 6. 完成状态

- ✅ 平台能力建设需求文档
- ✅ 控制接口汇总表（主动控制量 44 项 + 响应量 30+ 项）
- ✅ CR3 三要素 schema 定义
- ✅ simCase_template.m 代码实现
- ✅ Git 提交 `ec6dcec`

**Phase A 产物全部进入 `01_当前指导/`，作为 Phase B-D 的设计依据。**
