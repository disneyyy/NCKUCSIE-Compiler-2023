/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    //#define YYDEBUG 1
    //int yydebug = 1;

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
    static void insert_symbol(int, int, char*, char*, char*, int);
    static void change_func_sig(char*, char*);
    static struct symbol* lookup_symbol(char*);
    static void dump_symbol();
    static void undefined(char*);
    static char determine_type(char*);
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
        int array_len;
    };
    struct symbol* symbol_first[1000];
    int yyaddr = 0;
    /* Global variables */
    bool HAS_ERROR = false;
    bool is_div = false;
    bool is_if_stmt = false;
    bool is_while = false;
    char returntype = 'V';
    char div_backup_str[100];
    FILE *fp;
    int label_num = 0;
    //int if_num = 0;
    int while_num = 0;
    int counter_num = 0;
    int array_i = 0;
    int array_addr = 0;
    static void print_branch(char* success, char* fail, char* arg){
        //ifxx true_label (compare with 0)
        //  iconst_0
        //goto end(num)
        //true_label(num):
        //  iconst_1
        //end(num):

        fprintf(fp, "%s true_label%d\n", arg, label_num);
        if(!is_if_stmt && !is_while)
            fprintf(fp, "\t%s\n", fail);
        fprintf(fp, "goto end%d\n", label_num);
        fprintf(fp, "true_label%d:\n", label_num);
        if(!is_if_stmt && !is_while){
            fprintf(fp, "\t%s\n", success);
            fprintf(fp, "end%d:\n", label_num++);
        }
    }
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
%type <i_val> CheckMut FindInt SliceTerm
%type <s_val> AssignTerm
%type <s_val> ForCounter DclArrayHead ForID SliceHead

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
    : FuncHead '{' StmtList '}' { 
        dump_symbol();
        char temp;
        if(returntype == 'I' || returntype == 'B'){
            temp = 'i';
        }
        else if(returntype == 'F'){
            temp = 'f';
        }
        else if(returntype == 'V'){
            temp = ' ';
        }
        else{
            temp = 'a';
        }
        fprintf(fp, "%creturn\n", temp);
        fprintf(fp, ".end method\n\n");
        yyaddr = 0;
        }
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
            else if(strcmp($5, "bool") == 0) strcpy(temp, "I");
            else if(strcmp($5, "str") == 0) strcpy(temp, "S");
            strcat(func_sig, temp);
            change_func_sig($1, func_sig);
            returntype = temp[0];
            fprintf(fp, ".limit stack 100\n.limit locals 100\n");
        }
;

FuncPrint
    : FUNC ID {
            printf("func: %s\n", $2); 
            insert_symbol(-1, -1, $2, "func", "(V)V", 0);
            create_symbol();
            $$ = $2;

            fprintf(fp, ".method public static %s", $2);
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
    |   { $$ = "";}
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
    | BreakStmt ';' {
            fprintf(fp, "goto break%d\n", while_num);
        }
;

DeclStmt
    : CheckLet CheckMut ID ':' DataType {
            insert_symbol(yyaddr++, $2, $3, $5, "-", 0);
            char type = determine_type($5);
            if(strcmp($5, "bool") == 0) type = 'i';
            fprintf(fp, "%cstore %d\n", type, yyaddr-1);
            $$ = $5;
        }
    
    | CheckLet CheckMut ID ':' DataTypeDcl {
            insert_symbol(yyaddr++, $2, $3, $5, "-", 0);
            //char type = determine_type($5);
            //if(strcmp($5, "bool") == 0) type = 'i';
            //fprintf(fp, "%cstore %d\n", type, yyaddr-1);
            $$ = $5;
        }
    | CheckLet CheckMut ID '=' Expression {
            insert_symbol(yyaddr++, $2, $3, $5, "-", 0);
            char type = determine_type($5);
            if(strcmp($5, "bool") == 0) type = 'i';
            fprintf(fp, "%cstore %d\n", type, yyaddr-1);
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
    : SliceHead '[' SliceTerm ']' { 
            if($3 == 1){
                struct symbol *temp = lookup_symbol($1);
                if(temp != NULL){
                    fprintf(fp, "aload %d\n", temp->addr);
                    fprintf(fp, "invokevirtual java/lang/String.length()I\n");
                }
                else{
                    undefined($1);
                }
            }
            fprintf(fp, "invokevirtual java/lang/String/substring(II)Ljava/lang/String;\n");}
;
SliceHead
    : CheckAnd ID { 
            struct symbol *temp = lookup_symbol($2);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $2, temp->addr);
                fprintf(fp, "aload %d\n", temp->addr);
            }
            else{
                undefined($2);
            }
            $$ = $2;
        }
;

CheckAnd
    : '&'
;

SliceTerm
    : Expression { $$ = 0;}
    | Expression DDPrint Expression { $$ = 0;}
    | Expression DDPrint { $$ = 1;}
    | SliceHead DDPrint Expression { $$ = 0;}
;

DDPrint
    : DOTDOT { printf("DOTDOT\n");}
;

SliceHead
    : {
        fprintf(fp, "ldc 0\n");
    }
;

DataTypeDcl
    : INT       { $$ = "i32";}
    | FLOAT     { $$ = "f32";}
    | '&' STR   { $$ = "str";}
    | STR       { $$ = "str";}
    | BOOL      { $$ = "bool";}
;

DclArray 
    : DclArrayHead '=' '[' ArrayParamList ']' {
            array_i = 0;
            $$ = $1;
        }
;

DclArrayHead
    : CheckMut ID ':' '[' DataTypeDcl ';' FindInt ']' {
            insert_symbol(yyaddr++, $1, $2, $5, "-", $7);
            //yyaddr += $7;
            struct symbol* temp = lookup_symbol($2);
            char type[10];
            if(temp != NULL){
                if(strcmp($5, "f32") == 0){
                    strcpy(type, "float");
                }
                else if (strcmp($5, "i32") == 0 || strcmp($5, "bool") == 0){
                    strcpy(type, "int");
                }
                else{
                    strcpy(type, "int");
                }
                //declare array
                fprintf(fp, "ldc %d\n", $7);
                fprintf(fp, "newarray %s\n", type);
                fprintf(fp, "astore %d\n", yyaddr-1);
                array_addr = yyaddr-1;
            }
            else{
                HAS_ERROR = true;
            }
            $$ = $5;
        }
;

FindInt
    : INT_LIT { printf("INT_LIT %d\n", $1); $$ = $1;}
;

ArrayParamList
    : ArrayParamList ',' ArrayParamListBody Expression2
    | ArrayParamListBody Expression2
;

ArrayParamListBody
    : {
            fprintf(fp, "aload %d\n", array_addr);
            fprintf(fp, "ldc %d\n", array_i++);
        }
;

Expression2
    : Expression {
            /*
            char type = determine_type($1);
            if(strcmp($1, "bool") == 0) type = 'i';
            fprintf(fp, "%cstore %d\n", type, yyaddr++);
            */
            char type = determine_type($1);
            if(strcmp($1, "bool") == 0) type = 'i';
            fprintf(fp, "%castore\n", type);

        }
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
            char type = determine_type($1);
            char temp[20];
            if(strcmp($2, "ADD") == 0){
                strcpy(temp, "add");
            }
            else {
                strcpy(temp, "sub");
            }
            fprintf(fp, "%c%s\n", type, temp);
            printf("%s\n", $2);
            $$ = $3;
        }
;

ArithOperator
    : HighArith { $$ = $1;}
    | LowArith  { $$ = $1;}
;

HighArith
    : '*' { $$="MUL"; }
    | '/' { $$="DIV"; }
    | '%' { $$="REM"; }
;

LowArith
    : '+' { $$="ADD"; }
    | '-' { $$="SUB"; }
;
ArithTerm
    : ArithFactor {$$ = $1;}
    | ArithTerm HighArith ArithFactor   {  
            printf("%s\n", $2);
            char type = determine_type($3);;
            char temp[20];
            if(strcmp($2, "MUL") == 0){
                strcpy(temp, "mul");
            }
            else if(strcmp($2, "DIV") == 0){
                strcpy(temp, "div");
            }
            else{
                strcpy(temp, "rem");
            }
            fprintf(fp, "%c%s\n", type, temp);
            $$ = $3;
        }
;
ArithFactor
    : ID { 
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $1, temp->addr);
                char type = determine_type(temp->type);
                if(strcmp(temp->type, "bool") == 0) type = 'i';
                fprintf(fp, "%cload %d\n", type, temp->addr);
                $$ = temp->type;
            }
            else{
                undefined($1);
            }
            
        }
    | INT_LIT {
            if(!is_div)
                fprintf(fp, "ldc %d\n", $1);
            else{
                strcpy(div_backup_str, "");
                sprintf(div_backup_str, "ldc %d\n", $1);
            }
            printf("INT_LIT %d\n", $1); 
            $$ = "i32";
        }
    | FLOAT_LIT {
            if(!is_div)
                fprintf(fp, "ldc %f\n", $1);
            else{
                strcpy(div_backup_str, "");
                sprintf(div_backup_str, "ldc %f\n", $1);
            }
            printf("FLOAT_LIT %.6f\n", $1); 
            $$ = "f32";
        }
    | '-' ArithFactor { 
            fprintf(fp, "%cneg\n", determine_type($2));
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
            fprintf(fp, "%c2%c\n", before, after);
            $$ = $3;
        }
;

ConditionStmt
    : ArithStmt ConditionOp ArithStmt {
            invalid_operation($1, $2, $3);
            printf("%s\n", $2);
            char temp[20];
            if(strcmp($1, "i32") == 0){
                strcpy(temp, "isub");
            }
            else{
                strcpy(temp, "fcmpg");
            }
            fprintf(fp, "%s\n", temp);
            print_branch("iconst_1", "iconst_0", $2);

        }
;

ConditionOp
    : '>' { $$ = "ifge";}
    | '<' { $$ = "iflt";}
    | GEQ { $$ = "ifge";}
    | LEQ { $$ = "ifle";}
    | EQL { $$ = "ifeq";}
    | NEQ { $$ = "ifne";}
;

LogicStmt
    : LogicStmt LOR LogicTerm {
            printf("LOR\n");
            fprintf(fp, "ior\n");
        }
    | LogicTerm
;

LogicTerm
    : LogicTerm LAND LogicFactor {
            printf("LAND\n");
            fprintf(fp, "iand\n");
        }
    | LogicFactor
;

LogicFactor
    : '!' LogicFactor { printf("NOT\n"); }
    | Boolin
    | CallStmt
;

Boolin
    : TRUE  { printf("bool TRUE\n"); fprintf(fp, "iconst_1\n");}
    | FALSE { printf("bool FALSE\n");fprintf(fp, "iconst_0\n");}
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
            if(temp != NULL){
                printf("%s\n", $2);
                char type = determine_type(temp->type);
                if(strcmp(temp->type, "bool") == 0) type = 'i';
                if(strcmp($2, "ASSIGN") == 0){
                    //just assign
                    fprintf(fp, "%cstore %d\n", type, temp->addr);
                }
                else{
                    // ?=
                    fprintf(fp, "%cload %d\n", type, temp->addr);
                    //fprintf(fp, "%cstore %d\n", type, temp->addr);//temporary store
                    switch($2[0]){
                        case 'A':
                            fprintf(fp, "%cadd\n", type);
                        break;
                        case 'S':
                            fprintf(fp, "%csub\n", type);
                            fprintf(fp, "%cneg\n", type);// fix sequence
                        break;
                        case 'M':
                            fprintf(fp, "%cmul\n", type);
                        break;  
                        case 'D':
                            if(is_div){
                                is_div = false;
                                fprintf(fp, "%s", div_backup_str);
                            }
                            fprintf(fp, "%cdiv\n", type);
                        break;
                        default:
                            if(type != 'i') HAS_ERROR = true;
                            if(is_div){
                                is_div = false;
                                fprintf(fp, "%s", div_backup_str);
                            }
                            fprintf(fp, "%crem\n", type);
                    }
                    fprintf(fp, "%cstore %d\n", type, temp->addr);
                }                
            }
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
    | DIV_ASSIGN { $$ = "DIV_ASSIGN"; is_div = true;}
    | REM_ASSIGN { $$ = "REM_ASSIGN"; is_div = true;}
;
Block
    : BlockLBrace StmtList '}' { dump_symbol();}
;

BlockLBrace
    : '{' { create_symbol();}
;

IfStmt
    : IfStmt2 ElseStmt {
            fprintf(fp, "end%d_%d:\n", label_num, label_num);
            is_if_stmt = false;
            label_num++;
        }
;

IfStmt2
    : IF IfHead LogicStmt Block{
            fprintf(fp, "goto end%d_%d\n", label_num, label_num);
            fprintf(fp, "end%d:\n", label_num);
            //is_if_stmt = false;
        }
;

IfHead
    : {
            is_if_stmt = true;
        }
;

ElseStmt
    : ELSE Block
    |
;

ForStmt
    : ForHead Block {  
            fprintf(fp, "iconst_1\n");
            char counter_name[20];
            sprintf(counter_name, "counter_i%d", counter_num-1);
            struct symbol* temp_i = lookup_symbol(counter_name);

            strcpy(counter_name, "");
            sprintf(counter_name, "counter_max%d", counter_num-1);
            struct symbol* temp_max = lookup_symbol(counter_name);

            if(temp_i != NULL && temp_max != NULL){
                fprintf(fp, "iload %d\n", temp_i->addr);
                fprintf(fp, "iadd\n");
                fprintf(fp, "istore %d\n", temp_i->addr);

                fprintf(fp, "iload %d\n", temp_i->addr);
                fprintf(fp, "iload %d\n", temp_max->addr);
                fprintf(fp, "isub\n");
                print_branch("true", "false", "ifne");
            }
            else{
                HAS_ERROR = true;
            }
            is_while = false;
            fprintf(fp, "goto for%d\n", while_num++);
            fprintf(fp, "end%d:\n", label_num++);
        }
;
ForHead
    : FOR ForCounter IN ForID {
            create_symbol();
            insert_symbol(yyaddr++, 0, $2, "i32", "-", 0);
            struct symbol* temp = lookup_symbol($4);
            struct symbol* temp_counter = lookup_symbol($2);
            char type = 'i', type_counter = 'i';
            if(temp != NULL && temp_counter != NULL){
                type = determine_type(temp->type);
                if(strcmp(temp->type, "bool") == 0) type = 'i';
                type_counter = determine_type(temp_counter->type);
                if(strcmp(temp_counter->type, "bool") == 0) type_counter = 'i';
                is_while = true;

                //give counter_i a register
                char counter_name[20];
                sprintf(counter_name, "counter_i%d", counter_num);
                fprintf(fp, "ldc 0\n");
                fprintf(fp, "istore %d\n", yyaddr);
                insert_symbol(yyaddr++, 0, counter_name, "i32", "-", 0);

                //give counter_max a register
                strcpy(counter_name, "");
                sprintf(counter_name, "counter_max%d", counter_num++);
                fprintf(fp, "ldc %d\n", temp->array_len);
                fprintf(fp, "istore %d\n", yyaddr);
                insert_symbol(yyaddr++, 0, counter_name, "i32", "-", 0);
                
                fprintf(fp, "for%d:\n", while_num);
                
                fprintf(fp, "aload %d\n", temp->addr);
                fprintf(fp, "iload %d\n",yyaddr-2);// load counter_i
                fprintf(fp, "%caload\n", type);
                fprintf(fp, "%cstore %d\n", type_counter, temp_counter->addr);

            }
            else
                HAS_ERROR = true;
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
            $$ = $1;
        }
;

WhileStmt
    : WhileHead WHILE LogicStmt Block{
        is_while = false;
        fprintf(fp, "goto checkwhile%d\n", while_num++);
        fprintf(fp, "end%d:\n", label_num++);
    }
;

WhileHead
    : {
            is_while = true;
            fprintf(fp, "checkwhile%d:\n", while_num);
        }
;

PrintStmt
    : PRINTLN '(' Expression ')'    { 
            printf("PRINTLN %s\n", $3);
            char temp[50];
            if(strcmp($3, "i32") == 0){
                strcpy(temp, "I");
            }
            else if(strcmp($3, "f32") == 0){
                strcpy(temp, "F");
            }
            else{
                strcpy(temp, "Ljava/lang/String;");
            }
            //fprintf(fp, "%s\n", $3);
            if(strcmp($3, "bool") == 0){
                print_branch("ldc \"true\"", "ldc \"false\"", "ifne");
            }
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/println(%s)V\n", temp);    
        }
    | PRINT '(' Expression ')'      { 
            printf("PRINT %s\n", $3);
            char temp[50];
            if(strcmp($3, "i32") == 0){
                strcpy(temp, "I");
            }
            else if(strcmp($3, "f32") == 0){
                strcpy(temp, "F");
            }
            else{
                strcpy(temp, "Ljava/lang/String;");
            }
            //fprintf(fp, "%s\n", $3);
            if(strcmp($3, "bool") == 0){
                print_branch("ldc \"true\"", "ldc \"false\"", "ifne");
            }
            fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(%s)V\n", temp); 
        }
;

Expression
    : StringStmt { $$ = $1;}
    | MathStmt { $$ = $1;}
    | ID '[' INT_LIT ']' { 
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("IDENT (name=%s, address=%d)\n", $1, temp->addr);
                char type = determine_type(temp->type);
                if(strcmp(temp->type, "bool") == 0) type = 'i';
                fprintf(fp, "aload %d\n", temp->addr);
                fprintf(fp, "ldc %d\n", $3);
                fprintf(fp, "%caload\n", type);
            }
            else{
                undefined($1);
            }
            printf("INT_LIT %d\n", $3);
            $$ = temp->type;
        }
;


ReturnStmt
    : RETURN Expression {
            printf("breturn\n");
            char temp;
            if(returntype == 'I' || returntype == 'B'){
                temp = 'i';
            }
            else if(returntype == 'F'){
                temp = 'f';
            }
            else if(returntype == 'V'){
                temp = ' ';
            }
            else{
                temp = 'a';
            }
            fprintf(fp, "%creturn\n", temp);
        }
;

ReturnStmt2
    : Expression {
            printf("breturn\n");
            char temp;
            if(returntype == 'I' || returntype == 'B'){
                temp = 'i';
            }
            else if(returntype == 'F'){
                temp = 'f';
            }
            else if(returntype == 'V'){
                temp = ' ';
            }
            else{
                temp = 'a';
            }
            fprintf(fp, "%creturn\n", temp);
            //fprintf(fp, "end%d:\n", label_num++);
            //is_if_stmt = false;
        }
;

StringStmt
    : '\"' STRING_LIT '\"'  {
            printf("STRING_LIT \"%s\"\n", $2);
            fprintf(fp, "ldc \"%s\"\n", $2);
            $$ = "str";
        }
    | '\"' '\"' {
            printf("STRING_LIT \"\"\n");
            fprintf(fp, "ldc \"\"\n");
            $$ = "str";
        }
;

CallStmt
    : ID '(' CallParamList ')' {
            struct symbol *temp = lookup_symbol($1);
            if(temp != NULL){
                printf("call: %s%s\n", $1, temp->func_sig);
                fprintf(fp, "invokestatic Main/%s%s\n", $1, temp->func_sig);
                if(is_if_stmt){
                    print_branch("true", "false", "ifne");//if 1 != 0, true
                }
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
    :   LoopHead Block { 
            is_while = false;
            fprintf(fp, "goto loop%d\n", while_num);
            fprintf(fp, "break%d:\n", while_num++);
        }
;

LoopHead
    : LOOP {
            is_while = true;
            fprintf(fp, "loop%d:\n", while_num);
        }
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
    // .j file header
    fp = fopen("hw3.j", "w+");
    fprintf(fp, ".source hw3.j\n");
    fprintf(fp, ".class public Main\n");
    fprintf(fp, ".super java/lang/Object\n");

    yylineno = 0;
    create_symbol();
    yyparse();
    dump_symbol();
	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    fclose(fp);
    if(HAS_ERROR)
        remove("hw3.j");
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", scope_lv);
    symbol_first[scope_lv++] = NULL;
}

static void insert_symbol(int addr, int mut, char* name, char* type, char* func_sig, int array_len) {
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
    temp->mut = mut;
    strcpy(temp->type, type);
    temp->addr = addr;
    temp->lineno = yylineno+1;
    strcpy(temp->func_sig, func_sig);
    temp->next = NULL;
    temp->array_len = array_len;
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
    if(strcmp(name, "main") == 0){
        fprintf(fp, "([Ljava/lang/String;)V\n");
    }
    else
    {
        fprintf(fp, "%s\n", func_sig);
    }
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
    HAS_ERROR = true;
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
        HAS_ERROR = true;
    }
    //printf("%s\n", operator);
}

static char determine_type(char* type){
    if(strcmp(type, "i32") == 0){
        return 'i';
    }
    else if(strcmp(type, "f32") == 0){
        return 'f';
    }
    else{
        return 'a';
    }
}