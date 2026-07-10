# RouteA A9.9 阴极背压控制接口审计 v01

## 1. 结论

当前 Route A 的阴极出口不是纯开放边界，也不是固定开度被动背压阀。模型中 `Cathode Exhaust/Pressure Relief Valve` 是带压力设定端的 pressure relief/backpressure regulator：出口压力边界由目标压力、阀特性、流量、阴极通道/管路流阻和物理网络共同求解。

A9.9 已把原固定 `0.06 MPa` 背压偏置规整为模型工作区变量：

```text
routeA_target_p_ca_out_MPa
```

`Cathode Exhaust/Stack Pressure` 现在使用：

```text
routeA_target_p_ca_out_MPa - env_p
```

经 `env_p` 相加后送入 `Pressure Relief Valve` 的压力设定端。

## 2. 语义边界

| 项 | 当前语义 |
|---|---|
| 背压阀类型 | 目标压力驱动的 pressure relief/backpressure regulator |
| 出口边界 | 非纯开放；由 `routeA_target_p_ca_out_MPa` 给定压力目标 |
| 压降来源 | 电堆/阴极通道、出口管路、阀特性和流量共同决定 |
| FCU 接口 | A9.9 第一版暴露目标压力 setpoint，不新增外层 PI |
| 后续扩展 | 若要复刻“阀开度型背压控制”，再新增 `target_p_ca_out -> PI -> controlled area valve` 变体 |

## 3. 审计结果

入口：`run_routeA_a9_9_backpressure_control_audit.m`

结果：`generated=1`、`passed=1`、`cases=3/3`

| case | target p_ca_out | measured p_out | error | measured mdot |
|---|---:|---:|---:|---:|
| `p_ca_out_0.145MPa` | 0.145 MPa | 0.146 MPa | 0.001001 MPa | 0.04478 kg/s |
| `p_ca_out_0.161MPa` | 0.161325 MPa | 0.1622 MPa | 0.0008902 MPa | 0.04391 kg/s |
| `p_ca_out_0.180MPa` | 0.180 MPa | 0.1807 MPa | 0.0007253 MPa | 0.03872 kg/s |

三点目标压力升高时，实测阴极出口压力单调升高，且短工况末值误差约 0.7-1.0 kPa。当前审计证明压力设定接口有效；不代表背压阀动态参数已经完成产品级标定。
