%{                          // SECCION 1 Declaraciones de C-Yacc

#include <stdio.h>
#include <ctype.h>            // declaraciones para tolower
#include <string.h>           // declaraciones para cadenas
#include <stdlib.h>           // declaraciones para exit ()

#define FF fflush(stdout);    // para forzar la impresion inmediata
#define MAX_VARS 100

// Tabla de variables locales
char *local_vars[MAX_VARS];
int num_local_vars = 0;

void clear_local_vars() {
    num_local_vars = 0;
}

void add_local_var(char *name) {
    if (num_local_vars < MAX_VARS) {
        local_vars[num_local_vars++] = name;
    }
}

int is_local_var(char *name) {
    for (int i = 0; i < num_local_vars; i++) {
        if (strcmp(name, local_vars[i]) == 0)
            return 1;
    }
    return 0;
}


int yylex () ;
int yyerror () ;
char *mi_malloc (int) ;
char *gen_code (char *) ;
char *int_to_string (int) ;
char *char_to_string (char) ;

char temp [2048] ;

// Abstract Syntax Tree (AST) Node Structure

typedef struct ASTnode t_node ;

struct ASTnode {
    char *op ;
    int type ;		// leaf, unary or binary nodes
    t_node *left ;
    t_node *right ;
} ;

// Definitions for explicit attributes

typedef struct s_attr {
    int value ;    // - Numeric value of a NUMBER 
    char *code ;   // - to pass IDENTIFIER names, and other translations 
    t_node *node ; // - for possible future use of AST
} t_attr ;

#define YYSTYPE t_attr

%}

%token NUMBER        
%token IDENTIF       // Identificador=variable
%token INTEGER       // identifica el tipo entero
%token STRING
%token MAIN          // identifica el comienzo del proc. main
%token WHILE         // identifica el bucle main
%token PRINTF
%token PUTS
%token EQ NEQ AND OR NOT LE GE
%token IF ELSE
%token FOR




%right '='                    // asignación
%left OR                      // ||
%left AND                     // &&
%right '!'                    // !
%nonassoc EQ NEQ             // ==, !=
%nonassoc '<' '>' LE GE      // <, >, <=, >=
%left '+' '-'                // suma y resta
%left '*' '/' '%'            // multiplicación, división, módulo
%left UNARY_SIGN             // signo unario



%%                            // Seccion 3 Gramatica - Semantico

axioma:       programa                 { printf ("%s\n", $1.code) ; }
;

programa: declaraciones funciones  {sprintf(temp, "%s\n%s\n", $1.code, $2.code); $$.code = gen_code(temp);}
| declaraciones { $$.code = $1.code;}
;

declaracion_local:
    INTEGER lista_vars_local { $$.code = $2.code; }

lista_vars_local:
      lista_vars_local ',' definicion_var_local { sprintf(temp, "%s\n%s", $1.code, $3.code); $$.code = gen_code(temp); }
    | definicion_var_local { $$.code = $1.code; }

definicion_var_local:
    IDENTIF {
        add_local_var($1.code);
        fprintf(stderr, "FUNCION ACTUAL (en variables locales): %s\n", $1.code); // Depuración
        sprintf(temp, "(setq %s_%s 0)", $1.code, $1.code); // Generación de variable local con el nombre correcto
        $$.code = gen_code(temp);
    }
    | IDENTIF '=' NUMBER {
        add_local_var($1.code);
        fprintf(stderr, "FUNCION ACTUAL (en variables locales): %s\n", $1.code); // Depuración
        sprintf(temp, "(setq %s_%s %d)", $1.code, $1.code, $3.value); // Generación de variable local con el nombre correcto
        $$.code = gen_code(temp);
    }
;

declaraciones:
              declaraciones declaracion  { sprintf(temp, "%s\n%s\n", $1.code, $2.code); $$.code = gen_code(temp); }
            | declaracion                { $$.code = $1.code; }
;

declaracion:  INTEGER lista_vars ';'    { $$.code = $2.code; }
;

lista_vars:   lista_vars ',' definicion_var { sprintf(temp, "%s\n%s\n", $1.code, $3.code); $$.code = gen_code(temp); }
            | definicion_var             { $$.code = $1.code; }
;

definicion_var:
              IDENTIF                    { sprintf(temp, "(setq %s 0)", $1.code); $$.code = gen_code(temp); }
            | IDENTIF '=' NUMBER         { sprintf(temp, "(setq %s %d)", $1.code, $3.value); $$.code = gen_code(temp); }
;

funciones:    funciones funcion         { sprintf(temp, "%s\n%s\n", $1.code, $2.code); $$.code = gen_code(temp); }
            | funcion                   { $$.code = $1.code; }
;

funcion:    IDENTIF '(' ')' '{' cuerpo '}' {
        clear_local_vars(); // Limpiamos las variables locales antes de analizar el cuerpo
        fprintf(stderr, "FUNCION ACTUAL: %s\n", $1.code); // Depuración
        sprintf(temp, "(defun %s ()\n%s)", $1.code, $5.code);
        $$.code = gen_code(temp);
    }
;

cuerpo:       cuerpo sentencia           { sprintf(temp, "%s\n%s\n", $1.code, $2.code); $$.code = gen_code(temp); }
            | sentencia                  { $$.code = $1.code; }
;

inicializacion: IDENTIF '=' expresion;

sentencia:    declaracion_local ';' { $$.code = $1.code; }
            | IDENTIF '=' expresion ';' {
                char *id = $1.code;
                if (is_local_var(id)) {
                    sprintf(temp, "(setf main_%s %s)", id, $3.code);
                } else {
                    sprintf(temp, "(setf %s %s)", id, $3.code);
                }
                $$.code = gen_code(temp);
            }
            | PRINTF '(' STRING ',' lista_expr ')' ';' {sprintf(temp, "(princ %s)", $5.code); $$.code = gen_code(temp);}
            | WHILE '(' expresion ')' '{' cuerpo '}' {sprintf(temp, "(loop while %s do\n%s)", $3.code, $6.code); $$.code = gen_code(temp); }
            | PUTS '(' STRING ')' ';' { sprintf(temp, "(print \"%s\")", $3.code);  $$.code = gen_code(temp);}
            | IF '(' expresion ')' '{' cuerpo '}' {sprintf(temp, "(if %s\n(progn %s))", $3.code, $6.code);  $$.code = gen_code(temp);}
            | IF '(' expresion ')' '{' cuerpo '}' ELSE '{' cuerpo '}' {sprintf(temp, "(if %s\n(progn %s)\n(progn %s))", $3.code, $6.code, $10.code); $$.code = gen_code(temp);}
            | FOR '(' inicializacion ';' expresion ';' inicializacion ')' '{' cuerpo '}' {sprintf(temp, "(loop while %s do\n%s)", $5.code, $10.code); $$.code = gen_code(temp);}
;

lista_expr:   lista_expr ',' expresion  { sprintf(temp, "%s\n%s", $1.code, $3.code); $$.code = gen_code(temp); }
            | lista_expr ',' STRING {sprintf(temp, "%s\n\"%s\"", $1.code, $3.code); $$ .code = gen_code(temp); }
            | expresion {sprintf(temp, "%s", $1.code); $$.code = gen_code(temp);}
            | STRING {sprintf(temp, "\"%s\"", $1.code); $$.code = gen_code(temp);}
;


expresion:    termino                   { $$ = $1 ; }
            | expresion '+' expresion   { sprintf (temp, "(+ %s %s)", $1.code, $3.code) ; $$.code = gen_code (temp) ; }
            | expresion '-' expresion   { sprintf (temp, "(- %s %s)", $1.code, $3.code) ; $$.code = gen_code (temp) ; }
            | expresion '*' expresion   { sprintf (temp, "(* %s %s)", $1.code, $3.code) ; $$.code = gen_code (temp) ; }
            | expresion '/' expresion   { sprintf (temp, "(/ %s %s)", $1.code, $3.code) ; $$.code = gen_code (temp) ; }
            | expresion EQ expresion  { sprintf(temp, "(= %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion NEQ expresion { sprintf(temp, "(/= %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion '<' expresion { sprintf(temp, "(< %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion LE expresion  { sprintf(temp, "(<= %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion '>' expresion { sprintf(temp, "(> %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion GE expresion  { sprintf(temp, "(>= %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion '%' expresion { sprintf(temp, "(mod %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion AND expresion { sprintf(temp, "(and %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | expresion OR expresion  { sprintf(temp, "(or %s %s)", $1.code, $3.code); $$.code = gen_code(temp); }
            | '!' expresion           { sprintf(temp, "(not %s)", $2.code); $$.code = gen_code(temp); }

;

termino:      operando                            { $$ = $1 ; }                          
            | '+' operando %prec UNARY_SIGN       { $$ = $2 ; }
            | '-' operando %prec UNARY_SIGN       { sprintf (temp, "(- %s)", $2.code) ; $$.code = gen_code (temp) ; }
;

operando:     IDENTIF {
    if (is_local_var($1.code)) {
        sprintf(temp, "main_%s", $1.code);
    } else {
        sprintf(temp, "%s", $1.code);
    }
    $$.code = gen_code(temp);
}
            | NUMBER                    { sprintf (temp, "%d", $1.value) ; $$.code = gen_code (temp) ; }
            | '(' expresion ')'         { $$ = $2 ; }
;

%%                            // SECCION 4    Codigo en C

int n_line = 1 ;

int yyerror (mensaje)
char *mensaje ;
{
    fprintf (stderr, "%s en la linea %d\n", mensaje, n_line) ;
    printf ( "\n") ;	// bye
}

char *int_to_string (int n)
{
    sprintf (temp, "%d", n) ;
    return gen_code (temp) ;
}

char *char_to_string (char c)
{
    sprintf (temp, "%c", c) ;
    return gen_code (temp) ;
}

char *my_malloc (int nbytes)       // reserva n bytes de memoria dinamica
{
    char *p ;
    static long int nb = 0;        // sirven para contabilizar la memoria
    static int nv = 0 ;            // solicitada en total

    p = malloc (nbytes) ;
    if (p == NULL) {
        fprintf (stderr, "No queda memoria para %d bytes mas\n", nbytes) ;
        fprintf (stderr, "Reservados %ld bytes en %d llamadas\n", nb, nv) ;
        exit (0) ;
    }
    nb += (long) nbytes ;
    nv++ ;

    return p ;
}


/***************************************************************************/
/********************** Seccion de Palabras Reservadas *********************/
/***************************************************************************/

typedef struct s_keyword { // para las palabras reservadas de C
    char *name ;
    int token ;
} t_keyword ;

t_keyword keywords [] = { // define las palabras reservadas y los
    "main",        MAIN,           // y los token asociados
    "int",         INTEGER,
    "puts",        PUTS, 
    "printf",      PRINTF,
     "==",         EQ ,
    "!=",          NEQ ,
    "<=",          LE ,
    ">=",          GE ,
    "&&",          AND ,
    "||",          OR ,
    "while",       WHILE,
    "if",          IF,
    "else",        ELSE, 
    "for",         FOR,
    NULL,          0               // para marcar el fin de la tabla
} ;

t_keyword *search_keyword (char *symbol_name)
{                                  // Busca n_s en la tabla de pal. res.
                                   // y devuelve puntero a registro (simbolo)
    int i ;
    t_keyword *sim ;

    i = 0 ;
    sim = keywords ;
    while (sim [i].name != NULL) {
	    if (strcmp (sim [i].name, symbol_name) == 0) {
		                             // strcmp(a, b) devuelve == 0 si a==b
            return &(sim [i]) ;
        }
        i++ ;
    }

    return NULL ;
}

 
/***************************************************************************/
/******************* Seccion del Analizador Lexicografico ******************/
/***************************************************************************/

char *gen_code (char *name)     // copia el argumento a un
{                                      // string en memoria dinamica
    char *p ;
    int l ;
	
    l = strlen (name)+1 ;
    p = (char *) my_malloc (l) ;
    strcpy (p, name) ;
	
    return p ;
}


int yylex ()
{
// NO MODIFICAR ESTA FUNCION SIN PERMISO
    int i ;
    unsigned char c ;
    unsigned char cc ;
    char ops_expandibles [] = "!<=|>%&/+-*" ;
    char temp_str [256] ;
    t_keyword *symbol ;

    do {
        c = getchar () ;

        if (c == '#') {	// Ignora las lineas que empiezan por #  (#define, #include)
            do {		//	OJO que puede funcionar mal si una linea contiene #
                c = getchar () ;
            } while (c != '\n') ;
        }

        if (c == '/') {	// Si la linea contiene un / puede ser inicio de comentario
            cc = getchar () ;
            if (cc != '/') {   // Si el siguiente char es /  es un comentario, pero...
                ungetc (cc, stdin) ;
            } else {
                c = getchar () ;	// ...
                if (c == '@') {	// Si es la secuencia //@  ==> transcribimos la linea
                    do {		// Se trata de codigo inline (Codigo embebido en C)
                        c = getchar () ;
                        putchar (c) ;
                    } while (c != '\n') ;
                } else {		// ==> comentario, ignorar la linea
                    while (c != '\n') {
                        c = getchar () ;
                    }
                }
            }
        } else if (c == '\\') c = getchar () ;
		
        if (c == '\n')
            n_line++ ;

    } while (c == ' ' || c == '\n' || c == 10 || c == 13 || c == '\t') ;

    if (c == '\"') {
        i = 0 ;
        do {
            c = getchar () ;
            temp_str [i++] = c ;
        } while (c != '\"' && i < 255) ;
        if (i == 256) {
            printf ("AVISO: string con mas de 255 caracteres en linea %d\n", n_line) ;
        }		 	// habria que leer hasta el siguiente " , pero, y si falta?
        temp_str [--i] = '\0' ;
        yylval.code = gen_code (temp_str) ;
        return (STRING) ;
    }

    if (c == '.' || (c >= '0' && c <= '9')) {
        ungetc (c, stdin) ;
        scanf ("%d", &yylval.value) ;
//         printf ("\nDEV: NUMBER %d\n", yylval.value) ;        // PARA DEPURAR
        return NUMBER ;
    }

    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
        i = 0 ;
        while (((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '_') && i < 255) {
            temp_str [i++] = tolower (c) ;
            c = getchar () ;
        }
        temp_str [i] = '\0' ;
        ungetc (c, stdin) ;

        yylval.code = gen_code (temp_str) ;
        symbol = search_keyword (yylval.code) ;
        if (symbol == NULL) {    // no es palabra reservada -> identificador antes vrariabre
//               printf ("\nDEV: IDENTIF %s\n", yylval.code) ;    // PARA DEPURAR
            return (IDENTIF) ;
        } else {
//               printf ("\nDEV: OTRO %s\n", yylval.code) ;       // PARA DEPURAR
            return (symbol->token) ;
        }
    }

    if (strchr (ops_expandibles, c) != NULL) { // busca c en ops_expandibles
        cc = getchar () ;
        sprintf (temp_str, "%c%c", (char) c, (char) cc) ;
        symbol = search_keyword (temp_str) ;
        if (symbol == NULL) {
            ungetc (cc, stdin) ;
            yylval.code = NULL ;
            return (c) ;
        } else {
            yylval.code = gen_code (temp_str) ; // aunque no se use
            return (symbol->token) ;
        }
    }

//    printf ("\nDEV: LITERAL %d #%c#\n", (int) c, c) ;      // PARA DEPURAR
    if (c == EOF || c == 255 || c == 26) {
//         printf ("tEOF ") ;                                // PARA DEPURAR
        return (0) ;
    }

    return c ;
}


int main ()
{
    yyparse () ;
}