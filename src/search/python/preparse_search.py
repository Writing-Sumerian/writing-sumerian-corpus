from tokenize import Single
from typing import List
from py2plpy import plpy, Out, sql_properties

@sql_properties(volatility='stable', cost=1000)
def preparse_search(search_term:str, code:Out[str], wildcards:Out[List[str]], wildcards_explicit:Out[List[int]]):
     
    from lark import Lark, Transformer, v_args
    from collections import Counter
    import re

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
        VALUEX_SPEC_PLAN = plpy.prepare("SELECT sign_variant_id FROM sign_variants_text WHERE glyphs = $1 AND specific", ["text"])
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


    def value(id):
        return 'v'+str(id) if id is not None else ''

    def sign_variant(id):
        return 's'+str(id) if id is not None else ''

    def grapheme(id):
        return 'g'+str(id) if id is not None else ''

    def glyph(id):
        return 'c'+str(id) if id is not None else ''


    class T(Transformer):

        def __init__(self):
            self.wildcardId = 0
            self.wildcards = []

        def __default_token__(self, token):
            return token.value


        def start(self, args):
            return ''.join(list(zip(*args))[0]), self.wildcards


        def line(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return f"[{s}]", f"[{w}]"

        @v_args(meta=True)
        def paren(self, args, meta):
            s, w = [''.join(x) for x in zip(*args)]
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, True))
            return f"({s})@{self.wildcardId}", f"({w})"

        def alt(self, args):
            s, w = ['|'.join(x) for x in zip(*args)]
            return re.sub('@[0-9]+', '', s), w

        def lindicator(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return re.sub(r'([DP])', r'>\1', s), w

        def rindicator(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return re.sub(r'([DP])', r'<\1', s), w

        def det(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return re.sub(r'([vsgcxXnp])', r'D\1', s), f'{{{w}}}'

        def pc(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return re.sub(r'([vsgcxXnp])', r'P\1', s), f'<{w}>'

        @v_args(meta=True)
        def value(self, args, meta):
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            value_ids, sign_variant_ids = DB.value(args[0], args[1] if len(args) == 2 else None)
            ids = list(zip(value_ids, sign_variant_ids))
            s = '|'.join([value(value_id) + sign_variant(sign_variant_id) for value_id, sign_variant_id in ids])
            if len(ids) > 1:
                self.wildcardId += 1
                self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
                s = f'({s})@{self.wildcardId}'
            return s, w
      
        @v_args(meta=True)
        def pattern(self, args, meta):
            pattern = f'^{args[0][1:-1]}([0-9]+|x)?$'
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            value_ids, sign_variant_ids = DB.pattern(pattern, args[1] if len(args) == 2 else None)
            ids = list(zip(value_ids, sign_variant_ids))
            s = '|'.join([value(value_id) + sign_variant(sign_variant_id) for value_id, sign_variant_id in ids])
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            s = f'({s})@{self.wildcardId}'
            return s, w

        @v_args(meta=True)
        def sign(self, args, meta):
            s = ''
            w = ''
            if len(args) == 2:
                w = f'{args[0]}({args[1]})'
                grapheme_ids, glyph_ids = DB.signSpec(args[0], args[1])
                ids = list(zip(grapheme_ids, glyph_ids))
                s = '|'.join([grapheme(grapheme_id) + glyph(glyph_id) for grapheme_id, glyph_id in ids])
                res = '('+res+')' if len(ids) > 1 else res
            else:
                w = args[0]
                glyph_id, grapheme_ids = DB.signNoSpec(args[0])                
                if glyph_id:
                    s += glyph(glyph_id)    
                for i, variant in enumerate(grapheme_ids):
                    if i or glyph_id is not None:
                        s += '|'
                    v = '|'.join([grapheme(grapheme_id) for grapheme_id in variant])
                    s += f'({v})' if len(variant) > 1 else v
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            s = f'({s})@{self.wildcardId}'
            return s, w

        @v_args(meta=True)     
        def signx(self, args, meta):
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, 'X', False))
            return f'X@{self.wildcardId}', 'X'

        @v_args(meta=True)
        def valuex(self, args, meta):
            self.wildcardId += 1
            if len(args) == 1:
                self.wildcards.append((meta.start_pos, self.wildcardId, 'x', False))
                return f'x@{self.wildcardId}', 'x'
            sign_variant_id = DB.valuex(args[1])
            w = f'x({args[1]})'
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            return f'{sign_variant(sign_variant_id)}@{self.wildcardId}', w

        @v_args(meta=True)   
        def n(self, args, meta):
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, 'n', False))
            return f'n@{self.wildcardId}', 'n'

        def pseudochar(self, args):
            return 'p', ''


        # Operators

        def sep(self, args):
                r = ''.join(sorted(set(args)))
                return r or ' ', r or ' '
    
        def nullsep(self, args):
            r = ''.join(sorted(set(args)))
            plpy.info('nullsep')
            return r or ' ', r

        def wordbreak(self, args):
            return ';'

        def linebreak(self, args):
            return '//'

        def ellipsis(self, args):
            return '…'

        def colon(self, args):
            return ':'

        def con(self, args):
            return '-'


        # Complex signs

        def signspec(self, args):
            return '.'.join(args)

        def signt(self, args):
            return ''.join(args)

        def parensignt(self, args):
            return '('+'.'.join(args)+')'

        def xcon(self, args):
            return '×'


    def processWildcards(code, wildcards):
        
        used = {int(x.replace('@', '')) for x in re.findall(r'@[0-9]+', code)}
        wildcards = [x for x in wildcards if x[1] in used]

        wildcards.sort()

        wildcards = [w2 for w1, w2 in zip([None]+wildcards[:-1], wildcards) if w1 is None or w1[2] != w2[2] or w1[0]+1 != w2[0]]

        plpy.info(wildcards)

        d = {x[1]: i for i, x in enumerate(wildcards)}
        
        code = re.sub(r'@([0-9]+)', lambda m: f'@{d[int(m.group(1))]}' if int(m.group(1)) in d else '', code)

        wildcardsNew = ['']*len(wildcards)
        wildcardsExplicit = []
        c = Counter([x[2] for x in wildcards])
        c = {key: c[key] for key in c if c[key] != 1}
        for id in reversed(range(len(wildcards))):
            _, _, key, explicit = wildcards[id]
            n = c.get(key, 0)
            if n:
                c[key] = n-1
                key = f'{key}[{n}]'
            if explicit:
                wildcardsExplicit.append(id)
            wildcardsNew[id] = key

        #for i, id in enumerate(reversed(wildcardsExplicit)):
        #    wildcardsNew[str(i)] = id

        wildcardsExplicit.reverse()

        return code, wildcardsNew, wildcardsExplicit

        

    l = Lark(grammar, lexer='standard', propagate_positions=True)
    tree = l.parse(search_term.translate(search_term.maketrans('cjvCJV', 'šĝřŠĜŘ')))
    code, wildcards = T().transform(tree)
    code, wildcards, wildcardsExplicit = processWildcards(code, wildcards)
    return code, wildcards, wildcardsExplicit