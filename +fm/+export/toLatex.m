function text = toLatex(spec)
%TOLATEX Complete compilable document with roles and initial conditions.
spec=fm.core.validateSpec(spec);
lines={'\documentclass{article}','\usepackage{amsmath}','\begin{document}',['\section*{Model: ' escape(spec.name) '}'],['States: \texttt{' escape(strjoin(spec.stateNames,', ')) '}\par'],['Inputs: \texttt{' escape(list(spec.inputNames)) '}\par'],['Outputs: \texttt{' escape(strjoin(spec.outputNames,', ')) '}\par'],'\subsection*{Parameters}'};
p=fieldnames(spec.parameters);
if isempty(p), lines{end+1}='None.';
else
    lines{end+1}='\begin{align*}';
    for k=1:numel(p), lines{end+1}=[symbol(p{k}) ' &= ' number(spec.parameters.(p{k})) ' \\']; end
    lines{end+1}='\end{align*}';
end
lines=[lines {'\subsection*{Initial conditions}','\begin{align*}'}];
for k=1:numel(spec.stateNames)
    n=spec.stateNames{k}; lines{end+1}=[symbol(n) '(0) &= ' number(spec.initial.(n)) ' \\'];
end
lines=[lines {'\end{align*}','\subsection*{State equations}','\begin{align*}'}];
for k=1:numel(spec.stateNames), lines{end+1}=['\frac{d ' symbol(spec.stateNames{k}) '}{dt} &= ' fm.export.expressionLatex(spec.derivatives{k}) ' \\']; end
lines=[lines {'\end{align*}','\subsection*{Output equations}','\begin{align*}'}];
for k=1:numel(spec.outputNames), lines{end+1}=[symbol(spec.outputNames{k}) ' &= ' fm.export.expressionLatex(spec.outputExpressions{k}) ' \\']; end
lines=[lines {'\end{align*}','\end{document}'}]; text=[strjoin(lines,newline) newline];
end
function text=escape(text)
text=strrep(text,'_','\_');
end
function text=symbol(name)
text=['\mathrm{' escape(name) '}'];
end
function text=number(value)
text=fm.export.expressionLatex(struct('kind','number','value',value,'args',{{}}));
end
function text=list(values)
if isempty(values), text='(none)'; else, text=strjoin(values,', '); end
end
