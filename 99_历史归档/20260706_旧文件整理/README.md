# 20260706 旧文件整理归档

本目录用于收纳进入下一阶段 PEMFC-cEGR 系统级建模前，从项目根目录和活跃目录移出的旧输出、重复脚本、工作副本、候选模型和本地生成物。

## 归档范围

- `01_旧汇报与输出/outputs/`：原根目录 `outputs/`，主要是 20260606、20260608、20260612 的汇报输出、预览图片、前端演示依赖，以及 `comsol_2036_inventory.json`。
- `02_COMSOL候选模型与临时脚本/`：未跟踪的 20260629 Claude/Codex COMSOL 候选构建模型、COMSOL 克隆/参数整理临时脚本和 COMSOL 建模核查经验文件。
- `03_重复脚本与工作副本/`：根目录重复的 `fit_comsol_echem_polarization_stage1.m`，以及 20260701 带时间戳的电化学标定 workcopy。
- `04_本地缓存与自动生成物/`：`.cache`、`slprj`、`.slxc`、`.autosave`、脚本目录 `.codex_matlab_pref` 等 MATLAB/Simulink 或本地工具生成物。
- `05_本地客户端设置/`：原 `.claude/settings.json` 的归档副本。

## 未移动的当前主线

- 简化台架主线模型、脚本、参数真源和工况真源仍保留在 `01_自吸方案/03_台架测试_10kW_简化版/`。
- 已跟踪的 20260624 COMSOL 基线模型仍保留在 `02_多物理场机理模型演示/`。
- Codex/Claude MATLAB 启动脚本仍保留在 `02_多物理场机理模型演示/02_脚本/`，因为项目规则仍引用它们。
- 根目录 `node_modules` 是指向 Codex runtime 的 junction，本轮未移动。

## Git 说明

本轮是整理归档，不是删除。若 Git 显示原 `outputs/*` 删除，同时 `99_历史归档/...` 下出现对应文件，含义是移动归档。`slprj`、`.slxc`、`node_modules` 等仍受 `.gitignore` 规则约束。
