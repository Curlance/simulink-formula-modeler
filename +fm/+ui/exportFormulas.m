function paths = exportFormulas(spec,folder)
%EXPORTFORMULAS Chinese reports and a complete XeLaTeX document.
plain=fm.ui.specText(spec);
values=struct2cell(spec.parameters);
if any(cellfun(@(v)ischar(v)||isstring(v),values)), spec=fm.analysis.validateSymbolicSpec(spec);
else, spec=fm.core.validateSpec(spec); end
folder=char(folder);
if isempty(strtrim(folder))||exist(folder,'file')||exist(folder,'dir')
    error('fm:ReportExists','导出目录不能为空，也不能覆盖已有目录：%s',folder);
end
paths=struct('text',fullfile(folder,'equations.txt'),'latex',fullfile(folder,'equations.tex'), ...
    'markdown',fullfile(folder,'report.md'));
lines={'\documentclass[UTF8]{ctexart}','\usepackage{amsmath}','\begin{document}', ...
    ['\section*{模型：\texttt{' escape(spec.name) '}}'], ...
    '\subsection*{参数与初值}','\begin{align*}'};
p=fieldnames(spec.parameters);
for k=1:numel(p)
    value=spec.parameters.(p{k});
    if isnumeric(value), rhs=num(value); else, rhs='\text{未赋值实符号}'; end
    lines{end+1}=[id(p{k}) ' &= ' rhs ' \\'];
end
for k=1:numel(spec.stateNames)
    n=spec.stateNames{k}; lines{end+1}=[id(n) '(0) &= ' num(spec.initial.(n)) ' \\'];
end
lines=[lines {'\end{align*}','\subsection*{状态方程}','\begin{align*}'}];
for k=1:numel(spec.stateNames)
    lines{end+1}=['\frac{d ' id(spec.stateNames{k}) '}{dt} &= ' fm.export.expressionLatex(spec.derivatives{k}) ' \\'];
end
lines=[lines {'\end{align*}','\subsection*{输出方程}','\begin{align*}'}];
for k=1:numel(spec.outputNames)
    lines{end+1}=[id(spec.outputNames{k}) ' &= ' fm.export.expressionLatex(spec.outputExpressions{k}) ' \\'];
end
lines=[lines {'\end{align*}','\end{document}'}];
latex=[strjoin(lines,newline) newline];
report=['# 公式报告：' spec.name newline newline '```text' newline plain '```' newline newline ...
    '## 原始状态方程' newline newline '```text' newline strjoin(spec.equations,newline) newline '```' newline newline ...
    'LaTeX 文件使用 UTF-8 中文，编译时使用 XeLaTeX 与 ctex。' newline];
[ok,message]=mkdir(folder); if ~ok, error('fm:ReportWrite','无法创建目录：%s',message); end
writeOne(paths.text,plain); writeOne(paths.latex,latex); writeOne(paths.markdown,report);
end
function writeOne(path,text)
fid=fopen(path,'w','n','UTF-8'); if fid<0, error('fm:ReportWrite','无法创建文件：%s',path); end
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text);
[message,code]=ferror(fid); if code~=0, error('fm:ReportWrite','写入失败：%s',message); end
end
function text=escape(text), text=strrep(text,'_','\_'); end
function text=id(name), text=['\mathrm{' escape(name) '}']; end
function text=num(value), text=fm.export.expressionLatex(struct('kind','number','value',value,'args',{{}})); end
