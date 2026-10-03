# 验证记录

## GitHub 发布前回归 — 2026-10-03

在 MATLAB 9.12.0.1884302 (R2022a) 实际执行现有完整测试入口：

```matlab
run('tests/runAll.m');
```

**121 项测试，121 通过、0 失败、0 未完成，MATLAB 进程退出码 0。**

- [发布前 summary.json](evidence/release-summary.json)
- [发布前逐项 results.csv](evidence/release-results.csv)
- [开发基线 summary.json](evidence/baseline-summary.json)
- [开发基线逐项 results.csv](evidence/baseline-results.csv)

发布前运行生成的本地报告目录为 `artifacts/tests/20261003_165449_467/`。完整日志和 MAT 文件保留在开发机，不随发布仓库上传。

覆盖：公式语法和非法输入、变量与初值校验、公式导出、原生 SLX 生成与重建、实际参数和连线修改后的反向提取、嵌套子系统与信号路由、Transfer Fcn 和 State-Space、数值及符号传递函数、工作点线性化、独立解析解和 ODE 仿真、跨模块管道、中文界面。

复杂模型独立对比包括原生模型、提取后重建模型和手写解析解 / ODE；本次日志记录的七组案例最大误差为 `2.32258656752e-13`，固定阈值为 `2e-7`。

## 开发阶段的额外演示

开发记录中第二版界面端到端演示通过，输出 `V2_UI_COMPLEX_SYMBOLIC_LINEARIZATION_OK`，退出码 0。该演示未在本次包装过程中单独重跑；本次已重跑全部 UI 自动测试。

- 质量—弹簧符号表达式与独立手写 `1/(m*s^2+c*s+k)` 经 simplify 差为零。
- 嵌套模型 `dx/dt = u - x^3`、`y = x^2` 在 `x=1, u=1` 得到 `A=-3, B=1, C=2, D=0`，平衡残差为零。
- 该模型仿真与独立 ODE 最大误差为 `3.7872e-12`，预设阈值 `1e-6`。
- 小信号独立验证中，扰动 `0.1、0.05、0.025` 的误差缩放比约为 4，与一阶近似一致。
- 中文公式、符号分析和线性化 LaTeX 曾用 XeLaTeX + ctex 编译成功；本次未重跑 TeX 编译。

[符号界面截图](images/symbolic-interface.png) 与 [线性化界面截图](images/linearization-interface.png) 来自开发阶段真实演示。

## 支持边界

已验证 MATLAB R2022a；其他版本尚未验证。二阶隐式方程、任意第三方模型、模型引用、Simscape、Stateflow、离散和混合系统未覆盖，详见 [模型支持矩阵](model-support.md)。

公开仓库不包含本地开发备份、全部历史生成模型、SLXC 缓存及自动保存文件。测试与界面运行会重新生成 `artifacts/`。仅加载可信模型；受限表达式解析器不构成 SLX 加载沙箱。