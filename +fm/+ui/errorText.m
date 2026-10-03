function text = errorText(problem)
%ERRORTEXT Chinese context while retaining exact original diagnostics.
key=problem.identifier;
switch key
    case {'fm:UnknownSymbol','fm:analysis:UnknownSymbol'}
        hint='公式含未声明变量。请检查状态、输入和参数名称；不要直接引用其他输出别名。';
    case {'fm:NumericValue','fm:NumericMap'}
        hint='该操作需要有限实数参数和初值。若参数填写为 "symbolic"，请切换符号分析，或先赋数值。';
    case {'fm:Identifier','fm:DuplicateIdentifier','fm:DuplicateName'}
        hint='名称必须使用字母开头的英文标识符，且状态、输入、参数、输出不能重名或使用保留字。';
    case {'fm:DerivativeSyntax','fm:MissingDerivative','fm:DuplicateDerivative','fm:UnknownDerivative'}
        hint='每个状态必须对应一条 der(状态) = 表达式，请检查遗漏、重复或未声明的状态。';
    case 'fm:InitialStates'
        hint='初值 JSON 必须包含每个状态，不能遗漏或多填。工作点需要在右侧单独指定。';
    case {'fm:ModelCollision','fm:ArtifactCollision','fm:ReportExists'}
        hint='模型名称或输出文件发生冲突。请改用新的模型名/目录，或先保存并关闭同名模型。';
    case {'fm:analysis:Nonlinear','fm:analysis:AffineOffset'}
        hint='当前方程不能作为全局线性时不变系统。可以选择非线性工作点线性化并填写明确工作点。';
    case {'fm:UnsupportedBlock','fm:UnsupportedConfiguration','fm:UnsupportedModel'}
        hint='模型包含暂不支持的模块或配置。下面给出具体路径/原因；不会忽略这些内容继续导出。';
    case 'fm:AlgebraicLoop'
        hint='检测到纯代数环，当前提取器不能将其作为显式状态方程展开。请检查下面的模块路径。';
    otherwise
        hint='操作未完成，请根据下面的具体原因修正输入或模型。原输入已保留。';
end
text=sprintf('%s\n\n错误标识：%s\n详细信息：%s',hint,key,problem.message);
end
