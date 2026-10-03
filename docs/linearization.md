# 非线性工作点线性化

`fm.analysis.linearizeAt` 在显式指定的数值工作点计算解析 Jacobian，返回连续时间一阶局部模型和完整偏置。采用独立的安全 AST 前向自动微分；不使用有限差分判定结构、`eval` 或符号代理的 helper。

```matlab
spec = struct('name','polynomial_example', ...
    'states',{{'x'}},'inputs',{{'u'}},'parameters',struct(), ...
    'initial',struct('x',0), ...
    'equations',{{'der(x)=-x^2+u'}}, ...
    'outputs',struct('y','x^2+u^2'));
point = struct('states',struct('x',2),'inputs',struct('u',4));
r = fm.analysis.linearizeAt(spec,point);
% A=-4, B=1, C=4, D=8, f0=0, y0=20
% G(s)=4/(s+4)+8，作用于 delta_u 和 delta_y。
disp(r.text);
```

## 输入约定

```matlab
result = fm.analysis.linearizeAt(spec,operatingPoint,options)
```

- `spec` 可以是 `fm.core.validateSpec` 接受的数值原始结构，也可以是它返回的已验证结构。本函数重新验证源方程，忽略可能过期的缓存 AST。参数必须是有限实数，不能包含 `'symbolic'`。
- `operatingPoint` 必须仅含 `states`、`inputs` 两个标量结构。各映射的字段必须与对应声明名字完全一致；字段顺序可不同，缺失或多余字段均报错。值必须是有限实数数值标量；字符串、逻辑值、向量、复数均不接受。
- 无输入的自治系统使用 `inputs=struct()`，不可省略字段或写成 `[]`。其 `B`、`D` 为零列矩阵。
- `spec.initial` 仍需满足核心结构校验，但不作为工作点。工作点只来自 `operatingPoint`。
- `options` 可省略。`requireEquilibrium` 默认为逻辑值 `true`；`equilibriumTolerance` 默认为 `1e-8`，允许有限非负数（含零）。拒绝未知选项。

## 返回值与残差语义

状态、输入、输出顺序分别保持 `stateNames`、`inputNames`、`outputNames` 的声明顺序。

| 字段 | 含义 |
| --- | --- |
| `A`,`B`,`C`,`D` | `df/dx`、`df/du`、`dg/dx`、`dg/du` 在工作点的有限实数值 |
| `x0`,`u0` | 按声明顺序排列的工作点列向量 |
| `f0`,`y0` | 原方程在工作点的值 `f(x0,u0)`、`g(x0,u0)`，从不静默清零 |
| `equilibriumResidual` | 标量无穷范数 `norm(f0,inf)`；各状态的残差由 `f0` 完整给出 |
| `isEquilibrium` | `equilibriumResidual <= equilibriumTolerance` |
| `equilibriumTolerance` | 本次使用的容差 |
| `system` | `ss(A,B,C,D)`，仅编码齐次扰动部分；`Notes` 和 `UserData` 说明/保留偏置信息 |
| `transferSystem` | 仅在容差内平衡时为 `tf(system)`，非平衡时为 `[]` |
| `text`,`latex`,`conditions` | 中文说明、数值矩阵、工作点、残差、扰动公式及定义域条件 |

对于固定工作点，定义 `delta_x=x-x0`、`delta_u=u-u0`、`delta_y=y-y0`，完整一阶展开为：

\[
\delta\dot{x}=f_0+A\delta x+B\delta u+o(\|[\delta x;\delta u]\|),
\qquad
 y=y_0+C\delta x+D\delta u+o(\|[\delta x;\delta u]\|).
\]

它是工作点附近的局部近似，不是原非线性模型的全局等价表示。非零 `y0` 允许存在，即使工作点确实平衡，也需要把扰动输出加回 `y0` 才是绝对输出。`ss` 本身无法编码常数漂移，仿真非平衡展开时调用者必须显式加入 `f0`。

默认遇到非平衡点报 `fm:linearize:NotEquilibrium`，中文错误给出全部 `f0`、无穷范数和容差。显式允许非平衡点的例子：

```matlab
point.inputs.u = 1;
r = fm.analysis.linearizeAt(spec,point,struct('requireEquilibrium',false));
% f0=-3, y0=5, A=-4, B=1, C=4, D=2
% delta_x_dot 约等于 -3-4*delta_x+delta_u
% y 约等于 5+4*delta_x+2*delta_u
% r.transferSystem=[]；中文报告标明这是仿射局部展开。
```

在容差内判定平衡时，`transferSystem` 描述忽略容差内残差后的零初始小扰动响应：`delta_x(0)=0`。它不要求绝对状态 `x(0)=0`，也不包含非零初始扰动响应。很小但非零的 `f0` 仍完整保留在结果和报告中；需要严格平衡时指定容差为零。无输入系统可返回零输入通道的 `tf` 对象，但不存在输入输出传递通道。

## 解析微分与实数域边界

支持现有 AST 的 `+ - * / ^ sin cos exp`。乘积、商和复合函数按解析链式法则传播值与完整梯度。依赖标记独立于数值梯度，例如 `u^2+2` 在 `u=0` 的梯度为零，但仍然是可变指数。

- 除法要求原始分母在工作点非零，报告保留分母条件。`x/x` 在 `x=0`、`0*(1/x)` 在 `x=0` 都报错，不通过化简掩盖原式奇点。
- 正底数支持任意有限实指数，包括状态/输入相关指数。可变指数项使用 `a^b*log(a)*db`，常指数项使用 `b*a^(b-1)*da`，且不会为常量操作数计算无关的奇异偏导。
- 负底数支持对状态/输入无依赖的整数指数，包括参数给定的整数。负底数的可变或非整数指数拒绝：遵循 MATLAB `^` 的实值要求，不把 `(-8)^(1/3)` 私自解释为 `nthroot(-8,3)`。
- 零底数的常整数指数：指数 `1` 保留底数梯度；指数大于 `1` 的梯度为零；固定指数 `0` 遵循 MATLAB `a^0=1` 约定；负指数拒绝。
- 结构上恒为零的常量底数，在工作点指数严格为正时局部恒零，可以接受 `0^u`（`u0>0`）。
- 依赖变量的底数在零点遇到可变/非整数指数时保守拒绝，要求存在可证明的双侧实数可微邻域。这包括确有奇点的 `x^0.5`、不可微的 `(x^2)^0.5`，也可能拒绝经额外符号推理可证明可微的复合式（例如 `(x^2)^1.5` 在零点）。本实现不进行代数恒等式或高阶消除证明，不能把此类拒绝解读为数学上必然不可微。可改写为受支持的等价光滑公式后重试。
- 任何中间值或导数非实/非有限均报错，即使最终代数化简可能有限。没有有限差分回退，也不返回 `NaN` 伪结果。

主要错误标识为 `fm:linearize:OperatingPoint`、`OperatingPointNames`、`OperatingPointValue`、`Options`、`NotEquilibrium`、`Singular`、`Domain`、`Nondifferentiable`、`Nonfinite`。原始 spec 的结构/语法错误保持核心校验错误标识。

## 独立验证

`tests/TestLinearization.m` 包含手算 MIMO Jacobian、非零摆平衡点、非线性输出直接馈通、独立公式泰勒余项、独立 `ode45` 非线性响应与解析小信号解、幂/除法边界、工作点精确匹配、容差保留、完整中文报告检查。

```matlab
addpath(pwd); % 从仓库根目录运行
suite = matlab.unittest.TestSuite.fromFile('tests/TestLinearization.m');
results = run(suite);
assert(all([results.Passed]) && ~any([results.Incomplete]));
```

开发阶段本地历史证据位于 `artifacts/v2/linearize/`：`summary.json`、`results.csv`、`test-results.mat`、`final-test-log.txt`；可重复运行的脚本是该目录下的 `runOwnedTests.m`。误差缩放数据为 `taylor-scaling.mat`、`ode-small-signal.mat` 和可直接读取的 `scaling-evidence.json`；平衡/非平衡示例报告为 `example-report.txt/.tex`、`affine-report.txt/.tex`，完整平衡结果保存于 `example-result.mat`。此分析模块需要 Control System Toolbox，无需 Symbolic Math Toolbox，也不修改或生成 Simulink 模型。

已在 MATLAB `9.12.0.1884302 (R2022a)` 真实运行：20 项全部通过，失败 0、未完成 0，MATLAB 进程退出码 0。独立 ODE 小信号验证中，输入扰动 `0.1、0.05、0.025` 对应最大输出误差为 `0.0102010990、0.00255043386、0.000637628436`，相邻缩放比分别为 `3.99975046、3.99987472`。完整数值见 JSON/MAT 证据。本模块只运行自身测试；UI 集成与完整套件由主代理验证。


发布仓库的精简验证证据见 [验证记录](verification-report.md)。历史 `artifacts/` 未随仓库发布；完整回归入口为 `tests/runAll.m`。
