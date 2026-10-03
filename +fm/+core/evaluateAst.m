function value = evaluateAst(ast, bindings)
%EVALUATEAST Evaluate whitelisted scalar real arithmetic only.
fm.core.checkAst(ast);
if ~isstruct(bindings) || ~isscalar(bindings), error('fm:Bindings','Bindings must be a scalar struct.'); end
names=fieldnames(bindings);
for k=1:numel(names)
    v=bindings.(names{k});
    if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v)
        error('fm:Bindings','Binding %s must be a finite real numeric scalar.',names{k});
    end
end
value=visit(ast);
    function v=visit(n)
        switch n.kind
            case 'number', v=double(n.value);
            case 'symbol'
                if ~isfield(bindings,n.value), error('fm:MissingBinding','Missing value for symbol %s.',n.value); end
                v=double(bindings.(n.value));
            case 'unary'
                v=visit(n.args{1}); if strcmp(n.value,'-'), v=-v; end
            case 'binary'
                a=visit(n.args{1}); b=visit(n.args{2});
                switch n.value
                    case '+', v=a+b;
                    case '-', v=a-b;
                    case '*', v=a*b;
                    case '/'
                        if b==0, error('fm:DivisionByZero','Division denominator evaluates to zero.'); end
                        v=a/b;
                    case '^', v=a^b;
                end
            case 'call'
                a=visit(n.args{1});
                switch n.value
                    case 'sin', v=sin(a);
                    case 'cos', v=cos(a);
                    case 'exp', v=exp(a);
                end
        end
        if ~isreal(v) || ~isfinite(v), error('fm:NonRealResult','Expression produced a complex or nonfinite result. Check domains and magnitudes.'); end
    end
end
