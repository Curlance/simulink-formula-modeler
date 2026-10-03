function text = expressionLatex(ast)
%EXPRESSIONLATEX Standalone escaped LaTeX preserving the AST grouping.
fm.core.checkAst(ast); text=visit(ast);
end
function text=visit(n)
switch n.kind
    case 'number'
        text=sprintf('%.17g',n.value);
        parts=regexp(text,'^(.+)[eE]([+-]?\d+)$','tokens','once');
        if ~isempty(parts), text=[parts{1} '\times 10^{' sprintf('%d',str2double(parts{2})) '}']; end
    case 'symbol', text=['\mathrm{' strrep(n.value,'_','\_') '}'];
    case 'unary', text=['\left(' n.value visit(n.args{1}) '\right)'];
    case 'binary'
        a=visit(n.args{1}); b=visit(n.args{2});
        switch n.value
            case '/', text=['\frac{' a '}{' b '}'];
            case '^', text=['\left(' a '\right)^{' b '}'];
            case '*', text=['\left(' a ' \cdot ' b '\right)'];
            otherwise, text=['\left(' a ' ' n.value ' ' b '\right)'];
        end
    case 'call', text=['\' n.value '\left(' visit(n.args{1}) '\right)'];
end
end
