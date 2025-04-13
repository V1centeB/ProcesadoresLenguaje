/*Manuel Andres Trujillo, Vicente Antonio Barbato, Grupo 502*/
/*100423448@alumnos.uc3m.es 100438114@alumnos.uc3m.es*/

%{                          // SECCION 1 Declaraciones de C-Yacc

#include <stdio.h>
#include <ctype.h>            // declaraciones para tolower
#include <string.h>           // declaraciones para cadenas
#include <stdlib.h>           // declaraciones para exit ()

#define FF fflush(stdout);    // para forzar la impresion inmediata
#define MAX_VAR_LOCALES 64


int yylex () ;
int yyerror () ;
char *mi_malloc (int) ;
char *gen_code (char *) ;
char *int_to_string (int) ;
char *char_to_string (char) ;

char temp [2048] ;


// Tabla local para variables dentro de una función
char *tabla_locales[MAX_VAR_LOCALES];
int n_locales = 0;

// Nombre de la función actual
char nombre_funcion_actual[256] = ""; // De momento, solo main

// Función para insertar variable local
void insertar_variable_local(char *nombre) {
    if (n_locales < MAX_VAR_LOCALES) {
        tabla_locales[n_locales++] = nombre;
    }
}

// Función para comprobar si una variable es local
int es_variable_local(char *nombre) {
    for (int i = 0; i < n_locales; i++) {
        if (strcmp(tabla_locales[i], nombre) == 0)
            return 1;
    }
    return 0;
}

// Renombrado si es local
char *renombrar_variable(char *nombre) {
    if (strcmp(nombre_funcion_actual, "global") != 0 && es_variable_local(nombre)) {
        sprintf(temp, "%s_%s", nombre_funcion_actual, nombre);
        return gen_code(temp);
    }
    return nombre;
}


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

// Definitions for explicit attributes

%token NUMBER        
%token IDENTIF       // Identificador=variable
%token INTEGER       // identifica el tipo entero
%token STRING
%token PUTS
%token PRINTF
%token AND
%token OR
%token DIFERENTE
%token IGUAL
%token MAYORIGUAL
%token MENORIGUAL
%token MAIN          // identifica el comienzo del proc. main
%token WHILE         // identifica el bucle main
%token FOR
%token IF
%token ELSE



%right '='                    // es la ultima operacion que se debe realizar
%left OR
%left AND
%left IGUAL DIFERENTE
%left '>' MAYORIGUAL
%left '<' MENORIGUAL
%left '+' '-'                 // menor orden de precedencia
%left '*' '/' '%'                 // orden de precedencia intermedio
%left UNARY_SIGN              // mayor orden de precedencia

%%                            // Seccion 3 Gramatica - Semantico

axioma:                   decl_vars func_main                                               { printf ("%s\n %s\n", $1.code, $2.code); }
                        ;

func_main:              MAIN '(' ')'                                                        {n_locales = 0; strcpy(nombre_funcion_actual, "main");}
                        '{' codigo '}'                                                      {sprintf(temp, "(defun main ()\n%s)", $6.code);
                                                                                            $$.code = gen_code(temp);}
                        ;

decl_vars:                declaracion decl_vars                                             { sprintf(temp, "%s\n%s", $1.code, $2.code);
                                                                                            $$.code = gen_code(temp);}
                        |  /* lambda */                                                     { $$.code = "";}
                        ;                          


codigo:                   sentencia ';' codigo                                              { sprintf(temp, "%s\n %s", $1.code, $3.code);
                                                                                            $$.code = gen_code(temp);}
                        | sentencia codigo                                                  {sprintf(temp, "%s\n%s", $1.code, $2.code);
                                                                                            $$.code = gen_code(temp);}
                        | /* lambda */                                                      { $$.code = "";}
                        ;

sentencia:                IDENTIF '=' resto_variable                                                                    {char *nombre = renombrar_variable($1.code);
                                                                                                                        sprintf(temp, "(setf %s %s)", nombre, $3.code);
                                                                                                                        $$.code = gen_code(temp);}
                        | INTEGER IDENTIF asignacion_entero ';'                                                         {insertar_variable_local($2.code);
                                                                                                                        sprintf(temp, "(setq %s_%s %s)", nombre_funcion_actual, $2.code, $3.code);
                                                                                                                        $$.code = gen_code(temp);
                                                                                                                        }
                        | PUTS '(' STRING ')' ';'                                                                       { sprintf (temp, "(print \"%s\")", $3.code) ;
                                                                                                                        $$.code = gen_code (temp) ; }
                        | PRINTF '(' STRING resto_sentencia ')'                                                         { sprintf (temp, "(princ %s)", $4.code) ;
                                                                                                                        $$.code = gen_code (temp) ; }
                        | WHILE '(' expresion ')' '{' codigo '}'                                                        { sprintf(temp, "(loop while %s do \n%s)", $3.code, $6.code);
                                                                                                                        $$.code = gen_code (temp) ; }
                        | IF '(' expresion ')' '{' codigo '}' condicional                                               { sprintf (temp,"(if %s\n progn %s %s)", $3.code, $6.code, $8.code) ;
                                                                                                                        $$.code = gen_code (temp) ; }
                        | FOR '(' IDENTIF '=' termino ';' expresion ';' IDENTIF '=' expresion ')' '{' codigo '}'        { sprintf (temp, "(loop while %s do \n%s)", $7.code, $14.code) ;
                                                                                                                        $$.code = gen_code (temp) ; }
                        ;

condicional:             ELSE '{' codigo '}'                                                { sprintf (temp, "(progn %s)", $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        ;

resto_sentencia:          ',' STRING resto_sentencia                                        { sprintf (temp, "%s %s", $2.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | ',' expresion resto_sentencia                                     { sprintf (temp, "%s %s", $2.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | /* lambda */                                                      { $$.code = "";}
                        ;

resto_variable:           IDENTIF '=' resto_variable                                        {sprintf(temp, "(setq %s %s)", renombrar_variable($1.code), $3.code);
                                                                                            $$.code = gen_code(temp);}
                        |   expresion                                                       {$$.code = $1.code;}
                        ;

declaracion:              INTEGER IDENTIF asignacion_entero resto_declaracion ';'           { insertar_variable_local($2.code); }
                                                                                            { sprintf(temp, "(setq %s %s %s) %s", nombre_funcion_actual, $2.code, $3.code, $4.code) ;
                                                                                              $$.code = gen_code (temp) ; }
                        ;

asignacion_entero:        '=' NUMBER                                                        { sprintf(temp, "%d", $2.value);
                                                                                            $$.code = gen_code(temp);}
                        | /* lambda */                                                      { sprintf(temp, "0"); 
                                                                                            $$.code = gen_code(temp);}
                        ;

resto_declaracion:      ',' IDENTIF asignacion_entero resto_declaracion                     { sprintf (temp, "(setq %s %s) %s", $2.code, $3.code, $4.code) ; 
                                                                                            $$.code = gen_code (temp) ;}
                        | /* lambda */                                                      { $$.code = "";}
                        ;                              

expresion:                termino                                                           { $$ = $1 ; }
                        | expresion '+' expresion                                           { sprintf (temp, "(+ %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '-' expresion                                           { sprintf (temp, "(- %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '*' expresion                                           { sprintf (temp, "(* %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '/' expresion                                           { sprintf (temp, "(/ %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion AND expresion                                           { sprintf (temp, "(and %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion OR expresion                                            { sprintf (temp, "(or %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion DIFERENTE expresion                                     { sprintf (temp, "(/= %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion IGUAL expresion                                         { sprintf (temp, "(= %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '<' expresion                                           { sprintf (temp, "(< %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion MENORIGUAL expresion                                    { sprintf (temp, "(<= %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '>' expresion                                           { sprintf (temp, "(> %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion MAYORIGUAL expresion                                    { sprintf (temp, "(>= %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | expresion '%' expresion                                           { sprintf (temp, "(mod %s %s)", $1.code, $3.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        ;

termino:                  operando                                                          { $$ = $1 ; }
                        | '+' operando %prec UNARY_SIGN                                     { $$ = $1 ; }
                        | '-' operando %prec UNARY_SIGN                                     { sprintf (temp, "(- %s)", $2.code) ;
                                                                                            $$.code = gen_code (temp) ; }
                        ;

operando:                 IDENTIF                                                           {char *nuevo = renombrar_variable($1.code);
                                                                                             sprintf(temp, "%s", nuevo);
                                                                                             $$.code = gen_code(temp);}
                        | NUMBER                                                            { sprintf (temp, "%d", $1.value) ;
                                                                                            $$.code = gen_code (temp) ; }
                        | '(' expresion ')'                                                 { $$ = $2 ; }
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
    "&&",          AND,
    "||",          OR,
    "!=",          DIFERENTE,
    "==",          IGUAL,
    ">=",          MAYORIGUAL,
    "<=",          MENORIGUAL,
    "while",       WHILE,
    "for",         FOR,
    "if",          IF,
    "else",        ELSE,
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
