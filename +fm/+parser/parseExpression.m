function ast = parseExpression(text)
%PARSEEXPRESSION Precedence climbing; powers bind above unary and to the right.
tokens=fm.parser.tokenize(text); pos=1;
ast=expression(0,0);
if ~strcmp(tokens(pos).kind,'end'), fail('Unexpected token; an operator may be missing.'); end
fm.core.checkAst(ast);
    function n=expression(minimum,depth)
        if depth>128, error('fm:ExpressionDepth','Expression nesting exceeds 128 parse levels. Simplify it.'); end
        t=tokens(pos); pos=pos+1;
        switch t.kind
            case 'number', n=node('number',t.value,{});
            case 'identifier'
                if strcmp(tokens(pos).kind,'(')
                    if ~any(strcmp(t.value,{'sin','cos','exp'})), fail(['Unsupported function: ' t.value]); end
                    pos=pos+1; argument=expression(0,depth+1); expect(')');
                    n=node('call',t.value,{argument});
                else
                    if any(strcmp(t.value,{'sin','cos','exp','der','pi','Inf','NaN','i','j','ans'})), fail(['Reserved identifier: ' t.value]); end
                    n=node('symbol',t.value,{});
                end
            case {'+','-'}
                n=node('unary',t.kind,{expression(3,depth+1)});
            case '('
                n=expression(0,depth+1); expect(')');
            otherwise
                pos=pos-1; fail('Expected a number, identifier, or parenthesized expression.');
        end
        while true
            op=tokens(pos).kind;
            switch op
                case {'+','-'}, precedence=1;
                case {'*','/'}, precedence=2;
                case '^', precedence=4;
                otherwise, break;
            end
            if precedence<minimum, break; end
            pos=pos+1; nextMinimum=precedence+1;
            if strcmp(op,'^'), nextMinimum=precedence; end
            n=node('binary',op,{n,expression(nextMinimum,depth+1)});
        end
    end
    function expect(kind)
        if ~strcmp(tokens(pos).kind,kind), fail(['Expected ' kind]); end
        pos=pos+1;
    end
    function fail(message)
        error('fm:ExpressionSyntax','%s At position %d.',message,tokens(pos).position);
    end
end
function n=node(kind,value,args)
n=struct('kind',kind,'value',value,'args',{args});
end
