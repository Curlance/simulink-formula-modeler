<p align="center">
  <img src="docs/images/logo.svg" width="104" alt="Simulink Formula Modeler 图标">
</p>
<h1 align="center">Simulink Formula Modeler · 公式建模</h1>
<p align="center"><a href="README.md">English</a> | <strong>简体中文</strong></p>
<p align="center"><strong>从公式出发。建模、提取、分析。</strong></p>
<p align="center">本地 MATLAB 工具 · 可编辑的 Simulink 模型 · 符号传递函数 · 工作点线性化</p>
<p align="center">
  <a href="https://github.com/Curlance/simulink-formula-modeler/releases/latest">下载 ZIP</a> ·
  <img src="https://img.shields.io/badge/version-v0.2.1-6366f1" alt="版本 v0.2.1">
  <img src="https://img.shields.io/badge/MATLAB-R2022a-f59e0b" alt="MATLAB R2022a">
  <img src="https://img.shields.io/badge/tests-121_passed-22c55e" alt="121 项测试通过">
  <img src="https://img.shields.io/badge/UI-简体中文-0ea5e9" alt="中文界面">
</p>
<p align="center">
  <a href="https://github.com/Curlance/simulink-formula-modeler/releases/tag/v0.2.1">v0.2.1 发布</a> ·
  <a href="#界面预览">界面预览</a> · <a href="#启动">快速开始</a> ·
  <a href="docs/model-support.md">模型支持</a> · <a href="CHANGELOG.md">版本记录</a>
</p>

![项目展示：公式 → 模型 → 分析](docs/images/banner.svg)

MATLAB R2022a 下已实现并通过验证的个人工具。用公式自动搭建可编辑的 Simulink 模型，从实际模型反向提取方程，导出公式，并做数值 / 符号传递函数推导与非线性工作点线性化。

## 下载与环境

通过 GitHub 的 **Code → Download ZIP** 下载并解压，或运行：

```bash
git clone https://github.com/Curlance/simulink-formula-modeler.git
```

| 依赖 | 用途 |
| --- | --- |
| MATLAB（已验证 R2022a） | 界面、表达式解析与公式导出 |
| Simulink | 生成、读取与仿真模型 |
| Control System Toolbox | 数值传递函数和工作点线性化 |
| Symbolic Math Toolbox | 符号参数传递函数 |
| XeLaTeX + ctex（可选） | 将导出的中文 LaTeX 编译为 PDF |

其他 MATLAB 版本尚未验证。无需额外 Python 环境。

## 启动

在 MATLAB 命令窗口执行：

```matlab
cd('path/to/simulink-formula-modeler'); % 替换为实际下载目录
launch;
```

界面为中文。无需安装 Python 或调用云端服务。建模与模型提取需要 Simulink；传递函数分析需要 Control System Toolbox；符号分析需要 Symbolic Math Toolbox。

## 已实现能力

- 公式自动建模：显式一阶常微分方程组 → 可编辑的原生 SLX、原始 JSON 与重建脚本。
- **A 模型转公式**：读取实际模块参数、连线和初值，导出平坦一阶方程。
- **B 公式整理导出**：独立导出文本、LaTeX 完整文档与 Markdown，不依赖生成模型。
- **C 输入输出关系**：结构证明后提取 A/B/C/D 与数值传递函数，支持多输入输出及直接馈通。
- 单位常值输入仿真、响应曲线保存，并与独立积分的方程解对比。
- 中文界面：公式编辑、模型生成 / 打开 / 提取、三种分析模式、结果保存。

## 分析与模型支持

### 复杂模型解析

`fm.simulink.extractEquations` 现支持嵌套普通子系统（多端口、稳定命名、完整模块路径）、Goto/From 信号路由（local / scoped / global，含作用域歧义检测）、Terminator、SISO Transfer Fcn 与 SISO 多状态 State-Space（保留向量或标量扩展初值）。输出保留 `sourceMap`，可追溯到原模块路径。

不支持的结构（带控制端口的子系统、atomic、Variant、mask、库链接、模型引用、离散 / 延迟 / Mux / Demux / Bus / Stateflow / Simscape、MIMO 或向量接口）会被**明确拒绝并给出模块全路径**，不会静默跳过。详见 `docs/model-support.md`。

### 符号参数传递函数

`fm.analysis.deriveSymbolicTransferFunction(raw, options)` 保留指定参数为符号，输出符号 A/B/C/D、传递函数矩阵、各通道表达式、中文推导说明与 LaTeX。

- 参数值可填数值或精确字符串 `"symbolic"`；未赋值参数不会被占位数值冒充。
- 「保留符号参数」留空表示全部保留；填 `m,k` 则只保留这两项，其余数值参数代入。
- 保留原式的除法与幂定义域条件，即使化简后仍要求 `m ~= 0` 等条件。
- 线性性用符号 Jacobian 加残差恒等严格证明，不做数值采样；无法证明时保守拒绝。

详见 `docs/symbolic-analysis.md`。

### 非线性工作点线性化

`fm.analysis.linearizeAt(spec, operatingPoint, options)` 在显式数值工作点计算解析 Jacobian。

- 必须完整给出全部状态与输入的工作点，字段缺失或多填都报错。
- 默认要求平衡点，并报告状态导数残差；非平衡点默认报错，显式允许后返回带漂移项的仿射局部展开，且不给出误导性的传递函数。
- 返回 A/B/C/D、`f0`、`y0`、工作点、平衡残差、`system`、`transferSystem`（仅平衡时）及中文说明。
- 明确标注为局部小扰动近似，不是全局等价模型。

详见 `docs/linearization.md`。

## 脚本调用示例

从仓库根目录运行：

```matlab
addpath(pwd);
raw = jsondecode(fileread('examples/mass_spring_damper.json'));
spec = fm.core.validateSpec(raw);
folder = tempname(fullfile(pwd, 'artifacts')); % 每次使用新输出目录
modelPath = fm.simulink.generateModel(spec, folder);
open_system(modelPath);
result = fm.analysis.deriveTransferFunction(spec);
disp(result.system);
```

## 界面预览

![符号参数传递函数界面](docs/images/symbolic-interface.png)

![非线性工作点线性化界面](docs/images/linearization-interface.png)

## 验证证据

开发阶段在 MATLAB R2022a 完成 **121 项测试，121 通过、0 失败、0 未完成**。精简原始结果见 [summary.json](docs/evidence/baseline-summary.json) 与 [results.csv](docs/evidence/baseline-results.csv)。发布前回归结果见 [验证记录](docs/verification-report.md)。

端到端界面演示覆盖符号推导、嵌套模型提取和工作点线性化；嵌套非线性模型仿真与独立 ODE 最大误差为 `3.7872e-12`（阈值 `1e-6`）。

GitHub 仓库保留源码、示例、测试、文档、精选截图与精简测试证据。运行产生的 `artifacts/`、Simulink 缓存和开发备份保留在本地，不纳入版本控制。

## 已知限制

- 输入为显式一阶方程组；二阶系统需先写成一阶状态形式（当前不支持直接二阶隐式方程解析）。
- 模型解析覆盖常见的连续标量基础模块、嵌套虚拟子系统和信号路由；带控制端口子系统、模型引用、Simscape、Stateflow、离散与混合系统仍不支持，会明确报错。
- R2022a 原生 Transfer Fcn 没有可设置的初值，固定零初值；需要非零初值请用 State-Space。
- 符号推导对无法证明的恒等式保守拒绝，不枚举特殊参数退化分支。
- 线性化只支持可解析微分的实域表达式；零底数的复杂分数幂保守拒绝。
- 方程与模型不自动同步：改模型后重新提取，改公式后重新生成，改分析输入后重新运行分析。
- LaTeX 输出为可编译的数学文档，需自行用 XeLaTeX 编译为 PDF。
- 仅打开可信的本地模型。MATLAB 加载模型可能执行文件内回调；公式解析器的受限输入不等于 SLX 文件安全沙箱。

## 测试

```matlab
run('tests/runAll.m');
```

所有产物集中在项目目录，操作输出默认写入 `artifacts/exports`。模型、公式与分析导出均拒绝覆盖已有同名产物。

## 文档

- `docs/quick-start.md`：中文操作指南。
- `docs/v2-guide.md`：第二版功能的使用说明。
- `docs/model-support.md`：复杂模型支持矩阵。
- `docs/symbolic-analysis.md`：符号分析接口、条件与安全规则。
- `docs/linearization.md`：线性化语义与实数域边界。
- `docs/verification-report.md`：完整验证记录。
- [版本记录](CHANGELOG.md) 与 [开发说明](CONTRIBUTING.md)。

## 许可

目前未授予开源许可证。公开仓库可供查看；再分发、修改后发布或商业使用请先联系仓库所有者。
