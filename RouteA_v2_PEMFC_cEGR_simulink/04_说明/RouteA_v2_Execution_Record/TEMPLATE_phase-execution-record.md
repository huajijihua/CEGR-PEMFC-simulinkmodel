# RouteA_v2 Phase <N> Execution Record

记录编号：`R<N>_<short-name>_<YYYYMMDD>_vNN`
阶段：`Phase <N>`
状态：`PENDING | IN_PROGRESS | PASSED | PASSED_WITH_OPEN_RISKS | BLOCKED | DEFERRED`
日期：YYYY-MM-DD
执行人：
目标模型/脚本：
前置记录：
对应计划：[实施计划](../RouteA_v2_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)

## 1. 目标和边界

### 本次目标

### 允许修改范围

### 禁止修改范围

### 保持不变的假设

### 回滚边界

## 2. 输入和基线

| 项目 | 实际值/路径 |
|---|---|
| v2 模型 | |
| 模型根名称 | |
| 模型 hash/文件时间 | |
| 脚本版本 | |
| 参数层 | |
| case 输入 | |
| solver/容差/MaxStep | |
| 初态类型和来源 | |
| MATLAB/Simulink 版本 | |
| 相关文献/官方来源 | |
| 上一阶段状态 | |

## 3. 实际执行

按时间顺序记录实际发生的操作；没有执行的计划不要写成结果。

1.
2.
3.

## 4. 变更清单

| 对象 | 变更前 | 实际变更 | 变更后读回 | 是否保存 |
|---|---|---|---|---|
| | | | | |

## 5. 验证证据

| 检查 | 结果 | 证据路径/摘要 |
|---|---|---|
| read-back | `PASS/FAIL/NOT_RUN` | |
| `model_check` | `PASS/WARN/FAIL/NOT_RUN` | |
| update/compile | `PASS/FAIL/NOT_RUN` | |
| 最小仿真 | `PASS/FAIL/NOT_RUN` | |
| KPI/守恒 | `PASS/FAIL/NOT_OBSERVABLE/NOT_RUN` | |
| 磁盘保存核对 | `PASS/FAIL/NOT_RUN` | |

不要用旧模型、旧结果或静态检查填充“当前模型最小仿真”。

## 6. 结果和失败分类

### 结果摘要

### warning/error 分类

使用 `STRUCTURE`、`INITIALIZATION`、`NUMERICAL`、`PHYSICAL`、`CONTROL`、`OBSERVABILITY` 或 `CONFIGURATION`。

### 失败栈和最小复现输入

### 结果文件

只引用 `../../05_结果/` 中的摘要、KPI 或失败栈，不在本目录复制大文件。

## 7. 出口条件判定

| 出口条件 | 判定 | 证据/未满足原因 |
|---|---|---|
| | `PASS/FAIL/OPEN` | |

## 8. 未决项、暂停和下一步

### 未决项

### 是否阻断下一阶段

### 暂停/回滚决定

### 下一阶段准入条件

## 9. 结论

只写与本记录证据强度匹配的结论。明确说明未验证项，不使用“基本完成”或“应该可以”等替代状态。
