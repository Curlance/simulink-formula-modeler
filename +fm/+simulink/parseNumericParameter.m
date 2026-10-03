function value = parseNumericParameter(text, workspace, block, key)
%PARSENUMERICPARAMETER Safe numeric literals or a numeric workspace identifier.
% Matrices: [1 -2; 3 4], comma-separated entries, scalar identifiers.
% Deliberately no evaluation, indexing, colon expansion, or function calls.
try
    text=strtrim(char(text));
    if isempty(text) || numel(text)>32768, error('fm:NumericSyntax','参数为空或过长。'); end
    if ~isempty(regexp(text,'^[A-Za-z][A-Za-z0-9_]*$','once')) && isfield(workspace,text)
        value=workspace.(text);
    elseif text(1)=='[' && text(end)==']'
        body=strtrim(text(2:end-1));
        if isempty(body), value=[]; return; end
        rows=regexp(body,';','split'); values=cell(size(rows)); width=[];
        for r=1:numel(rows)
            row=strtrim(rows{r});
            if isempty(row) || ~isempty(regexp(row,'(^,|,$|,\s*,)','once'))
                error('fm:NumericSyntax','矩阵行或元素为空。');
            end
            tokens=regexp(row,'[\s,]+','split'); vals=zeros(1,numel(tokens));
            for c=1:numel(tokens)
                tok=tokens{c};
                if ~isempty(regexp(tok,'^[+-]?(?:(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)$','once'))
                    vals(c)=str2double(tok);
                else
                    sign=1;
                    if tok(1)=='-' || tok(1)=='+', if tok(1)=='-',sign=-1;end; tok=tok(2:end); end
                    if isempty(regexp(tok,'^[A-Za-z][A-Za-z0-9_]*$','once')) || ~isfield(workspace,tok) || ~isscalar(workspace.(tok))
                        error('fm:NumericSyntax','矩阵元素必须为数值字面量或标量参数标识符。');
                    end
                    vals(c)=sign*workspace.(tok);
                end
            end
            if isempty(width),width=numel(vals);elseif width~=numel(vals),error('fm:NumericSyntax','矩阵各行长度不相同。');end
            values{r}=vals;
        end
        value=vertcat(values{:});
    else
        % Reuse the existing restricted scalar AST, with scalar bindings only.
        scalars=struct(); names=fieldnames(workspace);
        for j=1:numel(names), if isscalar(workspace.(names{j})),scalars.(names{j})=workspace.(names{j});end,end
        value=fm.core.evaluateAst(fm.parser.parseExpression(text),scalars);
    end
    if ~(isnumeric(value)&&ismatrix(value)&&isreal(value)&&all(isfinite(value(:))))
        error('fm:NumericSyntax','必须是有限实数二维数组。');
    end
    value=full(double(value));
catch e
    error('fm:UnsafeParameter','%s 参数 %s 不支持：%s',block,key,e.message);
end
end
