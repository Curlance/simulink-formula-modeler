# 复杂 Simulink 模型解析（第二版）

`spec = fm.simulink.extractEquations(pathOrLoadedName)` 读取实际模块、参数、连线和初值，输出平坦的一阶标量状态方程。支持 MATLAB/Simulink R2022a；提取本身不依赖 Control System Toolbox，也不更新或编译模型。

## 当前支持范围

| 模块 | 范围 |
| --- | --- |
| Integrator | 连续、标量、内部初值，无限幅、复位、附加状态端口 |
| Inport / Outport | 顶层标量实数 double；内部端口可继承类型/宽度，逐层根据端口编号解析 |
| 普通 SubSystem | 未加 mask、未链接库、虚拟、无控制端口，可嵌套、有多个标量输入/输出 |
| Goto / From / Goto Tag Visibility | local、scoped、global；支持跨普通子系统路由和反馈 |
| Terminator | 接收并验证其输入，既不产生输出也不增加状态 |
| Transfer Fcn | 连续 SISO、proper、有理传递函数，数值行向量系数；不约去内部状态 |
| State-Space | 连续 SISO、多内部状态：A 为非空 n×n，B 为 n×1，C 为 1×n，D 为标量 |
| Constant / Gain / Sum / Product | 原有标量运算；不支持单输入向量归约 |
| Math / Trigonometry | pow、exp、sin、cos |

即使一个模块不在顶层输出或状态导数的可达路径上，也会检查其类型、配置、输入连接、路由和代数环。错误包含相关原模块的完整路径。状态模块的无直接馈通输出会切断代数依赖，因此正常状态反馈不会误判为代数环；D 非零的动态模块参与代数环检查。

## 动态及初值

State-Space 严格使用 `xdot=A*x+B*u`、`y=C*x+D*u`，按原矩阵行顺序展开状态。向量初值逐项保留，标量初值按 Simulink 语义扩展到每个状态。不会对系统做最小实现、删除不可观状态或用零初值覆盖非零初值。

R2022a 原生 Transfer Fcn **没有可设置的初始状态参数，初始状态固定为零**。解析器将分母首项归一化，使用可控伴随形式展开，保留直接馈通项。例如归一化分母为 `[1 a1 ... an]`，补齐后的分子为 `[b0 b1 ... bn]`：

- A 首行为 `[-a1 ... -an]`，下方为移位单位阵；B 为 `[1;0;...;0]`。
- D=`b0`，C=`[b1 ... bn]-b0*[a1 ... an]`。
- 对这个零初值实现验证的是输入/输出等价；不宣称合成状态一定对应 Simulink 未公开的内部状态坐标。
- 常数传递函数可作为无状态增益参与有状态模型；整体仍必须包含至少一个连续状态和一个顶层输出，这是现有 spec 的要求。

需要非零初值的传递函数模型请使用 State-Space 并明确选择状态实现。模型级 `LoadInitialState=on`（包括恢复保存状态）明确拒绝，避免把外部初值或 SimState 静默解释成模块默认值。

## 安全参数语法

模型工作区必须使用 Model File 数据源，可包含有限实数标量或二维数值数组。禁止基础工作区取值、数据字典、工作区脚本、Simulink.Parameter 对象以及任意代码求值。

- 原有标量参数仍使用受限 AST：如 `-k/2`、`k+1`；Constant/Gain/Integrator 不因矩阵支持而接受向量信号。
- 动态矩阵/系数可以写安全字面量：`[1 -2; 3 4]`、`[1e-2, -k; +3 .4]`。
- 可以使用一个完整工作区数组标识符，例如 `plantA`；数组在本次提取时数值化。
- 数组内部仅允许数值字面量或带可选正负号的标量参数标识符。`[k+1 2]`、`zeros(...)`、`eye(...)`、索引、冒号、转置、复数、Inf/NaN、拼接表达式和执行语句均拒绝。
- 数组参数不会放入仅允许标量的 `spec.parameters`；其数值进入导数/输出表达式。编辑原模型数组后重新提取，会生成更新后的表达式。

解析实现不使用 `eval`、`str2num`、`str2func` 或 workspace expression evaluation。**加载 SLX 是 MATLAB 原生加载操作，可能在事后检查前执行加载回调；这不是任意 SLX 的安全沙箱。只导入可信本地模型。** 发现模型/模块回调或 mask 后拒绝解析。

## 命名和来源追踪

- 根输入/输出按 Port 编号排序。子系统每组端口必须从 1 连续排列。
- 状态块以完整路径稳定排序，兼容已有 `fmOrder` 命名元数据；同块动态状态按索引排列。
- 嵌套状态名包含完整相对父路径；多状态动态模块加 `_x1`、`_x2` 等后缀。
- 空格、标点等转成下划线；保留字、各角色重名和截断冲突用确定性的序号去重。`fmName` 只作为命名提示，不能提供方程。
- `sourceMap.states.<state>`、`sourceMap.inputs.<input>`、`sourceMap.outputs.<output>` 保存原模块完整路径；`sourceMap.stateIndices.<state>` 保存块内状态索引（从 1 开始）。这些字段不参与公式求值。

提取不会调用模型 update、修改参数或连线，也不会保存模型。用户已经加载的模型始终保持打开；只有提取器自行加载的模型会在结束时关闭。

## 路由边界和明确拒绝的情况

local tag 仅在同一父系统可见；同名 local tag 可以在兄弟子系统各自使用。scoped tag 必须有同 tag 的上级 Goto Tag Visibility，采用最近声明确定范围；其 Goto/From 必须处于该范围内。global tag 跨整个已支持的虚拟层级可见。

当前采用保守且明确的路由子集：同 tag 的 Goto 可见范围重叠时直接报 `fm:AmbiguousRouting`，不猜测 local/scoped/global 混合优先级，也不支持同名嵌套 Goto 的遮蔽。不存在可见 Goto 报 `fm:UnresolvedRouting`；scoped Goto 没有声明报 `fm:RoutingScope`。重复的最近作用域声明也拒绝。

暂不支持 atomic、enabled、triggered、reset、action/function-call 子系统、Variant、库链接、mask、模型/子系统引用、离散模块、延迟、Mux/Demux、Bus、向量接口、Stateflow、Simscape。State-Space 的 MIMO 和空状态 A 不在当前范围内。Transfer Fcn 的矩阵分子、多输出、非 proper 系数、分母首项为零不在当前范围内。上述情况不是静默忽略或简化，而是明确拒绝。

## 实际验证入口及产物

```matlab
addpath(pwd);
results = runtests('tests/TestComplexModels.m');
assert(all([results.Passed]) && ~any([results.Incomplete]));
```

`tests/TestRoundTrip.m` 保留原有修改参数、改线、符号顺序、初值、标量限制和代数环回归；原来一律拒绝 TF/子系统的测试扩展为验证正确支持，并继续拒绝非 proper TF 和 atomic 子系统。

`tests/TestComplexModels.m` 创建真实 SLX 夹具，测试嵌套多端口、实际改线、跨子系统作用域、歧义/越界 tag、未知死分支路径、状态反馈与直接馈通代数环、数组语法、状态初值、稳定命名、sourceMap，以及已加载模型不被关闭/修改。

仿真对比使用原生模型和提取后重建模型，分别与**独立手写解析解或 ode45 方程**比较。覆盖非首一分母二阶 TF、直接馈通、前导零分子、非零 State-Space 向量初值和标量初值扩展。固定验证阈值为 `2e-7`，求解器 `ode45`，`RelTol=1e-10`、`AbsTol=1e-12`、`MaxStep=0.01`、0–2 秒。每个夹具目录保存 SLX、独立比较 MAT 和误差 JSON。

开发阶段复杂模型专属测试为 22 项全部通过，独立仿真 7 组最大误差为 `2.32258656752e-13`。GitHub 精简验证证据见 [验证记录](verification-report.md)；新运行的夹具与输出写入本地 `artifacts/`。

参考：MathWorks [Transfer Fcn](https://www.mathworks.com/help/simulink/slref/transferfcn.html)、[Goto](https://www.mathworks.com/help/simulink/slref/goto.html)、[Goto Tag Visibility](https://www.mathworks.com/help/simulink/slref/gototagvisibility.html)。
