from py2plpy import sql_properties

class jsonb:
    pass

@sql_properties(cost=100, volatility='immutable', strict=True, transform=[jsonb])
def compose_sign_html (tree:jsonb) -> str:
    import re

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}
    modifiers = {'g': 'gunû', 'š': 'šeššig', 't': 'tenû', 'n': 'nutillû', 'k': 'kabatenû', 'z': 'zidatenû', 'i': 'inversum', 'v': 'inversum', 'c': 'rounded'}

    def stack(a, b):
        return f'<span class="stack">{a}<br/>{b}</span>'
    
    def rotate(a, val):
        return f'<span class="rot{val}">{a}</span>'

    def compose(node):
        op = node['op']
        if len(node['vals']) == 2:
            if op == '&':
                return stack(compose(node['vals'][0]), compose(node['vals'][1]))
            elif op == '%':
                return '<span class="cross">'+stack(compose(node['vals'][0]), compose(node['vals'][1]))+'</span>'
            elif op == '@':
                return stack(rotate(compose(node['vals'][0]), '180'), compose(node['vals'][1]))
            return parenthesize(node['vals'][0], precedence[op], True) + op + parenthesize(node['vals'][1], precedence[op], False)
        elif len(node['vals']) == 1:
            if op in ['45', '90', '180']:
                return rotate(compose(node['vals'][0]), op)
            return parenthesize(node['vals'][0], 100, True) + '<span class="modifier">'+modifiers[op]+'</span>'
        else:
            if re.fullmatch(r'(BAU|LAK|KWU|RSP|REC|ZATU|ELLES|UKN)[0-9]{3}([a-c]|bis|ter)?', op):
                return re.sub(r'([0-9]+)$', r'<span class="slindex">\1</span>', op)
            else:
                return re.sub(r'(?<=[^0-9x])([0-9x]+)$', r'<span class="index">\1</span>', op)

    def parenthesize(node, prec, left):
        if len(node['vals']) == 2 and precedence[node['op']] + int(left) <= prec and node['op'] in ['.', '×']:
            return '(' + compose(node) + ')'
        return compose(node)

    return compose(tree)