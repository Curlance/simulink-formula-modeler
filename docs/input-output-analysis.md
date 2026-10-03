# 输入输出分析

入口接受 `fm.core.validateSpec(raw)` 返回的 schemaVersion=1 spec：

```matlab
stateSpace = fm.analysis.extractStateSpace(spec);
result = fm.analysis.deriveTransferFunction(spec);
disp(result.text)
```

`extractStateSpace` 返回数值 `A,B,C,D` 以及 `stateNames,inputNames,outputNames`。所有矩阵严格使用 spec 中已捕获的顺序，不排序标识符，不从 equations 的书写顺序推断状态顺序。无输入模型明确抛出 `fm:analysis:NoInputs`；方程导出不受影响。

## 结构判定

每个 AST 节点递归返回常数项 c 和系数行 v，代表 `c + v*[x;u]`。加减及一元运算传播系数；乘法至多允许一侧含状态/输入；除法要求分母为非零常数；幂允许参数常数运算，或状态/输入表达式的 0、1 次幂。sin/cos/exp 只接受结构化简后为常数的参数表达式。参数在当前数值处代入，允许有限实数的复合参数表达式。

不采样、不估算 Jacobian、不以容差把小系数或偏置当成零。`x-x` 可以在系数传播中化为零；一般多项式消项（如 `x*x-x*x`）不属于本版本的证明能力，会保守拒绝。任何非线性子节点先拒绝，因此 `0*sin(x)` 也不进入简化。不会接受带变量分母的约分（如 x/x），以免抹去定义域限制。常数算术出现零除、复数或非有限结果即失败。非零偏置必须由用户显式平移工作点，不自动线性化。

时间不是隐式输入。未声明符号（包括 t）会被核心验证或分析器拒绝；若把 t 声明为输入，其与状态的乘积仍判为非线性。常数参数是固定数值，不支持随时间变化的参数或符号参数框架。

## 传递函数结果

在 A/B/C/D 和名称字段之外，`deriveTransferFunction` 返回：

- `system`：Control System Toolbox 的连续时间 `tf`，保留输入/输出名称。
- `conditions`：数值参数、连续时间 LTI、零初始条件及未进行极零消除的说明。
- `text`、`latex`：带显式输出和输入通道名称的表达式。
- `numerator{iy,iu}`、`denominator{iy,iu}`：按 s 降幂排列的数值多项式系数。
- `channels(iy,iu)`：`outputName,inputName,numerator,denominator`。

支持 SISO、MIMO、直接馈通及纯直接馈通输出。定义为 `G(s)=C*(s*I-A)^(-1)*B+D`，假设 `x(0)=0`。spec 中实际初值不会进入 G；非零初值的自由响应属于另一项，不能并入传递函数。不会调用 minreal，避免容差取消真实的小项。MATLAB 可能返回分子前导零，这是合法的系数表示；展示时只忽略精确零。

状态空间提取仅依赖 MATLAB 数值运算；传递函数需要真实可执行的 Control System Toolbox `ss/tf`。缺失或执行失败分别报告 `fm:analysis:ToolboxUnavailable` / `fm:analysis:ToolboxExecutionFailed`。不需要 Symbolic Math Toolbox。

## 验证

`tests/TestInputOutput.m` 采用独立手写矩阵和解析传递函数验证一阶、质量-弹簧-阻尼器、双输入双输出、直接馈通、变量顺序、初值隔离、参数表达式、非线性/偏置拒绝、零除、复数/非有限值和时变符号。复频率点的 evalfr 校验独立于系数表示；系数比较只去掉精确前导零。

```matlab
addpath(pwd);
results = runtests('tests/TestInputOutput.m');
assert(all([results.Passed]) && ~any([results.Incomplete]));
```

执行日志和 MAT 结果保存在 `artifacts/analysis`。本次 MATLAB R2022a 实测结果：10 项 Passed，0 项 Failed，0 项 Incomplete，进程退出码 0；详见 `test-log.txt` 和 `test-results.mat`。


GitHub 发布说明：上述历史 `artifacts/` 路径属于开发机的本地记录，不随仓库发布。仓库内可查看的精简证据见 [验证记录](verification-report.md)。下载后运行测试会重新生成本地 `artifacts/`。
