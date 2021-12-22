from typing import List
from py2plpy import plpy


def parse_search(search_term:str, target_table:str, target_key:List[str]) -> str:
    """COST 100 STABLE"""
     
    from enum import Enum
    from lark import Lark, Transformer

    grammar = r"""
{{grammar}}  
    """

    class TokenType(Enum):
        CHAR = 1
        ELLIPSIS = 2
        COLON = 3
        WORDBREAK = 4
        LINEBREAK = 5
        LPAREN = 6
        RPAREN = 7

    class Token:
        def __init__(self, type):
            self.type = type

    class Char(Token):
        def __init__(self, id, condition, sign):
            self.type = TokenType.CHAR
            self.id = id
            self.condition = condition
            self.sign = sign
            self.word = None
            self.line = None


    class T(Transformer):

        def __init__(self):
            self.id = 0
            self.wordId = 0
            self.lineId = 0

        def __default_token__(self, token):
            return token.value

        def start(self, args):
            res = []
            for arg in args:
                res += arg
            return res 

        def word(self, args):
            #id = next(c for c in args[0] if c.type == TokenType.CHAR).id
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.word = self.wordId
                    #if c.type == TokenType.CHAR and c.id != id:
                    #    c.condition += f" AND c{c.id}.word_no = c{id}.word_no" 
                    res.append(c)
            self.wordId += 1
            return res

        def line(self, args):
            #id = next(c for c in args[0] if c.type == TokenType.CHAR).id
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.lineId = self.lineId
                    #if c.type == TokenType.CHAR and c.id != id:
                    #    c.condition += f" AND c{c.id}.line_no = c{id}.line_no"
                    res.append(c)
            self.lineId += 1
            return res

        def lindicator(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.condition += f" AND c{c.id}.alignment = 'right'"
                    res.append(c)
            return res

        def rindicator(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.condition += f" AND c{c.id}.alignment = 'left'"
                    res.append(c)
            return res

        def indicator(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.condition += f" AND c{c.id}.indicator"
                    res.append(c)
            return res

        def det(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.condition += f" AND NOT c{c.id}.phonographic"
                    res.append(c)
            return res

        def pc(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.condition += f" AND c{c.id}.phonographic"
                    res.append(c)
            return res

        def value(self, args):
            if len(args) == 2:
                r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants JOIN values USING (value_id) JOIN sign_identifiers USING (sign_id) WHERE value = '{args[0]}' AND sign_identifier = '{args[1].replace('x', '×')}'")
            else:
                r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants WHERE value = '{args[0]}'")
            value_ids = r[0]['ids']
            if not value_ids:
                raise ValueError
            self.id += 1
            if len(value_ids) == 1:
                return [Char(self.id, f"c{self.id}.value_id = {value_ids[0]}", False)]
            else:
                return [Char(self.id, f"c{self.id}.value_id = ANY (ARRAY{value_ids})", False)]
                    
        def sign(self, args):
            r = plpy.execute(f"SELECT array_agg(component_sign_id order by pos) AS ids FROM sign_identifiers JOIN sign_composition USING (sign_id) WHERE sign_identifier = '{args[0].replace('x', '×')}'")
            component_sign_ids = r[0]['ids']
            if not component_sign_ids:
                raise ValueError
            res = [Token(TokenType.LPAREN)]
            for component_sign_id in component_sign_ids:
                self.id += 1
                res.append(Char(self.id, f"c{self.id}.component_sign_id = {component_sign_id}", True))
            res.append(Token(TokenType.RPAREN))
            return res

        def pattern(self, args):
            pattern = f'^{args[0][1:-1]}([0-9]+|x)?$'
            if len(args) == 2:
                r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants JOIN values USING (value_id) JOIN sign_identifiers USING (sign_id) WHERE value ~ '{pattern}' AND sign_identifier = '{args[1].replace('x', '×')}'")
            else:
                r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants WHERE value ~ '{pattern}'")
            value_ids = r[0]['ids']
            if not value_ids:
                raise ValueError 
            self.id += 1
            if len(value_ids) == 1:
                return [Char(self.id, f"c{self.id}.value_id = {value_ids[0]}", False)]
            else:
                return [Char(self.id, f"c{self.id}.value_id = ANY (ARRAY{value_ids})", False)]
                        
        def signx(self, args):
            self.id += 1
            return [Char(self.id, 'c{self.id}.component_sign_id IS NOT NULL', True)]

        def valuex(self, args):
            if not len(args):
                self.id += 1
                return [Char(self.id, 'c{self.id}.component_sign_id IS NULL', False)]
            r = plpy.execute(f"SELECT sign_id FROM sign_identifiers WHERE sign_identifier = '{args[0].replace('x', '×')}'")
            if not len(r):
                raise ValueError
            self.id += 1
            return [Char(self.id, f"c{self.id}.sign_id = {r[0]['sign_id']}", False)]
            
        def n(self, args):
            self.id += 1
            return [Char(self.id, f"c{self.id}.type = 'number'", True)]

        def wordbreak(self, args):
            return [Token(TokenType.WORDBREAK)]

        def linebreak(self, args):
            return [Token(TokenType.LINEBREAK)]

        def ellipsis(self, args):
            return [Token(TokenType.ELLIPSIS)]

        def colon(self, args):
            return [Token(TokenType.COLON)]
        

    class Table:
        def __init__(self):
            self.ids = []
            self.ops = []

    class SingleTable(Table):
        def __init__(self, char):
            super().__init__()
            self.id = char.id
            self.ids.append(char.id)
            self.condition = char.condition

        def list(self, column):
            return f"c{self.id}.{column}"

        def first(self, column):
            return f"c{self.id}.{column}"

        def last(self, column):
            return f"c{self.id}.{column}"

    
    class ComplexTable(Table):
        def __init__(self, tables=[], unordered=False):
            super().__init__()
            self.tables = []
            for table in tables:
                self.append(table)
            self.unordered = unordered
            self.knownStart = not unordered
            self.knownEnd = not unordered

        def append(self, table):
            self.ids += table.ids
            self.tables.append(table)

        def list(self, column):
            return ', '.join(table.list(column) for table in self.tables)

        def first(self, column):
            if self.knownStart:
                return self.tables[0].first()
            return f"LEAST({self.list(column)})"

        def last(self, column):
            if self.knownEnd:
                return self.tables[-1].last()
            return f"GREATEST({self.list(column)})"


    class Translator:
        def __init__(self, tokens):
            self.words = {}
            self.lines = {}
            self.front = None
            self.back = None
            tokens = self.extractMarginals(tokens)
            self.table, _ = self.process(tokens)


        def key(id1, id2, key):
            return ' AND '.join(f"c{id1}.{col} = c{id2}.{col}" for col in key)


        def processUnordered(tables):
            t = None
            res = []
            for table in tables:
                if TokenType.COLON in table.ops:
                    if not t:
                        t = ComplexTable(unordered=True)
                    t.append(table)
                else:
                    if t:
                        t.append(table)
                        res.append(t)
                        t = None
                    else:
                        res.append(table)
            return res


        def join(table):
            conditions = []

            if not isinstance(table, ComplexTable):
                return [table.condition]

            if table.unordered:
                conditions.append(f"consecutive({table.list('position')})")
            else:
                for a, b in zip(table.tables[:-1], table.tables[1:]):
                    if TokenType.ELLIPSIS in a.ops:
                        conditions.append(f"{a.last('position')} < {b.first('position')}")
                    else:
                        conditions.append(f"next({a.last('position')}) = {b.first('position')}")
                    if TokenType.WORDBREAK in a.ops:
                        conditions.append(f"{a.last('word_no')} < {b.first('word_no')}")
                    if TokenType.LINEBREAK in a.ops:
                        conditions.append(f"{a.last('line_no')} < {b.first('line_no')}")

            for table in table.tables:
                conditions += Translator.join(table)

            return conditions


        def translateMarginals(front, back, tables, ids, targetTable, targetKey):
            fromClause = ''
            conditions = []
            if front:
                fromClause += f" LEFT JOIN {targetTable} cstart ON cstart.component_sign_id IS NULL AND next(cstart.position) = {tables[0].first('position')} AND {Translator.key(ids[0], 'start', targetKey)}"
                if front.type == TokenType.WORDBREAK:
                    conditions.append(f"(cstart.word_no IS NULL OR cstart.word_no < {tables[0].first('word_no')})")
                elif front.type == TokenType.LINEBREAK:
                    conditions.append(f"(cstart.line_no IS NULL OR cstart.line_no < {tables[0].first('line_no')})")
            if back:
                fromClause += f" LEFT JOIN {targetTable} cend ON cend.component_sign_id IS NULL AND cend.position = next({tables[-1].last('position')}) AND {Translator.key(ids[0], 'end', targetKey)}"
                if back.type == TokenType.WORDBREAK:
                    conditions.append(f"(cend.word_no IS NULL OR cend.word_no > {tables[-1].last('word_no')})")
                elif back.type == TokenType.LINEBREAK:
                    conditions.append(f"(cend.line_no IS NULL OR cend.line_no > {tables[-1].last('line_no')})")
            return conditions, fromClause


        def requireEqual(tables, col):
            conditions = []
            id = tables[0].id
            for t in tables[1:]:
                conditions.append(f"c{id}.{col} = c{t.id}.{col}")
            return conditions


        def extractMarginals(self, tokens):
            if tokens[0].type in [TokenType.WORDBREAK, TokenType.LINEBREAK]:
                self.front = tokens.pop(0)
            if tokens[-1].type in [TokenType.WORDBREAK, TokenType.LINEBREAK]:
                self.back = tokens.pop(-1)
            return tokens


        def process(self, tokens):
            tables = []
            ops = []
            i = 0
            while i < len(tokens):
                if tokens[i].type == TokenType.CHAR:
                    if len(tables):
                        tables[-1].ops = ops
                        ops = []
                    tables.append(SingleTable(tokens[i]))
                    if tokens[i].word is not None:
                        self.words.setdefault(tokens[i].word, []).append(tables[-1])
                    if tokens[i].line is not None:
                        self.lines.setdefault(tokens[i].line, []).append(tables[-1])
                elif tokens[i].type == TokenType.LPAREN:
                    if len(tables):
                        tables[-1].ops = ops
                        ops = []
                    t, n = self.process(tokens[i+1:])
                    tables.append(t)
                    i += n 
                elif tokens[i].type == TokenType.RPAREN:
                    break
                else:
                    ops.append(tokens[i].type)
                i += 1

            tables = Translator.processUnordered(tables)
            return ComplexTable(tables), i+1


        def translate(self, targetTable, targetKey):
            conditions = Translator.join(self.table)
            conditions += [Translator.key(self.table.ids[0], id, targetKey) for id in self.table.ids[1:]]

            for word in self.words.values():
                conditions += Translator.requireEqual(word, 'word_no')
            for line in self.lines.values():
                conditions += Translator.requireEqual(line, 'line_no')

            fromClause = ' CROSS JOIN '.join(f"{targetTable} c{id}" for id in self.table.ids)

            c, f = Translator.translateMarginals(self.front, self.back, self.table.tables, self.table.ids, targetTable, targetKey)
            fromClause += f
            conditions += c

            whereClause = ' AND '.join(conditions)
            keyCols = ', '.join(f"c{self.table.ids[0]}.{col}" for col in targetKey)
            arrayClause = ', '.join(f"sign_no(c{id}.position)" for id in self.table.ids)

            return f'SELECT {keyCols}, ARRAY[{arrayClause}] AS signs FROM {fromClause} WHERE {whereClause}'



    l = Lark(grammar, lexer='standard')
    #try:
    tree = l.parse(search_term.translate(search_term.maketrans('cjvCJV', 'šĝřŠĜŘ')))
    tokens = T().transform(tree)
    #except:
    #    return f"SELECT {', '.join(target_key)}, ARRAY[]::integer[] AS signs FROM {target_table} WHERE FALSE"

    translator = Translator(tokens)
    return translator.translate(target_table, target_key)

    

    

    

    


