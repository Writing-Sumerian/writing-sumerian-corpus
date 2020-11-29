from typing import List

def parse_search(search_term:str, target_table:str, target_key:List[str]) -> str:
    """COST 100 IMMUTABLE"""
     
    import re

    LCHARS = 'abdegĝhḫijklmnpqrsšṣtṭuwyz’'
    UCHARS = 'ABDEGĜHḪIJKLMNPQRSŠṢTṬUWYZ’'
    OPERATORS = r'\- ;‹›…<>{}'
    VALUE = re.compile(r'[{lchars}]+(?:[1-9][0-9]*)?'.format(lchars = LCHARS))
    SIGN = re.compile(r'(?:[{uchars}]+(?:[1-9][0-9]*)?|[0-9]+|(?:LAK|KWU|REC)[0-9]+[a-c]?)(?:@(?:[tgšc]|90|180))*'.format(uchars = UCHARS))


    def preprocess(term):
        
        term = term.replace('.', '-')
        term = term.replace('_', '.')

        term = re.sub(r'[^ ]+‹[^ ]*', r'»\0', term)

        term = re.sub(r'{([^}]*)}(?=[ \-;]|$)', r'{{\1}', term)
        term = re.sub(r'<([^>]*)>(?=[ \-;]|$)', r'<<\1>', term)

        return term


    class State:
        def __init__(self):
            self.gap = False
            self.part = ''
            self.con = ' '
            self.type = ''

        def processOp(self, op):

            if op == ' ':
                self.con = op
                self.part = ''
                self.type = ''
            elif op == ';':
                self.con = op
                self.part = ''
                self.type = ''
            elif op == '-':
                self.con = op

            elif op == '»':
                self.part = 'PREFIX'
            elif op == '‹':
                self.part = 'STEM'
            elif op == '›':
                self.part = 'SUFFIX'

            elif op == '{':
                self.type = 'DETS' if self.type == 'DETP' else 'DETP'
            elif op == '}':
                self.type = ''
            elif op == '<':
                self.type = 'PCS' if self.type == 'PCP' else 'PCP'
            elif op == '>':
                self.type = ''

            elif op == '…':
                self.gap = True

        def getType(self):
            return self.type if self.type else self.part


    def join_clause(a, b):
        return '{b} ON ('.format(b=b)+' AND '.join(['{a}.{col} = {b}.{col}'.format(a=a, b=b, col=col) for col in target_key])+')'


    state = State()
    conditions = []
    ctes = []
    cte_joins = []

    term = preprocess(search_term)
    tokens = re.findall(r'[{op}]|[^{op}]+'.format(op=OPERATORS), term)

    if tokens[0] in ';‹':
        from_clause = '{table} c JOIN {table} {join_clause}'.format(table=target_table, join_clause=join_clause('c', 'c0'))
        if tokens[0] == ';':
            conditions.append('((c0.sign_no = c.sign_no + 1 AND c.word_no != c0.word_no) OR (c0.sign_no = c.sign_no AND c.sign_no = 0))')
        elif tokens[0] == '‹':
            conditions.append("((c0.sign_no = c.sign_no + 1 AND c.stem = FALSE) OR (c0.sign_no = c.sign_no AND c.sign_no = 0))")
    else:
        from_clause = '{table} c0'.format(table=target_table)

    i = 0
    for token in tokens:

        if token in OPERATORS:
            state.processOp(token)
            continue

        # Connectors
        if i:
            if state.gap:
                conditions.append('c{i}.sign_no > c{i_p}.sign_no'.format(i = str(i), i_p = str(i-1)))
                state.gap = False 
            else:
                conditions.append('c{i}.sign_no = c{i_p}.sign_no + 1'.format(i = str(i), i_p = str(i-1)))

            if state.con == '-':
                conditions.append('c{i}.word_no = c{i_p}.word_no'.format(i = str(i), i_p = str(i-1)))
            elif state.con == ';':
                conditions.append('c{i}.word_no != c{i_p}.word_no'.format(i = str(i), i_p = str(i-1)))

        # Values
        if token == 'X':
            pass
        elif VALUE.fullmatch(token):
            ctes.append("cte{i} AS (SELECT value_id FROM value_variants WHERE value = '{sign}')".format(i = str(i), sign = token))
            cte_joins.append("cte{i} ON c{i}.value_id = cte{i}.value_id".format(i = str(i)))
        elif SIGN.fullmatch(token):
            ctes.append("cte{i} AS (SELECT sign_id FROM value_variants JOIN values USING (value_id) WHERE value = '{sign}')".format(i = str(i), sign = token.lower()))
            cte_joins.append("cte{i} ON c{i}.sign_id = cte{i}.sign_id".format(i = str(i)))
        else:
            ctes.append("cte{i} AS (SELECT value_id FROM value_variants WHERE value ~ '^{sign}$')".format(i = str(i), sign = token))
            cte_joins.append("cte{i} ON c{i}.value_id = cte{i}.value_id".format(i = str(i)))

        # Types
        if state.part:    
            conditions.append("c{i}.stem = {stem}".format(i = str(i), stem = state.part == 'STEM'))
        if state.type:    
            conditions.append("(c{i}.properties).type = '{type}'".format(i = str(i), type = state.type))

        i += 1


    from_clause = ' JOIN '.join([from_clause] + [target_table+' '+join_clause('c0', 'c'+str(j)) for j in range(1,i)] + cte_joins)

    if tokens[-1] in ';›':
        from_clause += ' JOIN {table} {join_clause1} JOIN (SELECT {key}, max(sign_no) as max_sign_no FROM {table} GROUP BY {key}) {join_clause2}'.format(key=', '.join(target_key), join_clause1=join_clause('c0', 'c_end'), join_clause2=join_clause('c0', 'counts'), table=target_table)
        if tokens[-1] == ';':
            conditions.append('((c_end.sign_no = c{i}.sign_no + 1 AND c{i}.word_no != c_end.word_no) OR (c_end.sign_no = c{i}.sign_no AND c_end.sign_no = max_sign_no))'.format(i = str(i-1)))
        elif tokens[-1] == '›':
            conditions.append("((c_end.sign_no = c{i}.sign_no + 1 AND c_end.segment_type = 'SUFFIX') OR (c_end.sign_no = c{i}.sign_no AND c_end.sign_no = max_sign_no))".format(i = str(i-1)))

    array_clause = ', '.join(['c{j}.sign_no'.format(j = str(j)) for j in range(i)])
    where_clause = ' AND '.join(conditions) if conditions else 'TRUE'
    cte_clause = ', '.join(ctes)

    return 'WITH {cte_clause} SELECT {keys}, ARRAY[{array_clause}] AS signs FROM {from_clause} WHERE {where_clause}'.format(keys = ', '.join(['c0.'+key for key in target_key]), cte_clause = cte_clause, array_clause = array_clause, from_clause = from_clause, where_clause = where_clause)
