%lex

%%

"#"(.)*\n                                 /* skip comments */
\s+                                       /* skip whitespace */

"switch"                                  return 'SWITCH';
"if"                                      return 'IF';
"else"                                    return 'ELSE';

[a-zA-Z][a-zA-Z0-9_]*                     return 'IDENTIFIER'

[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?    { yytext = Number(yytext); return 'CONST'; }
\"(\\.|[^\\"])*\"                         { yytext = yytext.substr(1, yyleng-2); return 'CONST'; }
\'[^\']*\'                                { yytext = yytext.substr(1, yyleng-2); return 'CONST'; }

"||"                                      return 'OR'
"&&"                                      return 'AND'
"=="                                      return 'EQUALS'
">="                                      return 'GTE'
"<="                                      return 'LTE'
"!="                                      return 'NEQ'
"=>"                                      return 'THEN'
";"                                       return 'END_STATEMENT'

"="|":"|"["|"]"|"("|")"|","|"{"|"}"|"+"|"%"|"*"|"-"|"/"|"%"|">"|"<"|"!"
                                          return yytext

/lex

%token AND
%token CONST
%token DEFAULT
%token ELSE
%token END_STATEMENT
%token EQUALS
%token GTE
%token IDENTIFIER
%token IF
%token JSON_START
%token LTE
%token NEQ
%token OR
%token SWITCH
%token THEN

%left '!'
%left OR AND
%left EQUALS NEQ LTE GTE '>' '<'
%left '+' '-'
%left '*' '/' '%'

%%

start
  : rules_list
    { $$ = {"op": "seq", "seq": $1}; console.log(JSON.stringify($$)); return $$; }
  ;

rules_list
  : /* empty */
    { $$ = []; }
  | rules_list rule
    { $$ = $1; $$.push($2); }
  ;

rule
  : expression
    { $$ = $1; }
  | IDENTIFIER '=' simple_expression END_STATEMENT
    { $$ = {"op": "set", "var": $1, "value": $3}; }
  ;

expression
  : switch_expression
    { $$ = $1; }
  | if_expression
    { $$ = $1; }
  ;

simple_expression
  : IDENTIFIER
    { $$ = {"op": "get", "var": $1}; }
  | '[' array ']'
    { $$ = {"op": "array", "values": $2}; }
  | IDENTIFIER '(' arguments ')'
    { $$ = $3; $$["op"] = $1; }
  | IDENTIFIER '[' simple_expression ']'
    { $$ = {"op": "index", "base": {"op": "get", "var": $1}, "index": $3}; }
  | '[' array ']' '[' simple_expression ']'
    { $$ = {"op": "index", "base": {"op": "array", "values": $2}, "index": $5}; }
  | '{' rules_list '}'
    { $$ = {"op": "seq", "seq": $2}; }
  | '(' simple_expression ')'
    { $$ = $2; }
  | CONST
    { $$ = $1; }
  | simple_expression '%' simple_expression
    { $$ = {"op": "%", "left": $1, "right": $3}; }
  | simple_expression '/' simple_expression
    { $$ = {"op": "/", "left": $1, "right": $3}; }
  | simple_expression '>' simple_expression
    { $$ = {"op": ">", "left": $1, "right": $3}; }
  | simple_expression '<' simple_expression
    { $$ = {"op": "<", "left": $1, "right": $3}; }
  | simple_expression EQUALS simple_expression
    { $$ = {"op": "equals", "left": $1, "right": $3}; }
  | simple_expression NEQ simple_expression
    { $$ = {"op": "not", "value": {"op": "equals", "left": $1, "right": $3}}; }
  | simple_expression LTE simple_expression
    { $$ = {"op": "<=", "left": $1, "right": $3}; }
  | simple_expression GTE simple_expression
    { $$ = {"op": ">=", "left": $1, "right": $3}; }
  | simple_expression '+' simple_expression
    { $$ = {"op": "sum", "values": [$1, $3]}; }
  | simple_expression '-' simple_expression
    { $$ = {"op": "sum", "values": [$1, {"op": "negative", "value": $3}]}; }
  | simple_expression '*' simple_expression
    { $$ = {"op": "product", "values": [$1, $3]}; }
  | '-' simple_expression
    { $$ = {"op": "negative", "value": $2}; }
  | '!' simple_expression
    { $$ = {"op": "not", "value": $2}; }
  | simple_expression OR simple_expression
    { $$ = {"op": "or", "values": [$1, $3]}; }
  | simple_expression AND simple_expression
    { $$ = {"op": "and", "values": [$1, $3]}; }
  ;

array
  : /* empty */
    { $$ = []; }
  | simple_expression
    { $$ = [$1]; }
  | array ',' simple_expression
    { $$ = $1; $$.push($3); }
  ;

arguments
  : /* empty */
    { $$ = {}; }
  | arguments_list
    { $$ = $1; }
  | values_list
    { $$ = $1; }
  ;

arguments_list
  : IDENTIFIER '=' simple_expression
    { $$ = {}; $$[$1] = $3; }
  | arguments_list ',' IDENTIFIER '=' simple_expression
    { $$ = $1; $$[$3] = $5; }
  ;

values_list
  : simple_expression
    { $$ = {}; $$["values"] = [$1]; }
  | values_list ',' simple_expression
    { $$ = $1; $$["values"].push($3); }
  ;

switch_expression
  : SWITCH '{' cases_list '}'
    { $$ = {"op": "switch", "cases": $3}; }
  ;

if_expression
  : IF '(' simple_expression ')' simple_expression optional_else_expression
    { $$ = {"op": "cond", "cond": [{"if": $3, "then": $5}]};
      if ($6["cond"]) {
        $$["cond"] = $$["cond"].concat($6["cond"]);
      }
    }
  ;

optional_else_expression
  : /* empty */
    { $$ = {}; }
  | ELSE if_expression
    { $$ = $2; }
  | ELSE simple_expression
    { $$ = {"op": "cond", "cond": [{"if": true, "then": $2}]}; }
  ;

cases_list
  : /* empty */
    { $$ = []; }
  | cases_list case END_STATEMENT
    { $$ = $1; $$.push($2); }
  ;

case
  : simple_expression THEN expression
    { $$ = {"op": "case", "condidion": $1, "result": $3}; }
  ;
