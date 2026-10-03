# 版本记录

## v0.2.0 — 2026-10-03

首次 GitHub 发布，包含第二版完整功能。

- 中文 MATLAB 界面与五个 JSON 示例。
- 显式一阶方程生成原生 Simulink 模型、JSON 与重建脚本。
- 模型反向提取：连续标量基础模块、嵌套虚拟子系统、Goto/From、SISO Transfer Fcn 与 State-Space。
- 独立公式导出、数值与符号参数传递函数、非线性工作点线性化。
- 单位输入仿真及独立 ODE 对比；完整回归包含 121 项测试。

已验证环境为 MATLAB R2022a；其他版本尚未验证。支持边界见 README 与 docs/model-support.md。
