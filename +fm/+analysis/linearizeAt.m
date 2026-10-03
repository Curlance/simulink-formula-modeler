function result = linearizeAt(spec, operatingPoint, options)
%LINEARIZEAT Analytic, real-domain Jacobian and full local affine expansion.
% result = fm.analysis.linearizeAt(spec, operatingPoint, options)
% operatingPoint.states/inputs are exact finite-real-scalar name maps.
% requireEquilibrium defaults to true; equilibriumTolerance defaults to 1e-8.
% See docs/linearization.md for domain rules and perturbation semantics.
if nargin < 3, options = struct(); end
options = checkOptions(options);
% Revalidate source equations; never trust an injected/stale cached AST.
spec = fm.core.validateSpec(spec);
if ~isstruct(operatingPoint) || ~isscalar(operatingPoint) || ...
        ~isequal(sort(fieldnames(operatingPoint)),sort({'states';'inputs'}))
    error('fm:linearize:OperatingPoint', ...
        '工作点必须是仅含 states 和 inputs 的标量结构，分别明确给出全部状态与输入。');
end
x0 = pointVector(operatingPoint.states,spec.stateNames,'states');
u0 = pointVector(operatingPoint.inputs,spec.inputNames,'inputs');
nx = numel(x0); nu = numel(u0); ny = numel(spec.outputNames);
names = [spec.stateNames spec.inputNames]; values = [x0;u0];
nodes = [spec.derivatives spec.outputExpressions];
labels = [strcat('der(',spec.stateNames,')') spec.outputNames];
jacobian = zeros(nx+ny,nx+nu); atPoint = zeros(nx+ny,1);
domainConditions = {};
for k = 1:numel(nodes)
    [atPoint(k),jacobian(k,:),~,nodeConditions] = differentiate( ...
        nodes{k},names,values,spec.parameters,labels{k});
    domainConditions = [domainConditions nodeConditions]; %#ok<AGROW>
end
f0 = atPoint(1:nx); y0 = atPoint(nx+1:end);
residual = norm(f0,inf);
isEquilibrium = residual <= options.equilibriumTolerance;
if options.requireEquilibrium && ~isEquilibrium
    error('fm:linearize:NotEquilibrium', ...
        ['指定工作点不是平衡点：f0 = %s，平衡残差 ||f0||_inf = %.17g，容差 = %.17g。' ...
         '如需完整仿射局部展开，请显式设置 requireEquilibrium=false。'], ...
        mat2str(f0,17),residual,options.equilibriumTolerance);
end
result = struct('A',jacobian(1:nx,1:nx),'B',jacobian(1:nx,nx+1:end), ...
    'C',jacobian(nx+1:end,1:nx),'D',jacobian(nx+1:end,nx+1:end), ...
    'f0',f0,'y0',y0,'x0',x0,'u0',u0, ...
    'equilibriumResidual',residual,'isEquilibrium',isEquilibrium, ...
    'equilibriumTolerance',options.equilibriumTolerance, ...
    'stateNames',{spec.stateNames},'inputNames',{spec.inputNames}, ...
    'outputNames',{spec.outputNames});
result.conditions = ['连续时间、有限实数参数；在固定工作点附近的一阶局部近似，并非全局等价模型。' ...
    'delta_x=x-x0，delta_u=u-u0，delta_y=y-y0；工作点是固定常量。' ...
    'system 仅表示 A、B、C、D 构成的齐次扰动部分，不编码 f0 漂移或 y0 偏置。'];
if isEquilibrium
    result.conditions = [result.conditions ...
        '按给定容差判定为平衡点；f0 实际值仍完整保留。' ...
        '传递函数 G(s)=C(sI-A)^(-1)B+D 仅描述忽略容差内残差后的零初值小扰动 delta_x(0)=0；' ...
        '不要求绝对状态 x(0)=0，也不包含非零初始扰动响应。'];
else
    result.conditions = [result.conditions ...
        '非平衡点：必须保留常数 f0，delta_x_dot 约等于 f0+A*delta_x+B*delta_u；' ...
        '这是固定点处的仿射局部展开，不是平衡点传递函数，transferSystem 为空。'];
end
if ~isempty(domainConditions)
    result.conditions = [result.conditions ' 定义域条件（工作点及邻域）：' ...
        strjoin(unique(domainConditions,'stable'),'；') '。'];
end
if exist('ss','file') ~= 2 || exist('tf','file') ~= 2
    error('fm:linearize:ToolboxUnavailable','线性化结果需要可执行的 Control System Toolbox ss/tf。');
end
try
    result.system = ss(result.A,result.B,result.C,result.D);
    result.system.StateName = result.stateNames;
    result.system.InputName = result.inputNames;
    result.system.OutputName = result.outputNames;
    result.system.Notes = {result.conditions};
    result.system.UserData = struct('isEquilibrium',isEquilibrium, ...
        'f0',f0,'y0',y0,'x0',x0,'u0',u0,'equilibriumResidual',residual);
    result.transferSystem = [];
    if isEquilibrium, result.transferSystem = tf(result.system); end
catch cause
    problem = MException('fm:linearize:ToolboxExecutionFailed', ...
        '无法构建线性化状态空间或传递函数：%s',cause.message);
    throw(addCause(problem,cause));
end
[result.text,result.latex] = renderResult(result);
end

function options = checkOptions(options)
if ~isstruct(options) || ~isscalar(options) || ...
        ~isempty(setdiff(fieldnames(options),{'requireEquilibrium';'equilibriumTolerance'}))
    error('fm:linearize:Options','options 必须是标量结构，仅支持 requireEquilibrium 和 equilibriumTolerance。');
end
if ~isfield(options,'requireEquilibrium'), options.requireEquilibrium = true; end
if ~islogical(options.requireEquilibrium) || ~isscalar(options.requireEquilibrium)
    error('fm:linearize:Options','requireEquilibrium 必须是逻辑标量 true 或 false。');
end
if ~isfield(options,'equilibriumTolerance'), options.equilibriumTolerance = 1e-8; end
v = options.equilibriumTolerance;
if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v) || v < 0
    error('fm:linearize:Options','equilibriumTolerance 必须是有限、非负实数标量。');
end
options.equilibriumTolerance = double(v);
end

function vector = pointVector(map,names,role)
if ~isstruct(map) || ~isscalar(map)
    error('fm:linearize:OperatingPoint','工作点 %s 必须是有限实数标量值的结构映射；无输入时也须提供空结构。',role);
end
present = reshape(fieldnames(map),1,[]);
missing = setdiff(names,present); extra = setdiff(present,names);
if ~isempty(missing) || ~isempty(extra)
    error('fm:linearize:OperatingPointNames', ...
        '工作点 %s 标识符不匹配：缺少 [%s]，多余 [%s]。', ...
        role,strjoin(missing,', '),strjoin(extra,', '));
end
vector = zeros(numel(names),1);
for k = 1:numel(names)
    value = map.(names{k});
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
        error('fm:linearize:OperatingPointValue','工作点 %s.%s 必须是有限实数数值标量。',role,names{k});
    end
    vector(k) = double(value);
end
end

function [value,gradient,dependent,conditions] = differentiate(node,names,values,parameters,label)
% Forward AD. Structural dependency is intentionally separate from gradient:
% e.g. exponent u^2+2 depends on u even where its gradient happens to vanish.
gradient = zeros(1,numel(names)); dependent = false; conditions = {};
switch node.kind
    case 'number'
        value = double(node.value);
    case 'symbol'
        index = find(strcmp(names,node.value),1);
        if isempty(index)
            value = parameters.(node.value);
        else
            value = values(index); gradient(index) = 1; dependent = true;
        end
    case 'unary'
        [value,gradient,dependent,conditions] = differentiate(node.args{1},names,values,parameters,label);
        if strcmp(node.value,'-'), value = -value; gradient = -gradient; end
    case 'call'
        [a,da,dependent,conditions] = differentiate(node.args{1},names,values,parameters,label);
        switch node.value
            case 'sin', value = sin(a); gradient = cos(a)*da;
            case 'cos', value = cos(a); gradient = -sin(a)*da;
            case 'exp', value = exp(a); gradient = value*da;
        end
    case 'binary'
        [a,da,aDependent,ac] = differentiate(node.args{1},names,values,parameters,label);
        [b,db,bDependent,bc] = differentiate(node.args{2},names,values,parameters,label);
        dependent = aDependent || bDependent; conditions = [ac bc];
        switch node.value
            case '+', value = a+b; gradient = da+db;
            case '-', value = a-b; gradient = da-db;
            case '*', value = a*b; gradient = b*da+a*db;
            case '/'
                if b == 0
                    domainError('Singular',label,node,'除数在工作点等于零，原表达式无定义（即使约分后可消去也不接受）');
                end
                value = a/b;
                % Avoid forming b^2, which can underflow for a valid divisor.
                gradient = (da-value*db)/b;
                conditions{end+1} = [fm.export.expressionText(node.args{2}) ' ~= 0'];
            case '^'
                [value,gradient,powerCondition] = powerDerivative( ...
                    a,da,aDependent,b,db,bDependent,node,label);
                if ~isempty(powerCondition), conditions{end+1} = powerCondition; end
        end
end
if ~isreal(value) || ~isfinite(value) || ~isreal(gradient) || any(~isfinite(gradient))
    domainError('Nonfinite',label,node,'数值或解析导数不是有限实数；请检查定义域、溢出或导数奇点');
end
end

function [value,gradient,condition] = powerDerivative(a,da,aDependent,b,db,bDependent,node,label)
condition = ''; base = fm.export.expressionText(node.args{1});
if a > 0
    value = a^b;
    gradient = zeros(size(da));
    % Do not form an irrelevant partial derivative of a constant operand.
    if aDependent && b ~= 0, gradient = (b*a^(b-1))*da; end
    if bDependent, gradient = gradient + (value*log(a))*db; end
    if bDependent || b ~= fix(b), condition = [base ' > 0']; end
elseif a < 0
    if bDependent || b ~= fix(b)
        domainError('Domain',label,node, ...
            '负底数仅支持对状态/输入无依赖的整数指数；可变或非整数指数不能保证实数开邻域');
    end
    value = a^b;
    if b == 0 || ~aDependent, gradient = zeros(size(da));
    else, gradient = (b*a^(b-1))*da;
    end
    if b < 0, condition = [base ' ~= 0']; end
else
    if b == 0 && ~bDependent
        % MATLAB's constant-exponent convention a^0 == 1 includes a=0.
        value = 1; gradient = zeros(size(da));
    elseif b <= 0
        domainError('Singular',label,node,'零底数的负次幂或可变零指数无有效实数开邻域');
    elseif ~aDependent
        % A structurally constant zero base is identically zero for b>0.
        value = 0; gradient = zeros(size(da));
        condition = [fm.export.expressionText(node.args{2}) ' > 0（恒零底数）'];
    elseif bDependent || b ~= fix(b)
        domainError('Nondifferentiable',label,node, ...
            '零底数处的可变或非整数指数无法由逐节点实数链式法则证明双侧可微');
    else
        value = 0;
        if b == 1, gradient = da; else, gradient = zeros(size(da)); end
    end
end
if a ~= 0 && ~bDependent && b < 0 && b == fix(b)
    condition = [base ' ~= 0'];
end
end

function domainError(kind,label,node,reason)
error(['fm:linearize:' kind],'表达式 %s 的子表达式 %s：%s。', ...
    label,fm.export.expressionText(node),reason);
end

function [text,latex] = renderResult(r)
if r.isEquilibrium, status = '平衡工作点（在指定容差内）';
else, status = '非平衡工作点：仿射局部展开，不是平衡点传递函数';
end
lines = {['非线性工作点线性化 — ' status], ...
    ['状态顺序：' strjoin(r.stateNames,', ')], ...
    ['输入顺序：' strjoin(r.inputNames,', ')], ...
    ['输出顺序：' strjoin(r.outputNames,', ')], ...
    ['指定工作点 x0：' namedVector(r.stateNames,r.x0)], ...
    ['指定工作点 u0：' namedVector(r.inputNames,r.u0)], ...
    ['f0 = f(x0,u0) = ' mat2str(r.f0,17)], ...
    ['y0 = g(x0,u0) = ' mat2str(r.y0,17)], ...
    sprintf('平衡残差 ||f0||_inf = %.17g；容差 = %.17g。',r.equilibriumResidual,r.equilibriumTolerance), ...
    ['A = ' mat2str(r.A,17)],['B = ' mat2str(r.B,17)], ...
    ['C = ' mat2str(r.C,17)],['D = ' mat2str(r.D,17)], ...
    '扰动定义：delta_x=x-x0，delta_u=u-u0，delta_y=y-y0。', ...
    '一阶局部近似（保留全部偏置）：', ...
    'delta_x_dot = f0 + A*delta_x + B*delta_u + o(||[delta_x;delta_u]||)', ...
    'y = y0 + C*delta_x + D*delta_u + o(||[delta_x;delta_u]||)', ...
    '因此 delta_y 约等于 C*delta_x+D*delta_u。',r.conditions};
text = strjoin(lines,newline);
rows = {['x_0&=' matrixLatex(r.x0) ',\quad u_0=' matrixLatex(r.u0)], ...
    ['f_0&=' matrixLatex(r.f0) ',\quad y_0=' matrixLatex(r.y0)], ...
    ['\|f_0\|_\infty&=' numberLatex(r.equilibriumResidual) ...
        ',\quad \varepsilon_{eq}=' numberLatex(r.equilibriumTolerance)], ...
    ['A&=' matrixLatex(r.A) ',\quad B=' matrixLatex(r.B)], ...
    ['C&=' matrixLatex(r.C) ',\quad D=' matrixLatex(r.D)], ...
    '\delta x&=x-x_0,\quad \delta u=u-u_0,\quad \delta y=y-y_0', ...
    '\delta\dot{x}&=f_0+A\delta x+B\delta u+o(\|[\delta x;\delta u]\|)', ...
    'y&=y_0+C\delta x+D\delta u+o(\|[\delta x;\delta u]\|)'};
if r.isEquilibrium
    rows{end+1} = 'G(s)&=C(sI-A)^{-1}B+D,\quad \delta x(0)=0';
end
latex = ['\text{' status '} ' newline ...
    '\text{固定工作点的一阶局部近似；完整保留偏置。}' newline ...
    '\begin{aligned}' newline ...
    joinLiteral(rows,[' \\' newline]) newline '\end{aligned}'];
end

function text = namedVector(names,values)
if isempty(names), text = '[]（无输入）'; return; end
parts = cell(1,numel(names));
for k = 1:numel(names), parts{k} = sprintf('%s=%.17g',names{k},values(k)); end
text = strjoin(parts,', ');
end

function text = matrixLatex(value)
if isempty(value)
    text = sprintf('\\left[\\,\\right]_{%d\\times%d}',size(value,1),size(value,2)); return;
end
rows = cell(1,size(value,1));
for i = 1:size(value,1)
    row = arrayfun(@numberLatex,value(i,:),'UniformOutput',false);
    rows{i} = strjoin(row,' & ');
end
text = ['\begin{bmatrix}' joinLiteral(rows,' \\ ') '\end{bmatrix}'];
end

function text = joinLiteral(parts,separator)
% strjoin interprets escape sequences in char delimiters in R2022a.
% Literal concatenation preserves both backslashes in LaTeX row separators.
text = parts{1};
for k = 2:numel(parts), text = [text separator parts{k}]; end %#ok<AGROW>
end

function text = numberLatex(value)
text = regexprep(sprintf('%.17g',value),'e([+-]?\d+)','\\times 10^{$1}');
end
