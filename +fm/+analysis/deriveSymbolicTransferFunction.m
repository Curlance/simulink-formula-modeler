function result = deriveSymbolicTransferFunction(rawOrSpec,options)
%DERIVESYMBOLICTRANSFERFUNCTION Exact AST-based, conditional symbolic LTI model.
% options.symbolicParameters defaults to all declared parameters. Explicit {}
% substitutes numeric declarations, but unresolved 'symbolic' remains symbolic.
if nargin<2, options=struct(); end
if ~isstruct(options) || ~isscalar(options) || ...
        any(~ismember(fieldnames(options),{'symbolicParameters'}))
    error('fm:symbolic:InvalidOptions','options 必须是仅含 symbolicParameters 的标量结构体。');
end
spec=fm.analysis.validateSymbolicSpec(rawOrSpec);
names=spec.parameterNames;
if isfield(options,'symbolicParameters')
    selected=options.symbolicParameters;
    if ~iscellstr(selected) || (~isempty(selected) && ~isvector(selected)) %#ok<ISCLSTR>
        error('fm:symbolic:InvalidOptions','symbolicParameters 必须是参数名 cellstr；空 cell 表示代入已赋值数值参数。');
    end
    selected=reshape(selected,1,[]);
    if numel(unique(selected))~=numel(selected) || any(~ismember(selected,names))
        error('fm:symbolic:InvalidOptions','symbolicParameters 不得重复，也不得包含未声明的参数名。');
    end
else
    selected=names;
end
selected=names(ismember(names,[selected spec.unresolvedParameters]));
if isempty(spec.inputNames)
    error('fm:symbolic:NoInputs','传递函数推导至少需要一个已声明输入。');
end
if exist('sym','file')~=2
    error('fm:symbolic:ToolboxUnavailable','符号推导需要可运行的 Symbolic Math Toolbox。');
end
bindings=struct(); dynamicNames=[spec.stateNames spec.inputNames];
z=sym(zeros(1,numel(dynamicNames)));
for k=1:numel(dynamicNames)
    % Names have already passed the shared identifier validator.
    z(k)=sym(dynamicNames{k},'real'); bindings.(dynamicNames{k})=z(k);
end
parameterSymbols=sym(zeros(1,numel(selected))); pi=0;
for k=1:numel(names)
    name=names{k};
    if ismember(name,selected)
        bindings.(name)=sym(name,'real'); pi=pi+1;
        parameterSymbols(pi)=bindings.(name);
    else
        bindings.(name)=sym(spec.parameters.(name),'f');
    end
end
nodes=[spec.derivatives spec.outputExpressions];
labels=[strcat('der(',spec.stateNames,')') spec.outputNames];
expressions=sym(zeros(numel(nodes),1));
domains=struct('kind',{},'source',{},'label',{},'relation',{});
for k=1:numel(nodes)
    [expressions(k),records]=fm.symbolic.astToSym(nodes{k},bindings,dynamicNames,labels{k});
    domains=[domains records]; %#ok<AGROW>
end
% Exact symbolic proof, without any numeric parameter sampling or sentinels.
rows=simplify(jacobian(expressions,z));
for k=1:size(rows,1)
    vars=arrayfun(@char,symvar(rows(k,:)),'UniformOutput',false);
    if any(ismember(vars,dynamicNames))
        error('fm:symbolic:Nonlinear', ...
            '%s 的符号 Jacobian 仍依赖状态或输入，无法证明为全局线性时不变方程；未进行线性化。',labels{k});
    end
    residual=simplify(expressions(k)-rows(k,:)*z.');
    if ~isAlways(residual==0,'Unknown','false')
        error('fm:symbolic:AffineOffset', ...
            '%s 存在非零或无法证明恒为零的仿射偏置 %s；请显式平移工作点。',labels{k},char(residual));
    end
end
nx=numel(spec.stateNames);
result=struct('A',rows(1:nx,1:nx),'B',rows(1:nx,nx+1:end), ...
    'C',rows(nx+1:end,1:nx),'D',rows(nx+1:end,nx+1:end), ...
    'stateNames',{spec.stateNames},'inputNames',{spec.inputNames}, ...
    'outputNames',{spec.outputNames},'symbolicParameters',{selected});
allNames=[dynamicNames names spec.outputNames];
laplaceName='s'; suffix=1;
while any(strcmp(laplaceName,allNames))
    if suffix==1, laplaceName='s_laplace';
    else, laplaceName=sprintf('s_laplace_%d',suffix); end
    suffix=suffix+1;
end
s=sym(laplaceName); assume(s,'clear');
result.laplaceVariable=s;
resolvent=s*sym(eye(nx))-result.A;
result.resolventCondition=(simplify(det(resolvent))~=0);
% The inverse has no parameter-only pivots: det(sI-A) is monic in s.
% Its original condition remains even if an unobservable pole cancels in G.
result.transferMatrix=simplify(result.C*(inv(resolvent)*result.B)+result.D);
result.domainConditions=domains;
result.parameterConditions=sym(zeros(0,1));
for k=1:numel(domains)
    relation=domains(k).relation;
    if ~isAlways(relation,'Unknown','false')
        result.parameterConditions(end+1,1)=relation;
    end
end
result.parameterSymbols=parameterSymbols;
result.parameterDeclarations=spec.parameters;
result.symbolicSpec=spec;
[result.text,result.latex,result.conditions]=fm.symbolic.renderResult(result);
end
