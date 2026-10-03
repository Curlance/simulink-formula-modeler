function text = specText(spec)
%SPECTEXT Chinese formula presentation retaining unresolved declarations.
values=struct2cell(spec.parameters);
if any(cellfun(@(v)ischar(v)||isstring(v),values))
    spec=fm.analysis.validateSymbolicSpec(spec);
else
    spec=fm.core.validateSpec(spec);
end
lines={['模型：' spec.name],['状态变量：' list(spec.stateNames)], ...
    ['输入变量：' list(spec.inputNames)],['输出变量：' list(spec.outputNames)],'参数：'};
names=fieldnames(spec.parameters);
for k=1:numel(names)
    value=spec.parameters.(names{k});
    if isnumeric(value), label=sprintf('%.17g',value); else, label='未赋值实符号'; end
    lines{end+1}=sprintf('  %s = %s',names{k},label);
end
if isempty(names), lines{end+1}='  无'; end
lines{end+1}='仿真初值（与线性化工作点分别设置）：';
for k=1:numel(spec.stateNames)
    name=spec.stateNames{k}; lines{end+1}=sprintf('  %s(0) = %.17g',name,spec.initial.(name));
end
lines{end+1}='状态方程：';
for k=1:numel(spec.stateNames)
    lines{end+1}=['  der(' spec.stateNames{k} ') = ' fm.export.expressionText(spec.derivatives{k})];
end
lines{end+1}='输出方程：';
for k=1:numel(spec.outputNames)
    lines{end+1}=['  ' spec.outputNames{k} ' = ' fm.export.expressionText(spec.outputExpressions{k})];
end
if any(cellfun(@(v)ischar(v)||isstring(v),values))
    lines{end+1}='包含未赋值参数：可进行符号分析与导出；数值建模、仿真和工作点线性化前请赋值。';
end
text=[strjoin(lines,newline) newline];
end
function text=list(names)
if isempty(names), text='无'; else, text=strjoin(names,', '); end
end
