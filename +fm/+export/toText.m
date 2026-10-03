function text = toText(spec)
%TOTEXT Export formulas and declared roles without Simulink.
spec=fm.core.validateSpec(spec);
lines={['Model: ' spec.name],['States: ' names(spec.stateNames)],['Inputs: ' names(spec.inputNames)],['Outputs: ' names(spec.outputNames)],'Parameters:'};
p=fieldnames(spec.parameters);
for k=1:numel(p), lines{end+1}=sprintf('  %s = %.17g',p{k},spec.parameters.(p{k})); end
if isempty(p), lines{end+1}='  (none)'; end
lines{end+1}='Initial conditions:';
for k=1:numel(spec.stateNames)
    n=spec.stateNames{k}; lines{end+1}=sprintf('  %s(0) = %.17g',n,spec.initial.(n));
end
lines{end+1}='State equations:';
for k=1:numel(spec.stateNames), lines{end+1}=['  der(' spec.stateNames{k} ') = ' fm.export.expressionText(spec.derivatives{k})]; end
lines{end+1}='Output equations:';
for k=1:numel(spec.outputNames), lines{end+1}=['  ' spec.outputNames{k} ' = ' fm.export.expressionText(spec.outputExpressions{k})]; end
text=[strjoin(lines,newline) newline];
end
function text=names(values)
if isempty(values), text='(none)'; else, text=strjoin(values,', '); end
end
