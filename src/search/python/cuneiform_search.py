from typing import List
from py2plpy import plpy


def parse_search(search_term:str, target_table:str, target_key:List[str]) -> str:
    """COST 100 STABLE"""
     
    from lark import Lark
    grammar = r"""
    start: breakstart? (line|word) (_space (line|word))* breakend?
    line: "[" word (_nbspace word)* "]"
    word: _part (_sep _part)*
    _sep: dots?_SEP(dots _SEP?)?
    _space: (_SPACE|dots|wordbreak|linebreak)+
    _nbspace: (_SPACE|dots|wordbreak)+
    _part: lindicator* char rindicator* | indicator+
    lindicator: indicator
    rindicator: indicator 
    indicator: det | pc
    det: "{" char (_sep char)* "}"
    pc: "<" char (_sep char)* ">"
    char: VALUE _signspec?   -> value
        | SIGN               -> sign
        | PATTERN _signspec? -> pattern
        | _SIGNX             -> signx
        | _VALUEX _signspec? -> valuex
        | _N                 -> n
    _signspec: COMMENT

    breakstart: (wordbreak|linebreak)+
    breakend: (wordbreak|linebreak)+

    dots: _DOTS
    wordbreak: ";"
    linebreak: _NL

    COMMENT.5: "(" _DOTSIGN ")"
    PATTERN.5: /\/[^\/]*\//
    SIGN.4: _SIMPLESIGN (_SIGNCON _SIMPLESIGN)*
    VALUE.3: /[abdegĝhḫijklmnpqrsšṣtṭuwyz’]+[0-9xX]*/
    _SIGNX.2: "X"
    _VALUEX.2: "x"
    _N.2: /[Nn]/
    _DOTS.2: "…"|"..."
    _SEP.1: /[.-]/
    _SPACE: /[\t \f\n]+/
    _NL: "//"
    _SIGNCON: /[×x%&]/
    _SIMPLESIGN: /[ABDEGĜHḪIJKLMNPQRSŠṢTṬUWYZ’]+[0-9]*/
    _DOTSIGN: _SIMPLESIGN ((_SIGNCON|".") _SIMPLESIGN)*
    """
    l = Lark(grammar, lexer='standard')

    class Listener:
        def __init__(self):
            self.consecutive = None
            self.sameWord = None
            self.sameWordNext = None
            self.sameLine = None
            self.sameLineNext = None

            self.alignment = None
            self.indicator = None
            self.phonographic = None

            self.previous_sign = False

            self.breakStart = False
            self.linebreakEnd = False
            self.wordbreakEnd = False

            self.i = 0
            self.conditions = []
            self.sources = []

        def commit(self, sign):
            if self.i:
                self.conditions += [f'c{self.i}.{key} = c0.{key}' for key in target_key]

                if self.consecutive:
                    if self.previous_sign and sign:
                        self.conditions.append(f'c{self.i}.component_no = c{self.i-1}.component_no+1')
                    else:
                        self.conditions.append(f'c{self.i}.sign_no = c{self.i-1}.sign_no+1')
                        if self.previous_sign:
                            self.conditions.append(f'c{self.i-1}.final')
                        elif sign:
                            self.conditions.append(f'c{self.i}.initial')
                else:
                    if self.previous_sign and sign:
                        self.conditions.append(f'c{self.i}.component_no > c{self.i-1}.component_no')
                    else:
                        self.conditions.append(f'c{self.i}.sign_no > c{self.i-1}.sign_no')
                if self.sameWord:
                    self.conditions.append(f'c{self.i}.word_no = c{self.i-1}.word_no')
                elif self.sameWord == False:
                    self.conditions.append(f'c{self.i}.word_no > c{self.i-1}.word_no')
                if self.sameLine:
                    self.conditions.append(f'c{self.i}.line_no = c{self.i-1}.line_no')
                elif self.sameLine == False:
                    self.conditions.append(f'c{self.i}.line_no > c{self.i-1}.line_no')

            if self.alignment is not None:
                self.conditions.append(f"(c{self.i}.properties).alignment = '{self.alignment}'")
            if self.indicator is not None:
                self.conditions.append(f"(c{self.i}.properties).indicator = '{self.indicator}'")
            if self.phonographic is not None:
                self.conditions.append(f"(c{self.i}.properties).phonographic = '{self.phonographic}'")

            if sign:
                self.sources.append(f'corpus_composition c{self.i}')
            else:
                self.sources.append(f'corpus c{self.i}')

            self.i += 1
            self.consecutive = True
            self.initialSameWord = False
            self.initialSameLine = False
            if self.sameWord == False:
                self.sameWord = None
            if self.sameWordNext is not None:
                self.sameWord = self.sameWordNext
                self.sameWordNext = None
            if self.sameLine == False:
                self.sameLine = None
            if self.sameLineNext is not None:
                self.sameLine = self.sameLineNext
                self.sameLineNext = None
            self.previous_sign = sign

        def compose(self):
            fromClause = ' CROSS JOIN '.join(self.sources)
            whereClause = ' AND '.join(self.conditions)
            arrayClause = ', '.join(f'c{i}.sign_no' for i in range(self.i))
            frontKey = ' AND '.join([f'cstart.{key} = c0.{key}' for key in target_key])
            backKey = ' AND '.join([f'cend.{key} = c0.{key}' for key in target_key])
            frontJoinClause = f'LEFT JOIN corpus cstart ON cstart.sign_no = c0.sign_no-1 AND {frontKey}'
            backJoinClause = f'LEFT JOIN corpus cend ON cend.sign_no = c{self.i-1}.sign_no+1 AND {backKey}'
            keys = ', '.join([f'c0.{key}' for key in target_key])
            return f'SELECT {keys}, ARRAY[{arrayClause}] AS signs FROM {fromClause} {frontJoinClause} {backJoinClause} WHERE {whereClause}'
        
        def visit(self, node):

            # Characters
            if node.data == 'value':
                if len(node.children) == 2:
                    #r = plpy.execute(f"SELECT array_agg(a.value_id) AS ids FROM value_variants a JOIN values x USING (value_id) JOIN values y USING (sign_id) JOIN value_variants b ON (y.value_id = b.value_id) WHERE a.value = '{node.children[0]}' AND b.value = '{node.children[1].lower()}'")
                    r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants JOIN values USING (value_id) JOIN sign_identifiers USING (sign_id) WHERE value = '{node.children[0]}' AND sign_identifier = '{node.children[1][1:-1].replace('x', '×')}'")
                else:
                    r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants WHERE value = '{node.children[0]}'")
                value_ids = r[0]['ids']
                if not value_ids:
                    raise ValueError
                if len(value_ids) == 1:
                    self.conditions.append(f"c{self.i}.value_id = {value_ids[0]}")
                else:
                    self.conditions.append(f"c{self.i}.value_id = ANY (ARRAY{value_ids})")          
                self.commit(False)
            elif node.data == 'sign':
                r = plpy.execute(f"SELECT array_agg(component_sign_id order by pos) AS ids FROM sign_identifiers JOIN sign_composition USING (sign_id) WHERE sign_identifier = '{node.children[0]}'")
                component_sign_ids = r[0]['ids']
                if not component_sign_ids:
                    raise ValueError
                for component_sign_id in component_sign_ids:
                    self.conditions.append(f"c{self.i}.component_sign_id = {component_sign_id}")
                    self.commit(True)
            elif node.data == 'pattern':
                pattern = '^'+node.children[0][1:-1]+'([0-9]+|x)?$'
                if len(node.children) == 2:
                    r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants JOIN values USING (value_id) JOIN sign_identifiers USING (sign_id) WHERE value = '{pattern}' AND sign_identifier = '{node.children[1][1:-1].replace('x', '×')}'")
                else:
                    r = plpy.execute(f"SELECT array_agg(value_id) AS ids FROM value_variants WHERE value ~ '{pattern}'")
                value_ids = r[0]['ids']
                if not value_ids:
                    raise ValueError 
                if len(value_ids) == 1:
                    self.conditions.append(f"c{self.i}.value_id = {value_ids[0]}")
                else:
                    self.conditions.append(f"c{self.i}.value_id = ANY (ARRAY{value_ids})")
                    
                self.commit(False)
            elif node.data == 'signx':
                self.commit(True)
            elif node.data == 'valuex':
                if len(node.children):
                    r = plpy.execute(f"SELECT sign_id FROM sign_identifiers WHERE sign_identifier = '{node.children[0][1:-1].replace('x', '×')}'")
                    if not len(r):
                        raise ValueError
                    self.conditions.append(f"c{self.i}.sign_id = {r[0]['sign_id']}")
                self.commit(False)
            elif node.data == 'n':
                self.conditions.append(f"(c{self.i}.properties).type = 'number'")
                self.commit(False)

            elif node.data == 'line':
                self.sameLineNext = True
                for child in node.children:
                    self.visit(child)
            elif node.data == 'word':
                self.sameWordNext = True
                for child in node.children:
                    self.visit(child)
                self.sameWord = None

            elif node.data == 'lindicator':
                self.alignment = 'right'
                for child in node.children:
                    self.visit(child)
                self.alignment = None
            elif node.data == 'rindicator':
                self.alignment = 'left'
                for child in node.children:
                    self.visit(child)
                self.alignment = None
            elif node.data == 'indicator':
                self.indicator = True
                for child in node.children:
                    self.visit(child)
                self.indicator = None
            elif node.data == 'det':
                self.phonographic = False
                for child in node.children:
                    self.visit(child)
                self.phonographic = None
            elif node.data == 'pc':
                self.phonographic = True
                for child in node.children:
                    self.visit(child)
                self.phonographic = None

            elif node.data == 'dots':
                self.consecutive = False
            elif node.data == 'wordbreak':
                self.sameWord = False
            elif node.data == 'linebreak':
                self.sameLine = False

            elif node.data == 'breakstart':
                self.breakStart = True
                for child in node.children:
                    if child.data == 'wordbreak':
                        self.conditions.append(f"(cstart.word_no IS NULL OR cstart.word_no != c0.word_no)")
                    elif child.data == 'linebreak':
                        self.conditions.append(f"(cstart.line_no IS NULL OR cstart.lineno != c0.line_no)")
            elif node.data == 'breakend':
                if self.previous_sign:
                    self.conditions.append(f'c{self.i-1}.final')
                for child in node.children:
                    if child.data == 'wordbreak':
                        self.conditions.append(f"(cend.word_no IS NULL OR cend.word_no != c{self.i-1}.word_no)")
                    elif child.data == 'linebreak':
                        self.conditions.append(f"(cend.line_no IS NULL OR cend.line_no != c{self.i-1}.word_no)") 

            else:
                for child in node.children:
                    self.visit(child)

    try:
        tree = l.parse(search_term.translate(search_term.maketrans('cjvCJV', 'šĝřŠĜŘ')))
        r = Listener()
        r.visit(tree)
    except:
        keys = ', '.join(target_key)
        return f'SELECT {keys}, ARRAY[]::integer[] AS signs FROM {target_table} WHERE FALSE'
    plpy.notice(r.compose())
    return r.compose()

print(parse_search('x(A.A)', 'corpus', ['text_id']))