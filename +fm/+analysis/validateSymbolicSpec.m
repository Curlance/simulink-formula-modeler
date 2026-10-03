function spec = validateSymbolicSpec(raw)
%VALIDATESYMBOLICSPEC Reuse the safe core without exposing structural sentinels.
% Parameter declarations remain finite real numbers or the exact 'symbolic'.
if ~isstruct(raw) || ~isscalar(raw)
    error('fm:symbolic:InvalidSpec','模型定义必须是标量结构体。');
end
if ~isfield(raw,'parameters')
    error('fm:MissingField','缺少必需字段 parameters。');
end
parameters=raw.parameters;
if isnumeric(parameters) && isempty(parameters), parameters=struct(); end
if ~isstruct(parameters) || ~isscalar(parameters)
    error('fm:symbolic:InvalidParameter','parameters 必须是标量结构体。');
end
names=reshape(fieldnames(parameters),1,[]);
structural=raw;
structural.parameters=struct();
unresolved={};
for k=1:numel(names)
    name=names{k}; value=parameters.(name);
    if isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value)
        % Retain the caller's declaration, including integer numeric types.
        structural.parameters.(name)=double(value);
    elseif (ischar(value) && isrow(value) && strcmp(value,'symbolic')) || ...
            (isstring(value) && isscalar(value) && ~ismissing(value) && strcmp(value,"symbolic"))
        unresolved{end+1}=name; %#ok<AGROW>
        % Only core declaration/parser validation sees this local sentinel.
        % No expression evaluation or linearity test uses structural.
        structural.parameters.(name)=1;
    else
        error('fm:symbolic:InvalidParameter', ...
            '参数 %s 必须是有限实数标量或精确字符串 ''symbolic''；不接受表达式字符串。',name);
    end
end
spec=fm.core.validateSpec(structural);
spec.parameters=parameters;
spec.symbolicSpec=true;
spec.unresolvedParameters=unresolved;
spec.parameterNames=names;
end
