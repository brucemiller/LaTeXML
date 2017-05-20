/*
       # /=====================================================================\ #
       # |  LaTeXML.xs                                                         | #
       # |                                                                     | #
       # |=====================================================================| #
       # | Part of LaTeXML:                                                    | #
       # |  Public domain software, produced as part of work done by the       | #
       # |  United States Government & not subject to copyright in the US.     | #
       # |---------------------------------------------------------------------| #
       # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
       # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
       # \=========================================================ooo==U==ooo=/ #
  */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
  /* Perhaps we should be using SV * ?  We're losing the unicode setting of the string! */
  /* Also: currently we copy string & free on DESTROY; Do getString (etal) need to copy? */
  /* the C ends up with sv_setpv, which(apparently) copies the string into the PV(string var) */
typedef char * UTF8;
typedef struct Token {
  int catcode;
  UTF8 string;
} T_Token;

typedef T_Token * PTR_Token;

typedef SV * PTR_SV;
typedef struct Tokens {
  int ntokens;
  PTR_SV * tokens;
} T_Tokens;

typedef T_Tokens * PTR_Tokens;

typedef struct Token * LaTeXML_Core_Token;
typedef struct Tokens * LaTeXML_Core_Tokens;

typedef enum {
    CC_ESCAPE      =  0,
    CC_BEGIN       =  1,
    CC_END         =  2,
    CC_MATH        =  3,
    CC_ALIGN       =  4,
    CC_EOL         =  5,
    CC_PARAM       =  6,
    CC_SUPER       =  7,
    CC_SUB         =  8,
    CC_IGNORE      =  9,
    CC_SPACE       = 10,
    CC_LETTER      = 11,
    CC_OTHER       = 12,
    CC_ACTIVE      = 13,
    CC_COMMENT     = 14,
    CC_INVALID     = 15,
    CC_CS          = 16,
    CC_NOTEXPANDED = 17,
    CC_MARKER      = 18,
    CC_MAX         = 18
} T_Catcode;

/* Categorization of Category codes */

int PRIMITIVE_CATCODE[] = 
  { 1, 1, 1, 1,
    1, 1, 1, 1,
    1, 0, 1, 0,
    0, 0, 0, 0,
    0, 1};
int EXECUTABLE_CATCODE[] =
  { 0, 1, 1, 1,
    1, 0, 0, 1,
    1, 0, 0, 0,
    0, 1, 0, 0,
    1, 0};

int ACTIVE_OR_CS[] = 
  {0, 0, 0, 0,
   0, 0, 0, 0,
   0, 0, 0, 0,
   0, 1, 0, 0,
   1, 0};
int LETTER_OR_OTHER[] = 
  {0, 0, 0, 0,
   0, 0, 0, 0,
   0, 0, 0, 1,
   1, 0, 0, 0,
   0, 0};

UTF8 standardchar[] =
  { "\\",  "{",   "}",   "$",
    "&",  "\n",  "#",  "^",
    "_",  NULL, NULL, NULL,
    NULL, NULL, "%",  NULL};

UTF8 CC_NAME[] =
  {"Escape", "Begin", "End", "Math",
   "Align", "EOL", "Parameter", "Superscript",
   "Subscript", "Ignore", "Space", "Letter",
   "Other", "Active", "Comment", "Invalid",
   "ControlSequence", "NotExpanded"};
UTF8 PRIMITIVE_NAME[] =
  {"Escape",    "Begin", "End",       "Math",
   "Align",     "EOL",   "Parameter", "Superscript",
   "Subscript", NULL,    "Space",     NULL,
   NULL,        NULL,     NULL,       NULL,
   NULL,       "NotExpanded"};
UTF8 EXECUTABLE_NAME[] = 
  {NULL,       "Begin", "End", "Math",
   "Align",     NULL,   NULL, "Superscript",
   "Subscript", NULL,   NULL, NULL,
   NULL,        NULL,   NULL, NULL,
   NULL,        NULL};

UTF8 CC_SHORT_NAME[] =
  {"T_ESCAPE", "T_BEGIN", "T_END", "T_MATH",
   "T_ALIGN", "T_EOL", "T_PARAM", "T_SUPER",
   "T_SUB", "T_IGNORE", "T_SPACE", "T_LETTER",
   "T_OTHER", "T_ACTIVE", "T_COMMENT", "T_INVALID",
   "T_CS", "T_NOTEXPANDED"};

LaTeXML_Core_Token
make_token(UTF8 string, int catcode){
  /*check string not null ? */
  PTR_Token token;
  if((catcode < 0) || (catcode > CC_MAX)){
    croak("Illegal catcode %d",catcode); }
  Newx(token,1,T_Token);
  /* check for out of memory ? */
  Newx(token->string,(strlen(string) + 1),char);
  strcpy(token->string, string);
  token->catcode = catcode;
  return token; }

     /* You'll often need SvRV(arg) */
#define SvToken(arg) INT2PTR(LaTeXML_Core_Token, SvIV((SV*) arg))
#define SvTokens(arg) INT2PTR(LaTeXML_Core_Tokens, SvIV((SV*) arg))


#define T_LETTER(arg) (make_token((arg), 11))
#define T_OTHER(arg)  (make_token((arg), 12))
#define T_ACTIVE(arg) (make_token((arg), 13))
#define T_CS(arg)     (make_token((arg), 16))

  /* Note peculiar pre-allocation strategy for nalloc!
     it is expected that the caller has allocated enough room for it's arguments
     assuming they are Token's; add_to_tokens will grow if it encounters Tokens/Reversions */
void
add_to_tokens(PTR_Tokens tokens, int * nalloc, SV * thing, int revert) {
  /* fprintf(stderr, "Item %s; ", sv_reftype(t, 1));*/
  dTHX;                         /* perhaps want to look into pTHX, perl context, etc??? */
  if (sv_isa(thing, "LaTeXML::Core::Token")) {
    /*fprintf(stderr, "Token.");*/
    thing = SvRV(thing);
    SvREFCNT_inc(thing);
    tokens->tokens[tokens->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens toks = SvTokens(SvRV(thing));
    int n = toks->ntokens;
    int i;
    /*fprintf(stderr, "Tokens(%d): ", nt);*/
    Renew(tokens->tokens, (*nalloc)+= n-1, PTR_SV);
    for (i = 0 ; i < n ; i++) {
      /*fprintf(stderr, "adding item %d; ",j);*/
      SvREFCNT_inc(toks->tokens[i]);
      tokens->tokens[tokens->ntokens++] = toks->tokens[i]; } }
  else if (revert){             /* Insert the what Revert($thing) returns */
    dSP;
    I32 ax;
    int i,nvals;
    ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
    PUSHs(thing);
    PUTBACK;
    nvals = call_pv("Revert", G_ARRAY);
    SPAGAIN;
    SP -= nvals; ax = (SP - PL_stack_base) + 1;
    Renew(tokens->tokens, (*nalloc)+= nvals-1, PTR_SV);    
    for(i=0; i<nvals; i++){
      add_to_tokens(tokens, nalloc, ST(i), revert); }
    PUTBACK; FREETMPS; LEAVE; }
  else {
    /* Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))*/
    croak("Tokens: Expected a Token, got ???"); }
}


MODULE = LaTeXML PACKAGE = LaTeXML::Core::Token

LaTeXML_Core_Token
Token(string, catcode)
    UTF8 string
    int catcode
  CODE:
    RETVAL = make_token(string, catcode);
  OUTPUT:
    RETVAL

LaTeXML_Core_Token
T_LETTER(string)
    UTF8 string

LaTeXML_Core_Token
T_OTHER(string)
    UTF8 string

LaTeXML_Core_Token
T_ACTIVE(string)
    UTF8 string

LaTeXML_Core_Token
T_CS(string)
    UTF8 string

int
getCatcode(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->catcode;
  OUTPUT:
    RETVAL

UTF8
getString(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->string;
  OUTPUT:
    RETVAL

UTF8
toString(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->string;
  OUTPUT:
    RETVAL

int
getCharcode(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = (self->catcode == CC_CS ? 256 : (int) self->string [0]);
  OUTPUT:
    RETVAL

UTF8
getCSName(self)
    LaTeXML_Core_Token self
  INIT:
    UTF8 s = PRIMITIVE_NAME[self->catcode];
  CODE:
    RETVAL = (s == NULL ? self->string : s);
    OUTPUT:
    RETVAL 

UTF8
getMeaningName(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = (ACTIVE_OR_CS[self->catcode]
              ? self->string
              : NULL);
  OUTPUT:
    RETVAL

UTF8
getExpandableName(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = (ACTIVE_OR_CS [self->catcode]
              ? self->string
              : EXECUTABLE_NAME[self->catcode]);
  OUTPUT:
    RETVAL 

int
isExecutable(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = EXECUTABLE_CATCODE [self->catcode];
  OUTPUT:
    RETVAL

    #    /* Compare two tokens; They are equal if they both have same catcode & string*/
    #    /* [We pretend all SPACE's are the same, since we'd like to hide newline's in there!]*/
    #    /* NOTE: That another popular equality checks whether the "meaning" (defn) are the same.*/
    #    /* That is NOT done here; see Equals(x,y) and XEquals(x,y)*/

int
equals(self, b)
    LaTeXML_Core_Token self
    SV * b
  INIT:
    IV bptr;
    LaTeXML_Core_Token bb;
  CODE:
    if (SvOK(b) && sv_isa(b, "LaTeXML::Core::Token")) {
    bptr = SvIV((SV *) SvRV(b));
    bb = INT2PTR(LaTeXML_Core_Token, bptr);
    if (self->catcode != bb->catcode) {
      RETVAL = 0; }
    else if (self->catcode == CC_SPACE) {
      RETVAL = 1; }
    else {
      RETVAL = strcmp(self->string, bb->string) == 0; } }
    else {
      RETVAL = 0; }
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Token self
  CODE:
    # printf("DESTROY TOKEN %s[%s]!\n",CC_SHORT_NAME[self->catcode],self->string);
    Safefree(self->string);
    Safefree(self);

MODULE = LaTeXML PACKAGE = LaTeXML::Core::Tokens

  #  Return a LaTeXML::Core::Tokens made from the arguments (tokens)
  # Curiously, faster but more resident memory?
  #   av_extend doesn't help; is newRV *always* required?
  # Potential optimizations:
  #   - empty args: return a constant
  #   - single Tokens arg; just return that arg
  #   - do our own memory management of the array of Token's


SV *
Tokens(...)
  INIT:
    int i;
    PTR_Tokens tokens;
    int nalloc;
  CODE:
    if((items == 1) && sv_isa(ST(0), "LaTeXML::Core::Tokens")) {
      SvREFCNT_inc(ST(0));
      RETVAL = ST(0); }
    else {
      Newxz(tokens,1, T_Tokens);
      if(items > 0){
        Newx(tokens->tokens,nalloc=items, PTR_SV); }
      /*fprintf(stderr, "\nCreate Tokens(%d): ", items);*/
      for (i = 0 ; i < items ; i++) {
        add_to_tokens(tokens,&nalloc,ST(i),0); }
     /*fprintf(stderr, "done %d.\n", tokens->ntokens);*/
     RETVAL = newSV(0);
     sv_setref_pv(RETVAL, "LaTeXML::Core::Tokens", (void*)tokens);
    }
  OUTPUT:
    RETVAL

void
unlist(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
  PPCODE:
    EXTEND(SP, self->ntokens);
    for(i = 0; i < self->ntokens; i++) {
      PUSHs(sv_2mortal(newRV_inc(self->tokens[i]))); }
 
int
isBalanced(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i, level;
  CODE:
    level = 0;
    /*fprintf(stderr,"\nChecking balance of %d tokens",self->ntokens);*/
    for (i = 0 ; i < self->ntokens ; i++) {
      LaTeXML_Core_Token t = SvToken(self->tokens[i]);
      int cc = t->catcode;
      /*fprintf(stderr,"[%d]",cc);*/
      if (cc == CC_BEGIN) {
        /*fprintf(stderr,"+");*/
        level++; }
      else if (cc == CC_END) {
        /*fprintf(stderr,"-");*/
        level--; } }
      /*fprintf(stderr,"net %d",level);*/
    RETVAL = (level == 0);
  OUTPUT:
    RETVAL


LaTeXML_Core_Tokens
substituteParameters(self,...)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
    PTR_Tokens tokens;
    int nalloc;
  CODE:
    Newxz(tokens,1,T_Tokens);
    if(self->ntokens > 0){
      Newx(tokens->tokens,nalloc=self->ntokens, PTR_SV); }
    /*fprintf(stderr,"\nsubstituting:");*/
    for (i = 0 ; i < self->ntokens ; i++) {
      LaTeXML_Core_Token t = SvToken(self->tokens[i]);
      int cc = t->catcode;
      if(cc != CC_PARAM){ /* non #, so copy it*/
        /*fprintf(stderr,"copy %s;",t->string);*/
        SvREFCNT_inc(self->tokens[i]);
        tokens->tokens[tokens->ntokens++] = self->tokens[i]; }
      else if(i >= self->ntokens) { /* # at end of tokens? */
        croak("substituteParamters: fell off end of pattern"); }
      else {
        /*t = SvToken(self->tokens[++i]);*/
        i++;
        t = SvToken(self->tokens[i]);
        /*fprintf(stderr,"#%s ",t->string);*/
        cc = t->catcode;
        if(cc == CC_PARAM){ /* next char is #, just duplicate it */
          /*fprintf(stderr,"copy#;");*/
          SvREFCNT_inc(self->tokens[i]);
          tokens->tokens[tokens->ntokens++] = self->tokens[i]; }
        else {                  /* otherwise, insert the appropriate arg. */
          int argn = (int) t->string[0] - (int) '0';
          /*fprintf(stderr,"arg%d;",argn);*/
          if((argn < 1) || (argn > 9)){
            croak("substituteTokens: Illegal argument number %d",argn); }
          else if ((argn <= items) && SvOK(ST(argn))){      /* ignore undef */
            add_to_tokens(tokens,&nalloc, ST(argn), 1); } }
      } }
    /*fprintf(stderr,"done\n");*/
    RETVAL = tokens;
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
  CODE:
    # printf("DESTROY TOKEN %s[%s]!\n",CC_SHORT_NAME[self->catcode],self->string);
    for (i = 0 ; i < self->ntokens ; i++) {
      SvREFCNT_dec(self->tokens[i]); }
    Safefree(self->tokens);
    Safefree(self);
