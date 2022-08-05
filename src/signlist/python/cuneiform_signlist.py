class jsonb:
    pass


def parse_sign(sign:str) -> jsonb:
    """COST 100 IMMUTABLE STRICT TRANSFORM FOR TYPE jsonb"""

    import re

    def parse(sign):
        level = 0
        for op in ['.', '×', '&', '%@', '+']:
            for i, c in list(enumerate(sign))[::-1]:
                if c == '(':
                    level -= 1
                elif c == ')':
                    level += 1
                elif c in op and not level:
                    if c == '@' and i+1 < len(sign) and sign[i+1] in 'tgšnkzicdfvabx419':
                        continue
                    return {'op': c.replace('+', '.'), 'vals': [parse(sign[:i]), parse(sign[i+1:])]}
        m = re.match(r'(.*)@([tgšnkzicdfvabx]|45|90|180)$', sign)
        if m:
            return {'op': m.group(2), 'vals': [parse(m.group(1))]}
        if sign.startswith('(') and sign.endswith(')'):
            return parse(sign[1:-1])
        return {'op': sign, 'vals': []}
    
    return parse(sign)



def compose_sign(tree:jsonb) -> str:
    """COST 100 IMMUTABLE STRICT TRANSFORM FOR TYPE jsonb"""

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}

    def compose(node):
        if len(node['vals']) == 2:
            lval = parenthesize(node['vals'][0], precedence[node['op']], True)
            rval = parenthesize(node['vals'][1], precedence[node['op']], False)
            return lval + node['op'] + rval
        elif len(node['vals']) == 1:
            return parenthesize(node['vals'][0], 100, True) + '@' + node['op']
        else:
            return node['op']

    def parenthesize(node, prec, left):
        if len(node['vals']) == 2 and precedence[node['op']] + int(left) <= prec:
            return '(' + compose(node) + ')'
        return compose(node)

    return compose(tree)



def normalize_sign(tree:jsonb) -> jsonb:
    """COST 100 IMMUTABLE STRICT TRANSFORM FOR TYPE jsonb"""

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}

    def normalize(node):
        if len(node['vals']) == 2:
            modified = False
            op = node['op']
            while precedence[op] < 2 and node['vals'][1]['op'] == op:
                v = node['vals'][1]
                node['vals'][1] = v['vals'][1]
                node['vals'][0] = {'op': op, 'vals': [node['vals'][0], v['vals'][0]]}
                modified = True
            if op == '.' and node['vals'][0]['op'] == '&' and node['vals'][1]['op'] == '&':
                l = node['vals'][0]
                r = node['vals'][1]
                node['op'] = '&'
                node['vals'] = [
                    {'op': '.', 'vals': [l['vals'][0], r['vals'][0]]},
                    {'op': '.', 'vals': [l['vals'][1], r['vals'][1]]}
                ]
                modified = True
            modified |= normalize(node['vals'][0])
            modified |= normalize(node['vals'][1])
            return modified
        elif len(node['vals']) == 1:
            return normalize(node['vals'][0])
        return False

    while normalize(tree):
        pass
    return tree



def match_sign(tree:jsonb, pattern:jsonb) -> bool:
    """COST 100 IMMUTABLE STRICT TRANSFORM FOR TYPE jsonb"""

    precedence = {'.': 0, '×': 1, '&': 2, '%': 3, '@': 3, '+': 4}

    def match(node1, node2):
        if node2['op'] == 'X':
            return True
        if len(node1['vals']) != len(node2['vals']):
            return False

        if len(node2['vals']) == 2 and node2['vals'][1]['op'] == 'X' and precedence[node1['op']] == precedence[node2['op']] and match(node1['vals'][0], node2):
            return True

        if node1['op'] != node2['op']:
            return False
        for val1, val2 in zip(node1['vals'], node2['vals']):
            if not match(val1, val2):
                return False
        return True

    return match(tree, pattern)