from tokenize import Single
from typing import List
from py2plpy import plpy


def parse_search(search_term:str, target_table:str, target_key:List[str]) -> str:
    """COST 100 STABLE"""
     
    import itertools
    from enum import Enum
    from lark import Lark, Transformer

    grammar = r"""
{{grammar}}  
    """

    class DB:

        QUERY = "SELECT array_agg(value_id) AS value_ids, array_agg(sign_variant_id) AS sign_variant_ids FROM {fromClause} WHERE {whereClause}"
        NOSPEC_FROM = "(SELECT DISTINCT value, value_id, CASE glyphs_required WHEN TRUE THEN sign_variant_id ELSE NULL END AS sign_variant_id FROM value_map) _"
        GRAPHEME_TABLE = "sign_variants JOIN allomorphs USING (allomorph_id) JOIN values USING (sign_id) JOIN value_variants USING (value_id)"
        
        VALUE_SPEC_PLAN = plpy.prepare(QUERY.format(fromClause='value_map', whereClause='value = $1 AND glyphs = $2'), ["text", "text"])
        VALUE_NOSPEC_PLAN = plpy.prepare(QUERY.format(fromClause=NOSPEC_FROM, whereClause='value = $1'), ["text"])
        PATTERN_SPEC_PLAN = plpy.prepare(QUERY.format(fromClause='value_map', whereClause='value ~ $1 AND glyphs = $2'), ["text", "text"])
        PATTERN_NOSPEC_PLAN = plpy.prepare(QUERY.format(fromClause=NOSPEC_FROM, whereClause='value ~ $1'), ["text"])
        VALUEX_SPEC_PLAN = plpy.prepare("SELECT sign_variant_id FROM sign_variants_text WHERE glyphs = $1", ["text"])
        SIGN_SPEC_PLAN = plpy.prepare(f"""SELECT grapheme_ids, glyph_ids FROM {GRAPHEME_TABLE} JOIN sign_variants_text 
            USING (sign_variant_id, allomorph_id) WHERE value = $1 AND glyphs = $2""", ["text", "text"])
        SIGN_GRAPHEME_PLAN = plpy.prepare(f"SELECT DISTINCT grapheme_ids FROM {GRAPHEME_TABLE} WHERE value = $1", ["text"])
        SIGN_GLYPH_PLAN = plpy.prepare("SELECT glyph_ids FROM sign_map WHERE glyphs = $1 AND array_length(glyph_ids, 1) = 1", ["text"])
        
        def normalizeGlyphs(sign):
            r = plpy.execute(f"SELECT normalize_glyphs('{sign}')")
            return r[0]['normalize_glyphs']

        def value(value, spec=None):
            if spec is not None:
                r = plpy.execute(DB.VALUE_SPEC_PLAN, [value, DB.normalizeGlyphs(spec)])
            else:
                r = plpy.execute(DB.VALUE_NOSPEC_PLAN, [value])
            value_ids = r[0]['value_ids']
            if not value_ids:
                raise ValueError
            return value_ids, r[0]['sign_variant_ids']

        def pattern(pattern, spec=None):
            if spec is not None:
                r = plpy.execute(DB.PATTERN_SPEC_PLAN, [pattern, DB.normalizeGlyphs(spec)])
            else:
                r = plpy.execute(DB.PATTERN_NOSPEC_PLAN, [pattern])
            value_ids = r[0]['value_ids']
            if not value_ids:
                raise ValueError
            return value_ids, r[0]['sign_variant_ids']

        def valuex(spec):
            r = plpy.execute(DB.VALUEX_SPEC_PLAN, [DB.normalizeGlyphs(spec)])
            if len(r) != 1:
                raise ValueError
            return r[0]['sign_variant_id']

        def signNoSpec(sign):
            r = plpy.execute(DB.SIGN_GLYPH_PLAN, [DB.normalizeGlyphs(sign)])
            glyph_id = r[0]['glyph_ids'][0] if len(r) else None
            r = plpy.execute(DB.SIGN_GRAPHEME_PLAN, [sign.lower()])
            grapheme_ids = (row['grapheme_ids'] for row in r)
            if not glyph_id and not grapheme_ids:
                raise ValueError
            return glyph_id, grapheme_ids

        def signSpec(sign, spec):
            r = plpy.execute(DB.SIGN_SPEC_PLAN, [sign.lower(), DB.normalizeGlyphs(spec)])
            if len(r) != 1:
                raise ValueError
            return r[0]['grapheme_ids'], r[0]['glyph_ids']



    class TokenType(Enum):
        CHAR = 1
        ELLIPSIS = 2
        COLON = 3
        WORDBREAK = 4
        LINEBREAK = 5
        LPAREN = 6
        RPAREN = 7
        BAR = 8
        CON = 9


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

        def make_condition(id, value_id, sign_variant_id):
            c = []
            if value_id is not None:
                c.append(f"c{id}.value_id = {value_id}")
            if sign_variant_id is not None:
                c.append(f"c{id}.sign_variant_id = {sign_variant_id}")
            return '('+" AND ".join(c)+')'


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
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.word = self.wordId
                    res.append(c)
            self.wordId += 1
            return res

        def line(self, args):
            res = []
            for arg in args:
                for c in arg:
                    if c.type == TokenType.CHAR:
                        c.lineId = self.lineId
                    res.append(c)
            self.lineId += 1
            return res

        def paren(self, args):
            return [Token(TokenType.LPAREN)] + list(itertools.chain.from_iterable(args)) + [Token(TokenType.RPAREN)]

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
            value_ids, sign_variant_ids = DB.value(args[0], args[1].replace('x', '×') if len(args) == 2 else None)
            ids = zip(value_ids, sign_variant_ids)
            self.id += 1
            return [Char(self.id, "("+" OR ".join(T.make_condition(self.id, value_id, sign_variant_id) for value_id, sign_variant_id in ids)+")", False)]
                    
        def pattern(self, args):
            pattern = f'^{args[0][1:-1]}([0-9]+|x)?$'
            value_ids, sign_variant_ids = DB.pattern(pattern, args[1].replace('x', '×') if len(args) == 2 else None)
            ids = zip(value_ids, sign_variant_ids)
            self.id += 1
            return [Char(self.id, "("+" OR ".join(T.make_condition(self.id, value_id, sign_variant_id) for value_id, sign_variant_id in ids)+")", False)]

        def sign(self, args):
            res = []
            
            if len(args) == 2:
                grapheme_ids, glyph_ids = DB.signSpec(args[0], args[1])
                res.append(Token(TokenType.LPAREN))
                for grapheme_id, glyph_id in zip(grapheme_ids, glyph_ids):
                    self.id += 1
                    res.append(Char(self.id, f"c{self.id}.grapheme_id = {grapheme_id} AND c{self.id}.glyph_id = {glyph_id}", True))
                res.append(Token(TokenType.RPAREN))
            else:
                glyph_id, grapheme_ids = DB.signNoSpec(args[0])                
                if glyph_id:
                    self.id += 1
                    res.append(Char(self.id, f"c{self.id}.glyph_id = {glyph_id}", True))                   
                for i, variant in enumerate(grapheme_ids):
                    if i or glyph_id:
                        res.append(Token(TokenType.BAR))
                    res.append(Token(TokenType.LPAREN))
                    for grapheme_id in variant:
                        self.id += 1
                        res.append(Char(self.id, f"c{self.id}.grapheme_id = {grapheme_id}", True))
                    res.append(Token(TokenType.RPAREN))

            return res
                        
        def signx(self, args):
            self.id += 1
            return [Char(self.id, f"c{self.id}.glyph_id IS NOT NULL", True)]

        def valuex(self, args):
            if len(args) == 1:
                self.id += 1
                return [Char(self.id, f"c{self.id}.sign_variant_id IS NOT NULL", False)]
            sign_variant_id = DB.valuex(args[1].replace('x', '×'))
            self.id += 1
            return [Char(self.id, f"c{self.id}.sign_variant_id = {sign_variant_id}", False)]
            
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

        def con(self, args):
            return [Token(TokenType.CON)]
        
        def bar(self, args):
            return [Token(TokenType.BAR)]

        def signspec(self, args):
            return '.'.join(args)

        def signt(self, args):
            return ''.join(args)

        def parensignt(self, args):
            return '('+'.'.join(args)+')'

        def xcon(self, args):
            return '×'
        

    class Table:
        def __init__(self):
            self.ids = []
            self.ops = []

        def list(self, column):
            return ', '.join(f"c{id}.{column}" for id in self.ids)


    class SingleTable(Table):
        def __init__(self, char):
            super().__init__()
            self.id = char.id
            self.ids.append(char.id)
            self.condition = char.condition

        def first(self, column):
            return f"c{self.id}.{column}"

        def last(self, column):
            return f"c{self.id}.{column}"


    class DummyTable(SingleTable):
        def __init__(self, id):
            super().__init__(Char(id, f"c{id}.position IS NULL", None))

    
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

        def first(self, column):
            if self.knownStart:
                return self.tables[0].first(column)
            return f"LEAST({self.list(column)})"

        def last(self, column):
            if self.knownEnd:
                return self.tables[-1].last(column)
            return f"GREATEST({self.list(column)})"

    class AlternativeTable(Table):
        def __init__(self, table1, table2):
            super().__init__()
            self.ops = table2.ops
            if len(table1.ids) < len(table2.ids):
                table1, table2 = table2, table1
            self.ids = table1.ids
            idMap = dict(zip(table2.ids, table1.ids))
            AlternativeTable.replaceIds(table2, idMap)
            if len(table2.ids) < len(table1.ids):
                if not isinstance(table2, ComplexTable):
                    ops = table2.ops
                    table2.ops = []
                    table2 = ComplexTable([table2])
                    table2.ops = ops
                for id in table1.ids[len(table2.ids):]:
                    table2.append(DummyTable(id))
            self.tables = [table1, table2]

        def replaceIds(table, idMap):
            if isinstance(table, SingleTable):
                table.condition = table.condition.replace(f'c{table.id}.', f'c{idMap[table.id]}.')
                table.id = idMap[table.id]
                table.ids = [table.id]
            else:
                table.ids = [idMap[id] for id in table.ids]
                for t in table.tables:
                    AlternativeTable.replaceIds(t, idMap)

        def first(self, column):
            return self.tables[0].first(column)

        def last(self, column):
            return f"GREATEST({self.tables[0].last(column)}, {self.tables[1].last(column)})"



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

        def processAlternative(tables):
            res = []
            for table in tables:
                if res and TokenType.BAR in res[-1].ops:
                    res[-1] = AlternativeTable(res[-1], table)
                else:
                    res.append(table)
            return res


        def join(table):
            conditions = []

            if isinstance(table, SingleTable):
                return [table.condition]

            if isinstance(table, AlternativeTable):
                c1 = ' AND '.join(Translator.join(table.tables[0]))
                c2 = ' AND '.join(Translator.join(table.tables[1]))
                return [f"(({c1}) OR ({c2}))"]

            if table.unordered:
                conditions.append(f"consecutive({table.list('position')})")
            
            for a, b in zip(table.tables[:-1], table.tables[1:]):
                if isinstance(b, DummyTable):
                    continue
                if not table.unordered:
                    if TokenType.ELLIPSIS in a.ops:
                        conditions.append(f"{a.last('position')} < {b.first('position')}")
                    else:
                        conditions.append(f"next({a.last('position')}) = {b.first('position')}")
                if TokenType.CON in a.ops:
                    conditions.append(f"{a.last('word_no')} = {b.first('word_no')}")
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
                fromClause += f" LEFT JOIN {targetTable} cstart ON cstart.glyph_id IS NULL AND next(cstart.position) = {tables[0].first('position')} AND {Translator.key(ids[0], 'start', targetKey)}"
                if front.type == TokenType.WORDBREAK:
                    conditions.append(f"(cstart.word_no IS NULL OR cstart.word_no < {tables[0].first('word_no')})")
                elif front.type == TokenType.LINEBREAK:
                    conditions.append(f"(cstart.line_no IS NULL OR cstart.line_no < {tables[0].first('line_no')})")
            if back:
                fromClause += f" LEFT JOIN {targetTable} cend ON cend.glyph_id IS NULL AND cend.position = next({tables[-1].last('position')}) AND {Translator.key(ids[0], 'end', targetKey)}"
                if back.type == TokenType.WORDBREAK:
                    conditions.append(f"(cend.word_no IS NULL OR cend.word_no > {tables[-1].last('word_no')})")
                elif back.type == TokenType.LINEBREAK:
                    conditions.append(f"(cend.line_no IS NULL OR cend.line_no > {tables[-1].last('line_no')})")
            return conditions, fromClause


        def requireEqual(tables, col):
            conditions = []
            id0 = tables[0].ids[0]
            for t in tables:
                for id in t.ids:
                    if id0 != id:
                        conditions.append(f"(c{id0}.{col} = c{id}.{col} OR c{id}.{col} IS NULL)")
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

            tables = Translator.processAlternative(tables)
            tables = Translator.processUnordered(tables)
            return ComplexTable(tables), i+1


        def translate(self, targetTable, targetKey):
            conditions = Translator.join(self.table)
            #conditions += [Translator.key(self.table.ids[0], id, targetKey) for id in self.table.ids[1:]]
            for col in targetKey:
                conditions += Translator.requireEqual([self.table], col)
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
            matchClause = ', '.join(f"c{id}.position" for id in self.table.ids)

            return f'SELECT {keyCols}, get_sign_nos({matchClause}) AS signs FROM {fromClause} WHERE {whereClause}'



    l = Lark(grammar, lexer='standard')
    #try:
    tree = l.parse(search_term.translate(search_term.maketrans('cjvCJV', 'šĝřŠĜŘ')))
    tokens = T().transform(tree)
    #except:
    #    return f"SELECT {', '.join(target_key)}, ARRAY[]::integer[] AS signs FROM {target_table} WHERE FALSE"

    translator = Translator(tokens)
    return translator.translate(target_table, target_key)

    

    

    

    


