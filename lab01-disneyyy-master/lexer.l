/*
    filename: lexer.l
*/

/* Definition section */
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #define YY_NO_UNPUT
    #define YY_NO_INPUT
    #define print_token(token) \
        printf("%-8s \t %s\n", strcmp(token, "NEWLINE")? yytext: "", token)

    int line_num = 0;
    int comment_num = 0;
    int last_comment_line = -1;
%}


/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]
id {letter}+({letter}|{digit})*
inumber {digit}+
fnumber ({digit}*\.{digit}+)
line_comment "//"[^\n]*
string_lit [^\"]+

%x FUNC FUNC_SPACE STR_LIT STR_LIT_END MUL_COMMENT
/* Rules section */
%%

"+"         { print_token("ADD"); }
"-"         { print_token("SUB"); }
"*"         { print_token("MUL"); }
"/"         { print_token("QUO"); }
"%"         { print_token("REM"); }


">"         { print_token("GTR"); }
"<"         { print_token("LSS"); }
">="        { print_token("GEQ"); }
"<="        { print_token("LEQ"); }
"=="        { print_token("EQL"); }
"!="        { print_token("NEQ"); }


"="         { print_token("ASSIGN"); }
"+="        { print_token("ADD_ASSIGN"); }
"-="        { print_token("SUB_ASSIGN"); }
"*="        { print_token("MUL_ASSIGN"); }
"/="        { print_token("QUO_ASSIGN"); }
"%="        { print_token("REM_ASSIGN"); }


"&"         { print_token("BAND"); }
"|"         { print_token("BOR"); }
"~"         { print_token("BNOT"); }
">>"        { print_token("RSHIFT"); }
"<<"        { print_token("LSHIFT"); }


"&&"        { print_token("LAND"); }
"||"        { print_token("LOR"); }
"!"         { print_token("NOT"); }


"("         { print_token("LPAREN"); }
")"         { print_token("RPAREN"); }
"["         { print_token("LBRACK"); }
"]"         { print_token("RBRACK"); }
"{"         { print_token("LBRACE"); }
"}"         { print_token("RBRACE"); }


";"         { print_token("SEMICOLON"); }
","         { print_token("COMMA"); } 
"\""        { print_token("QUOTA"); BEGIN(STR_LIT);}
"\n"        { print_token("NEWLINE"); line_num++; }
":"         { print_token("COLON"); }
"->"        { print_token("ARROW"); }
".."        { print_token("DOTDOT"); }



{inumber}   { print_token("INT_LIT"); }
{fnumber}   { print_token("FLOAT_LIT"); }
<STR_LIT>{string_lit} { print_token("STRING_LIT"); BEGIN(STR_LIT_END); }
<STR_LIT>"\"" { print_token("QUOTA"); BEGIN(0); }
<STR_LIT_END>"\"" { print_token("QUOTA"); BEGIN(0); }


{line_comment}    { print_token("COMMENT"); comment_num++; }
"/*"        { 
                if(last_comment_line != -1 && last_comment_line < line_num)
                    comment_num++;
                printf("/*");
                BEGIN(MUL_COMMENT); 
            }
<MUL_COMMENT>"*/"   { print_token("MUTI_LINE_COMMENT"); BEGIN(0); }
<MUL_COMMENT>"\n"   { 
                        comment_num++; 
                        line_num++; 
                        printf("\n"); 
                        last_comment_line = line_num; 
                    }

"print"     { print_token("PRINT"); }
"println"   { print_token("PRINTLN"); }
"if"        { print_token("IF"); }
"else"      { print_token("ELSE"); }
"for"       { print_token("FOR"); }
"true"      { print_token("TRUE"); }
"false"     { print_token("FALSE"); }
"let"       { print_token("LET"); }
"mut"       { print_token("MUT"); }
"fn"        { 
                print_token("FUNC"); 
            }
"return"    { print_token("RETURN"); }
"break"     { print_token("BREAK"); }
"as"        { print_token("AS"); }
"in"        { print_token("IN"); }
"while"     { print_token("WHILE"); }
"loop"      { print_token("LOOP"); }


"i32"       { print_token("INT"); }
"f32"       { print_token("FLOAT"); }
"bool"      { print_token("BOOL"); }
"char"      { print_token("CHAR"); }

{id}        { print_token("IDENT"); }
<<EOF>>     { 
                line_num++; 
                if(last_comment_line != -1 && last_comment_line < line_num)
                    comment_num++;
                yyterminate(); 
            }
[ \t]+    {;}
.           {;}
%%

/*  C Code section */
int yywrap(void)
{
    return 1;
}

int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    yylex();
    printf("\nFinish scanning,\n");
    printf("total line: %d\n", line_num);
    printf("comment line: %d\n", comment_num);
    fclose(yyin);
    return 0;
}