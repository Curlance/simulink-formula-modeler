function [value,conditions] = astToSym(ast,bindings,dynamicNames,label)
%ASTTOSYM Translate a checked AST using only explicit symbolic operations.
% Domain records are captured BEFORE constructing/simplifying their parent.
fm.core.checkAst(ast);
conditions=struct('kind',{},'source',{},'label',{},'relation',{});
value=visit(ast);
    function value=visit(node)
        switch node.kind
            case 'number'
                value=sym(node.value,'f');
            case 'symbol'
                if ~isfield(bindings,node.value)
                    error('fm:symbolic:UnknownSymbol','%s 包含未声明变量 %s。',label,node.value);
                end
                value=bindings.(node.value);
            case 'unary'
                value=visit(node.args{1});
                if strcmp(node.value,'-'), value=-value; end
            case 'call'
                a=visit(node.args{1});
                switch node.value
                    case 'sin', value=sin(a);
                    case 'cos', value=cos(a);
                    case 'exp', value=exp(a);
                end
            case 'binary'
                a=visit(node.args{1}); b=visit(node.args{2});
                switch node.value
                    case '+', value=a+b;
                    case '-', value=a-b;
                    case '*', value=a*b;
                    case '/'
                        relation=(b~=0);
                        record(relation,'division',node.args{2},'分母不得为零');
                        value=a/b;
                    case '^'
                        % MATLAB scalar ^ uses the principal branch. For real
                        % operands a negative base requires an integer exponent.
                        if isempty(symvar(b)) && isAlways(b==floor(b),'Unknown','false')
                            if isAlways(b<0,'Unknown','false')
                                record(a~=0,'negativePower',node.args{1},'负整数幂的底数不得为零');
                            end
                        elseif isempty(symvar(b))
                            if isAlways(b>0,'Unknown','false')
                                relation=(a>=0);
                            else
                                relation=(a>0);
                            end
                            record(relation,'realPower',node,'实数非整数幂的定义域');
                        else
                            relation=(a>0) | ((a==0) & (b>=0)) | ((a<0) & (b==floor(b)));
                            record(relation,'realPower',node,'实数幂分支：正底数，或零底数且指数非负，或负底数且指数为整数');
                        end
                        value=a^b;
                end
        end
    end
    function record(relation,kind,node,reason)
        source=fm.export.expressionText(node);
        if isAlways(~relation,'Unknown','false')
            if strcmp(kind,'division') || strcmp(kind,'negativePower')
                error('fm:symbolic:DivisionByZero','%s 的原式 %s 无定义：%s。',label,source,reason);
            end
            error('fm:symbolic:Domain','%s 的原式 %s 不满足%s。',label,source,reason);
        end
        vars=arrayfun(@char,symvar(relation),'UniformOutput',false);
        if any(ismember(vars,dynamicNames))
            error('fm:symbolic:Nonlinear', ...
                '%s 的原式 %s 定义域依赖状态或输入，不能建立全局 LTI 模型。',label,source);
        end
        conditions(end+1)=struct('kind',kind,'source',source,'label',label,'relation',relation);
    end
end
