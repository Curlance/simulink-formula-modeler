function spec = validateSpec(raw)
%VALIDATESPEC Normalize JSON/MATLAB inputs and enforce the public contract.
if ~isstruct(raw) || ~isscalar(raw), error('fm:SpecType','Specification must be a scalar struct.'); end
required={'name','states','inputs','parameters','initial','equations','outputs'};
for k=1:numel(required)
    if ~isfield(raw,required{k}), error('fm:MissingField','Missing required field: %s.',required{k}); end
end
spec=raw; spec.name=textValue(raw.name,'name'); identifier(spec.name,'model');
spec.states=textList(raw.states,'states',false);
spec.inputs=textList(raw.inputs,'inputs',true);
spec.equations=textList(raw.equations,'equations',false);
spec.parameters=numericMap(raw.parameters,'parameters',true);
spec.initial=numericMap(raw.initial,'initial',false);
if ~isstruct(raw.outputs) || ~isscalar(raw.outputs) || isempty(fieldnames(raw.outputs))
    error('fm:Outputs','outputs must be a nonempty scalar struct of expression strings.');
end
spec.outputs=raw.outputs;
spec.stateNames=spec.states; spec.inputNames=spec.inputs;
spec.outputNames=reshape(fieldnames(raw.outputs),1,[]);
parameterNames=reshape(fieldnames(spec.parameters),1,[]);
allNames=[spec.states spec.inputs parameterNames spec.outputNames];
for k=1:numel(allNames), identifier(allNames{k},'variable'); end
if numel(unique(allNames))~=numel(allNames), error('fm:DuplicateIdentifier','State, input, parameter and output names must be unique across all roles.'); end
initialNames=reshape(fieldnames(spec.initial),1,[]);
if ~isempty(setxor(initialNames,spec.states)), error('fm:InitialStates','initial must contain exactly one finite real scalar for every state, without extra fields.'); end
allowed=[spec.states spec.inputs parameterNames];
spec.derivatives=cell(1,numel(spec.states)); seen=false(1,numel(spec.states));
for k=1:numel(spec.equations)
    equation=spec.equations{k};
    if numel(equation)>8192, error('fm:ExpressionLength','Derivative equation exceeds 8192 characters.'); end
    parts=regexp(equation,'^\s*der\s*\(\s*([A-Za-z][A-Za-z0-9_]*)\s*\)\s*=\s*(.*?)\s*$','tokens','once');
    if isempty(parts), error('fm:DerivativeSyntax','Equation %d must have form der(state) = expression.',k); end
    index=find(strcmp(spec.states,parts{1}),1);
    if isempty(index), error('fm:UnknownDerivative','Derivative refers to undeclared state %s.',parts{1}); end
    if seen(index), error('fm:DuplicateDerivative','Derivative for %s is defined more than once.',parts{1}); end
    spec.derivatives{index}=parseKnown(parts{2},allowed); seen(index)=true;
end
if ~all(seen), error('fm:MissingDerivative','Missing derivatives for: %s.',strjoin(spec.states(~seen),', ')); end
spec.outputExpressions=cell(1,numel(spec.outputNames));
for k=1:numel(spec.outputNames)
    name=spec.outputNames{k}; expression=textValue(spec.outputs.(name),['output ' name]);
    spec.outputs.(name)=expression; spec.outputExpressions{k}=parseKnown(expression,allowed);
end
spec.schemaVersion=1;
end
function ast=parseKnown(expression,allowed)
ast=fm.parser.parseExpression(expression); names=fm.core.checkAst(ast);
unknown=setdiff(names,allowed);
if ~isempty(unknown), error('fm:UnknownSymbol','Unknown symbol(s): %s. Declare state/input/parameter names; output aliases cannot be referenced.',strjoin(unknown,', ')); end
end
function identifier(value,role)
if ~isvarname(value) || isempty(regexp(value,'^[A-Za-z][A-Za-z0-9_]*$','once')) || any(strcmp(value,{'sin','cos','exp','der','pi','Inf','NaN','i','j','ans'}))
    error('fm:Identifier','Invalid or reserved %s identifier: %s.',role,value);
end
end
function value=textValue(value,label)
if isstring(value) && isscalar(value) && ~ismissing(value), value=char(value); end
if ~ischar(value) || (~isrow(value) && ~isempty(value)) || isempty(strtrim(value))
    error('fm:TextType','%s must be nonempty scalar text.',label);
end
end
function values=textList(value,label,allowEmpty)
if isempty(value)
    if ~allowEmpty, error('fm:EmptyList','%s cannot be empty.',label); end
    values={}; return;
end
if isstring(value) && any(ismissing(value(:))), error('fm:TextType','%s cannot contain missing strings.',label); end
if ischar(value), value={value}; elseif isstring(value), value=cellstr(value); end
if ~iscell(value) || ~isvector(value), error('fm:TextList','%s must be a vector of text values.',label); end
values=reshape(value,1,[]);
for k=1:numel(values), values{k}=textValue(values{k},label); end
end
function values=numericMap(values,label,allowEmpty)
if allowEmpty && isempty(values) && isnumeric(values), values=struct(); end
if ~isstruct(values) || ~isscalar(values), error('fm:NumericMap','%s must be a scalar struct.',label); end
names=fieldnames(values);
for k=1:numel(names)
    value=values.(names{k});
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
        error('fm:NumericValue','%s.%s must be a finite real numeric scalar.',label,names{k});
    end
    values.(names{k})=double(value);
end
end
