/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    #define YYDEBUG 1
    int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;
    int scope_lv = 0;
    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(int, int, char*, char*, char*);
    static void change_func_sig(char*, char*);
    static struct symbol* lookup_symbol(char*);
    static void dump_symbol();
    static void undefined(char*);
    static void invalid_operation(char*, char*, char*);
    struct symbol{
        int index;
        char name[20];
        int mut;
        char type[20];
        int addr;
        int lineno;
        char func_sig[20];
        struct symbol* next;
    };
    struct symbol* symbol_first[1000];
    int yyaddr = 0;
    /* Global variables */
    bool HAS_ERROR = false;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token RETURN BREAK
%token ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT ID FUNC 

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type
%type <s_val> Expression ExpressionTerm MathStmt DeclStmt DclArray
%type <s_val> FunctionDeclStmt DataType DataTypeDcl CheckReturnType ParamList FuncPrint
%type <s_val> ArithStmt ArithTerm ArithFactor ArithOperator HighArith LowArith
%type <s_val> LogicStmt LogicOp
%type <s_val> ConditionStmt ConditionOp  
%type <s_val> ShiftStmt ShiftOp
%type <s_val> StringStmt
%type <i_val> CheckMut
%type <s_val> AssignTerm
%type <s_val> ForCounter

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | 
;

FunctionDeclStmt
    : FuncHead '{' StmtList '}' { dump_symbol(); yyaddr = 0;}
;

FuncHead
    : FuncPrint '(' ParamList ')' CheckReturnType {
            //printf("%s\n", $3);
            char func_sig[50];
            char temp[10];
            strcpy(temp, $3);
            strcpy(func_sig, "(");
            strcat(func_sig, temp);
            strcat(func_sig, ")");
            //printf("%s\n", func_sig);
            if(strcmp($5, "V") == 0) strcpy(temp, "V");
            else if(strcmp($5, "i32") == 0) strcpy(temp, "I");
            else if(strcmp($5, "f32") == 0) strcpy(temp, "F");
            else if(strcmp($5, "bool") == 0) strcpy(temp, "B");
            else if(strcmp($5, "str") == 0) strcpy(temp, "S");
            strcat(func_sig, temp);
            change_func_sig($1, func_sig);
        }
;

FuncPrint
    : FUNC ID {
            printf("func: %s\n", $2); 
            insert_symbol(-1, -1, $2, "func", "(V)V");
            create_symbol();
            $$ = $2;
        }
;

CheckReturnType
    : ARROW DataTypeDcl { $$ = $2;}
    |                   { $$ = "V";}
;

ParamList
    : ParamList ',' DeclStmt {
            //printf("%s\n", $1);
            char pl[50];
            char temp[10];
            if(strcmp($3, "i32") == 0) strcpy(temp, "I");
            else if(strcmp($3, "f32") == 0) strcpy(temp, "F");
            else if(strcmp($3, "bool") == 0) strcpy(temp, "B");
            else if(strcmp($3, "str") == 0) strcpy(temp, "S");
            strcpy(pl, $1);
            strcat(pl, temp);
            $$ = pl;
        }
    | DeclStmt  { 
            char temp[10];
            if(strcmp($1, "i32") == 0) strcpy(temp, "I");
            else if(strcmp($1, "f32") == 0) strcpy(temp, "F");
            else if(strcmp($1, "bool") == 0) strcpy(temp, "B");
            else if(strcmp($1, "str") == 0) strcpy(temp, "S");
            $$ = temp;
        }
    |   { $$ = "V";}
;

StmtList
    : StmtList Stmt
    | Stmt
;

Stmt
    : DeclStmt ';'
    | ReturnStmt
    | MathStmt ';'
    | AssignStmt ';'
    | Block 
    | IfStmt 
    | ForStmt 
    | WhileStmt
    | PrintStmt ';'
    | ReturnStmt ';'
    | ReturnStmt2
    | CallStmt ';'
    | LoopStmt
    | BreakStmt ';'
;

DeclStmt
    : CheckLet CheckMut ID ':' DataType {
            insert_symbol(yyaddr++, $2, $3, $5, "-");
            $$ = $5;
        }
    
    | CheckLet CheckMut ID ':' DataTypeDcl {
            insert_symbol(yyaddr++, $2, $3, $5, "-");
            $$ = $5;
        }
    | CheckLet CheckMut ID '=' Expression {
            insert_symbol(yyaddr++, $2, $3, $5, "-");
            $$ = $5;
        }
    | CheckLet DclArray { $$ = $2;}
;

CheckLet
    : LET
    |
;

CheckMut
    : MUT   { $$=1;}
    |       { $$=0;}

DataType
    : INT '=' ArithStmt          { $$ = "i32";}
    | INT '=' LoopStmt          { $$ = "i32";}
    | FLOAT '=' ArithStmt        { $$ = "f32";}
    | FLOAT '=' LoopStmt        { $$ = "f32";}
    | '&' STR '=' StringStmt    { $$ = "str";}
    | '&' STR '=' SliceStmt    { $$ = "str";}
    | '&' STR '=' LoopStmt    { $$ = "str";}
    | STR '=' StringStmt        { $$ = "str";}
    | STR '=' SliceStmt        { $$ = "str";}
    | STR '=' LoopStmt        { $$ = "str";}
    | BOOL '=' LogicStmt        { $$ = "bool";}
    | BOOL '=' LoopStmt        { $$ = "bool";}
;

SliceStmt
    : SliceHead '[' SliceTerm ']' 
;
SliceHead
    : CheckAnd ID { 
            struct symbol *temp = lookup_symbol($2);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $2, temp->addr);
            }
            else{
                undefined($2);
            }
            
        }
;

CheckAnd
    : '&'
;

SliceTerm
    : Expression
    | Expression DDPrint Expression 
    | Expression DDPrint
    | DDPrint Expression
;

DDPrint
    : DOTDOT { printf("DOTDOT\n");}
;

DataTypeDcl
    : INT       { $$ = "i32";}
    | FLOAT     { $$ = "f32";}
    | '&' STR   { $$ = "str";}
    | STR       { $$ = "str";}
    | BOOL      { $$ = "bool";}
;

DclArray 
    : CheckMut ID ':' '[' DataTypeDcl ';' FindInt ']' '=' '[' ArrayParamList ']' {
            insert_symbol(yyaddr++, $1, $2, "array", "-");
            $$ = $5;
        }
;

FindInt
    : INT_LIT { printf("INT_LIT %d\n", $1);}
;

ArrayParamList
    : ArrayParamList ',' Expression
    | Expression
;

MathStmt
    : ArithStmt { $$ = $1;}
    | ConditionStmt { $$ = $1;}
    | LogicStmt { $$ = "bool";}
    | ShiftStmt
;

ArithStmt
    : ArithTerm { $$ = $1;}
    | ArithStmt LowArith ArithTerm   { 
            /*
            if(strcmp($3, "none")!=0){
                struct symbol *temp = lookup_symbol($3);
                printf("%s\n", $2);
                strcpy($$, temp->type);
            }
            else{
                printf("%s\n", $2);
            }
            */
            printf("%s\n", $2);
            $$ = $3;
        }
;

ArithOperator
    : HighArith { $$ = $1;}
    | LowArith  { $$ = $1;}
;

HighArith
    : '*' { $$="MUL";}
    | '/' { $$="DIV";}
    | '%' { $$="REM";}
;

LowArith
    : '+' { $$="ADD";}
    | '-' { $$="SUB";}
;
ArithTerm
    : ArithFactor {$$ = $1;}
    | ArithTerm HighArith ArithFactor   {  
            printf("%s\n", $2);
            $$ = $3;
        }
;
ArithFactor
    : ID { 
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $1, temp->addr);
                $$ = temp->type;
            }
            else{
                undefined($1);
            }
            
        }
    | INT_LIT {
            printf("INT_LIT %d\n", $1); 
            $$ = "i32";
        }
    | FLOAT_LIT {
            printf("FLOAT_LIT %.6f\n", $1); 
            $$ = "f32";
        }
    | '-' ArithFactor { 
            printf("NEG\n");
            $$ = $2;
        }
    | '(' ArithStmt ')' { $$ = $2;}
    | ArithFactor AS DataTypeDcl { 
            char before, after;
            if(strcmp($1, "i32")==0)    before = 'i';
            else                        before = 'f';
            if(strcmp($3, "i32")==0)    after = 'i';
            else                        after = 'f';
            printf("%c2%c\n", before, after);
            $$ = $3;
        }
;

ConditionStmt
    : ArithStmt ConditionOp ArithStmt {
            invalid_operation($1, $2, $3);
            printf("%s\n", $2);
        }
;

ConditionOp
    : '>' { $$ = "GTR";}
    | '<' { $$ = "LSS";}
    | GEQ { $$ = "GEQ";}
    | LEQ { $$ = "LEQ";}
    | EQL { $$ = "EQL";}
    | NEQ { $$ = "NEQ";}
;

LogicStmt
    : LogicStmt LOR LogicTerm {
            printf("LOR\n");
        }
    | LogicTerm
;

LogicTerm
    : LogicTerm LAND LogicFactor {
            printf("LAND\n");
        }
    | LogicFactor
;

LogicFactor
    : '!' LogicFactor { printf("NOT\n"); }
    | Boolin
    | CallStmt
;

Boolin
    : TRUE  { printf("bool TRUE\n");}
    | FALSE { printf("bool FALSE\n");}
    | ConditionStmt
    | '(' LogicStmt ')'
;

ShiftStmt
    : Expression ShiftOp Expression { 
                invalid_operation($1, $2, $3);
                printf("LSHIFT\n");
                
            }
;

ShiftOp
    : LSHIFT { $$ = "LSHIFT";}
    | RSHIFT { $$ = "RSHIFT";}
;
AssignStmt
    : ID AssignTerm Expression { 
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL)
                printf("%s\n", $2);
            else{
                undefined($1);
            }
        }
;

AssignTerm
    : '=' { $$ = "ASSIGN";}
    | ADD_ASSIGN { $$ = "ADD_ASSIGN";}
    | SUB_ASSIGN { $$ = "SUB_ASSIGN";}
    | MUL_ASSIGN { $$ = "MUL_ASSIGN";}
    | DIV_ASSIGN { $$ = "DIV_ASSIGN";}
    | REM_ASSIGN { $$ = "REM_ASSIGN";}
;
Block
    : BlockLBrace StmtList '}' { dump_symbol();}
;

BlockLBrace
    : '{' { create_symbol();}
;

IfStmt
    : IfStmt ElseStmt
    | IF LogicStmt Block
;

ElseStmt
    : ELSE Block
;

ForStmt
    : ForHead '{' StmtList '}' {
            dump_symbol();
        }
;
ForHead
    : FOR ForCounter IN ForID {
            create_symbol();
            insert_symbol(yyaddr++, 0, $2, "i32", "-");
        }
;

ForCounter
    : ID { $$ = $1;}
;

ForID
    : ID {
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $1, temp->addr);
            }
            else{
                undefined($1);
            }
        }
;

WhileStmt
    : WHILE LogicStmt Block
;

PrintStmt
    : PRINTLN '(' Expression ')'    { printf("PRINTLN %s\n", $3);}
    | PRINT '(' Expression ')'      { printf("PRINT %s\n", $3);}
;

Expression
    : StringStmt { $$ = $1;}
    | MathStmt { $$ = $1;}
    | ID '[' INT_LIT ']' { 
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $1, temp->addr);
            }
            else{
                undefined($1);
            }
            printf("INT_LIT %d\n", $3);
            $$ = "array";
        }
;


ReturnStmt
    : RETURN Expression {
            printf("breturn\n");
        }
;

ReturnStmt2
    : Expression {
            printf("breturn\n");
        }
;

StringStmt
    : '\"' STRING_LIT '\"'  {
            printf("STRING_LIT \"%s\"\n", $2);
            $$ = "str";
        }
    | '\"' '\"' {
            printf("STRING_LIT \"\"\n");
            $$ = "str";
        }
;

CallStmt
    : ID '(' CallParamList ')' {
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("call: %s%s\n", $1, temp->func_sig);
            }
            else{
                undefined($1);
            }
        }
;

CallParamList
    : CallParamList ',' Expression
    | Expression
    |
;

LoopStmt
    :   LOOP BlockLBrace StmtList '}' { dump_symbol();}
;

BreakStmt
    : BREAK 
    | BREAK Expression 
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    create_symbol();
    yyparse();
    dump_symbol();
	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", scope_lv);
    symbol_first[scope_lv++] = NULL;
}

static void insert_symbol(int addr, int mut, char* name, char* type, char* func_sig) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope_lv-1);
    //printf("%s\n", type);
    struct symbol* temp = malloc(sizeof(struct symbol));
    if(symbol_first[scope_lv-1] == NULL){
        temp->index = 0;
        symbol_first[scope_lv-1] = temp;
    }
    else{
        struct symbol* find_last = symbol_first[scope_lv-1];
        while(find_last->next != NULL){
            find_last = find_last->next;
        }
        find_last->next = temp;
        temp->index = find_last->index+1;
    }
    strcpy(temp->name, name);
    /*
    if(strcmp(type, "func") == 0){
        temp->mut = -1;
    }
    else{
        temp->mut = 0;
    }
    */
    temp->mut = mut;
    strcpy(temp->type, type);
    temp->addr = addr;
    temp->lineno = yylineno+1;
    /*
    if(strcmp(type, "func") == 0){
        strcpy(temp->func_sig, "(V)V");
    }
    else{
        strcpy(temp->func_sig, "-");
    }
    */
    strcpy(temp->func_sig, func_sig);
    temp->next = NULL;
}

static void change_func_sig(char* name, char* func_sig){
    int scope_cur = scope_lv-1;
    struct symbol* temp = symbol_first[scope_cur];
    //printf("%s\n", name);
    while(scope_cur < scope_lv){
        while(temp!=NULL && strcmp(temp->name, name) != 0 ){
            //printf("%s\n", temp->name);
            temp = temp->next;
        }
        if(temp == NULL && scope_cur > 0 )
            temp = symbol_first[--scope_cur];
        else
            break;
    }
    strcpy(temp->func_sig, func_sig);
}

static struct symbol* lookup_symbol(char* name) {
    int scope_cur = scope_lv-1;
    struct symbol* temp = symbol_first[scope_cur];
    //printf("%s\n", name);
    while(scope_cur < scope_lv){
        while(temp!=NULL && strcmp(temp->name, name) != 0 ){
            //printf("%s\n", temp->name);
            temp = temp->next;
        }
        if(temp == NULL && scope_cur > 0 )
            temp = symbol_first[--scope_cur];
        else
            break;
    }
    
    return temp;
}

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", --scope_lv);
    struct symbol* temp = symbol_first[scope_lv];
    struct symbol* temp_pre = temp;
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
            "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    while(temp!=NULL){
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                temp->index, temp->name, temp->mut, temp->type, temp->addr, temp->lineno, temp->func_sig);
        temp = temp->next;
        free(temp_pre);
        temp_pre = temp;
    }
    
}

static void undefined(char* id){
    char err[100];
    yylineno++;
    strcpy(err, "undefined: ");
    strcat(err, id);
    yyerror(err);
    yylineno--;
}

static void invalid_operation(char* left_token, char* operator, char* right_token){
    bool correct = true;
    struct symbol* left = lookup_symbol(left_token);
    struct symbol* right;
    char ltype[10], rtype[10];
    if(left != NULL)
        strcpy(ltype, left->type);
    else if(strcmp(left_token,"i32")!=0
            && strcmp(left_token,"f32")!=0
            && strcmp(left_token,"bool")!=0
            && strcmp(left_token,"str")!=0)
        strcpy(ltype, "undefined");
    else
        strcpy(ltype, left_token);
    if(strcmp(right_token,"i32")!=0
        && strcmp(right_token,"f32")!=0
        && strcmp(right_token,"bool")!=0
        && strcmp(right_token,"str")!=0)
    {
        right = lookup_symbol(right_token);
        if(right == NULL){
            correct = false;
            strcpy(rtype, "undefined");
        }
        else{
            strcpy(rtype, right->type);
        }
    }
    else{
        strcpy(rtype, right_token);
    }
    if(strcmp(ltype, rtype)!=0 && correct){
        correct = false;
        char err[100];
        yylineno++;
        strcpy(err, "invalid operation: ");
        strcat(err, operator);
        strcat(err, " (mismatched types ");
        strcat(err, ltype);
        strcat(err, " and ");
        strcat(err, rtype);
        strcat(err, ")");
        yyerror(err);
        yylineno--;
    }
    //printf("%s\n", operator);
}