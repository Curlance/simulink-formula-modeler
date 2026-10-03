function symbols = checkAst(ast)
%CHECKAST Validate the shared AST at public trust boundaries.
symbols={}; count=0; visit(ast,0); symbols=unique(symbols,'stable');
    function visit(n,depth)
        count=count+1;
        if depth>100 || count>4096, error('fm:ExpressionDepth','AST exceeds depth 100 or 4096 nodes.'); end
        if ~isstruct(n) || ~isscalar(n) || ~isequal(sort(fieldnames(n)),sort({'kind';'value';'args'}))
            error('fm:InvalidAst','Each AST node must contain exactly kind, value, and args.');
        end
        if ~ischar(n.kind) || ~isrow(n.kind) || ~iscell(n.args) || (~isempty(n.args) && ~isrow(n.args))
            error('fm:InvalidAst','AST kind must be char and args must be a row cell array.');
        end
        arity=0;
        switch n.kind
            case 'number'
                if ~isnumeric(n.value) || ~isscalar(n.value) || ~isreal(n.value) || ~isfinite(n.value)
                    error('fm:InvalidAst','AST numbers must be finite real numeric scalars.');
                end
            case 'symbol'
                if ~ischar(n.value) || ~isrow(n.value) || ~isvarname(n.value) || isempty(regexp(n.value,'^[A-Za-z][A-Za-z0-9_]*$','once')) || any(strcmp(n.value,{'sin','cos','exp','der','pi','Inf','NaN','i','j','ans'}))
                    error('fm:InvalidAst','AST symbol must be a nonreserved identifier.');
                end
                symbols{end+1}=n.value;
            case 'unary'
                validOp(n.value,{'+','-'}); arity=1;
            case 'binary'
                validOp(n.value,{'+','-','*','/','^'}); arity=2;
            case 'call'
                validOp(n.value,{'sin','cos','exp'}); arity=1;
            otherwise
                error('fm:InvalidAst','Unsupported AST node kind.');
        end
        if numel(n.args)~=arity, error('fm:InvalidAst','Wrong argument count for AST node %s.',n.kind); end
        for k=1:numel(n.args), visit(n.args{k},depth+1); end
    end
end
function validOp(value,allowed)
if ~ischar(value) || ~isrow(value) || ~any(strcmp(value,allowed))
    error('fm:InvalidAst','Unsupported AST operator or function.');
end
end
