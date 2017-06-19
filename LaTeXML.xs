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

#define DEBUG_TOKENNOT
#ifdef DEBUG_TOKEN
#  define DEBUG_Token(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Token 1
#else
#  define DEBUG_Token(...)
#  define DEBUGGING_Token 0
#endif

#define DEBUG_TOKENSNOT
#ifdef DEBUG_TOKENS
#  define DEBUG_Tokens(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Tokens 1
#else
#  define DEBUG_Tokens(...)
#  define DEBUGGING_Tokens 0
#endif

#define DEBUG_TOKENSTACKNOT
#ifdef DEBUG_TOKENSTACK
#  define DEBUG_Tokenstack(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Tokenstack 1
#else
#  define DEBUG_Tokenstack(...)
#  define DEBUGGING_Tokenstack 0
#endif

#define DEBUG_MOUTHNOT
#ifdef DEBUG_MOUTH
#  define DEBUG_Mouth(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Mouth 1
#else
#  define DEBUG_Mouth(...)
#  define DEBUGGING_Mouth 0
#endif

#define DEBUG_GULLETNOT
#ifdef DEBUG_GULLET
#  define DEBUG_Gullet(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Gullet 1
#else
#  define DEBUG_Gullet(...)
#  define DEBUGGING_Gullet 0
#endif

  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     Structures */

  /* Currently we copy string & free on DESTROY; Do getString (etal) need to copy? */
  /* the C ends up with sv_setpv, which(apparently) copies the string into the PV(string var) */
typedef SV * PTR_SV;

typedef char * UTF8;
typedef struct Token_struct {
  int catcode;
  UTF8 string;
} T_Token;
typedef T_Token  * LaTeXML_Core_Token;

typedef struct Tokens_struct {
  int ntokens;
  int nalloc;
  PTR_SV * tokens;
} T_Tokens;
typedef T_Tokens * LaTeXML_Core_Tokens;

typedef struct Tokenstack_struct {
  int ntokens;
  int nalloc;
  PTR_SV * tokens;
} T_Tokenstack;
typedef T_Tokenstack * LaTeXML_Core_Tokenstack;

typedef struct Mouth_struct {
  UTF8 source;
  UTF8 short_source;
  SV * saved_state;
  UTF8 note_message;
  int lineno;
  STRLEN colno;
  UTF8 chars;
  STRLEN bufsize;
  STRLEN ptr;
  STRLEN nbytes;
  STRLEN prev_ptr;
  STRLEN prev_colno;
  int prev_lineno;
  int at_eof;
  LaTeXML_Core_Tokenstack pushback;
} T_Mouth;
typedef T_Mouth * LaTeXML_Core_Mouth;

     /* You'll often need SvRV(arg) */
#define SvToken(arg)      INT2PTR(LaTeXML_Core_Token,      SvIV((SV*) arg))
#define SvTokens(arg)     INT2PTR(LaTeXML_Core_Tokens,     SvIV((SV*) arg))
#define SvTokenstack(arg) INT2PTR(LaTeXML_Core_Tokenstack, SvIV((SV*) arg))
#define SvMouth(arg)      INT2PTR(LaTeXML_Core_Mouth,      SvIV((SV*) arg))

#define CopyChar(src,dest,n) if(n==1){ *(dest)=*(src); } else { Copy(src,dest,n,char); } *((dest)+n)=0

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
    0, 1, 0};
int EXECUTABLE_CATCODE[] =
  { 0, 1, 1, 1,
    1, 0, 0, 1,
    1, 0, 0, 0,
    0, 1, 0, 0,
    1, 0, 0};

int ACTIVE_OR_CS[] = 
  {0, 0, 0, 0,
   0, 0, 0, 0,
   0, 0, 0, 0,
   0, 1, 0, 0,
   1, 0, 0};
int LETTER_OR_OTHER[] = 
  {0, 0, 0, 0,
   0, 0, 0, 0,
   0, 0, 0, 1,
   1, 0, 0, 0,
   0, 0, 0};

int CC_TrivialRead[] = 
  { 0, 1, 1, 1,
    1, 0, 1, 1,
    1, 0, 0, 1,
    1, 1, 0, 0,
    1, 1, 0};

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

  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    C-level code 
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

UTF8
string_copy(UTF8 string){
  int n = strlen(string);
  UTF8 newstring;
  Newx(newstring,(n + 1),char);
  CopyChar(string,newstring,n);
  return newstring; }

  /*======================================================================
    C-level Token support */
SV *
token_new(pTHX_ UTF8 string, int catcode){
  /*check string not null ? */
  SV * sv;
  LaTeXML_Core_Token token;
  int n;
  if((catcode < 0) || (catcode > CC_MAX)){
    croak("Illegal catcode %d",catcode); }
  DEBUG_Token("Create %s[%s] ",CC_SHORT_NAME[catcode],string);
  Newx(token,1,T_Token);
  if(string == NULL){
    croak("Token %s string is not defined", CC_SHORT_NAME[catcode]); }
  n = strlen(string);
  Newx(token->string,(n + 1),char);
  CopyChar(string,token->string,n);
  token->catcode = catcode;
  sv = newSV(0);
  sv_setref_pv(sv, "LaTeXML::Core::Token", (void*)token);
  return sv; }

void
token_DESTROY(pTHX_ LaTeXML_Core_Token token){
  DEBUG_Token("DESTROY Token %s[%s]!\n",CC_SHORT_NAME[token->catcode],token->string);
  Safefree(token->string);
  Safefree(token); }

#define T_LETTER(arg) (token_new(aTHX_ (arg), 11))
#define T_OTHER(arg)  (token_new(aTHX_ (arg), 12))
#define T_ACTIVE(arg) (token_new(aTHX_ (arg), 13))
#define T_CS(arg)     (token_new(aTHX_ (arg), 16))

int
token_equals(pTHX_ SV * a, SV * b) {
  LaTeXML_Core_Token aa,bb;
  aa = SvToken(a);
  bb = SvToken(b);
  if (aa->catcode != bb->catcode) {
    return 0; }
  else if (aa->catcode == CC_SPACE) {
    return 1; }
  else {
    return strcmp(aa->string, bb->string) == 0; } }

  /*======================================================================
    C-Level Tokens support */

  /* Tokens are immutable once created & returned to Perl.
     Note peculiar pre-allocation strategy for nalloc!
     it is expected that the caller has allocated enough room for it's arguments
     assuming they are Token's; add_to_tokens will grow if it encounters Tokens/Reversions */

#define TOKENS_ALLOC_QUANTUM 10

LaTeXML_Core_Tokens
tokens_new(pTHX_ int nalloc) {
  LaTeXML_Core_Tokens tokens;
  Newxz(tokens,1, T_Tokens);
  if(nalloc > 0){
    tokens->nalloc = nalloc;
    Newx(tokens->tokens, tokens->nalloc, PTR_SV); }
  return tokens; }

void
tokens_DESTROY(pTHX_ LaTeXML_Core_Tokens tokens){
  int i;
  DEBUG_Tokens("DESTROY Tokens(%d)",tokens->ntokens);
  for (i = 0 ; i < tokens->ntokens ; i++) {
    SvREFCNT_dec(tokens->tokens[i]); }
  Safefree(tokens->tokens);
  Safefree(tokens); }

void
tokens_shrink(pTHX_ LaTeXML_Core_Tokens tokens){
  if(tokens->nalloc > tokens->ntokens){
    Renew(tokens->tokens,tokens->nalloc = tokens->ntokens, PTR_SV); } }

void
tokens_add_to(pTHX_ LaTeXML_Core_Tokens tokens, SV * thing, int revert) {
  DEBUG_Tokens("\nAdding to tokens:");
  if (sv_isa(thing, "LaTeXML::Core::Token")) {
    DEBUG_Tokens( "Token.");
    thing = SvRV(thing);
    SvREFCNT_inc(thing);
    if(tokens->ntokens >= tokens->nalloc){
      /* croak("LaTeXML::Core::Tokens bad Tokens length prediction!"); }*/
      tokens->nalloc += TOKENS_ALLOC_QUANTUM;
      Renew(tokens->tokens, tokens->nalloc, PTR_SV); }
    tokens->tokens[tokens->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens toks = SvTokens(SvRV(thing));
    int n = toks->ntokens;
    int i;
    DEBUG_Tokens( "Tokens(%d): ", n);
    if(n > 0){
      tokens->nalloc += n-1;
      Renew(tokens->tokens, tokens->nalloc, PTR_SV);
      for (i = 0 ; i < n ; i++) {
        DEBUG_Tokens( "adding item %d; ",i);
        SvREFCNT_inc(toks->tokens[i]);
        tokens->tokens[tokens->ntokens++] = toks->tokens[i]; } } }
  else if (revert){             /* Insert the what Revert($thing) returns */
    dSP;
    I32 ax;
    int i,nvals;
    DEBUG_Tokens( "Reversion:");
    ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
    PUSHs(thing);
    PUTBACK;
    nvals = call_pv("Revert", G_ARRAY);
    SPAGAIN;
    SP -= nvals; ax = (SP - PL_stack_base) + 1;
    DEBUG_Tokens( "%d items",nvals);
    tokens->nalloc += nvals-1;
    Renew(tokens->tokens, tokens->nalloc, PTR_SV);    
    for(i=0; i<nvals; i++){
      tokens_add_to(aTHX_ tokens, ST(i), revert); }
    PUTBACK; FREETMPS; LEAVE; }
  else {
    /* Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))*/
    croak("Tokens add_to: Expected a Token, got %s", SvPV_nolen(thing)); }
  DEBUG_Tokens( "Done adding.");
}

void
tokens_trimBraces(pTHX_ LaTeXML_Core_Tokens tokens){
  /*  if(tokens->ntokens > 1){*/
  while(tokens->ntokens > 1){
    LaTeXML_Core_Token t = SvToken(tokens->tokens[tokens->ntokens-1]);
    if(t->catcode == CC_SPACE){
      SvREFCNT_dec(tokens->tokens[tokens->ntokens-1]);
      tokens->ntokens--; }
    else {
      break; } }
  if(tokens->ntokens > 2){
    LaTeXML_Core_Token t0 = SvToken(tokens->tokens[0]);
    LaTeXML_Core_Token tn = SvToken(tokens->tokens[tokens->ntokens-1]);
    if((t0->catcode == CC_BEGIN) && (tn->catcode == CC_END)){
      int i;
      int level = 0;
      int balanced1 = 0;          /* 0 = unknown, +1 = one outer level, -1 not */
      for (i = 0 ; i < tokens->ntokens ; i++) {
        LaTeXML_Core_Token t = SvToken(tokens->tokens[i]);
        int cc = t->catcode;
        if (cc == CC_BEGIN) {
          level++;
          if(level == 1){
            if(balanced1 == 0){
              balanced1 = +1; }
            else {
              balanced1 = -1; } } }
        else if (cc == CC_END) {
          level--; }
        else if (level == 0) {
          balanced1 = -1; } }
      if((level == 0) && (balanced1 == 1)){
        SvREFCNT_dec(tokens->tokens[0]);
        SvREFCNT_dec(tokens->tokens[tokens->ntokens-1]);
        Move(tokens->tokens+1,tokens->tokens,tokens->ntokens-2, PTR_SV);
        tokens->ntokens -= 2; } } } }

  /* Remove trailing spaces */
void
tokens_trimright(pTHX_ LaTeXML_Core_Tokens tokens){
  LaTeXML_Core_Token t;
  while((tokens->ntokens > 1) && (t=SvToken(tokens->tokens[tokens->ntokens-1]))
        && (t->catcode == CC_SPACE)){
    SvREFCNT_dec(tokens->tokens[tokens->ntokens-1]);
    tokens->ntokens--; }
}

LaTeXML_Core_Tokens
tokens_trim(pTHX_ LaTeXML_Core_Tokens tokens){
  int i;
  int i0 = 0;
  int n  = tokens->ntokens;
  while(i0 < n){
    LaTeXML_Core_Token t = SvToken(tokens->tokens[i0]);
    if(t->catcode == CC_SPACE){
      i0++; }
    else {
      break; } }
  while(n > i0){
    LaTeXML_Core_Token t = SvToken(tokens->tokens[n-1]);
    if(t->catcode == CC_SPACE){
      n--; }
    else {
      break; } }
  if(i0 + 2 <= n){
    LaTeXML_Core_Token t0 = SvToken(tokens->tokens[i0]);
    LaTeXML_Core_Token tn = SvToken(tokens->tokens[n-1]);
    if((t0->catcode == CC_BEGIN) && (tn->catcode == CC_END)){
      int level = 0;
      int balanced1 = 0;          /* 0 = unknown, +1 = one outer level, -1 not */
      for (i = i0 ; i < n ; i++) {
        LaTeXML_Core_Token t = SvToken(tokens->tokens[i]);
        int cc = t->catcode;
        if (cc == CC_BEGIN) {
          level++;
          if(level == 1){
            if(balanced1 == 0){
              balanced1 = +1; }
            else {
              balanced1 = -1; } } }
        else if (cc == CC_END) {
          level--; }
        else if (level == 0) {
          balanced1 = -1; } }
      if((level == 0) && (balanced1 == 1)){
        i0++; n--; } } }
  LaTeXML_Core_Tokens trimmed = tokens_new(aTHX_ n-i0);
  int j = 0;
  for(i = i0; i < n; i++){
    SvREFCNT_inc(tokens->tokens[i]);
    trimmed->tokens[j++] = tokens->tokens[i]; }
  trimmed->ntokens = j;
  return trimmed; }

  /*======================================================================
    C-Level Tokenstack support 
    Similar to Tokens, but puts tokens in reverse order */
#define TOKENSTACK_ALLOC_QUANTUM 10

LaTeXML_Core_Tokenstack
tokenstack_new(pTHX) {
  LaTeXML_Core_Tokenstack stack;
  Newxz(stack,1, T_Tokenstack);
  DEBUG_Tokenstack("New tokenstack %p\n",stack);
  stack->nalloc = TOKENSTACK_ALLOC_QUANTUM;
  Newx(stack->tokens, stack->nalloc, PTR_SV);
  return stack; }

void
tokenstack_DESTROY(pTHX_ LaTeXML_Core_Tokenstack stack){
  int i;
  for (i = 0 ; i < stack->ntokens ; i++) {
    SvREFCNT_dec(stack->tokens[i]); }
  Safefree(stack->tokens);
  Safefree(stack); }

void
tokenstack_push(pTHX_ LaTeXML_Core_Tokenstack stack, SV * thing) {
  DEBUG_Tokenstack("Tokenstack push %p: %p ",stack,thing);
  if (sv_isa(thing, "LaTeXML::Core::Token")) {
    DEBUG_Tokenstack( "Token.");
    thing = SvRV(thing);
    SvREFCNT_inc(thing);
    if(stack->ntokens >= stack->nalloc){
      stack->nalloc += TOKENSTACK_ALLOC_QUANTUM;
      Renew(stack->tokens, stack->nalloc, PTR_SV); }
    stack->tokens[stack->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens tokens = SvTokens(SvRV(thing));
    int n = tokens->ntokens;
    int i;
    DEBUG_Tokenstack( "Tokens(%d): ", n);
    if(n > 0){
      stack->nalloc += n-1;
      Renew(stack->tokens, stack->nalloc, PTR_SV);
      for (i = n-1 ; i >= 0 ; i--) {
        DEBUG_Tokenstack( "adding item %d; ",i);
        SvREFCNT_inc(tokens->tokens[i]);
        stack->tokens[stack->ntokens++] = tokens->tokens[i]; } } }
  else {
    /* Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))*/
    croak("Tokens push: Expected a Token, got %s (%p)",SvPV_nolen(thing), thing); }
  DEBUG_Tokenstack("Done pushing.\n");
}

SV *
tokenstack_pop(pTHX_ LaTeXML_Core_Tokenstack stack) {
  DEBUG_Tokenstack("Tokenstack pop %p\n",stack);
  if(stack->ntokens > 0){
    return newRV_inc(stack->tokens[--stack->ntokens]); }
  else {
    return NULL; } }

  /*======================================================================
    C-level State support */

SV *
state_global(pTHX){
  return get_sv("STATE",0); }

SV *
state_lookup(pTHX_ SV * state, UTF8 table, UTF8 string){
  HV * hash;
  AV * array;
  SV ** ptr;
  SV * sv;
  if(! string){
    return NULL; }
  hash = MUTABLE_HV(SvRV(state));
  ptr  = hv_fetch(hash,table,strlen(table),0); /* $$state{$table} */
  if(! ptr){
    croak("State doesn't have a %s table!",table); }
  hash = MUTABLE_HV(SvRV(*ptr));
  ptr  = hv_fetch(hash,string,-strlen(string),0); /* $$state{$table}{$key}; neg. length=>UTF8*/
  if( ! ptr){
    return NULL; }
  array = MUTABLE_AV(SvRV(*ptr));
  ptr  = av_fetch(array,0,0);/* $$state{catcode}{$key}[0] */
  if ( ! ptr){
    return NULL; }
  sv = *ptr;
  sv = (SvOK(sv) ? sv : NULL);
  return sv; }

int
state_catcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "catcode", string);
  return (sv ? SvIV(sv) : CC_OTHER); }

int
state_mathcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "mathcode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_SFcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "sfcode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_LCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "lccode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_UCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "uccode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_Delcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "delcode", string);
  return (sv ? SvIV(sv) : 0); }

SV *
state_value(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "value", string);
  if(sv){
    SvREFCNT_inc(sv); }
  return sv; }

int
state_intval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "value", string);
  return (sv ? SvIV(sv) : 0); }
int
state_booleval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup(aTHX_ state, "value", string);
  return (sv ? SvTRUE(sv) : 0); }

SV *
state_meaning(pTHX_ SV * state, SV * token){
  if(token){
    LaTeXML_Core_Token t = SvToken(SvRV(token));
    if(ACTIVE_OR_CS[t->catcode]){
      SV * sv = state_lookup(aTHX_ state, "meaning", t->string);
      if(sv){
        SvREFCNT_inc(sv);
        return sv; }
      else {
        return NULL; } }
    SvREFCNT_inc(token);
    return token; }
  return NULL; }

SV *
state_definition(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(SvRV(token));
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  if(name){
    SV * defn = state_lookup(aTHX_ state, "meaning", name);
    if(! defn){
      return NULL; }
    if(sv_isa(defn, "LaTeXML::Core::Token")){ /* But NOT a simple token! */
      return NULL; }
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

SV *
state_conditional(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(SvRV(token));
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  if(name){
    SV * defn = state_lookup(aTHX_ state, "meaning", name);
    if(! defn){
      return NULL; }
    /*if(sv_isa(defn, "LaTeXML::Core::Token")){ */ /* But NOT a simple token! */
    if(! sv_derived_from(defn, "LaTeXML::Core::Definition")){
      return NULL; }
    HV * hash;
    SV ** ptr;
    hash = MUTABLE_HV(SvRV(defn));
    ptr  = hv_fetchs(hash,"conditional_type",0);    /* $$defn{conditional_type} */
    if((! ptr) || !SvOK(*ptr)){
      return NULL; }
    SV * type = *ptr; 
    SvREFCNT_inc(type);
    return type; }
  else {
    return NULL; } }

SV *
state_expandable(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(SvRV(token));
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  if(name){
    SV * defn = state_lookup(aTHX_ state, "meaning", name);
    if(! defn){
      return NULL; }
    /*if(sv_isa(defn, "LaTeXML::Core::Token")){ */ /* But NOT a simple token! */
    if(! sv_derived_from(defn, "LaTeXML::Core::Definition")){
      return NULL; }
    HV * hash;
    SV ** ptr;
    hash = MUTABLE_HV(SvRV(defn));
    ptr  = hv_fetchs(hash,"isExpandable",0);    /* $$defn{isExpandable} */
    if((! ptr) || !SvOK(*ptr)){
      return NULL; }
    ptr  = hv_fetchs(hash,"isProtected",0);    /* $$defn{isProtected} */    
    if(ptr && SvOK(*ptr)){
      return NULL; }
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

int letter_or_other[] = {
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 1,
  1, 0, 0, 0,
  0, 0};

SV *
state_digestable(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(SvRV(token));
  int cc = t->catcode;
  char * name =
    (ACTIVE_OR_CS [cc]
     || (letter_or_other[cc] && state_booleval(aTHX_ state, "IN_MATH")
         && (state_mathcode(aTHX_ state, t->string) == 0x8000))
     ? t->string
     : EXECUTABLE_NAME[cc]);
  if(name){
    SV * defn = state_lookup(aTHX_ state, "meaning", name);
    if(! defn){
      SvREFCNT_inc(token);
      return token; }
    /* If \let to an executable token, lookup IT's defn! */
    if(sv_isa(defn, "LaTeXML::Core::Token")){
      LaTeXML_Core_Token let = SvToken(SvRV(defn));
      char * letname = EXECUTABLE_NAME[let->catcode];
      if(letname) {
        SV * letdefn = state_lookup(aTHX_ state, "meaning", letname);
        if(letdefn){
          defn = letdefn; } } }
    SvREFCNT_inc(defn);
    return defn; }
  else {
    SvREFCNT_inc(token);
    return token; } }

SV *
state_lookupExpandable(pTHX_ SV * state, SV * token){
  /* return LaTeXML::Core::State::lookupExpandable($STATE, $token); */
  SV * defn;
  int nvals;
  dSP; ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,2);
  PUSHs(state);
  PUSHs(token);
  PUTBACK;
  nvals = call_method("lookupExpandable",G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    defn = NULL; }
  else {
    defn = POPs;
    if(!SvOK(defn)){
      defn = NULL; }
    else {
      SvREFCNT_inc(defn); } }   /* Why??? */
  PUTBACK; FREETMPS; LEAVE;
  return defn; }

  /*======================================================================
    C-level Mouth support */

void
mouth_setInput(pTHX_ LaTeXML_Core_Mouth mouth, UTF8 input);

LaTeXML_Core_Mouth
mouth_new(pTHX_ UTF8 source, UTF8 short_source, UTF8 content, SV * saved_state, UTF8 note_message){
  LaTeXML_Core_Mouth mouth;
  Newxz(mouth,1,T_Mouth);
  DEBUG_Mouth("Creating MOUTH for %s\n",source);
  Newxz(mouth->chars,3,char);
  mouth->bufsize = 3;
  mouth->lineno  = 1;
  mouth->pushback = tokenstack_new(aTHX);
  mouth->source = string_copy(source);
  mouth->short_source = string_copy(short_source);
  if(saved_state){
    SvREFCNT_inc(saved_state); }
  mouth->saved_state = saved_state;
  mouth->note_message = string_copy(note_message);
  mouth_setInput(aTHX_ mouth, content);
  return mouth; }

void
mouth_DESTROY(pTHX_ LaTeXML_Core_Mouth mouth){
  Safefree(mouth->chars);
  Safefree(mouth->source);
  Safefree(mouth->short_source);
  if(mouth->saved_state){
    SvREFCNT_dec(mouth->saved_state); }
  Safefree(mouth->note_message);  
  tokenstack_DESTROY(aTHX_ mouth->pushback);
  Safefree(mouth); }

#define CR 13
#define LF 10

void
mouth_setInput(pTHX_ LaTeXML_Core_Mouth mouth, UTF8 input){
  mouth->nbytes = strlen(input);
  DEBUG_Mouth("SET INPUT got %lu bytes: '%s'\n",mouth->nbytes,input);
  if(mouth->nbytes > mouth->bufsize){ /* Check if buffer big enough. */
    if(mouth->bufsize == 0){    /* first line? new buffer */
      Newx(mouth->chars, (mouth->nbytes + 2), char); }
    else {                    /* Else, grow if needed */
      Renew(mouth->chars, (mouth->nbytes + 2), char); }
    mouth->bufsize = mouth->nbytes; }
  CopyChar(input,mouth->chars,mouth->nbytes);
  /* Force the buffer to end with a CR */
  if((mouth->nbytes > 0)
     && ! ((*(mouth->chars+mouth->nbytes -1) == CR)
           || (*(mouth->chars+mouth->nbytes -1) == LF))){
    *(mouth->chars+mouth->nbytes) = CR;
    mouth->nbytes++; }
  mouth->ptr    = 0;
  mouth->colno  = 0;
  mouth->lineno = 1;
  mouth->at_eof = 0;
  mouth->prev_ptr    = mouth->ptr;
  mouth->prev_colno  = mouth->colno;
  mouth->prev_lineno = mouth->lineno;
}

  /* Since readToken looks ahead, we'll need to be able to undo the effects of mouth_readChar! */
int
mouth_readChar(pTHX_ LaTeXML_Core_Mouth mouth, SV * state, char * character, int * catcode){
  if(mouth->ptr < mouth->nbytes){
    STRLEN ch_len;
    int nca = 0;                /* # chars advanced in buffer */
    int nba = 0;                /* # bytes advanced */
    int nbr = 0;                /* # bytes returned */
    char c;
    mouth->prev_ptr = mouth->ptr;
    mouth->prev_colno = mouth->colno;
    mouth->prev_lineno = mouth->lineno;
    DEBUG_Mouth("READCHAR @ %lu, %d x %lu\n", mouth->ptr, mouth->lineno, mouth->colno);
    /* Check for line ends: CR+LF (Windows) | CR (Unix) | LF (old Mac);
       normalize to CR = \r = ^^M, which is what TeX expects. */
    if(((c = *(mouth->chars+mouth->ptr)) == CR) || (c == LF)){
      nba++; nca++;
      if((c == CR) && (mouth->ptr + nba < mouth->nbytes)
         && (*(mouth->chars+mouth->ptr+1) == LF)){ /* Got CRLF */
        nba++; nca++; }
      nbr = 1;
      DEBUG_Mouth(" succeeded w/CR\n");
      CopyChar("\r",character,1);      
      *catcode = state_catcode(aTHX_ state,character); /* But still, lookup current catcode! */
      mouth->ptr += nba;
      mouth->colno = 0;
      mouth->lineno ++; }
    else {
      ch_len = UTF8SKIP(mouth->chars+mouth->ptr);
      CopyChar(mouth->chars+mouth->ptr,character,ch_len);
      DEBUG_Mouth("NEXT examine '%s', %lu bytes\n",character, ch_len);
      nca ++;
      nba += ch_len;
      nbr += ch_len;
      *catcode = state_catcode(aTHX_ state,character);
      if((*catcode == CC_SUPER)          /* Check for ^^hex or ^^<ctrl> */
         && (mouth->ptr + nba + ch_len + 1 <= mouth->nbytes)       /* at least 2 more chars? */
         && ( ((ch_len == 1) && (*character == *(mouth->chars+mouth->ptr+nba)))
              || (strncmp(character,mouth->chars+mouth->ptr + nba,ch_len)==0)) ){ /* check if same */
        DEBUG_Mouth("NEXT saw ^^\n");
        nba += ch_len;
        nca ++;
        /* Look for 2 lower-case hex or 1 control char (pure ASCII!) */
        char c1,c2, * tmp;
        UV code;
        if((mouth->ptr + nba + 2 <= mouth->nbytes)
           && (c1 = * (mouth->chars+mouth->ptr + nba))
           && ( ((c1 = c1-'0') >= 0) && ((c1 <= 9) || (((c1 = c1-'a'+'0'+10) >=10) && (c1 <= 15))))
           && (c2 = * (mouth->chars+mouth->ptr + nba + 1))
           && ( ((c2 = c2-'0') >= 0) && ((c2 <= 9) || (((c2 = c2-'a'+'0'+10) >=10) && (c2 <= 15)))) ){
          nba += 2;
          nca += 2;
          code = c1*16+c2; }
        else {
          c1 = * (mouth->chars+mouth->ptr + nba);
          nba ++;
          nca ++;
          code = (c1 > 64 ? c1 - 64 : c1 + 64); } /* ???? */
        /* Code point could have 8th bit, turn to multibyte unicode! */
        tmp = (char *)uvchr_to_utf8((U8 *)character,code);
        nbr = tmp - character;    /* how many bytes */
        *catcode = state_catcode(aTHX_ state,character); }
      DEBUG_Mouth("NEXT Succeed %d bytes, %d chars advanced => '%s', %d bytes\n",
                   nba,nca,character,nbr);
      mouth->ptr += nba;
      mouth->colno += nca; }
    return nbr; }
  else {
    DEBUG_Mouth("NEXT Failed\n");
    return 0; } }

  /* Put back the previously parsed character.  Would be nice to save it for next call,
     but the catcodes can (& will) change by then! */
void
mouth_unreadChar(pTHX_ LaTeXML_Core_Mouth mouth){
  DEBUG_Mouth("PUTBack char\n");
  mouth->ptr = mouth->prev_ptr;
  mouth->colno = mouth->prev_colno;
  mouth->lineno = mouth->prev_lineno;
}

int
mouth_readLine(pTHX_ LaTeXML_Core_Mouth mouth){
  STRLEN p = 0,pend;
  char c;
  /* Skip to CRLF|CR|LF */
  while((mouth->ptr + p < mouth->nbytes)
        && ( ( (c=*(mouth->chars + mouth->ptr + p)) != CR) && (c != LF)) ){
    p += UTF8SKIP(mouth->chars + mouth->ptr + p); }
  pend = p + 1;
  if((mouth->ptr + pend < mouth->nbytes)
     && (*(mouth->chars + mouth->ptr + pend - 1) == CR)
     && (*(mouth->chars + mouth->ptr + pend) == LF)){ /* CRLF */
    pend ++; }
  /* Now skip backwards over any trailing spaces */
  while(*(mouth->chars + mouth->ptr + p - 1) == ' ') {
    p--; }
  mouth->ptr   += pend;
  mouth->colno = 0;
  mouth->lineno++;
  return p; }


/*
int
mouth_fetchInput(pTHX_ LaTeXML_Core_Mouth mouth){
  int nvals;
  char * line;
  SV * sv;
  dSP;
  DEBUG_Mouth("FETCHLINE\n");
  ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(mouth);
  PUTBACK;
  nvals = call_method("getNextLine",G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    line = NULL; }
  else {
    sv = POPs;
    if(!SvOK(sv)){
      line = NULL; }
    else {
      if(! SvUTF8(sv)) {
        sv = sv_mortalcopy(sv);
        sv_utf8_upgrade(sv); }
      line = (UTF8)SvPV_nolen(sv);
      mouth->nbytes = strlen(line);
      DEBUG_Mouth("FETCHLINE got %lu bytes: '%s'\n",mouth->nbytes,line);
      if(mouth->nbytes > mouth->bufsize){
        if(mouth->bufsize == 0){    
          Newx(mouth->chars, (mouth->nbytes + 1), char); }
        else {                   
          Renew(mouth->chars, (mouth->nbytes + 1), char); }
        mouth->bufsize = mouth->nbytes; }
      CopyChar(line,mouth->chars,mouth->nbytes);
      mouth->ptr = 0; } }
  PUTBACK; FREETMPS; LEAVE;
  if(line == NULL){
    DEBUG_Mouth("No remaining input\n");
    mouth->at_eof = 1;
    return 0; }
  else {
    return 1; } }
*/

void
mouth_unreadToken(pTHX_ LaTeXML_Core_Mouth mouth, SV * thing){
  tokenstack_push(aTHX_ mouth->pushback, thing); }

SV *
mouth_readToken(pTHX_ LaTeXML_Core_Mouth mouth, SV * state){
  char ch[UTF8_MAXBYTES+1];
  int  cc;
  STRLEN nbytes;
  STRLEN startcol = mouth->colno;
  SV * token = NULL;
  if(mouth->pushback->ntokens > 0){
    token = tokenstack_pop(aTHX_ mouth->pushback); }
  while(token == NULL){
    DEBUG_Mouth("READ Token @ %lu\n",startcol);
    if((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc))){
      if((startcol == 0) && (cc == CC_SPACE)){ /* Ignore leading spaces */
        DEBUG_Mouth("Skipping leading space\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc) && (cc == CC_SPACE))){
        } }
      if(CC_TrivialRead[cc]){   /* Common, trivial case first */
        DEBUG_Mouth("Token[%s,%s]\n",ch,CC_SHORT_NAME[cc]);
        token = token_new(aTHX_ ch,cc); }
      else if(cc == CC_ESCAPE){
        /* WARNING: Actually, room for the whole file!
           What's a SAFE strategy for reasonable max token length??? */
        char buffer[mouth->nbytes+1]; /* room for whole line. */
        STRLEN p;
        buffer[0]='\\'; p = 1; buffer[p]=0; /* Store \, 'cause CS are stored that way */
        DEBUG_Mouth("ESCAPE '%s'\n",buffer);
        if((nbytes = mouth_readChar(aTHX_ mouth,state,buffer+p,&cc))){
          p+=nbytes;
          if(cc == CC_LETTER){
            while((nbytes = mouth_readChar(aTHX_ mouth,state,buffer+p,&cc)) && (cc == CC_LETTER)){
              p+=nbytes; }
            *(buffer+p)=0;    /* terminate the CS, in case we just added a non-letter */
            /* if peeked char was space, skip spaces */
            while((cc == CC_SPACE) && (nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc)) ){
            }
            /* In \read & we get EOL, we'll put it back to turn into a space; otherwise remove it */
            if ((cc == CC_EOL) && !(state_intval(aTHX_ state,"PRESERVE_NEWLINES") > 1)) {
              nbytes = 0; }    /* so it will NOT be put back  */
            if(nbytes) {        /* put back last non-letter, non-space peeked char, if any */
              mouth_unreadChar(aTHX_ mouth); } }
        }
        else {
          croak("Missing character following escape char %s",ch); }
        DEBUG_Mouth("Token[%s,%s]\n",buffer,CC_SHORT_NAME[CC_CS]);
        token = token_new(aTHX_ buffer,CC_CS); }
      else if (cc == CC_SPACE){
        int cr = 0;
        DEBUG_Mouth("Skipping spaces\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc)) /* skip following spaces */
              && ((cc == CC_SPACE) || (cc == CC_EOL)) ){
          if(cc == CC_EOL){
            cr = 1;
            nbytes = 0;
            break; } }
        if(cr && state_intval(aTHX_ state,"PRESERVE_NEWLINES")){
          token = token_new(aTHX_ "\n",CC_SPACE); }
        else {
          token = token_new(aTHX_ " ",CC_SPACE); }
        if(nbytes){           /* put back non-space (if any) */
          mouth_unreadChar(aTHX_ mouth); } }
      else if (cc == CC_COMMENT){
        STRLEN pstart = mouth->ptr;
        STRLEN n;
        if((n = mouth_readLine(aTHX_ mouth))
           && state_booleval(aTHX_ state,"INCLUDE_COMMENTS")){
          char buffer[n+2];
          buffer[0]='%';            
          Copy(mouth->chars+pstart,buffer+1,n,char);
          buffer[n+1] = 0;
          DEBUG_Mouth("Comment '%s'\n",buffer);
          token = token_new(aTHX_ buffer,cc);
        }
        startcol = mouth->colno; }
      else if (cc == CC_EOL){
        if(startcol == 0){
          DEBUG_Mouth("EOL \\par\n");
          token = T_CS("\\par"); }
        else if(state_intval(aTHX_ state,"PRESERVE_NEWLINES")){
          DEBUG_Mouth("EOL T_SPACE[\\n]\n");
          token = token_new(aTHX_ "\n",CC_SPACE); }
        else {
          DEBUG_Mouth("EOL T_SPACE\n");
          token = token_new(aTHX_ " ",CC_SPACE); } }
      else if (cc == CC_IGNORE){
        DEBUG_Mouth("IGNORE\n"); }
      else if (cc == CC_INVALID){
        DEBUG_Mouth("INVALID\n");
        token = token_new(aTHX_ ch,CC_OTHER); } /* ? */
      else {
        DEBUG_Mouth("No proper Catcode '%d'\n",cc); }
      }
    else {                    /* Got no input; Try for next line. */
      /* Comment this out; it currently has no effect, but we may want to "chunk" input???
      if(! mouth_fetchInput(aTHX_ mouth)){
      break; } */                /* EXIT FROM OUTER LOOP */
      mouth->at_eof = 1;        /* but still terminate */
      break;
      /* This should be integrated into above; CC_EOL ? CC_COMMENT ? 
      if(((mouth->lineno % 25) == 0) && state_booleval(aTHX_ state,"INCLUDE_COMMENTS")){
        char * source = mouth_getShortsource(aTHX_ mouth);
        if(source != NULL){
          char * comment = form("**** %s Line %d ****",source,mouth->lineno);
          token = token_new(aTHX_ comment, CC_COMMENT); } }
      else {
      startcol = mouth->colno; } */
    } }
  return token; }

LaTeXML_Core_Tokens
mouth_readTokens(pTHX_ LaTeXML_Core_Mouth mouth, SV * state, SV * until){
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  LaTeXML_Core_Token u = (until ? SvToken(SvRV(until)) : NULL);
  char * test = (u ? u->string : NULL);
  SV * token;
  /* NOTE: Compare to Until's string, NOT catcode!! */
  while ( (token = mouth_readToken(aTHX_ mouth, state)) ) {
    LaTeXML_Core_Token t = SvToken(SvRV(token));
    if(test && (strcmp(test,t->string) == 0)){
      break; }
    tokens_add_to(aTHX_ tokens,token,0); }
  tokens_trimright(aTHX_ tokens);
  return tokens; }

  /*======================================================================
    C-level Gullet support */

LaTeXML_Core_Mouth
gullet_getMouth(pTHX_ SV * gullet){
  HV * hash;
  SV ** ptr;
  hash = MUTABLE_HV(SvRV(gullet));
  ptr  = hv_fetchs(hash,"mouth",0);
  if(! ptr){
    croak("Gullet doesn't have an mouth!"); }
  /*  return SvRV(*ptr); }*/
  return SvMouth(SvRV(*ptr)); }

LaTeXML_Core_Tokenstack
gullet_getPendingComments(pTHX_ SV * gullet){
  HV * hash;
  SV ** ptr;
  hash = MUTABLE_HV(SvRV(gullet));
  ptr  = hv_fetchs(hash,"pending_comments",0);
  if(! ptr){
    croak("Gullet doesn't have a pending_comments!"); }
  /*  return SvRV(*ptr); }*/
  return SvTokenstack(SvRV(*ptr)); }

void
gullet_stopProfiling(pTHX_ SV * gullet, SV * marker){
  croak("Stop Profiling: Not Yet Implemented!"); }

SV *
gullet_readToken(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  while(1){
    SV * token = mouth_readToken(aTHX_ mouth, state);
    if(token == NULL){
      return NULL; }
    else {
      LaTeXML_Core_Token t = SvToken(SvRV(token));
      int cc = t->catcode;
      if(cc == CC_COMMENT){
        LaTeXML_Core_Tokenstack pc = gullet_getPendingComments(aTHX_ gullet);
        DEBUG_Gullet("PUSH Comment: %s\n",t->string);
        tokenstack_push(aTHX_ pc,token); }
      /* AND CC_MARKER!!!*/
      else if(cc == CC_MARKER){
        gullet_stopProfiling(aTHX_ gullet, token); }
      else {
        return token; } } } }

int
gullet_nextMouth(pTHX_ SV * gullet){
  /* return unless $$self{autoclose} && $toplevel && @{ $$self{mouthstack} };
     $self->closeMouth;     # Next input stream.  */
  SV * sv;
  int nvals;
  dSP; ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(gullet);
  PUTBACK;
  nvals = call_method("nextMouth",G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    sv = NULL; }
  else {
    sv = POPs;
    if(!SvOK(sv)){
      sv = NULL; } }
  PUTBACK; FREETMPS; LEAVE;
  return (sv != NULL); }

void
gullet_expand(pTHX_ SV * gullet, SV * state, SV * defn){
  SV * tokens;
  int nvals;
  HV * defnhash = MUTABLE_HV(SvRV(defn));
  SV ** ptr;

  /* Lookup $$defn{trivial_expansion} and avoid call to invoke! */
  if( (ptr  = hv_fetchs(defnhash,"trivial_expansion",0))
      && SvOK(*ptr) ){
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    mouth_unreadToken(aTHX_ mouth, *ptr); }
  else {
    dSP; ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,2);
    PUSHs(defn);
    PUSHs(gullet);
    PUTBACK;
    nvals = call_method("invoke",G_ARRAY);
    SPAGAIN;
    if(nvals < 1){
      tokens = NULL; }
    else {
      tokens = POPs;
      if(!SvOK(tokens)){
        tokens = NULL; }
      else {
        LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
        mouth_unreadToken(aTHX_ mouth, tokens); } }
    PUTBACK; FREETMPS; LEAVE; }
}

int readXToken_interesting_catcode[] = {
  0, 1, 1, 1,
  1, 0, 0, 1,
  1, 0, 0, 0,
  0, 1, 1, 0,
  1, 1, 1};

SV *
gullet_readXToken(pTHX_ SV * gullet, SV * state, int toplevel, int commentsok){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  LaTeXML_Core_Tokenstack comments = gullet_getPendingComments(aTHX_ gullet);
  SV * token;
  if(commentsok && (token = tokenstack_pop(aTHX_ comments))){
    return token; }
  while(1){
        mouth = gullet_getMouth(aTHX_ gullet);
    SV * token = mouth_readToken(aTHX_ mouth, state);
    SV * defn;
    if(token == NULL){
      if( toplevel && gullet_nextMouth(aTHX_ gullet) ) {
        mouth = gullet_getMouth(aTHX_ gullet);
        DEBUG_Gullet("End of input... next mouth=%p\n",mouth); }
      else {
        DEBUG_Gullet("End of input...Done\n");
        return NULL; } }
    else {
      LaTeXML_Core_Token t = SvToken(SvRV(token));
      int cc = t->catcode;
      DEBUG_Gullet("Token %s[%s] (%p): ",CC_SHORT_NAME[cc],t->string,t);
      if (!readXToken_interesting_catcode[cc]) {    /* Short circuit tests */
        DEBUG_Gullet("simple return\n");
        return token; }                           /* just return it */
      /* else if ( (defn = state_lookupExpandable(aTHX_ state, token)) ) {*/
      else if ( (defn = state_expandable(aTHX_ state, token)) ) {
        DEBUG_Gullet("expand & loop\n");
        gullet_expand(aTHX_ gullet, state, defn);
        mouth = gullet_getMouth(aTHX_ gullet); /* Expansion could change Mouths! */
        if(state_booleval(aTHX_ state, "PROFILING")){
          mouth_unreadToken(aTHX_ mouth, token_new(aTHX_ t->string,CC_MARKER)); } }
      else if (cc == CC_NOTEXPANDED) {
        DEBUG_Gullet("noexpand return\n");
        /* Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
           so this token should never leak out through an EXTERNAL call to readToken. */
        return mouth_readToken(aTHX_ mouth, state); }    /* Just return the next token.*/
      else if (cc == CC_COMMENT) {
        DEBUG_Gullet("comment\n");
        if(commentsok){
          return token; }
        else {
          tokenstack_push(aTHX_ comments,token); } }
      else if (cc == CC_MARKER) {
        DEBUG_Gullet("marker\n");
        gullet_stopProfiling(aTHX_ gullet, token); }
      else {
        DEBUG_Gullet("return\n");
        return token; }                                  /* just return it  */
    } }
  return NULL; }                                            /* never get here. */

LaTeXML_Core_Tokens
gullet_readXTokens(pTHX_ SV * gullet, SV * state, SV * until){
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  LaTeXML_Core_Token u = (until ? SvToken(SvRV(until)) : NULL);
  char * test = (u ? u->string : NULL);
  SV * token;
  /* NOTE: Compare to Until's string, NOT catcode!! */
  while ( (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ) {
    LaTeXML_Core_Token t = SvToken(SvRV(token));
    if(test && (strcmp(test,t->string) == 0)){
      break; }
    tokens_add_to(aTHX_ tokens,token,0); }
  /*tokens_trimright(aTHX_ tokens);*/
  return tokens; }

int balanced_interesting_cc[] = {
  0, 1, 1, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 1};

LaTeXML_Core_Tokens
gullet_readBalanced(pTHX_ SV * gullet, SV * state, LaTeXML_Core_Tokens tokens){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  int level = 1;
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(SvRV(token));    
    int cc = t->catcode;
    if(!balanced_interesting_cc[cc]){
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_END){
      level--;
      if(level == 0){
        break; }
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_BEGIN){
      level++;
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_MARKER){
      gullet_stopProfiling(aTHX_ gullet, token); }
    else {
      tokens_add_to(aTHX_ tokens,token,0); } }
  /*tokens_shrink(tokens);*/
  return tokens; }

SV *
gullet_readNonSpace(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(SvRV(token));    
    int cc = t->catcode;
    if(cc == CC_SPACE){}
    /* comment ? */
    else if(cc == CC_MARKER){
      gullet_stopProfiling(aTHX_ gullet, token); }
    else {
      return token; } }
  return NULL; }

void
gullet_skipSpaces(pTHX_ SV * gullet, SV * state){
  SV * token = gullet_readNonSpace(aTHX_ gullet, state);
  if(token != NULL){
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    mouth_unreadToken(aTHX_ mouth, token); } }

void
gullet_skip1Space(pTHX_ SV * gullet,  SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token = mouth_readToken(aTHX_ mouth, state);
  if(token != NULL){
    LaTeXML_Core_Token t = SvToken(SvRV(token));    
    int cc = t->catcode;
    if(cc != CC_SPACE){
      mouth_unreadToken(aTHX_ mouth, token); } } }

LaTeXML_Core_Tokens
gullet_readArg(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  SV * token = gullet_readNonSpace(aTHX_ gullet, state);
  if(token == NULL){
    return NULL; }
  else {
    LaTeXML_Core_Token t = SvToken(SvRV(token));    
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      gullet_readBalanced(aTHX_ gullet, state, tokens); }
    else {
      tokens_add_to(aTHX_ tokens,token,0); }
    return tokens; } }

LaTeXML_Core_Tokens
gullet_readUntilBrace(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(SvRV(token));    
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      mouth_unreadToken(aTHX_ mouth, token);
      break; }
    else {
      tokens_add_to(aTHX_ tokens,token,0); } }
  return tokens; }

#define MAX_CSNAME 1000
SV *
gullet_readCSName(pTHX_ SV * gullet, SV * state){
  char buffer[MAX_CSNAME];            /* !!!!! */
  SV * token;
  int p = 0;
  buffer[p++] = '\\'; buffer[p] = 0;
  while ( (token = gullet_readXToken(aTHX_ gullet, state,0,0)) ) {
    LaTeXML_Core_Token t = SvToken(SvRV(token));        
    int cc = t->catcode;
    if (cc == CC_CS){
      if(strcmp(t->string, "\\endcsname") == 0){
        break; }
      else  {
        croak("Token shouldn't appear between \\csname and \\endcsname");
        /* if (defined $STATE->lookupDefinition($token)) {
           Error('unexpected', $token, $gullet,
           "The control sequence " . ToString($token) . " should not appear between \csname and \endcsname"); }
           else {
           Error('undefined', $token, $gullet, "The token " . Stringify($token) . " is not defined"); } } */
      } }
    else {
      /* Keep newlines from having \n! */
      char * s = (standardchar[cc] == NULL ? t->string : standardchar[cc]);
      int l = strlen(s);
      if(p + l >= MAX_CSNAME){
        croak("Internal error: csname too long!"); }
      strncpy(buffer+p,s,l); p += l; buffer[p]=0;} }
  return token_new(aTHX_ buffer, CC_CS); }

  /* Note the following 2 readMatch return -1 for failure, otherwise the index of the match */
int
gullet_readMatch(pTHX_ SV * gullet, SV * state,
                 int nchoices, int maxlength, int type[], SV * choices[]) {
  SV * token;
  int ncandidates = nchoices;
  int matched = -1;
  int choice;
  SV * tokens_read[maxlength];
  int nread = 0;
  int disabled[nchoices];
  LaTeXML_Core_Tokens tokens; 
  for(choice = 0; (choice < nchoices); choice++){
    disabled[choice] = 0; }
  while( (matched < 0) && ncandidates && (token = gullet_readToken(aTHX_ gullet, state)) ){
    /*SvREFCNT_inc(token);*/          /* ?? */
    tokens_read[nread++] = token;
    for(choice = 0; (matched < 0) && (choice < nchoices); choice++){
      if(! disabled[choice]){
        switch(type[choice]){
        case 0: break;
        case 1: if(token_equals(aTHX_ SvRV(token), choices[choice])){
            matched = choice; }
          else {
            ncandidates--;
            disabled[choice] = 1; }        /* failed on this choice */
          break;
        case 2:
          tokens = SvTokens(choices[choice]);
          if(token_equals(aTHX_ SvRV(token), tokens->tokens[nread-1])){
            if(nread == tokens->ntokens){
              matched = choice; } }
          else {
            ncandidates--;
            disabled[choice] = 1; }      /* failed on this choice */
          break; } } } }
  if(matched >= 0){              /* Found a match! */
     return matched; }
  else {
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    while(nread > 0){
      mouth_unreadToken(aTHX_ mouth, tokens_read[--nread]); }
    return -1; } }

int
gullet_readMatch1(pTHX_ SV * gullet, SV * state, SV * tomatch){
  SV * token;
  if( (token = gullet_readToken(aTHX_ gullet, state)) ){
    if(token_equals(aTHX_ SvRV(token), tomatch)){
      return 0; }
    else {
      LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
      mouth_unreadToken(aTHX_ mouth, token);
      return -1; } }
  else {
    return -1; } }

int
gullet_readKeyword(pTHX_ SV * gullet, SV * state,
                 int nchoices, int maxlength, STRLEN length[], char * choices[]) {
  SV * token;
  int ncandidates = nchoices;
  int matched = -1;
  int choice;
  SV * tokens_read[maxlength];
  int nread = 0;
  int disabled[nchoices];
  gullet_skipSpaces(aTHX_ gullet, state);
  for(choice = 0; (choice < nchoices); choice++){
    disabled[choice] = 0; }
  while( ( (ncandidates > 0) && !((ncandidates == 1) && (matched >= 0)))
         && (nread < maxlength) && (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ){
    tokens_read[nread++] = token;
    LaTeXML_Core_Token t = SvToken(SvRV(token));
    DEBUG_Gullet("readKeyword try %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
    /* (mostly) Assume ASCII for the moment ? */
    for(choice = 0; choice < nchoices; choice++){
      if(! disabled[choice] && (nread <= length[choice])){
        if(foldEQ_utf8(t->string, NULL, strlen(t->string), 1, /* Case insensitive match */
                       choices[choice]+nread-1, NULL, 1, 1)){
          DEBUG_Gullet("readKeyword matched %s to %d\n",choices[choice],nread);
          if(nread == length[choice]){
            DEBUG_Gullet("readKeyword matched %s\n",choices[choice]);
            matched = choice; } }
        else {
          DEBUG_Gullet("readKeyword failed %s\n",choices[choice]);
          ncandidates--;
          disabled[choice] = 1; } } } }      /* failed on this choice */

  int nmatched = (matched >= 0 ? length[matched] : 0);
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  while(nread > nmatched){
      mouth_unreadToken(aTHX_ mouth, tokens_read[--nread]); }
  if(matched >= 0){              /* Found a match! */
    DEBUG_Gullet("readKeyword matched %s\n",choices[matched]);
    return matched; }
  else {
    DEBUG_Gullet("readKeyword failed\n");
    return -1; } }

  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Perl Modules
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/
  /* REMEMBER: DO NOT RETURN NULL!!!! Return &PL_sv_undef !!! */
 # /*======================================================================
 #    LaTeXML::Core::State
 #   ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::State
  
int
lookupCatcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_catcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

int
lookupMathcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_mathcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

int
lookupSFcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_SFcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

int
lookupLCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_LCcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

int
lookupUCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_UCcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

int
lookupDelcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_Delcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

SV *
lookupValue(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_value(aTHX_ state, string);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

SV *
lookupMeaning(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_meaning(aTHX_ state, token);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

SV *
lookupConditional(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_conditional(aTHX_ state, token);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

SV *
lookupExpandable(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_expandable(aTHX_ state, token);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

SV *
lookupDefinition(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_definition(aTHX_ state, token);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

SV *
lookupDigestableDefinition(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_digestable(aTHX_ state, token);
    RETVAL = (RETVAL ? RETVAL : &PL_sv_undef);
  OUTPUT:
    RETVAL

 # /*======================================================================
 #    LaTeXML::Core::Token 
 #   ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Token

SV *
Token(string, catcode)
    UTF8 string
    int catcode
  CODE:
    RETVAL = token_new(aTHX_ string, catcode);
  OUTPUT:
    RETVAL

SV *
T_LETTER(string)
    UTF8 string

SV *
T_OTHER(string)
    UTF8 string

SV *
T_ACTIVE(string)
    UTF8 string

SV *
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
equals(a, b)
    SV * a
    SV * b
  CODE:
   if (SvOK(a) && sv_isa(a, "LaTeXML::Core::Token")
       && SvOK(b) && sv_isa(b, "LaTeXML::Core::Token")) {
     RETVAL = token_equals(aTHX_ SvRV(a),SvRV(b)); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Token self
  CODE:
    token_DESTROY(aTHX_ self);


 #/*======================================================================
 #   LaTeXML::Core::Tokens
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Tokens

SV *
Tokens(...)
  INIT:
    int i;
    LaTeXML_Core_Tokens tokens;
  CODE:
    if((items == 1) && sv_isa(ST(0), "LaTeXML::Core::Tokens")) {
      SvREFCNT_inc(ST(0));
      RETVAL = ST(0); }
    else {
      tokens = tokens_new(aTHX_ items);
      for (i = 0 ; i < items ; i++) {
        tokens_add_to(aTHX_ tokens,ST(i),0); }
     DEBUG_Tokens( "done %d.\n", tokens->ntokens);
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
    DEBUG_Tokens("\nChecking balance of %d tokens",self->ntokens);
    for (i = 0 ; i < self->ntokens ; i++) {
      LaTeXML_Core_Token t = SvToken(self->tokens[i]);
      int cc = t->catcode;
      DEBUG_Tokens("[%d]",cc);
      if (cc == CC_BEGIN) {
        DEBUG_Tokens("+");
        level++; }
      else if (cc == CC_END) {
        DEBUG_Tokens("-");
        level--; } }
      DEBUG_Tokens("net %d",level);
    RETVAL = (level == 0);
  OUTPUT:
    RETVAL


LaTeXML_Core_Tokens
substituteParameters(self,...)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
    LaTeXML_Core_Tokens tokens;
  CODE:
    tokens = tokens_new(aTHX_ self->ntokens);
    DEBUG_Tokens("\nsubstituting:");
    for (i = 0 ; i < self->ntokens ; i++) {
      LaTeXML_Core_Token t = SvToken(self->tokens[i]);
      int cc = t->catcode;
      if(cc != CC_PARAM){ /* non #, so copy it*/
        DEBUG_Tokens("copy %s;",t->string);
        SvREFCNT_inc(self->tokens[i]);
        tokens->tokens[tokens->ntokens++] = self->tokens[i]; }
      else if(i >= self->ntokens) { /* # at end of tokens? */
        croak("substituteParamters: fell off end of pattern"); }
      else {
        /*t = SvToken(self->tokens[++i]);*/
        i++;
        t = SvToken(self->tokens[i]);
        DEBUG_Tokens("#%s ",t->string);
        cc = t->catcode;
        if(cc == CC_PARAM){ /* next char is #, just duplicate it */
          DEBUG_Tokens("copy#;");
          SvREFCNT_inc(self->tokens[i]);
          tokens->tokens[tokens->ntokens++] = self->tokens[i]; }
        else {                  /* otherwise, insert the appropriate arg. */
          int argn = (int) t->string[0] - (int) '0';
          DEBUG_Tokens("arg%d;",argn);
          if((argn < 1) || (argn > 9)){
            croak("substituteTokens: Illegal argument number %d",argn); }
          else if ((argn <= items) && SvOK(ST(argn))){      /* ignore undef */
            tokens_add_to(aTHX_ tokens, ST(argn), 1); } }
      } }
    DEBUG_Tokens("done\n");
    RETVAL = tokens;
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
trim(self)
    LaTeXML_Core_Tokens self
  CODE:
    RETVAL = tokens_trim(aTHX_ self); 
  OUTPUT:
    RETVAL
  
void
DESTROY(self)
    LaTeXML_Core_Tokens self
  CODE:
    tokens_DESTROY(aTHX_ self);

 #/*======================================================================
 #   LaTeXML::Core::Tokenstack
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Tokenstack

SV *
new()
  INIT:
    LaTeXML_Core_Tokenstack stack;
  CODE:
    stack = tokenstack_new(aTHX);
    RETVAL = newSV(0);
    sv_setref_pv(RETVAL, "LaTeXML::Core::Tokenstack", (void*)stack);
  OUTPUT:
    RETVAL

void
push(stack,token)
    LaTeXML_Core_Tokenstack stack;
    SV * token;
  CODE:
    tokenstack_push(aTHX_ stack,token); 

SV *
pop(stack)
    LaTeXML_Core_Tokenstack stack;
  CODE:
    RETVAL = tokenstack_pop(aTHX_ stack); 
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Mouth
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Mouth


LaTeXML_Core_Mouth
new_internal(source,short_source,content,saved_state,note_message)
      UTF8 source;
      UTF8 short_source;
      UTF8 content;
      SV * saved_state;
      UTF8 note_message;
  CODE:
      /* NOTE: This is NOT getting blessed into the appropriate subclass !!!!!!! */
    RETVAL = mouth_new(aTHX_ source,short_source,content,saved_state,note_message); 
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Mouth self
  CODE:
    mouth_DESTROY(aTHX_ self);

void
finish_internal(mouth)
    LaTeXML_Core_Mouth mouth;
  INIT:
    LaTeXML_Core_Tokenstack pb = mouth->pushback;
  CODE:
    DEBUG_Mouth("Finished with Mouth for %s\n",mouth->source);
    mouth->lineno = 1;
    mouth->colno  = 0;
    mouth->nbytes = 0;
    mouth->ptr    = 0;
    while(pb->ntokens > 0){
      pb->ntokens--;
      SvREFCNT_dec(pb->tokens[pb->ntokens]); }

int
hasMoreInput(mouth)
    LaTeXML_Core_Mouth mouth
  CODE:
    DEBUG_Mouth("Mouth has %lu bytes\n", mouth->nbytes-mouth->ptr);
    RETVAL = (mouth->pushback->ntokens > 0) || (mouth->ptr < mouth->nbytes);
  OUTPUT:
    RETVAL

void
getPosition(mouth)
    LaTeXML_Core_Mouth mouth;
  PPCODE:
    EXTEND(SP, 2);
    mPUSHi((IV) mouth->lineno);
    mPUSHi((IV) mouth->colno);

UTF8
getSource(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth->source;
  OUTPUT:
    RETVAL

UTF8
getShortSource(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->short_source;
  OUTPUT:
    RETVAL

UTF8
getNoteMessage(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->note_message;
  OUTPUT:
    RETVAL

SV *
getSavedState(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    if(mouth->saved_state){
      RETVAL = SvREFCNT_inc(mouth->saved_state);
      RETVAL = mouth->saved_state; }
    else {
      RETVAL = &PL_sv_undef; }
     /*mouth->saved_state = NULL; */             /* use only ONCE! */
  OUTPUT:
    RETVAL

void
setInput(mouth,input)
    LaTeXML_Core_Mouth mouth;
    UTF8 input;
  CODE:
    mouth_setInput(aTHX_ mouth,input);

SV *
readToken(mouth)
    LaTeXML_Core_Mouth mouth;
  INIT:
    SV * token;
  CODE:
    token = mouth_readToken(aTHX_ mouth, state_global(aTHX));
    if(token == NULL){
      RETVAL = &PL_sv_undef; }
    else {
      RETVAL = token; }
  OUTPUT:
    RETVAL


LaTeXML_Core_Tokens
readTokens(mouth,...)
    LaTeXML_Core_Mouth mouth;
  INIT:
    SV * until = NULL;
  CODE:
    if(items > 1){
      until = ST(1); }
    RETVAL = mouth_readTokens(aTHX_ mouth, state_global(aTHX), until);
  OUTPUT:
    RETVAL
  
void
unread(mouth,...)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      mouth_unreadToken(aTHX_ mouth, ST(i)); }

void
getPushback(mouth)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int i,n;
    LaTeXML_Core_Tokenstack pb;
  PPCODE:
    pb = mouth->pushback;
    n = pb->ntokens;
    EXTEND(SP, n);
    for(i = n-1; i >= 0; i--) {
      PUSHs(sv_2mortal(tokenstack_pop(aTHX_ pb))); }

int
atEOF(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth->at_eof;
  OUTPUT:
    RETVAL

SV *
readRawLine(mouth,...)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int noread = 0;
  CODE:
    if(items > 1){
      noread = SvIV(ST(1)); }
    /* Peculiar logic: 'noread' really means return the rest of current line,
       if we've alread read something from it */
    if(noread){
      if(mouth->colno > 0){
        STRLEN pstart = mouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        /*
        if(n==0){ fprintf(stderr,"KEEP RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(mouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"KEEP RAW: '%s'\n",buffer); }
              */
        RETVAL = newSVpvn_flags(mouth->chars+pstart,n, SVf_UTF8); }
      else {
        RETVAL = &PL_sv_undef; } }
    else {
      if(mouth->ptr >= mouth->nbytes){       /* out of input */
        /* mouth_fetchInput(aTHX_ mouth); }  */
        mouth->at_eof = 1; }
      if(mouth->ptr < mouth->nbytes) { /* If we have input now */
        STRLEN pstart = mouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        /*
        if(n==0){ fprintf(stderr,"READ RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(mouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"READ RAW: '%s'\n",buffer); }
               */
        RETVAL = newSVpvn_flags(mouth->chars+pstart,n, SVf_UTF8);
      }
      else {
        DEBUG_Mouth("NO MORE RAW\n");
        RETVAL = &PL_sv_undef;; } }
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Gullet
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Gullet

SV *
readToken(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    SV * token;
  CODE:
    token = gullet_readToken(aTHX_ gullet, state);
    RETVAL = (token == NULL ? &PL_sv_undef : token);
  OUTPUT:
    RETVAL

void
unread(gullet,...)
    SV * gullet;
  INIT:
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      mouth_unreadToken(aTHX_ mouth, ST(i)); }

SV *
readXToken(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    SV * token;
    int toplevel=0,commentsok=0;
  CODE:
    if(items > 1){
      toplevel = SvIV(ST(1));
      if(items > 2){
        commentsok = SvIV(ST(2)); } }
    token = gullet_readXToken(aTHX_ gullet, state, toplevel, commentsok);
    RETVAL = (token == NULL ? &PL_sv_undef : token);
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readXTokens(gullet,...)
    SV * gullet;
  INIT:
    SV * until = NULL;
  CODE:
    if(items > 1){
      until = ST(1); }
    RETVAL = gullet_readXTokens(aTHX_ gullet, state_global(aTHX), until);
  OUTPUT:
    RETVAL

SV *
readNonSpace(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readNonSpace(aTHX_ gullet, state);
  OUTPUT:
    RETVAL

void
skipSpaces(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_skipSpaces(aTHX_ gullet, state);

void
skip1Space(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_skip1Space(aTHX_ gullet, state);

LaTeXML_Core_Tokens
readBalanced(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  CODE:
    RETVAL = gullet_readBalanced(aTHX_ gullet, state, tokens);
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readArg(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readArg(aTHX_ gullet, state);
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readUntilBrace(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readUntilBrace(aTHX_ gullet, state);
  OUTPUT:
    RETVAL

SV *
readCSName(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    SV * token;
  CODE:
    token = gullet_readCSName(aTHX_ gullet, state);
    RETVAL = (token == NULL ? &PL_sv_undef : token);
  OUTPUT:
    RETVAL

SV *
readMatch(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  CODE:
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    DEBUG_Gullet("readMatch: start\n");
    for(choice = 0; choice < nchoices; choice++){
      SV * thing = ST(1+choice);
      if (sv_isa(thing, "LaTeXML::Core::Token")) {
        type[choice] = 1;
        choices[choice] = SvRV(thing);
        DEBUG_Gullet("readMatch: choice %d = %s[%s]\n", choice,
         CC_SHORT_NAME[ (SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);
        if(maxlength < 1){
          maxlength = 1; } }
      else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
        LaTeXML_Core_Tokens tokens = SvTokens(SvRV(thing));
        if(tokens->ntokens == 1){
          type[choice] = 1;
          choices[choice] = tokens->tokens[0];
          DEBUG_Gullet("readMatch: choice %d = %s[%s]\n", choice,
            CC_SHORT_NAME[(SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);}
        else {
          type[choice] = 2;
          choices[choice] = SvRV(thing);
          DEBUG_Gullet("readMatch: choice %d = %s[%s] ... (%d) \n",choice,
            CC_SHORT_NAME[(SvToken(tokens->tokens[0]))->catcode],
            (SvToken(tokens->tokens[0]))->string, tokens->ntokens); }
        if(maxlength < tokens->ntokens){
          maxlength = tokens->ntokens; } }
      else {
        croak("readMatch: Expected a Token or Tokens, got %s", SvPV_nolen(thing)); } }

    /* Common case! */
    if((nchoices == 1) && (maxlength == 1)) {  
       /* match = gullet_readMatch1(aTHX_ gullet, state, choices[0]); }*/
      SV * token;
      match = -1;
      if( (token = gullet_readToken(aTHX_ gullet, state)) ){
        if(token_equals(aTHX_ SvRV(token), choices[0])){
          match = 0; }
        else {
          LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
          mouth_unreadToken(aTHX_ mouth, token); } } }
    else {  
      match = gullet_readMatch(aTHX_ gullet, state, nchoices,maxlength, type, choices);
    }
   if(match >= 0){
     DEBUG_Gullet("readMatch: Succeeded choice %d\n",match);
     RETVAL = ST(1+match);
     SvREFCNT_inc(RETVAL); }
   else {
     DEBUG_Gullet("readMatch: Failed\n");
     RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
readUntil(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  PPCODE:
    DEBUG_Gullet("readUntil: start\n");
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    for(choice = 0; choice < nchoices; choice++){
      SV * thing = ST(1+choice);
      if (sv_isa(thing, "LaTeXML::Core::Token")) {
        type[choice] = 1;
        choices[choice] = SvRV(thing);
        DEBUG_Gullet("readUntil: choice %d = %s[%s]\n",choice,
          CC_SHORT_NAME[(SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);
        if(maxlength < 1){
          maxlength = 1; } }
      else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
        LaTeXML_Core_Tokens tokens = SvTokens(SvRV(thing));
        if(tokens->ntokens == 1){
          type[choice] = 1;
          choices[choice] = tokens->tokens[0];
          DEBUG_Gullet("readUntil: choice %d = %s[%s]\n",choice,
            CC_SHORT_NAME[(SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);}
        else {
          type[choice] = 2;
          choices[choice] = SvRV(thing);
          DEBUG_Gullet("readUntil: choice %d = %s[%s] ... (%d) \n",choice,
            CC_SHORT_NAME[(SvToken(tokens->tokens[0]))->catcode],
            (SvToken(tokens->tokens[0]))->string, tokens->ntokens); }
        if(maxlength < tokens->ntokens){
          maxlength = tokens->ntokens; } }
      else {
        croak("readMatch: Expected a Token or Tokens, got %s", SvPV_nolen(thing)); } }

      /* Common case! */
      /* if((nchoices == 1) && (maxlength == 1)) {  */
      int balanced1=0;          /* 0: unknown; +1: yes; -1: no */
      while( (match = gullet_readMatch(aTHX_ gullet, state,
                                       nchoices,maxlength, type, choices)) < 0) {
        SV * token = gullet_readToken(aTHX_ gullet, state);
        if(token == NULL){
          break; }
        LaTeXML_Core_Token t = SvToken(SvRV(token));
        tokens_add_to(aTHX_ tokens, token, 0);
        DEBUG_Gullet("readUntil: collect %s[%s] (%p)\n",CC_SHORT_NAME[t->catcode],t->string,t);
        int cc = t->catcode;
        if(cc == CC_BEGIN){
          if(balanced1 == 0){
            balanced1 = +1; }
          else {
            balanced1 = -1; }
          DEBUG_Gullet("readUntil: readBalanced\n");
          gullet_readBalanced(aTHX_ gullet, state, tokens);
          tokens_add_to(aTHX_ tokens, token_new(aTHX_ "}", CC_END),0); }
        else if ((cc != CC_SPACE) || (balanced1 != +1)) {
          balanced1 = -1; } }
       /* NOTE that we should(?) be stripping outer { } if a single balanced group */
         /* match = gullet_readMatch1(aTHX_ gullet, state, choices[0]); }*/
    if(balanced1 == 1){
      tokens_trimBraces(aTHX_ tokens); }
    if(match < 0){                  /* Never found a match? */
      DEBUG_Gullet("readUntil: Fell off end!\n"); }
    else {
      DEBUG_Gullet("readUntil: Succeeded at choice %d!\n",match); }
    U8 gimme = GIMME_V;
    if(gimme == G_VOID){}
    else if (gimme == G_SCALAR){
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv); }
    else {
      EXTEND(SP, 2);
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv);
      if(match < 0){
        PUSHs(&PL_sv_undef); }
      else {
        sv = ST(1+match);
        SvREFCNT_inc(sv);
        PUSHs(sv); } }

SV *
readKeyword(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    STRLEN length[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    char * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  CODE:
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    DEBUG_Gullet("readKeyword: start\n");
    for(choice = 0; choice < nchoices; choice++){
      SV * key = ST(1+choice);
      if(!SvUTF8(key)){
        key = sv_mortalcopy(key);
        sv_utf8_upgrade(key); }
      choices[choice] = SvPV(key, length[choice]);
      DEBUG_Gullet("readKeyword: choice %d = %s\n",choice,choices[choice]);
      if(maxlength < length[choice]){
          maxlength = length[choice]; } }

    /* Common case! */
    match = gullet_readKeyword(aTHX_ gullet, state, nchoices, maxlength, length, choices);

   if(match >= 0){
     DEBUG_Gullet("readKeyword: Succeeded choice %d\n",match);
     RETVAL = ST(1+match);
     SvREFCNT_inc(RETVAL); }
   else {
     DEBUG_Gullet("readKeyword: Failed\n");
     RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL
    

void
readNextConditional(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    SV * token;
    SV * type;
  PPCODE:
    while( (token = mouth_readToken(aTHX_ mouth, state)) ){
      if ( (type = state_conditional(aTHX_ state, token)) ) {
        break; } }
  if(type){
    EXTEND(SP,2);
    PUSHs(sv_2mortal(newRV_inc(token)));
    PUSHs(sv_2mortal(type)); }
    
