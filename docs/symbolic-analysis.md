# 符号参数传递函数

入口：`fm.analysis.deriveSymbolicTransferFunction(rawOrSpec, options)`。需要 Symbolic Math Toolbox；推导本身无需 Control System Toolbox。测试中的独立数值交叉验证使用 Control。

## 参数声明与选择

`raw` 的状态、输入、方程、输出和初值结构沿用第一版契约。`parameters` 每个值只能是有限实数标量或精确的 `'symbolic'`（也接受 MATLAB 标量 string `"symbolic"`）。不接受公式字符串、数值字符串、复数、数组、NaN、Inf 或 logical。

- 不传 `options`：所有参数均保留为符号，即使声明有数值。
- `options.symbolicParameters={'m','k'}`：保留所选参数和全部未赋值参数，其余已赋值参数代入。
- `options.symbolicParameters={}`：代入所有已赋值数值参数；声明为 `'symbolic'` 的参数仍为符号。
- 参数名必须已声明且不重复，输出符号参数列表始终按原声明顺序排列。
- 参数和状态、输入符号默认 real，不添加 positive 假设。拉普拉斯变量不限制为实数。

```matlab
raw = struct('name','spring','states',{{'x','v'}},'inputs',{{'F'}}, ...
    'parameters',struct('m','symbolic','c','symbolic','k','symbolic'), ...
    'initial',struct('x',0,'v',0), ...
    'equations',{{'der(x)=v','der(v)=(F-c*v-k*x)/m'}}, ...
    'outputs',struct('position','x'));
r = fm.analysis.deriveSymbolicTransferFunction(raw);
disp(r.text)
% A=[0,1;-k/m,-c/m], B=[0;1/m], C=[1,0], D=0
% G=1/(m*s^2+c*s+k), 原式要求 m~=0
```

`fm.analysis.validateSymbolicSpec(raw)` 重用安全 core/parser 校验声明和方程。结构校验所需数值占位仅存在于函数内部副本，返回 `spec.parameters` 保留原声明；`symbolicSpec=true`、`unresolvedParameters` 标明符号输入。含未赋值参数的 spec 交给数值 core 会被拒绝，不能直接用于数值模型生成。对已有 spec 重新解析保留的 equations/outputs，不信任调用方篡改或过期的 AST 字段。

## 结果字段

| 字段 | 类型与语义 |
| --- | --- |
| `A/B/C/D` | 符号状态空间矩阵 |
| `transferMatrix` | 输出行 × 输入列的 sym 矩阵 |
| `stateNames/inputNames/outputNames` | 保留声明顺序的 cellstr |
| `symbolicParameters` | 实际保留的符号参数名 cellstr |
| `parameterSymbols` | 与上述名称顺序一致的 sym 行向量，方便 `subs` |
| `laplaceVariable` | 标量 sym；避开全部声明名，依次选择 s、s_laplace、s_laplace_2 等 |
| `text/latex/conditions` | 中文说明、公式及适用条件，类型为 char |
| `domainConditions` | 结构数组，每条含 kind/source/label/relation；记录原 AST 的除法与幂定义域 |
| `parameterConditions` | 未证明恒真的参数条件 sym 列向量；各项须同时满足 |
| `resolventCondition` | 原始状态消元条件 det(sI-A) ~= 0，即使传函约简仍保留 |
| `parameterDeclarations/symbolicSpec` | 原始参数及保留声明的已校验 spec |

`text` 列出状态矩阵、变量顺序、各输入输出通道、线性证明依据和 `G(s)=C(sI-A)^(-1)B+D`。传函一律采用 **零初值 x(0)=0**，不包含 spec 所设置的非零初始状态响应。LaTeX 片段的中文文本需要支持中文的 TeX 环境。

## 安全性、证明和定义域

仅从已校验 AST 逐节点调用 sym 运算，支持 `+ - * / ^ sin cos exp`，不执行用户字符串，也不对整段字符串使用 str2sym。

线性证明先计算符号 Jacobian，要求其不含状态或输入，随后严格证明原式减去 Jacobian 乘状态输入向量恒为零。无法证明就拒绝；不使用数值采样、占位参数或容差判断。非线性报 `fm:symbolic:Nonlinear`，非零或无法证明为零的仿射偏置报 `fm:symbolic:AffineOffset`。

例如默认模式的 `(p-1)*x^2+u` 即使声明 `p=1` 仍被拒绝，因为默认 p 保留为符号；明确选择空参数列表后才可以按已赋值 p=1 的特定模型推导。若 p 声明为 `'symbolic'`，任何选择方式都不能将其偷偷替换成 1。

每个除法节点在计算父节点之前记录分母非零条件。因此 `p/p` 简化为 1 后仍要求 p~=0；`0*(1/p)` 也保留此条件。嵌套除法的所有条件都保留。原式恒定零分母即使乘零也拒绝。

幂采用 MATLAB 标量 `^` 的实值主分支：

- 非负整数指数没有额外限制；负整数指数要求底数非零。
- 正非整数常数指数要求底数非负；负非整数常数指数要求底数为正。
- 参数指数保留分支条件：底数为正，或底数为零且指数非负，或底数为负且指数为整数。

全部条件取交集，没有把“未证明为零”当成“一定非零”。不额外枚举所有条件的可满足性或特殊参数退化分支。状态或输入相关的非平凡定义域会明确拒绝，所以 `x/x` 不能因约简就当作全局 LTI。一般符号恒等式无法由引擎证明时也可能保守拒绝。

数值叶子和已代入数值使用 `sym(value,'f')` 保留已解析数值的精确二进制值，不把微小非零系数舍入成零。十进制文本已经经过共享 parser 的 double 解析，并非任意精度十进制输入。

## 实际验证

最终代码在 MATLAB R2022a、Symbolic 9.1、Control 10.11.1 上完整运行：**27 passed、0 failed、0 incomplete，MATLAB 进程退出码 0**。测试覆盖一阶与弹簧阻尼手推公式、MIMO、混合参数、保留声明、非法参数、符号非线性与偏置、极小系数、原式除法和幂分支、s 命名冲突、零初值和 LaTeX。符号参数代入后还在多个复频率点与独立手算式及原有数值 `tf` 同时比较。

从仓库根目录在 MATLAB 中重复运行：

```matlab
addpath(pwd);
results = runtests('tests/TestSymbolicAnalysis.m');
assert(all([results.Passed]) && ~any([results.Incomplete]));
```

完整套件请运行 `tests/runAll.m`。精简验证证据见 [验证记录](verification-report.md)，本地历史开发日志未随仓库发布。