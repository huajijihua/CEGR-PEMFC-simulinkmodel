# MathWorks Official Examples R2025b

归档日期：2026-07-06

本目录为从本机 MATLAB 示例缓存复制出的官方示例快照，来源目录为：

`C:\Users\ADMIN\Documents\MATLAB\Examples\R2025b`

## 子目录

| 子目录 | 原始来源 | 主要用途 |
|---|---|---|
| `01_GasMixture_PEMFuelCellSystemWithCustomLibrary` | `simscapefluids\PEMFuelCellSystemWithACustomLibraryExample` | Gas Mixture / 自定义库 PEMFC 示例，优先用于四物种气体域和 cEGR 主骨架分析 |
| `02_MoistAir_PEMFuelCellSystem` | `simscape\PEMFuelCellSystemExample` | Moist Air PEMFC 系统示例，用于 BOP 架构、压缩机、加湿、冷却、背压阀参考 |
| `03_FCEV_ReferenceApplication` | `autoblks\FCEVRefApplicationExample` | Fuel Cell Electric Vehicle reference application，用于整车控制、mapped fuel cell、系统接口参考 |

## 配套气路复用资料

- [Simscape Fluids 燃料电池气路组件复用调查与建模建议](04_SimscapeFluids_燃料电池气路组件复用调查_v01.md)：记录本机 `SimscapeFluids_lib.slx` 的 Gas/Moist Air 阀门、孔口、阻力、管路和容腔组件，以及官方 `FuelCell_lib.slx` 的 FC 域复用边界。

## 使用纪律

- 本目录是官方示例材料归档，不是当前项目主模型。
- 后续若要修改、裁剪或派生模型，应另建工作副本，不直接覆盖本目录原始快照。
- MATLAB Examples 原始缓存不移动、不删除；本目录只作为项目材料池中的可追溯副本。
