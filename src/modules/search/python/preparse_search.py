from typing import List
from py2plpy import plpy, Out, sql_properties

@sql_properties(volatility='stable', cost=1000)
def preparse_search(search_term:str, code:Out[str], wildcards:Out[List[str]], wildcards_explicit:Out[List[int]]):
     
    from lark import Lark, Transformer, v_args
    from lark.exceptions import UnexpectedInput, VisitError
    from collections import Counter
    import re

    grammar = r"""
{{grammar}}  
    """

    class DB:
        
        VALUE_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.values_search WHERE value = $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        PATTERN_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.values_search WHERE value ~ $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        VALUEX_SPEC_PLAN = plpy.prepare("SELECT array_agg('s' || sign_variant_id::text) AS codes FROM @extschema:cuneiform_signlist@.sign_variants_composition WHERE glyphs = $1 AND specific", ["text"])
        SIGN_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.signs_search WHERE sign = $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        FORM_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.forms_search WHERE form = $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        SIGN_DESCRIPTION_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.sign_descriptions_search WHERE sign = $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        FORM_DESCRIPTION_PLAN = plpy.prepare("SELECT array_agg(code) AS codes FROM @extschema@.form_descriptions_search WHERE form = $1 and sign_spec IS NOT DISTINCT FROM $2", ["text", "text"])
        
        def normalizeGlyphs(sign):
            if sign is None:
                return None
            r = plpy.execute(f"SELECT @extschema:cuneiform_signlist@.normalize_glyphs('{sign}')")
            return r[0]['normalize_glyphs']

        def value(value, spec=None):
            codes = plpy.execute(DB.VALUE_PLAN, [value, DB.normalizeGlyphs(spec)])[0]['codes']
            if not codes:
                raise ValueError
            return codes

        def pattern(pattern, spec=None):
            codes = plpy.execute(DB.PATTERN_PLAN, [pattern, DB.normalizeGlyphs(spec)])[0]['codes']
            if not codes:
                raise ValueError
            return codes

        def valuex(spec):
            codes = plpy.execute(DB.VALUEX_SPEC_PLAN, [DB.normalizeGlyphs(spec)])[0]['codes']
            if len(codes) != 1:
                raise ValueError
            return codes[0]

        def sign(sign, spec):
            if re.search(r'[\.×&%@]|[0-9][0-9][0-9]$', sign):
                r = plpy.execute(DB.SIGN_DESCRIPTION_PLAN, [DB.normalizeGlyphs(sign), DB.normalizeGlyphs(spec)])
            else:
                r = plpy.execute(DB.SIGN_PLAN, [sign, DB.normalizeGlyphs(spec)])
            codes = r[0]['codes']
            if not codes:
                raise ValueError
            return codes
        
        def form(sign, spec):
            if re.search(r'[\.×&%@]|[0-9][0-9][0-9]$', sign):
                r = plpy.execute(DB.FORM_DESCRIPTION_PLAN, [DB.normalizeGlyphs(sign), DB.normalizeGlyphs(spec)])
            else:
                r = plpy.execute(DB.FORM_PLAN, [sign, DB.normalizeGlyphs(spec)])
            codes = r[0]['codes']
            if not codes:
                raise ValueError
            return codes


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
        def paren(self, meta, args):
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
            return re.sub(r'(?<![0-9])([vsgcxXnp])', r'D\1', s), f'{{{w}}}'

        def pc(self, args):
            s, w = [''.join(x) for x in zip(*args)]
            return re.sub(r'(?<![0-9])([vsgcxXnp])', r'P\1', s), f'<{w}>'

        @v_args(meta=True)
        def value(self, meta, args):
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            codes = DB.value(args[0], args[1] if len(args) == 2 else None)
            s = '|'.join(codes)
            if len(codes) > 1:
                self.wildcardId += 1
                self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
                s = f'({s})@{self.wildcardId}'
            return s, w
      
        @v_args(meta=True)
        def pattern(self, meta, args):
            pattern = f'^{args[0][1:-1]}([0-9]+|x)?$'
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            codes = DB.pattern(pattern, args[1] if len(args) == 2 else None)
            s = '|'.join(codes)
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            s = f'({s})@{self.wildcardId}'
            return s, w

        @v_args(meta=True)
        def sign(self, meta, args):
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            codes = DB.sign(args[0], args[1] if len(args) == 2 else None)
            s = '|'.join(codes)
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            s = f'({s})@{self.wildcardId}'
            return s, w

        @v_args(meta=True)
        def form(self, meta, args):
            w = args[0] + (f'({args[1]})' if len(args) == 2 else '')
            codes = DB.form(args[0], args[1] if len(args) == 2 else None)
            s = '('+')|('.join(codes)+')'
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            s = f'({s})@{self.wildcardId}'
            return s, w

        @v_args(meta=True)     
        def signx(self, meta, args):
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, 'X', False))
            return f'X@{self.wildcardId}', 'X'

        @v_args(meta=True)
        def valuex(self, meta, args):
            self.wildcardId += 1
            if len(args) == 1:
                self.wildcards.append((meta.start_pos, self.wildcardId, 'x', False))
                return f'x@{self.wildcardId}', 'x'
            code = DB.valuex(args[1])
            w = f'x({args[1]})'
            self.wildcards.append((meta.start_pos, self.wildcardId, w, False))
            return f'{code}@{self.wildcardId}', w

        @v_args(meta=True)   
        def n(self, meta, args):
            self.wildcardId += 1
            self.wildcards.append((meta.start_pos, self.wildcardId, 'n', False))
            return f'n@{self.wildcardId}', 'n'

        def pseudochar(self, args):
            return 'p', ''


        # Operators

        def sep(self, args):
                if ':' in args and '…' in args:
                    plpy.error('preparse_search syntax error')
                r = ''.join(sorted(set(args)))
                return r or ' ', r or ' '
    
        def nullsep(self, args):
            r = ''.join(sorted(set(args)))
            return r or ' ', r

        def wordbreak(self, args):
            return ','

        def compoundbreak(self, args):
            return ';'

        def linebreak(self, args):
            return '/'

        def ellipsis(self, args):
            return '…'

        def colon(self, args):
            return ':'

        def wordcon(self, args):
            return '='

        def compoundcon(self, args):
            return '-'


        # Complex signs

        def complex_sign(self, args):
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

        wildcardsExplicit.reverse()

        return code, wildcardsNew, wildcardsExplicit

        
    tr = str.maketrans('cjvCJV', 'šĝřŠĜŘ')
    searchTerm = re.sub(r'(?<!@)[cjvCJV]', lambda m: m.group().translate(tr), search_term)

    l = Lark(grammar, lexer='basic', propagate_positions=True)
    try:
        tree = l.parse(searchTerm)
        code, wildcards = T().transform(tree)
    except (UnexpectedInput, VisitError):
        plpy.error('preparse_search syntax error')
    code, wildcards, wildcardsExplicit = processWildcards(code, wildcards)
    return code, wildcards, wildcardsExplicit