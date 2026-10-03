function text = expressionText(ast)
%EXPRESSIONTEXT Fully parenthesized, round-trippable scalar expression.
fm.core.checkAst(ast); text=visit(ast);
end
function text=visit(n)
switch n.kind
    case 'number'
        text=sprintf('%.17g',n.value);
        if n.value<0, text=['(' text ')']; end
    case 'symbol', text=n.value;
    case 'unary', text=['(' n.value visit(n.args{1}) ')'];
    case 'binary', text=['(' visit(n.args{1}) ' ' n.value ' ' visit(n.args{2}) ')'];
    case 'call', text=[n.value '(' visit(n.args{1}) ')'];
end
end
