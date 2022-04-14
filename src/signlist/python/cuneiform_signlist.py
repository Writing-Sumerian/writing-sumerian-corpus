def normalize_operators(sign:str) -> str:
    """COST 100 STABLE STRICT"""

    import re

    precedence = {
        '.': 0,
        '×': 1,
        '&': 2,
        '%': 3,
        '@': 3,
        '+': 4
    }


    class Node:      
        def parentesize(self, _, __):
            return self.compose()

        def compose(self):
            return None

        def normalize(self):
            return False


    class BinaryOp(Node):
        def __init__(self, op, l, r):
            self.op = op
            self.l = l
            self.r = r

        def parentesize(self, prec, left):
            if precedence[self.op] + int(left) <= prec:
                return '(' + self.compose() + ')'
            return self.compose()

        def compose(self):
            lval = self.l.parentesize(precedence[self.op], True)
            rval = self.r.parentesize(precedence[self.op], False)
            return lval + self.op + rval

        def normalize(self):
            modified = False
            while precedence[self.op] < 2 and self.r.op == self.op:
                v = self.r
                self.r = v.r
                self.l = BinaryOp(self.op, self.l, v.l)
                modified = True
            if self.op == '.' and self.l.op == '&' and self.r.op == '&':
                l = self.l
                r = self.r
                self.op = '&'
                self.l = BinaryOp('.', l.l, r.l)
                self.r = BinaryOp('.', l.r, r.r)
                modified = True
            return modified or self.l.normalize() or self.r.normalize()


    class UnaryOp(Node):
        def __init__(self, op, v):
            self.op = op
            self.v = v

        def compose(self):
            return self.v.parentesize(100, True) + '@' + self.op

        def normalize(self):
            return self.v.normalize()


    class Leaf(Node):
        def __init__(self, val):
            self.val = val
            self.op = None

        def compose(self):
            return self.val


    def parse(sign):
        level = 0
        for op in ['.', '×&%@', '+']:
            for i, c in list(enumerate(sign))[::-1]:
                if c == '(':
                    level -= 1
                elif c == ')':
                    level += 1
                elif c in op and not level:
                    if c == '@' and i+1 < len(sign) and sign[i+1] in 'tgšnkzicdfvabx':
                        continue
                    return BinaryOp(c.replace('+', '.'), parse(sign[:i]), parse(sign[i+1:]))
        if m := re.match(r'(.*)@([tgšnkzicdfvabx]|45|90)$', sign):
            return UnaryOp(m.group(2), parse(m.group(1)))
        if sign.startswith('(') and sign.endswith(')'):
            return parse(sign[1:-1])
        return Leaf(sign)

    tree = parse(sign)
    while tree.normalize():
        pass
    return tree.compose()


print(normalize_operators('AŠ.(TUG2.TUG2)'))