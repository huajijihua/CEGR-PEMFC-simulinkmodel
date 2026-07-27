# RouteA_before

This is an isolated Git snapshot of the RouteA model before the v10 physical hot-start and command-profile changes.

## Source

- Git commit: `7f20c7a9086af304b6006c6748bd1189ba2d80a6`
- Commit subject: `feat(routea): unify I/P/V runner and v09 warm starts`
- Source branch state: this commit is in `origin/master`
- Snapshot date: 2026-07-22

The selected commit is the historical point that introduced the unified Current, Power, and Voltage runner and contains the three-branch `RouteA_platform_default_initial_state.mat`. The RouteA engineering specification at that commit records three 2 s warm-start smoke runs with finite I/V/P and no warnings. That statement is historical evidence from the committed record; this isolated copy is not silently declared revalidated by this copy operation.

## Contents

- `01_模型/RouteA_GasMixture_Derived/`: RouteA `.slx`, platform parameter script, drive-cycle data, and the three-branch initial-state MAT file.
- `03_脚本/RouteA_GasMixture_Derived/`: electrical-boundary runner, Current/Power/Voltage matrix runners, initial-state helpers, and related RouteA scripts.
- `04_说明/`: the committed RouteA engineering specification, implementation record, and IPV runner interface note.

The snapshot contains 42 files copied from the commit tree. It does not replace or modify the active `RouteA_v2_PEMFC_cEGR_simulink` model, scripts, results, or execution records.

The `_git_provenance_7f20c7a/` directory contains the source archive and extraction residue kept for provenance after the directory move. It is not part of the model entry and is not required to run the snapshot.

## Model entry

- Model: `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
- Initial state: `01_模型/RouteA_GasMixture_Derived/RouteA_platform_default_initial_state.mat`
- Main runner: `03_脚本/RouteA_GasMixture_Derived/run_routeA_electrical_boundary_study.m`
