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

/*======================================================================
 Towards consistent, predictable API's for both C & Perl,
 in consideration of the fact that there will be a lot of storing/fetching
 pointers to objects in both C structures and Perl Hashes & Arrays,
 as well as creating new objects when required.

 * C-API should return NULL for failures, non-things, etc
 * Perl-API should watch for NULL's and return &PL_sv_undef
   (otherwise mysterious memory errors)

 * C-API functions should give the rights to the caller any object(s) returned,
   typically through SvREFCNT_inc (or equivalent).
   The caller either returns the object to it's caller, or uses SvREFCNT_dec
   (or equivalent) when done with the object.
   Exception: functions named with _noinc suffix; use when you know you'll be done
   with the object before anyone will dec its refcnt or Perl will get a chance to do any cleanup.
   Functions are NOT responsible for managing the REFCNT of arguments!
 
   [ALWAYS? Or is there a naming convention for exceptions?
   eg. the gullet_getMouth, various state methods etc where you are
   seldom likely to return the object to Perl ???]

 * Functions that store an object should assure that REFCNT is incremented.

 * Perl-API functions should always set mortal (eg. sv_2mortal),
   but note that RETVAL will automatically have sv_2mortal applied!

 * BE CAREFUL about putting things like POPs inside something like SvTRUE
   Some of the latter are macros that duplicate it's arguments!!!!!!

NOTE: Neither hv_store/hv_fetch (& av) change the reference count on the stored
   SV *, and fetch returns the same SV that was stored.

Question: Should some of the C API avoid passing pTHX as argument ?
It's not always actually needed or passed through.
But, if we omit it, we need to be predictable.

Major ToDo:
(1) separate into modules
(2) reimplement tracing
(3) develop error & logging API
 ======================================================================*/

#define DEBUG_STATENOT
#ifdef DEBUG_STATE
#  define DEBUG_State(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_State 1
#else
#  define DEBUG_State(...)
#  define DEBUGGING_State 0
#endif

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

#define DEBUG_BOXSTACKNOT
#ifdef DEBUG_BOXSTACK
#  define DEBUG_Boxstack(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Boxstack 1
#else
#  define DEBUG_Boxstack(...)
#  define DEBUGGING_Boxstack 0
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

#define DEBUG_EXPANDABLENOT
#ifdef DEBUG_EXPANDABLE
#  define DEBUG_Expandable(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Expandable 1
#else
#  define DEBUG_Expandable(...)
#  define DEBUGGING_Expandable 0
#endif

#define DEBUG_STOMACHNOT
#ifdef DEBUG_STOMACH
#  define DEBUG_Stomach(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Stomach 1
#else
#  define DEBUG_Stomach(...)
#  define DEBUGGING_Stomach 0
#endif

#define DEBUG_PRIMITIVENOT
#ifdef DEBUG_PRIMITIVE
#  define DEBUG_Primitive(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Primitive 1
#else
#  define DEBUG_Primitive(...)
#  define DEBUGGING_Primitive 0
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

typedef struct Boxstack_struct {
  int nboxes;
  int nalloc;
  int discard;
  PTR_SV * boxes;
} T_Boxstack;
typedef T_Boxstack * LaTeXML_Core_Boxstack;

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


#define SvHash(arg)       MUTABLE_HV(SvRV(arg))
#define SvArray(arg)      MUTABLE_AV(SvRV(arg))
#define SvToken(arg)      INT2PTR(LaTeXML_Core_Token,      SvIV((SV*) SvRV(arg)))
#define SvTokens(arg)     INT2PTR(LaTeXML_Core_Tokens,     SvIV((SV*) SvRV(arg)))
#define SvTokenstack(arg) INT2PTR(LaTeXML_Core_Tokenstack, SvIV((SV*) SvRV(arg)))
#define SvMouth(arg)      INT2PTR(LaTeXML_Core_Mouth,      SvIV((SV*) SvRV(arg)))

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

#define SCALED_POINT 65536
#define POINTS_PER_INCH 72.27
UTF8 UNIT_NAME[] =
  {"em","ex",
   "pt","pc",
   "in","bp",
   "cm","mm",
   "dd","cc","sp",
   "truept","truepc",
   "truein","truebp",
   "truecm", "truemm",
   "truedd","truecc","truesp",
   "mu"};
#define MAX_TEXT_UNITS 20
#define MAX_UNITS 21

double UNIT_VALUE[] =           /* in scaled points. */
  {655361., 282168., /* Apparent defaults; SHOULD reference current font! */
   1.*SCALED_POINT, 12.*SCALED_POINT,
   POINTS_PER_INCH*SCALED_POINT, POINTS_PER_INCH*SCALED_POINT/72.,
   POINTS_PER_INCH*SCALED_POINT/2.54, POINTS_PER_INCH*SCALED_POINT/2.54/10.,
   1238.*SCALED_POINT/1157., 12.*1238.*SCALED_POINT/1157., 1.,
   1.*SCALED_POINT, 12.*SCALED_POINT,
   POINTS_PER_INCH*SCALED_POINT, POINTS_PER_INCH*SCALED_POINT/72.,
   POINTS_PER_INCH*SCALED_POINT/2.54, POINTS_PER_INCH*SCALED_POINT/2.54/10.,
   1238.*SCALED_POINT/1157., 12.*1238.*SCALED_POINT/1157., 1.,
   1.*SCALED_POINT};            /* NOTE! Converts to Scaled Mu!! NOT Scaled Points */

  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    C-level code 
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

  /*======================================================================
    Shorthands for generalized hash objects */
/* Performance penalty for all this cruft when the hash is used several times??? */
SV *
object_get_noinc(pTHX_ SV * object, UTF8 key){ /* No refcnt inc! */
  HV * hash = SvHash(object);
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return *ptr; }
  else {
    return NULL; } }

SV *
object_get(pTHX_ SV * object, UTF8 key){
  HV * hash = SvHash(object);
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    SvREFCNT_inc(*ptr);
    return *ptr; }
  else {
    return NULL; } }

UTF8
object_getPV(pTHX_ SV * object, UTF8 key){
  HV * hash = SvHash(object);
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvPV_nolen(*ptr); }
  else {
    return NULL; } }

int
object_getIV(pTHX_ SV * object, UTF8 key){
  HV * hash = SvHash(object);
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvIV(*ptr); }
  else {
    return 0; } }


AV *
object_getAV(pTHX_ SV * object, UTF8 key){
  HV * hash = SvHash(object);
  SV ** ptr;
  if(! ((ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr))){
    return NULL; }
  else if(! SvROK(*ptr)){
    fprintf(stderr,"Expected a reference (to an array) for %s key %s, got %s",
          sv_reftype(SvRV(object),1), key, sv_reftype(*ptr,1));
    Perl_sv_dump(aTHX_ *ptr);
    return NULL;  }
  else if (SvTYPE(SvRV(*ptr)) != SVt_PVAV){
    fprintf(stderr,"Expected a reference to an array for %s key %s, got %s",
          sv_reftype(SvRV(object),1), key, sv_reftype(SvRV(*ptr),1));
    Perl_sv_dump(aTHX_ *ptr);
    return NULL; }
  else {
    AV * av = SvArray(*ptr);
    SvREFCNT_inc(av);
    return av; } }

int
object_getBoole(pTHX_ SV * object, UTF8 key){
  HV * hash = SvHash(object);
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvTRUE(*ptr); }
  else {
    return 0; } }

void
object_put_noinc(pTHX_ SV * object, UTF8 key, SV * value){
  HV * hash = SvHash(object);
  hv_store(hash,key,-strlen(key),value, 0); }

void
object_put(pTHX_ SV * object, UTF8 key, SV * value){
  HV * hash = SvHash(object);
  SvREFCNT_inc(value);
  hv_store(hash,key,-strlen(key),value, 0); }

int
array_getIV(pTHX_ SV * array, int i){
  AV * av = SvArray(array);
  SV ** ptr;
  if( (ptr = av_fetch(av,i,0)) && *ptr && SvOK(*ptr)){
    return SvIV(*ptr); }
  else {
    return 0; } }

  /*======================================================================
    Some string utilities */
UTF8
string_copy(UTF8 string){
  int n = strlen(string);
  UTF8 newstring;
  Newx(newstring,(n + 1),char);
  CopyChar(string,newstring,n);
  return newstring; }

void
showstr(UTF8 op, UTF8 name, UTF8 string){
  fprintf(stderr,"%s %s: '%s'= ",op, name,string);
  int i=0;
  while(*(string+i)){
    fprintf(stderr,"%hhx",*(string+i)); i++; }
  fprintf(stderr,"\n"); }

  /*======================================================================
    C-level Token support */
SV *
token_new(pTHX_ UTF8 string, int catcode){ /* NOTE: string is copied! */
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
    C-Level Numbers, Dimensions ... support
    Strictly speaking, Number should contain int (SViv); others contain SVnv (double) */

SV *
number_new(pTHX_ int num){
  AV * av = newAV();
  av_push(av, newSViv(num));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Number",0));
  return ref; }

int
number_value(pTHX_ SV * sv){     /* num presumbed to be SViv */
  AV * av = SvArray(sv);
  SV ** ptr;
  if( (ptr = av_fetch(av,0,0)) && SvOK(*ptr)){
    if(SvIOK(*ptr)){
      return SvIV(*ptr); }
    else if (SvNOK(*ptr)){
      return SvNV(*ptr); }
    else {
      croak("Expected an integer"); } }
  return 0; }

int
number_formatScaled(pTHX_ char * buffer, int sp){   /* Knuth's: TeX the Program, algorithm 103 */
  /* buffer should be (at least)  char buffer = [3*sizeof(int)*CHAR_BIT/8 + 2]; */
  int delta = 10;
  int ptr = 0;
  if(sp < 0){
    buffer[ptr++] = '-'; sp = -sp; }
  ptr += sprintf(buffer+ptr,"%d", sp >> 16);
  buffer[ptr++] = '.';
  sp = 10*(sp & 0xFFFF) + 5;
  do {
    if(delta > 0x10000){
      sp = sp + 0100000 - 50000; }  /* round the last digit */
    buffer[ptr++] = '0' + (sp / 0x10000);
    sp = 10 * (sp & 0xFFFF); delta = delta * 10; }
  while( sp > delta );
  buffer[ptr] = 0;
  return ptr; }

SV *
dimension_new(pTHX_ int sp){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Dimension",0));
  return ref; }

SV *
glue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  av_push(av, newSViv(plus));
  av_push(av, newSViv(plusfill));
  av_push(av, newSViv(minus));
  av_push(av, newSViv(minusfill));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Glue",0));
  return ref; }

SV *
glue_negate(pTHX_ SV * glue){
  AV * av = newAV();
  int sp = array_getIV(aTHX_ glue, 0);
  int pv = array_getIV(aTHX_ glue, 1);
  int pf = array_getIV(aTHX_ glue, 2);
  int mv = array_getIV(aTHX_ glue, 3);
  int mf = array_getIV(aTHX_ glue, 4);
  av_push(av, newSViv(-sp));
  av_push(av, newSViv(-pv));
  av_push(av, newSViv(pf));
  av_push(av, newSViv(-mv));
  av_push(av, newSViv(mf));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Glue",0));
  return ref; }

SV *
muglue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  av_push(av, newSViv(plus));
  av_push(av, newSViv(plusfill));
  av_push(av, newSViv(minus));
  av_push(av, newSViv(minusfill));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Core::MuGlue",0));
  return ref; }

SV *
muglue_negate(pTHX_ SV * muglue){
  AV * av = newAV();
  int sp = array_getIV(aTHX_ muglue, 0);
  int pv = array_getIV(aTHX_ muglue, 1);
  int pf = array_getIV(aTHX_ muglue, 2);
  int mv = array_getIV(aTHX_ muglue, 3);
  int mf = array_getIV(aTHX_ muglue, 4);
  av_push(av, newSViv(-sp));
  av_push(av, newSViv(-pv));
  av_push(av, newSViv(pf));
  av_push(av, newSViv(-mv));
  av_push(av, newSViv(mf));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Core::MuGlue",0));
  return ref; }

SV *
float_new(pTHX_ double num){     /* num presumbed to be SViv/SVnv scaled points */
  AV * av = newAV();
  av_push(av, newSVnv(num));
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Float",0));
  return ref; }

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

UTF8                            /* NOTE: This returns a newly allocated string! */
tokens_toString(pTHX_ LaTeXML_Core_Tokens tokens){
  int i;
  int length = 0;
  int lengths[tokens->ntokens]; /* Risky if many? */
  char * string;
  for(i = 0; i < tokens->ntokens; i++){
    LaTeXML_Core_Token t = SvToken(tokens->tokens[i]);
    lengths[i] =  strlen(t->string); /* cache strlen's */
    length += lengths[i]; }
  /*length += strlen(t->string);}*/
  Newx(string,length+1,char);
  int pos = 0;
  for(i = 0; i < tokens->ntokens; i++){
    LaTeXML_Core_Token t = SvToken(tokens->tokens[i]);
    /*int l = strlen(t->string);*/
    int l = lengths[i];
    strncpy(string+pos, t->string, l);
    pos += l; }
  string[length]=0;
  return string; }

int
tokens_equals(pTHX_ LaTeXML_Core_Tokens a,LaTeXML_Core_Tokens b){
  if(a->ntokens != b->ntokens){
    return 0; }
  else {
    int i;
    for(i = 0; i < a->ntokens; i++){
      if(! token_equals(aTHX_ a->tokens[i],b->tokens[i])){
        return 0; } }
    return 1; } }

void
tokens_shrink(pTHX_ LaTeXML_Core_Tokens tokens){
  if(tokens->nalloc > tokens->ntokens){
    Renew(tokens->tokens,tokens->nalloc = tokens->ntokens, PTR_SV); } }

void                            /* adds in-place */
tokens_add_to(pTHX_ LaTeXML_Core_Tokens tokens, SV * thing, int revert) {
  /* Tempting to define a _noinc variant ?? */
  DEBUG_Tokens("\nAdding to tokens:");
  if (sv_isa(thing, "LaTeXML::Core::Token")) {
    DEBUG_Tokens( "Token.");
    if(tokens->ntokens >= tokens->nalloc){
      tokens->nalloc += TOKENS_ALLOC_QUANTUM;
      Renew(tokens->tokens, tokens->nalloc, PTR_SV); }
    /* NOTE: Beware Tokens coming from Perl: use newSVsv (else the SV can change behind your back */
    SvREFCNT_inc(thing);
    tokens->tokens[tokens->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens toks = SvTokens(thing);
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
    croak("Tokens add_to: Expected a Token, got a %s: %s",
          (SvROK(thing) ? sv_reftype(SvRV(thing),1) : sv_reftype(thing,1)),
            SvPV_nolen(thing)); }
  DEBUG_Tokens( "Done adding.");
}

void                            /* Modifies in-place */
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

void                            /* Remove trailing spaces, in-place */
tokens_trimright(pTHX_ LaTeXML_Core_Tokens tokens){
  LaTeXML_Core_Token t;
  while((tokens->ntokens > 1) && (t=SvToken(tokens->tokens[tokens->ntokens-1]))
        && (t->catcode == CC_SPACE)){
    SvREFCNT_dec(tokens->tokens[tokens->ntokens-1]);
    tokens->ntokens--; }
}

LaTeXML_Core_Tokens             /* trim's left/right space, then braces; creates NEW tokens */
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

LaTeXML_Core_Tokens
tokens_substituteParameters(pTHX_ LaTeXML_Core_Tokens tokens, int nargs, SV **args){
  int i;
  LaTeXML_Core_Tokens result = tokens_new(aTHX_ tokens->ntokens);
  DEBUG_Tokens("\nsubstituting:");
  for (i = 0 ; i < tokens->ntokens ; i++) {
    LaTeXML_Core_Token t = SvToken(tokens->tokens[i]);
    int cc = t->catcode;
    if(cc != CC_PARAM){ /* non #, so copy it*/
      DEBUG_Tokens("copy %s;",t->string);
      SvREFCNT_inc(tokens->tokens[i]);
      result->tokens[result->ntokens++] = tokens->tokens[i]; }
    else if(i >= tokens->ntokens) { /* # at end of tokens? */
      croak("substituteParamters: fell off end of pattern"); }
    else {
      /*t = SvToken(tokens->tokens[++i]);*/
      i++;
      t = SvToken(tokens->tokens[i]);
      DEBUG_Tokens("#%s ",t->string);
      cc = t->catcode;
      if(cc == CC_PARAM){ /* next char is #, just duplicate it */
        DEBUG_Tokens("copy#;");
        SvREFCNT_inc(tokens->tokens[i]);
        result->tokens[result->ntokens++] = tokens->tokens[i]; }
      else {                  /* otherwise, insert the appropriate arg. */
        int argn = (int) t->string[0] - (int) '0';
        DEBUG_Tokens("arg%d;",argn);
        if((argn < 1) || (argn > 9)){
          croak("substituteTokens: Illegal argument number %d",argn); }
        else if ((argn <= nargs) && args[argn-1]) {      /* ignore undef */
          tokens_add_to(aTHX_ result, args[argn-1], 1); } }
    } }
  DEBUG_Tokens("done\n");
return result; }

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
    SvREFCNT_inc(thing);
    if(stack->ntokens >= stack->nalloc){
      stack->nalloc += TOKENSTACK_ALLOC_QUANTUM;
      Renew(stack->tokens, stack->nalloc, PTR_SV); }
    /* NOTE: Beware Tokens coming from Perl: use newSVsv (else the SV can change behind your back */
    SvREFCNT_inc(thing);
    stack->tokens[stack->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens tokens = SvTokens(thing);
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
    return stack->tokens[--stack->ntokens]; }
  else {
    return NULL; } }


  /*======================================================================
    C-level State support */

SV *
state_global(pTHX){             /* WARNING: Can we pretend we don't need refcnt's here? */
  return get_sv("STATE",0); }

SV *                            /* WARNING: No refcnt increment here!!! */
state_lookup_noinc(pTHX_ SV * state, UTF8 table, UTF8 string){
  HV * hash;
  AV * array;
  SV ** ptr;
  SV * sv;
  if(! string){
    return NULL; }
  hash = SvHash(state);
  ptr  = hv_fetch(hash,table,strlen(table),0); /* $$state{$table} */
  if(! ptr){
    croak("State doesn't have a %s table!",table); }
  hash = SvHash(*ptr);
  ptr  = hv_fetch(hash,string,-strlen(string),0); /* $$state{$table}{$key}; neg. length=>UTF8*/
  if( ! ptr){
    return NULL; }
  array = SvArray(*ptr);
  ptr  = av_fetch(array,0,0);/* $$state{catcode}{$key}[0] */
  if ( ! ptr){
    return NULL; }
  sv = *ptr;
  sv = (SvOK(sv) ? sv : NULL);
  return sv; }

SV *
state_lookup(pTHX_ SV * state, UTF8 table, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, table, string);
  return (sv ? SvREFCNT_inc(sv) : NULL); }

void
state_assign_internal(pTHX_ SV * state, UTF8 table, UTF8 key, SV * value, UTF8 scope){
  HV * self_hash;
  HV * table_hash;
  AV * key_entries;
  AV * undo_stack;
  SV ** ptr;
  U32 tablelen = strlen(table);
  /* NOTE: Use NEGATIVE Length in hv_(store|fetch|..) for UTF8 keys!!!!!!!! */
  U32 keylen = strlen(key);
  /* if exists tracing....*/
  self_hash = SvHash(state);
  if(scope == NULL){
    scope = "local";
    if( (ptr = hv_fetch(self_hash,"prefixes",8,0)) ){
      HV * prefixes = SvHash(*ptr);
      if( (ptr = hv_fetch(prefixes,"global",6,0)) && SvTRUE(*ptr) ){
        scope = "global"; } } }

  SvREFCNT_inc(value);          /* Eventually we'll store it... */
  DEBUG_State("START Assign internal in table %s, %s => %p; scope=%s\n",table, key, value, scope);

  if(! (ptr = hv_fetch(self_hash,table,tablelen,0)) ){
    croak("State doesn't have a %s table!",table); }
  /* Get the hash for the requested table */
  table_hash = SvHash(*ptr); /* $$state{$table} */
  /* Get --- or create --- the list of bound values for key in this table */
  if( ( ptr = hv_fetch(table_hash,key,-keylen,0) )){
    key_entries = SvArray(*ptr); } /* $$state{$table} */
  else {
    DEBUG_State("Assign internal: new stack for %s in table %s\n",key, table);
    key_entries = newAV();
    hv_store(table_hash, key, -keylen, newRV_noinc((SV *) key_entries), 0); }
  /* Get the undo stack */
  if(! (ptr = hv_fetch(self_hash,"undo",4,0) )){
    croak("State doesn't have an undo stack!"); }
  undo_stack = SvArray(*ptr); /* $$state{undo}  */

  if(strcmp(scope,"global") == 0){
    SSize_t nframes = av_len(undo_stack) + 1;
    int iframe;
    HV * frame = NULL;
    DEBUG_State("Assign internal global: checking %lu frames\n",nframes);
    for(iframe = 0; iframe < nframes; iframe++){
      if(! (ptr = av_fetch(undo_stack, iframe,0) )){
        croak("State's undo stack doesn't have a valid frame %d!", iframe); }
      frame = SvHash(*ptr); /* $$state{undo}[$iframe]{$table} */
      DEBUG_State("Assign internal global: examining frame %d = %p\n",iframe, frame);
      /* Remove bindings made in all frames down-to & including the next lower locked frame*/
      if( ( ptr = hv_fetch(frame,table,tablelen,0) ) ){
        HV * table_frame = SvHash(*ptr);
        DEBUG_State("Assign internal global: found frame table %p\n",table_frame);
        if( ( ptr = hv_fetch(table_frame,key,-keylen,0)) ){
          int nbindings = SvIV(*ptr); /* $n = $$frame{$table}{$key} */
          DEBUG_State("Assign internal global:  %d bindings in frame\n",nbindings);
          if(nbindings > 0){ /* Undo the bindings, if $key was bound in this frame */
            DEBUG_State("Assign internal global: clearing %d bindings\n",nbindings);
            int nb;
            for(nb = 0; nb < nbindings; nb++){
              /* SV * ignore = av_shift(key_entries); PERL_UNUSED_VAR(ignore);  */
              SvREFCNT_dec(av_shift(key_entries)); 
            }
            hv_delete(table_frame,key,-keylen,G_DISCARD); } /* delete $$frame{$table}{$key}; */
          else {
            DEBUG_State("Assign internal global: no bindings\n"); } }
        else {
          DEBUG_State("Assign internal global: no entry for key %s found in table frame\n",key); } }
      else {
        DEBUG_State("Assign internal global: no entry for table %s found in frame\n",table); }
      if((ptr = hv_fetch(frame,"_FRAME_LOCK_",12,0)) && SvTRUE(*ptr)){
        /* whatever is left -- if anything -- should be bindings below the locked frame. */
        DEBUG_State("Assign internal global: locked frame at %d\n",iframe);
        break; } }            /* last if $$frame{_FRAME_LOCK_}; } */
    /* Note that there will only be one value in the stack, now */
    HV * table_frame;
    if( ( ptr = hv_fetch(frame,table,tablelen,0)) ){
      table_frame = SvHash(*ptr); }
    else {
      table_frame = newHV();
      hv_store(frame,table,tablelen, newRV_noinc( (SV *) table_frame), 0); }
    hv_store(table_frame, key, -keylen, newSViv(1), 0); /* $$frame{$table}{$key} = 1 */
    av_unshift(key_entries,1);
    av_store(key_entries,0,value); } /* unshift(@{ $$self{$table}{$key} }, $value); */

  else if (strcmp(scope, "local") == 0){
    HV * frame;                 /* top undo frame */
    HV * table_frame;           /* $$state{undo}[0]{$table} */
    DEBUG_State("Assign internal local\n");
    if(! (ptr = av_fetch(undo_stack, 0 ,0) )){
      croak("State's undo stack doesn't have a valid frame for 0!"); }
    frame = SvHash(*ptr);  /* $$state{undo}[0] */
    if( ( ptr = hv_fetch(frame,table,tablelen,0)) ){
      table_frame = SvHash(*ptr); }
    else {
      table_frame = newHV();
      hv_store(frame,table,tablelen, newRV_noinc((SV *) table_frame),0); }
    
    if( ( ptr = hv_fetch(table_frame,key,-keylen,0) )){ /* If value previously assigned in this frame */
      /* Simply replace the value  */
      DEBUG_State("Assign internal local: replacing value\n");
      av_store(key_entries,0,value); }
    else {        /* Otherwise, push new value & set 1 to be undone */
      DEBUG_State("Assign internal local: pushing new value\n");
      hv_store(table_frame,key,-keylen, newSViv(1), 0); /* $$self{undo}[0]{$table}{$key} = 1; */
      av_unshift(key_entries,1);
      av_store(key_entries,0,value); } } /* unshift(@{ $$self{$table}{$key} }, $value); */
  else {
    /* croak("Storing under random scopes (%s) NOT YET IMPLEMENTED!",scope);*/
    AV * stash;
    if(! (stash = (AV *) state_lookup_noinc(aTHX_ state, "stash", scope)) ){
      stash = newAV();
      state_assign_internal(aTHX_ state, "stash", scope, newRV_noinc((SV *) stash), "global"); }
    AV * entry = newAV();
    av_extend(entry,3);
    av_store(entry,0,newSVpv(table,tablelen));
    av_store(entry,1,newSVpv(key,keylen));
    av_store(entry,2,value);
    av_unshift(stash,1);
    av_store(stash,0,(SV *) entry); /* push(@{ $$self{stash}{$scope}[0] }, [$table, $key, $value]); */
    if(state_lookup_noinc(aTHX_ state, "stash_active", scope)){
      state_assign_internal(aTHX_ state, table, key, value, "local"); } }
  DEBUG_State("DONE Assign internal in table %s, %s => %p; scope=%s\n",table, key, value, scope);
}

void
state_pushFrame(pTHX_ SV * state){
  AV * undo_stack = object_getAV(aTHX_ state, "undo");
  HV * frame = newHV();
  av_unshift(undo_stack, 1);
  av_store(undo_stack, 0, newRV_noinc((SV *)frame));
  SvREFCNT_dec(undo_stack); }

void
state_popFrame(pTHX_ SV * state){
  SV * sv;
  AV * undo_stack = object_getAV(aTHX_ state, "undo");
  /* remove the first undo frame */
  SV * undo_frame_sv = av_shift(undo_stack);
  HV * undo_frame = SvHash(undo_frame_sv);
  if(object_getBoole(aTHX_ undo_frame_sv, "_FRAME_LOCK_")){
    croak("unexpected:<endgroup> Attempt to pop past locked stack frame"); }
  hv_iterinit(undo_frame);
  I32 tablenamelen;
  UTF8 tablename;
  /* for each table(value,meaning,...) */
  while( (sv = hv_iternextsv(undo_frame, &tablename,&tablenamelen)) ){
    HV * undo_table = SvHash(sv);
    SV * table = object_get(aTHX_ state, tablename);
    HV * tablehv = SvHash(table);
    hv_iterinit(undo_table);
    /*I32 keylen;*/
    STRLEN keylen;
    UTF8 key;
    /*while( (sv = hv_iternextsv(undo_table, &key,&keylen)) ){*/
    HE * entry;
    while( (entry = hv_iternext(undo_table)) ){
      /*key = hv_iterkey(entry, &keylen);*/
      key = HePV(entry, keylen);
      sv = hv_iterval(undo_table, entry);
      /*int utf = HeUTF8(entry);
        fprintf(stderr,"Key %s %s utf8\n",key, (utf ? "IS":"IS NOT"));*/
      
      int n_undo = SvIV(sv);
      /*SV * undo_sv = object_get(aTHX_ table, key);*/
      /* Some messup with unicode ??? */
      SV ** ptr;
      if( ! ((ptr = hv_fetch(tablehv,key,-keylen,0)) && SvOK(*ptr)) ){
        /* NOTE: Mysteriously perl is retrieving the keys from the undo table
           in a different encoding than we need to look them up in the regular table.
           we need to get them back into utf8!?!?!? */
        /*fprintf(stderr,"RECHECK table entry %s{%s}\n",tablename,key);*/
        STRLEN altkeylen = keylen;
        UTF8 altkey = (UTF8) bytes_to_utf8((U8 *)key,&altkeylen);
        ptr  = hv_fetch(tablehv,altkey,-altkeylen,0); }
        /*if( (ptr = hv_fetch(tablehv,key,keylen,0) || hv_fetch(tablehv,key,-keylen,0))
          && SvOK(*ptr) ){*/
      if(ptr && SvOK(*ptr)){
        AV * undo = SvArray(*ptr);
        int i;
        for(i = 0; i < n_undo; i++){
          SV * ignore = av_shift(undo); PERL_UNUSED_VAR(ignore); } }
      else {
        fprintf(stderr,"Missing table entry %s{%s}\n",tablename,key); } }
    SvREFCNT_dec(table); }
  SvREFCNT_dec(undo_stack); }

int
state_catcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "catcode", string);
  return (sv ? SvIV(sv) : CC_OTHER); }

int
state_mathcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "mathcode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_SFcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "sfcode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_LCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "lccode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_UCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "uccode", string);
  return (sv ? SvIV(sv) : 0); }

int
state_Delcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "delcode", string);
  return (sv ? SvIV(sv) : 0); }

SV *
state_value(pTHX_ SV * state, UTF8 string){
  return state_lookup(aTHX_ state, "value", string); }

int
state_intval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);
  return (sv ? SvIV(sv) : 0); }
int
state_booleval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);
  return (sv ? SvTRUE(sv) : 0); }

void
state_beginSemiverbatim(pTHX_ SV * state, int nchars, char ** chars){
  state_pushFrame(aTHX_ state);
  state_assign_internal(aTHX_ state, "value","MODE", newSVpv("text",4), "local");
  state_assign_internal(aTHX_ state, "value","IN_MATH", newSViv(0), "local");
  SV * sv;
  int i;
  if( (sv = state_lookup_noinc(aTHX_ state, "value","SPECIALS")) ){
    AV * specials = SvArray(sv);
    int n = av_len(specials)+1;
    for(i = 0; i < n; i++){
      SV ** ptr;
      if( (ptr = av_fetch(specials,i,0)) ){
        state_assign_internal(aTHX_ state, "catcode", SvPV_nolen(*ptr), newSViv(CC_OTHER),"local"); } } }
  for(i = 0; i < nchars; i++){
    state_assign_internal(aTHX_ state, "catcode", chars[i], newSViv(CC_OTHER),"local"); }
  state_assign_internal(aTHX_ state, "mathcode", "'", newSViv(0x8000),"local");
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(state);  PUTBACK;
  call_method("setASCIIencoding",G_DISCARD);
  SPAGAIN; PUTBACK; FREETMPS; LEAVE;
}

void
state_endSemiverbatim(pTHX_ SV * state){
  state_popFrame(aTHX_ state); }

SV *
state_meaning(pTHX_ SV * state, SV * token){
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    if(ACTIVE_OR_CS[t->catcode]){
      return state_lookup(aTHX_ state, "meaning", t->string); }
    SvREFCNT_inc(token);
    return token; }
  return NULL; }
  
int
state_prefix(pTHX_ SV * state, UTF8 key){
  SV * prefixes = object_get_noinc(aTHX_ state, "prefixes");
  return object_getBoole(aTHX_ prefixes,key); }

void
state_clearPrefixes(pTHX_ SV * state){
  SV * prefixes = object_get_noinc(aTHX_ state, "prefixes");
  hv_clear(SvHash(prefixes)); }

SV *
state_definition(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, "meaning", name))
     && !sv_isa(defn, "LaTeXML::Core::Token")){ /* not a simple token! */
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

SV *
state_expandable(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, "meaning", name))
     && SvROK(defn) && sv_derived_from(defn, "LaTeXML::Core::Definition")
     && object_getBoole(aTHX_ defn,"isExpandable")
     && ! object_getBoole(aTHX_ defn,"isProtected")){
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


/* SV * expandable_op(aTHX_ token, expandable_defn, gullet, state, nargs, args)*/
/* And, perhaps eventually, Tokens to accumulate results? */
typedef SV * expandable_op(pTHX_ SV *, SV *, SV *, SV *, int, SV **);
/* void primitive_op(aTHX_ token, primitive_defn, stomach, state, nargs, args, resultstack)*/
typedef void primitive_op(pTHX_ SV *, SV *, SV *, SV *, int, SV **, LaTeXML_Core_Boxstack);
/* SV * parameter_op(aTHX_ parameter, gullet, state, nargs, args) */
typedef SV * parameter_op(pTHX_ SV *, SV *, SV *, int, SV **);  

void
state_install_expandable_op(pTHX_ SV * state, UTF8 opcode, expandable_op * op){
  HV * hash = SvHash(state);
  SV ** ptr;
  HV * table;
  if( (ptr  = hv_fetch(hash,"expandable_ops",14,0)) && SvOK(*ptr) ){
    table =  SvHash(*ptr); }
  else {
    table = newHV();
    hv_store(hash,"expandable_ops",14,newRV_noinc((SV*)table),0); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(table,opcode,-strlen(opcode),  ref,0);  }

expandable_op *
state_lookup_expandable_op(pTHX_ SV * state, UTF8 opcode){
  SV * expandable_ops = object_get_noinc(aTHX_ state, "expandable_ops");
  if(expandable_ops){
    SV * sv_op = object_get_noinc(aTHX_ expandable_ops, opcode);
    if(sv_op){
      IV tmp = SvIV((SV*)SvRV(sv_op));
      return INT2PTR(expandable_op *, tmp); } }
  return NULL; }

void
state_install_primitive_op(pTHX_ SV * state, UTF8 opcode, primitive_op * op){
  HV * hash = SvHash(state);
  SV ** ptr;
  HV * table;
  if( (ptr  = hv_fetch(hash,"primitive_ops",13,0)) && SvOK(*ptr) ){
    table =  SvHash(*ptr); }
  else {
    table = newHV();
    hv_store(hash,"primitive_ops",13,newRV_noinc((SV*)table),0); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(table,opcode,-strlen(opcode),  ref,0);  }

primitive_op *
state_lookup_primitive_op(pTHX_ SV * state, UTF8 opcode){
  SV * primitive_ops = object_get_noinc(aTHX_ state, "primitive_ops");
  if(primitive_ops){
    SV * sv_op = object_get_noinc(aTHX_ primitive_ops, opcode);
    if(sv_op){
      IV tmp = SvIV((SV*)SvRV(sv_op));
      return INT2PTR(primitive_op *, tmp); } }
  return NULL; }

void
state_install_parameter_op(pTHX_ SV * state, UTF8 opcode, parameter_op * op){
  HV * hash = SvHash(state);
  SV ** ptr;
  HV * table;
  if( (ptr  = hv_fetch(hash,"parameter_ops",13,0)) && SvOK(*ptr) ){
    table =  SvHash(*ptr); }
  else {
    table = newHV();
    hv_store(hash,"parameter_ops",13,newRV_noinc((SV*)table),0); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(table,opcode,-strlen(opcode),  ref,0);  }

parameter_op *
state_lookup_parameter_op(pTHX_ SV * state, UTF8 opcode){
  SV * parameter_ops = object_get_noinc(aTHX_ state, "parameter_ops");
  if(parameter_ops){
    SV * sv_op = object_get_noinc(aTHX_ parameter_ops, opcode);
    if(sv_op){
      IV tmp = SvIV((SV*)SvRV(sv_op));
      return INT2PTR(parameter_op *, tmp); } }
  return NULL; }

void gullet_unreadToken(pTHX_ SV * gullet, SV * token);

void
state_afterAssignment(pTHX_ SV * state){
  SV * after = state_value(aTHX_ state, "afterAssignment");
  if(after){
    state_assign_internal(aTHX_ state, "value", "afterAssignment", NULL,"global");
    SV * gullet = object_get(aTHX_ object_get_noinc(aTHX_ state, "stomach"), "gullet");
    gullet_unreadToken(aTHX_ gullet, after);
    SvREFCNT_dec(gullet);
    SvREFCNT_dec(after); } }

  /*======================================================================
    C-level Boxstack support;
    accumulator for boxes/whatsit's resulting from Primitives & Constructors */

#define BOXSTACK_ALLOC_QUANTUM 10

LaTeXML_Core_Boxstack
boxstack_new(pTHX) {
  LaTeXML_Core_Boxstack stack;
  Newxz(stack,1, T_Boxstack);
  DEBUG_Boxstack("New boxstack %p\n",stack);
  stack->nalloc = BOXSTACK_ALLOC_QUANTUM;
  Newx(stack->boxes, stack->nalloc, PTR_SV);
  return stack; }

void
boxstack_DESTROY(pTHX_ LaTeXML_Core_Boxstack stack){
  int i;
  for (i = 0 ; i < stack->nboxes ; i++) {
    SvREFCNT_dec(stack->boxes[i]); }
  Safefree(stack->boxes);
  Safefree(stack); }

/* Invoke a Stomach->method to produce boxes */
void                            /* Horrible naming!!! */
boxstack_callmethod(pTHX_ LaTeXML_Core_Boxstack stack, UTF8 method,
              SV * state, SV * stomach, SV * token,
              int nargs, SV ** args) {
  DEBUG_Boxstack("Boxstack %p call %s on %d args\n",stack,method,nargs);
  int i;
  DEBUG_Boxstack("Replacement is METHOD %s\n", method);
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,nargs+1); PUSHs(stomach); 
  for(i=0; i<nargs; i++){
    SV * arg = (args[i] ? args[i] : &PL_sv_undef);
    PUSHs(arg); }
  PUTBACK;
  if(stack->discard){
    call_method(method,G_DISCARD);
    DEBUG_Boxstack("code returned, discarding values\n");
    SPAGAIN; }
  else {
    int nvals = call_method(method,G_ARRAY);
    DEBUG_Boxstack("code returned %d values\n", nvals);
    SPAGAIN;
    if(stack->nboxes+nvals >= stack->nalloc){
      stack->nalloc += nvals;
      Renew(stack->boxes, stack->nalloc, PTR_SV); }
    SP -= nvals;
    I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
    for(i = 0; i < nvals; i++){
      SV * box = ST(i);
      if (box && SvOK(box)){
        DEBUG_Boxstack("Box %s.",sv_reftype(SvRV(box),1));
        /*box = SvRV(box);  ????? */
        SvREFCNT_inc(box);
        stack->boxes[stack->nboxes++] = box; } } }
  PUTBACK; FREETMPS; LEAVE;
  DEBUG_Boxstack("Done accumulating.\n"); }

/* Call a primitive's replacement sub (OPCODE or CODE) on the given arguments */
void                            /* Horrible naming!!! */
boxstack_call(pTHX_ LaTeXML_Core_Boxstack stack, SV * primitive, SV * sub,
              SV * state, SV * stomach, SV * token,
              int nargs, SV ** args) {
  DEBUG_Boxstack("Boxstack %p call %p on %d args\n",stack,sub,nargs);
  int i;
  if(! SvOK(sub)){      /* empty? */
    DEBUG_Boxstack("Replacement is undef\n");
    return; }
  else if(sv_isa(sub,"LaTeXML::Core::Opcode")){
    UTF8 opcode = SvPV_nolen(SvRV(sub));
    DEBUG_Boxstack("Replacement is opcode %s\n", opcode);
    primitive_op * op = state_lookup_primitive_op(aTHX_ state, opcode);
    if(op){
      op(aTHX_ token, primitive, stomach, state, nargs, args, stack); }
    else {
      croak("Internal error: Primitive opcode %s has no definition",opcode); } }
  else if(SvTYPE(SvRV(sub)) == SVt_PVCV){ /* ref $expansion eq 'CODE' */
    DEBUG_Boxstack("Replacement is CODE %p\n", sub);
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,nargs+1); PUSHs(stomach); 
    for(i=0; i<nargs; i++){
      SV * arg = (args[i] ? args[i] : &PL_sv_undef);
      PUSHs(arg); }
    PUTBACK;
    if(stack->discard){
      call_sv(sub,G_DISCARD);
      DEBUG_Boxstack("code returned discarding values\n");
      SPAGAIN; }
    else {
      int nvals = call_sv(sub,G_ARRAY);
      DEBUG_Boxstack("code returned %d values\n", nvals);
      SPAGAIN;
      if(stack->nboxes+nvals >= stack->nalloc){
        stack->nalloc += nvals;
        Renew(stack->boxes, stack->nalloc, PTR_SV); }
      SP -= nvals;
      I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
      for(i = 0; i < nvals; i++){
        SV * box = ST(i);
        if (box && SvOK(box)){
          DEBUG_Boxstack("Box.");
          /*box = SvRV(box);  ????? */
          SvREFCNT_inc(box);
          stack->boxes[stack->nboxes++] = box; } } }
    PUTBACK; FREETMPS; LEAVE;
    DEBUG_Boxstack("Done accumulating.\n"); }
  else {
    LaTeXML_Core_Token t = SvToken(token);
    croak("Boxstack replacement for %s is not CODE or Opcode: %p",t->string, sub); } }


void
boxstack_callAV(pTHX_ LaTeXML_Core_Boxstack stack, SV * primitive, AV * subs,
                SV * state, SV * stomach, SV * token,
                int nargs, SV ** args) {
  int i;
  if(subs){
    SSize_t nsubs = av_len(subs) + 1;
    DEBUG_Boxstack("Boxstack %p calling %ld subs\n",stack,nsubs);
    for(i = 0; i < nsubs; i++){
      SV ** ptr = av_fetch(subs,i,0);
      if(*ptr && SvOK(*ptr)){
        SV * sub = *ptr;
        boxstack_call(aTHX_ stack, primitive, sub, state, stomach, token, nargs, args); } }
    DEBUG_Boxstack("Boxstack %p done calling %ld subs\n",stack,nsubs); }
}
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

SV *
mouth_getLocator(pTHX_ LaTeXML_Core_Mouth mouth){
  int l = mouth->lineno;
  int c = mouth->colno;
  /*
  if(length > 0){
    my $msg   = "at " . $self->getSource . "; line $l col $c";
    my $chars = $$self{chars};
    if (my $n = $$self{nchars}) {
      $c = $n - 1 if $c >= $n;
      my $c0 = ($c > 50      ? $c - 40 : 0);
      my $cm = ($c < 1       ? 0       : $c - 1);
      my $cn = ($n - $c > 50 ? $c + 40 : $n - 1);
      my $p1 = ($c0 <= $cm ? join('', @$chars[$c0 .. $cm]) : ''); chomp($p1);
      my $p2 = ($c <= $cn  ? join('', @$chars[$c .. $cn])  : ''); chomp($p2);
      $msg .= "\n  " . $p1 . "\n  " . (' ' x ($c - $c0)) . '^' . ' ' . $p2; }
    return $msg; }
    else { */
  SV * loc = newSV(0);
  sv_setpvf(loc,"at %s; line %d col %d",mouth->source,l,c);
  return loc; }

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
  if(mouth->pushback->ntokens > 0){
    return tokenstack_pop(aTHX_ mouth->pushback); }
  while(1){
    DEBUG_Mouth("READ Token @ %lu\n",startcol);
    if((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc))){
      if((startcol == 0) && (cc == CC_SPACE)){ /* Ignore leading spaces */
        DEBUG_Mouth("Skipping leading space\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc) && (cc == CC_SPACE))){
        } }
      if(CC_TrivialRead[cc]){   /* Common, trivial case first */
        DEBUG_Mouth("Token[%s,%s]\n",ch,CC_SHORT_NAME[cc]);
        return token_new(aTHX_ ch,cc); }
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
        return token_new(aTHX_ buffer,CC_CS); }
      else if (cc == CC_SPACE){
        int cr = 0;
        DEBUG_Mouth("Skipping spaces\n");
        while((nbytes = mouth_readChar(aTHX_ mouth,state,ch,&cc)) /* skip following spaces */
              && ((cc == CC_SPACE) || (cc == CC_EOL)) ){
          if(cc == CC_EOL){
            cr = 1;
            nbytes = 0;
            break; } }
        if(nbytes){           /* put back non-space (if any) */
          mouth_unreadChar(aTHX_ mouth); }
        if(cr && state_intval(aTHX_ state,"PRESERVE_NEWLINES")){
          return token_new(aTHX_ "\n",CC_SPACE); }
        else {
          return token_new(aTHX_ " ",CC_SPACE); } }
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
          return token_new(aTHX_ buffer,cc);
        }
        startcol = mouth->colno; }
      else if (cc == CC_EOL){
        if(startcol == 0){
          DEBUG_Mouth("EOL \\par\n");
          return T_CS("\\par"); }
        else if(state_intval(aTHX_ state,"PRESERVE_NEWLINES")){
          DEBUG_Mouth("EOL T_SPACE[\\n]\n");
          return token_new(aTHX_ "\n",CC_SPACE); }
        else {
          DEBUG_Mouth("EOL T_SPACE\n");
          return token_new(aTHX_ " ",CC_SPACE); } }
      else if (cc == CC_IGNORE){
        DEBUG_Mouth("IGNORE\n"); }
      else if (cc == CC_INVALID){
        DEBUG_Mouth("INVALID\n");
        return token_new(aTHX_ ch,CC_OTHER); } /* ? */
      else {
        DEBUG_Mouth("No proper Catcode '%d'\n",cc); }
      }
    else {                    /* Got no input; Try for next line. */
      /* Comment this out; it currently has no effect, but we may want to "chunk" input???
      if(! mouth_fetchInput(aTHX_ mouth)){
      break; } */                /* EXIT FROM OUTER LOOP */
      mouth->at_eof = 1;        /* but still terminate */
      return NULL;
      /* This should be integrated into above; CC_EOL ? CC_COMMENT ? 
      if(((mouth->lineno % 25) == 0) && state_booleval(aTHX_ state,"INCLUDE_COMMENTS")){
        char * source = mouth_getShortsource(aTHX_ mouth);
        if(source != NULL){
          char * comment = form("**** %s Line %d ****",source,mouth->lineno);
          token = token_new(aTHX_ comment, CC_COMMENT); } }
      else {
      startcol = mouth->colno; } */
    } } }

LaTeXML_Core_Tokens
mouth_readTokens(pTHX_ LaTeXML_Core_Mouth mouth, SV * state, SV * until){
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  LaTeXML_Core_Token u = (until ? SvToken(until) : NULL);
  char * test = (u ? u->string : NULL);
  SV * token;
  /* NOTE: Compare to Until's string, NOT catcode!! */
  while ( (token = mouth_readToken(aTHX_ mouth, state)) ) {
    LaTeXML_Core_Token t = SvToken(token);
    if(test && (strcmp(test,t->string) == 0)){
      SvREFCNT_dec(token);
      break; }
    tokens_add_to(aTHX_ tokens,token,0);
    SvREFCNT_dec(token); }
  tokens_trimright(aTHX_ tokens);
  return tokens; }

  /*======================================================================
    C-level Gullet support */

LaTeXML_Core_Mouth
gullet_getMouth(pTHX_ SV * gullet){ /* Warning: NO refcnt */
  HV * hash;
  SV ** ptr;
  hash = SvHash(gullet);
  ptr  = hv_fetchs(hash,"mouth",0);
  if(! ptr){
    croak("Gullet doesn't have an mouth!"); }
  /*  return SvRV(*ptr); }*/
  return SvMouth(*ptr); }

SV *
gullet_getLocator(pTHX_ SV * gullet){
  HV * hash;
  SV ** ptr;
  LaTeXML_Core_Mouth mouth = NULL;
  hash = SvHash(gullet);
  ptr  = hv_fetchs(hash,"interestingmouth",0);
  if(ptr && *ptr){
    mouth = SvMouth(*ptr); }
  else {
    ptr  = hv_fetchs(hash,"mouth",0);
    if(ptr && *ptr){
      mouth = SvMouth(*ptr); } }
  if(mouth){
    return mouth_getLocator(aTHX_ mouth); }
  else {
    SV * loc = newSV(0);
    sv_setpv(loc,"Unknown");
    return loc; } }

LaTeXML_Core_Tokenstack
gullet_getPendingComments(pTHX_ SV * gullet){
  HV * hash;
  SV ** ptr;
  hash = SvHash(gullet);
  ptr  = hv_fetchs(hash,"pending_comments",0);
  if(! ptr){
    croak("Gullet doesn't have a pending_comments!"); }
  /*  return SvRV(*ptr); }*/
  return SvTokenstack(*ptr); }

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
      LaTeXML_Core_Token t = SvToken(token);
      int cc = t->catcode;
      if(cc == CC_COMMENT){
        LaTeXML_Core_Tokenstack pc = gullet_getPendingComments(aTHX_ gullet);
        DEBUG_Gullet("PUSH Comment: %s\n",t->string);
        tokenstack_push(aTHX_ pc,token);
        SvREFCNT_dec(token); }
      /* AND CC_MARKER!!!*/
      else if(cc == CC_MARKER){
        gullet_stopProfiling(aTHX_ gullet, token); }
      else {
        return token; } } } }

void
gullet_unreadToken(pTHX_ SV * gullet, SV * token){
  mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token); }

void                            /* Show next tokens; risky if followed by catcode changes! */
gullet_showContext(pTHX_ SV * gullet){
  int ntokens = 10;
  SV * tokens[ntokens];
  SV * state = state_global(aTHX);
  int i;
  fprintf(stderr,"To be read:");
  for(i = 0; i< ntokens; i++){
    SV * token = gullet_readToken(aTHX_ gullet, state); 
    if(!token){ break; }
    LaTeXML_Core_Token t = SvToken(token);
    fprintf(stderr," %s[%s]",CC_SHORT_NAME[t->catcode],t->string);
    tokens[i]=token; }
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  for( ; i > 0; i--){  
    mouth_unreadToken(aTHX_ mouth, tokens[i-1]); }
  fprintf(stderr,"\n"); }

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

SV *
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state);

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
      LaTeXML_Core_Token t = SvToken(token);
      int cc = t->catcode;
      DEBUG_Gullet("Token %s[%s] (%p): ",CC_SHORT_NAME[cc],t->string,t);
      if (!readXToken_interesting_catcode[cc]) {    /* Short circuit tests */
        DEBUG_Gullet("simple return\n");
        return token; }                           /* just return it */
      else if ( (defn = state_expandable(aTHX_ state, token)) ) {
        DEBUG_Gullet("expand & loop\n");
        SV * expansion = expandable_invoke(aTHX_ defn, token, gullet, state);
        SvREFCNT_dec(token);
        SvREFCNT_dec(defn);
        mouth = gullet_getMouth(aTHX_ gullet); /* Expansion could change Mouths! */
        if(expansion){
          mouth_unreadToken(aTHX_ mouth, expansion);
          SvREFCNT_dec(expansion); }
        if(state_booleval(aTHX_ state, "PROFILING")){
          mouth_unreadToken(aTHX_ mouth, token_new(aTHX_ t->string,CC_MARKER)); } }
      else if (cc == CC_NOTEXPANDED) {
        DEBUG_Gullet("noexpand return\n");
        /* Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
           so this token should never leak out through an EXTERNAL call to readToken. */
        SvREFCNT_dec(token);
        return mouth_readToken(aTHX_ mouth, state); }    /* Just return the next token.*/
      else if (cc == CC_COMMENT) {
        DEBUG_Gullet("comment\n");
        if(commentsok){
          return token; }
        else {
          tokenstack_push(aTHX_ comments,token);
          SvREFCNT_dec(token); } }
      else if (cc == CC_MARKER) {
        DEBUG_Gullet("marker\n");
        gullet_stopProfiling(aTHX_ gullet, token);
        SvREFCNT_dec(token); }
      else {
        DEBUG_Gullet("return\n");
        return token; }                                  /* just return it  */
    } }
  return NULL; }                                            /* never get here. */

void
gullet_expandafter(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  LaTeXML_Core_Tokenstack comments = gullet_getPendingComments(aTHX_ gullet);
  SV * token1 = gullet_readToken(aTHX_ gullet, state);
  SV * noexpandthe;
  ENTER;
  if(! token1){
    croak("No token1 for \\expandafter"); }
  /* local $LaTeXML::NOEXPAND_THE = undef; */
  noexpandthe = get_sv("LaTeXML::NOEXPAND_THE",0);
  save_item(noexpandthe);
  sv_setsv(noexpandthe,&PL_sv_undef);
  while(1){
    SV * token = mouth_readToken(aTHX_ mouth, state);
    SV * defn;
    if(token == NULL){
      croak("No token2 for \\expandafter"); }
    else {
      LaTeXML_Core_Token t = SvToken(token);
      int cc = t->catcode;
      if (!readXToken_interesting_catcode[cc]) {    /* Short circuit tests */
        mouth_unreadToken(aTHX_ mouth, token);
        SvREFCNT_dec(token);
        break; }
      else if ( (defn = state_expandable(aTHX_ state, token)) ) {
        SV * expansion = expandable_invoke(aTHX_ defn, token, gullet, state);
        SvREFCNT_dec(token);
        SvREFCNT_dec(defn);
        mouth = gullet_getMouth(aTHX_ gullet); /* Expansion can change mouth? */
        if(expansion){
          mouth_unreadToken(aTHX_ mouth, expansion);
          SvREFCNT_dec(expansion); }
        if(state_booleval(aTHX_ state, "PROFILING")){
          SV * marker = token_new(aTHX_ t->string,CC_MARKER);
          mouth_unreadToken(aTHX_ mouth, marker); SvREFCNT_dec(marker); }
        break; }
      else if (cc == CC_NOTEXPANDED) {
        /* Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
           so this token should never leak out through an EXTERNAL call to readToken. */
        /*token = mouth_readToken(aTHX_ mouth, state);
          mouth_unreadToken(aTHX_ mouth, token);*/
        SvREFCNT_dec(token);
        break; }
      else if (cc == CC_COMMENT) {
        tokenstack_push(aTHX_ comments,token);
        SvREFCNT_dec(token); }
      else if (cc == CC_MARKER) {
        gullet_stopProfiling(aTHX_ gullet, token); }
      else {
        mouth_unreadToken(aTHX_ mouth, token);
        SvREFCNT_dec(token);
        break; }                                 /* just return it  */
    } }
  mouth_unreadToken(aTHX_ mouth, token1); /* Now put back First token */
  SvREFCNT_dec(token1);
  LEAVE;
}

int balanced_interesting_cc[] = {
  0, 1, 1, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 1};

void
gullet_readBalanced(pTHX_ SV * gullet, SV * state, LaTeXML_Core_Tokens tokens, int expanded){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  int level = 1;
  while( (token = (expanded ? gullet_readXToken(aTHX_ gullet, state, 0,0)
                   : mouth_readToken(aTHX_ mouth, state))) ){
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(!balanced_interesting_cc[cc]){
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_END){
      level--;
      if(level == 0){
        SvREFCNT_dec(token);
        break; }
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_BEGIN){
      level++;
      tokens_add_to(aTHX_ tokens,token,0); }
    else if(cc == CC_MARKER){
      gullet_stopProfiling(aTHX_ gullet, token); }
    else {
      tokens_add_to(aTHX_ tokens,token,0); }
    SvREFCNT_dec(token); }
  if (level > 0) {
    croak("expected:}:  Gullet->readBalanced ran out of input in an unbalanced state."); }
}

SV *
gullet_readNonSpace(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(cc == CC_SPACE){
      SvREFCNT_dec(token); }
    /* comment ? */
    else if(cc == CC_MARKER){
      gullet_stopProfiling(aTHX_ gullet, token); }
    else {
      return token; } }
  return NULL; }

SV *
gullet_readXNonSpace(pTHX_ SV * gullet, SV * state){
  SV * token;
  while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0)) ){
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(cc == CC_SPACE){
      SvREFCNT_dec(token); }
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
    gullet_unreadToken(aTHX_ gullet, token);
    SvREFCNT_dec(token); } }

void
gullet_skip1Space(pTHX_ SV * gullet,  SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token = mouth_readToken(aTHX_ mouth, state);
  if(token != NULL){
    LaTeXML_Core_Token t = SvToken(token);    
    if(t->catcode != CC_SPACE){
      mouth_unreadToken(aTHX_ mouth, token); }
    SvREFCNT_dec(token);  } }

void
gullet_skipEquals(pTHX_ SV * gullet,  SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token = mouth_readToken(aTHX_ mouth, state);
  if(token != NULL){
    LaTeXML_Core_Token t = SvToken(token);    
    if((t->catcode != CC_OTHER) || (strcmp(t->string,"=") !=0)){
      mouth_unreadToken(aTHX_ mouth, token); }
    SvREFCNT_dec(token);  } }

LaTeXML_Core_Tokens
gullet_readArg(pTHX_ SV * gullet, SV * state){
  SV * token = gullet_readNonSpace(aTHX_ gullet, state);
  if(token == NULL){
    return NULL; }
  else {
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      gullet_readBalanced(aTHX_ gullet, state, tokens, 0); }
    else {
      tokens_add_to(aTHX_ tokens,token,0); }
    SvREFCNT_dec(token);
    return tokens; } }

LaTeXML_Core_Tokens
gullet_readXArg(pTHX_ SV * gullet, SV * state){
  SV * token = gullet_readXNonSpace(aTHX_ gullet, state);
  if(token == NULL){
    return NULL; }
  else {
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      gullet_readBalanced(aTHX_ gullet, state, tokens, 1); }
    else {
      tokens_add_to(aTHX_ tokens,token,0); }
    SvREFCNT_dec(token);
    return tokens; } }

LaTeXML_Core_Tokens
gullet_readXUntilEnd(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  SV * token;
  /* NOTE: Compare to Until's string, NOT catcode!! */
  while ( (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ) {
    tokens_add_to(aTHX_ tokens,token,0);
    SvREFCNT_dec(token); }
  /*tokens_trimright(aTHX_ tokens);*/
  return tokens; }

LaTeXML_Core_Tokens
gullet_readUntilBrace(pTHX_ SV * gullet, SV * state){
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(token);    
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      mouth_unreadToken(aTHX_ mouth, token);
      SvREFCNT_dec(token);
      break; }
    else {
      tokens_add_to(aTHX_ tokens,token,0);
      SvREFCNT_dec(token); } }
  return tokens; }

#define MAX_CSNAME 1000
SV *
gullet_readCSName(pTHX_ SV * gullet, SV * state){
  char buffer[MAX_CSNAME];            /* !!!!! */
  SV * token;
  int p = 0;
  buffer[p++] = '\\'; buffer[p] = 0;
  while ( (token = gullet_readXToken(aTHX_ gullet, state,0,0)) ) {
    LaTeXML_Core_Token t = SvToken(token);        
    int cc = t->catcode;
    if (cc == CC_CS){
      if(strcmp(t->string, "\\endcsname") == 0){
        SvREFCNT_dec(token);
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
      strncpy(buffer+p,s,l); p += l; buffer[p]=0;}
    SvREFCNT_dec(token); }      /* Done with token */
  return token_new(aTHX_ buffer, CC_CS); }

int                            /* fill in type, prepare choices; return max length */
gullet_prepareMatch(pTHX_ SV * gullet, int nchoices, int * type, SV ** choices){
  int maxlength = 0;
  int choice;
  /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
  for(choice = 0; choice < nchoices; choice++){
    SV * thing = choices[choice];
    if (sv_isa(thing, "LaTeXML::Core::Token")) {
      type[choice] = 1;
      /*choices[choice] = SvRV(thing);*/
      DEBUG_Gullet("readUntil: choice %d = %s[%s]\n",choice,
         CC_SHORT_NAME[(SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);
      if(maxlength < 1){
        maxlength = 1; } }
    else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
      LaTeXML_Core_Tokens tokens = SvTokens(thing);
      if(tokens->ntokens == 1){
        type[choice] = 1;
        choices[choice] = tokens->tokens[0];
        DEBUG_Gullet("readUntil: choice %d = %s[%s]\n",choice,
          CC_SHORT_NAME[(SvToken(choices[choice]))->catcode],(SvToken(choices[choice]))->string);}
      else {
        type[choice] = 2;
        /*choices[choice] = SvRV(thing);*/
        DEBUG_Gullet("readUntil: choice %d = %s[%s] ... (%d) \n",choice,
                     CC_SHORT_NAME[(SvToken(tokens->tokens[0]))->catcode],
                     (SvToken(tokens->tokens[0]))->string, tokens->ntokens); }
      if(maxlength < tokens->ntokens){
        maxlength = tokens->ntokens; } }
    else {
      croak("readMatch Choice %d,: Expected a Token or Tokens, got a %s: %s",
            choice, (SvROK(thing) ? sv_reftype(SvRV(thing),1) : sv_reftype(thing,1)),
            SvPV_nolen(thing)); } }
  return maxlength; }

int  /* Note readMatch returns -1 for failure, otherwise the index of the match */
gullet_readMatch(pTHX_ SV * gullet, SV * state,
                 int nchoices, int maxlength, int type[], SV * choices[]) {
  SV * token;
  /* Common case! */
  if((nchoices == 1) && (maxlength == 1)) {  
    if( (token = gullet_readToken(aTHX_ gullet, state)) ){
      /*if(token_equals(aTHX_ SvRV(token), choices[0])){*/
      if(token_equals(aTHX_ token, choices[0])){
        return 0; }
      else {
        gullet_unreadToken(aTHX_ gullet, token); }
      SvREFCNT_dec(token); }
    return -1; }                /* Failed */
  else {  
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
            /*          case 1: if(token_equals(aTHX_ SvRV(token), choices[choice])){*/
          case 1: if(token_equals(aTHX_ token, choices[choice])){
              matched = choice; }
            else {
              ncandidates--;
              disabled[choice] = 1; }        /* failed on this choice */
            break;
          case 2:
            tokens = SvTokens(choices[choice]);
            /*if(token_equals(aTHX_ SvRV(token), tokens->tokens[nread-1])){*/
            if(token_equals(aTHX_ token, tokens->tokens[nread-1])){
              if(nread == tokens->ntokens){
                matched = choice; } }
            else {
              ncandidates--;
              disabled[choice] = 1; }      /* failed on this choice */
            break; } } } }
    if(matched >= 0){              /* Found a match! */
      int i;
      for(i = 0; i < nread; i++){
        SvREFCNT_dec(tokens_read[i]); }
      return matched; }
    else {
      LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
      while(nread > 0){
        SV * token = tokens_read[--nread];
        mouth_unreadToken(aTHX_ mouth, token);
        SvREFCNT_dec(token); }
      return -1; } } }

LaTeXML_Core_Tokens  /* Note readMatch returns -1 for failure, otherwise the index of the match */
gullet_readUntilMatch(pTHX_ SV * gullet, SV * state, int expanded,
                      int nchoices, int maxlength, int type[], SV * choices[],
                      int * match) {
    
  LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  int balanced1=0;          /* 0: unknown; +1: yes; -1: no */
  while( (*match = gullet_readMatch(aTHX_ gullet, state,
                                   nchoices,maxlength, type, choices)) < 0) {
    SV * token = (expanded ? gullet_readXToken(aTHX_ gullet, state,0, 0)
                  : gullet_readToken(aTHX_ gullet, state));
    if(token == NULL){
      break; }
    LaTeXML_Core_Token t = SvToken(token);
    tokens_add_to(aTHX_ tokens, token, 0);
    SvREFCNT_dec(token);
    DEBUG_Gullet("readUntil: collect %s[%s] (%p)\n",CC_SHORT_NAME[t->catcode],t->string,t);
    int cc = t->catcode;
    if(cc == CC_BEGIN){
      if(balanced1 == 0){
        balanced1 = +1; }
      else {
        balanced1 = -1; }
      DEBUG_Gullet("readUntil: readBalanced\n");
      gullet_readBalanced(aTHX_ gullet, state, tokens, 0);
      SV * egroup = token_new(aTHX_ "}", CC_END);
      tokens_add_to(aTHX_ tokens, egroup,0); SvREFCNT_dec(egroup); }
    else if ((cc != CC_SPACE) || (balanced1 != +1)) {
      balanced1 = -1; } }
  /* NOTE that we should(?) be stripping outer { } if a single balanced group */
  if(balanced1 == 1){
    tokens_trimBraces(aTHX_ tokens); }
  if(*match < 0){                  /* Never found a match? */
    DEBUG_Gullet("readUntil: Fell off end!\n"); }
  else {
    DEBUG_Gullet("readUntil: Succeeded at choice %d!\n",*match); }
  return tokens; }

int
gullet_readKeyword(pTHX_ SV * gullet, SV * state, int nchoices, char * choices[]) {
  SV * token;
  int ncandidates = nchoices;
  int matched = -1;
  int choice;
  int nread = 0;
  int length[nchoices];
  int disabled[nchoices];
  int maxlength = 0;
  gullet_skipSpaces(aTHX_ gullet, state);
  for(choice = 0; (choice < nchoices); choice++){
    disabled[choice] = 0;
    int l = strlen(choices[choice]);
    length[choice] = l;
    if(l > maxlength) { maxlength = l; } }
  SV * tokens_read[maxlength];
  while( ( (ncandidates > 0) && !((ncandidates == 1) && (matched >= 0)))
         && (nread < maxlength) && (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ){
    tokens_read[nread++] = token;
    LaTeXML_Core_Token t = SvToken(token);
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
  int i;
  for(i = 0; i < nread; i++){
    SvREFCNT_dec(tokens_read[i]); }
  if(matched >= 0){              /* Found a match! */
    DEBUG_Gullet("readKeyword matched %s\n",choices[matched]);
    return matched; }
  else {
    DEBUG_Gullet("readKeyword failed\n");
    return -1; } }

void
gullet_addnewparameter(pTHX_ AV * parameters, SV * state,
                       UTF8 type, LaTeXML_Core_Tokens extra, int novalue){
  HV * hash = newHV();
  SV * types = state_lookup_noinc(aTHX_ state,"value", "PARAMETER_TYPES");
  SV * desc;
  /* Lookup type in PARAMETER_TYPES and copy keys & values to new hash */
  if(types && (desc = object_get(aTHX_ types, type))){
    HV * table = SvHash(desc);
    hv_iterinit(table);
    I32 keylen;
    UTF8 key;
    SV * value;
    while( (value = hv_iternextsv(table, &key,&keylen)) ){
      SvREFCNT_inc(value);
      hv_store(hash,key,keylen,value,0); }
    SvREFCNT_dec(desc); }
  else {                        /* Else try to fill in... */
    croak("internal:missing_parameter_definition:%s",type); }
  SV * spec;
  if(extra){
    AV * list = newAV();
    SV * tokens = newSV(0);
    sv_setref_pv(tokens, "LaTeXML::Core::Tokens", (void*)extra);
    av_push(list,tokens);
    hv_store(hash,"extra",5, newRV_noinc((SV*)list),0);
    UTF8 xtra = tokens_toString(aTHX_ extra);
    spec = newSVpvf("%s:%s",type,xtra);
    Safefree(xtra); }
  else if(strcmp(type,"Plain")==0) {
    spec = newSVpv("{}",2); }
  else {
    spec = newSVpv(type,strlen(type)); }
  hv_store(hash,"spec",4, spec,0);
  if(novalue){
    hv_store(hash,"novalue",7, newSViv(1),0); }
  SV * ref = newRV_noinc((SV*)hash);
  sv_bless(ref, gv_stashpv("LaTeXML::Core::Parameter",0));
  av_push(parameters, ref); }

SV *
gullet_readDefParameters(pTHX_ SV * gullet, SV * state){
  AV * parameters = newAV();
  int prev_n = 0;
  /*fprintf(stderr,"\n******* Parsing Def Parameters\n");*/
  SV * token = gullet_readToken(aTHX_ gullet, state);
  while(token ){
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    /*fprintf(stderr,"DefParameters Loop: %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);*/
    if(cc == CC_BEGIN){         /* Done */
      /*(fprintf(stderr,"DefParameters: got { done!\n");*/
      break; }
    else if(cc == CC_PARAM){
      SvREFCNT_dec(token);
      token = gullet_readToken(aTHX_ gullet, state);
      if(! token){ croak("Missing token reading \\def parameters"); }
      t = SvToken(token);
      cc = t->catcode;
      if(cc == CC_BEGIN){       /* #{ means require brace (UNLESS following #1#{; see below! */
        /*fprintf(stderr,"DefParameters: got #{ done!\n");*/
        gullet_addnewparameter(aTHX_ parameters, state, "RequireBrace",NULL,0);
        break; }
      else {                    /* better get 1--9! */
        int n = t->string[0] - '0';
        if((n < 1) || (n > 9)){
          croak("Invalid parameter number"); }
        else if(n != prev_n+1){
          croak("parameters not in order"); }
        /*fprintf(stderr,"DefParameters: got #%d\n",n);*/
        prev_n = n;
        SvREFCNT_dec(token);
        token = gullet_readToken(aTHX_ gullet, state); /* Peek next token */
        if(! token){ croak("Missing token reading \\def parameters"); }
        t = SvToken(token);
        cc = t->catcode;
        /* Got #1; Look ahead to determine any delimiting */
        if(cc == CC_BEGIN){ /* end of parameter list */
          /*fprintf(stderr,"DefParameters CHECK: got {\n");*/
          gullet_addnewparameter(aTHX_ parameters, state,"Plain",NULL,0); }
        else if(cc == CC_PARAM) { /* Probably next parameter, but.... */
          SV * peek = gullet_readToken(aTHX_ gullet,state);
          LaTeXML_Core_Token pt = SvToken(peek);
          if(pt->catcode == CC_BEGIN){ /* #1#{ means #1 gets UntilBrace */
            /*fprintf(stderr,"DefParameters CHECK: got #{\n");*/
            gullet_addnewparameter(aTHX_ parameters,state,"UntilBrace",NULL,0);
            SvREFCNT_dec(token);
            token = peek; }     /* and absorb the # */
          else {                /* #1#2 means #1 is just a plain argument */
            /*fprintf(stderr,"DefParameters CHECK: got next arg\n");*/
            gullet_unreadToken(aTHX_ gullet, peek); /* put back the peeked token */
            gullet_addnewparameter(aTHX_ parameters,state,"Plain",NULL,0); } }
        else {  /* Anything else, we have following delimiting text */
          /*fprintf(stderr,"DefParameters CHECK: reading delimeter\n");*/
          LaTeXML_Core_Tokens until = tokens_new(aTHX_ 1);
          tokens_add_to(aTHX_ until, token,0);
          int prev_cc = cc;
          while( (token = gullet_readToken(aTHX_ gullet, state)) && (t = SvToken(token))
                 && ((cc = t->catcode) != CC_PARAM) && (cc != CC_BEGIN)){
            if((cc != CC_SPACE) || (prev_cc != CC_SPACE)){ /* Collapse spaces */
              tokens_add_to(aTHX_ until, token,0);
              SvREFCNT_dec(token); }
            prev_cc = cc; }
          gullet_addnewparameter(aTHX_ parameters,state,"Until",until,0); } } }
    else if (av_len(parameters) < 0) {                      /* initial text, reqiure */
      /*fprintf(stderr,"DefParameters: initial delimeter\n");*/
      LaTeXML_Core_Tokens until = tokens_new(aTHX_ 1);
      tokens_add_to(aTHX_ until, token,0);
      int prev_cc = cc;
      while( (token = gullet_readToken(aTHX_ gullet, state)) && (t = SvToken(token))
             && ((cc = t->catcode) != CC_PARAM) && (cc != CC_BEGIN)){
        if((cc != CC_SPACE) || (prev_cc != CC_SPACE)){ /* Collapse spaces */
          tokens_add_to(aTHX_ until, token,0);
          SvREFCNT_dec(token); }
        prev_cc = cc; }
      gullet_addnewparameter(aTHX_ parameters,state,"Match",until, 1); }
    else {
      croak("what happened?"); } }
  if(token){
    gullet_unreadToken(aTHX_ gullet, token);
    SvREFCNT_dec(token); }
  if(av_len(parameters) > -1){
    /*fprintf(stderr,"****** DefParameters: read %ld parameters\n", av_len(parameters)+1);*/
    SV * ref = newRV_noinc((SV*)parameters);
    sv_bless(ref, gv_stashpv("LaTeXML::Core::Parameters",0));
    return ref; }
  else {
    /*fprintf(stderr,"****** DefParameters: read NO parameters\n");*/
    return NULL; } }

int
gullet_readOptionalSigns(pTHX_ SV * gullet, SV * state){
  SV * token;
  int sign = +1;
  while ( (token = gullet_readXToken(aTHX_ gullet, state,0,0)) ) {
    LaTeXML_Core_Token t = SvToken(token);        
    if (t->catcode == CC_SPACE){ }
    else if (strcmp("+",t->string)==0){}
    else if (strcmp("-",t->string)==0){
      sign = - sign; }
    else {
      gullet_unreadToken(aTHX_ gullet, token);
      SvREFCNT_dec(token);
      break; }
    SvREFCNT_dec(token); }
  return sign; }

int
gullet_readArguments(pTHX_ SV * gullet,  int npara, AV * parameters, SV * fordefn, SV * args[]);


SV *
gullet_readRegisterValue(pTHX_ SV * gullet, SV * state, int ntypes, UTF8 * regtypes){
  /* Accept one of several types, to handle numeric cases w/various coercions */
  /* my $number = $self->readRegisterValue('Number')*/
  SV * token = NULL;
  SV * defn = NULL;
  UTF8 type = NULL;
  if( (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ) {
    if ( (defn = state_definition(aTHX_ state, token))
         && (type = object_getPV(aTHX_ defn, "registerType"))){
      int typeok = 0;
      int i;
      for(i = 0; i < ntypes ; i++){
        if(strcmp(type,regtypes[i])==0){
          typeok = 1;
          break; }}
      if(typeok){
        /* $defn->valueOf($defn->readArguments($self));*/
        AV * parameters = object_getAV(aTHX_ defn,"parameters");
        SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
        SV * args[npara];
        int nargs = 0;
        if(parameters){
          nargs = gullet_readArguments(aTHX_ gullet, npara, parameters, token, args);
          SvREFCNT_dec(parameters); }
        dSP; ENTER; SAVETMPS; PUSHMARK(SP);
        EXTEND(SP,nargs+1); PUSHs(defn);
        for(i=0; i<nargs; i++){
          /* No need for mortal/refcnt stuff, since args will be explicitly decremented later*/
          SV * arg = (args[i] ? args[i] : &PL_sv_undef);
          PUSHs(arg); }
        PUTBACK;
        int nvals = call_method("valueOf",G_SCALAR);
        SPAGAIN;
        SV * value = NULL;
        if(nvals){
          value = POPs; SvREFCNT_inc(value); }
        PUTBACK; FREETMPS; LEAVE;
        SvREFCNT_dec(defn);
        SvREFCNT_dec(token);
        for(i = 0; i < nargs; i++){ /* NOW, we can clean up the args */
          SvREFCNT_dec(args[i]); }
        return value; } } }
  if(defn){ SvREFCNT_dec(defn); }
  if(token){
    gullet_unreadToken(aTHX_ gullet, token);
    SvREFCNT_dec(token); }
  return NULL; }

int
gullet_readInteger(pTHX_ SV * gullet, SV * state){
  SV * token = gullet_readXToken(aTHX_ gullet, state, 0, 0);
  if(! token){
    return 0; }
  else {
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    char ch = *(t->string);
    if((cc == CC_OTHER) && (ch >= '0') && (ch <= '9')) { /* Read Decimal */
      int integer = ch - '0';
      SvREFCNT_dec(token);
      while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0))
             && (t = SvToken(token)) && (ch = *(t->string))
             && (ch >= '0') && (ch <= '9')) {
        integer = 10*integer + (ch - '0');
        SvREFCNT_dec(token); }
      /*fprintf(stderr,"Decimal: %d\n",integer);*/
      if(token){
        if(t->catcode != CC_SPACE){
          mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token); }
        SvREFCNT_dec(token); }
      return integer; }
    else if(ch == '\''){        /* Read Octal */
      int integer = 0;
      SvREFCNT_dec(token);
      while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0))
             && (t = SvToken(token)) && (ch = *(t->string))
             && (ch >= '0') && (ch <= '7')) {
        integer = 8*integer + (ch - '0');
        SvREFCNT_dec(token); }
      /*fprintf(stderr,"Octal: %d\n",integer);*/
      if(token){
        if(t->catcode != CC_SPACE){
          mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token); }
        SvREFCNT_dec(token); }
      return integer; }
    else if(ch == '"'){         /* Read Hex */
      int integer = 0;
      SvREFCNT_dec(token);
      while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0))
             && (t = SvToken(token)) && (ch = *(t->string))
             && (((ch >= '0') && (ch <= '9')) || ((ch >= 'A') && (ch <= 'F')))) {
        integer = 16*integer + (ch >= 'A' ? (ch - 'A' + 10) : (ch - '0'));
        SvREFCNT_dec(token); }
      /*fprintf(stderr,"Hex: %d\n",integer);*/
      if(token){
        if(t->catcode != CC_SPACE){
          mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token); }
        SvREFCNT_dec(token); }
      return integer; }
    else if(ch == '`'){         /* Read charcode */
      SvREFCNT_dec(token);
      if( (token = gullet_readToken(aTHX_ gullet, state)) ){
        t = SvToken(token);
        U8 * string = (U8*) t->string;
        int code;
        if(string[0] == '\\'){ string++; }
        /*if(!UTF8_IS_INVARIANT(string[0])){
          fprintf(stderr,"CHARCODE %s\n",string);
          STRLEN len = strlen((char *)string);
          code = utf8_to_uvchr_buf(string,string+len,&len); }
          else { */
        code = string[0];/* }*/
        /*fprintf(stderr,"Charcode: %s => %d\n",string,code);*/
        SvREFCNT_dec(token);
        return code; } } }
  return 0; }

double
gullet_readFloatingPoint(pTHX_ SV * gullet, SV * state, int comma_p){
  SV * token = gullet_readXToken(aTHX_ gullet, state, 0, 0);
  double number = 0.0;
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    char ch = *(t->string);
    if((cc == CC_OTHER) && (((ch >= '0') && (ch <= '9')) || (ch == '.') || (comma_p && (ch == ',')))) {
      if((ch >= '0') && (ch <= '9')){ /* Read leading digits */
        SvREFCNT_dec(token);
        number = ch - '0';
        while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0))
               && (t = SvToken(token)) && (ch = *(t->string))
               && (ch >= '0') && (ch <= '9')) {
          number = 10*number + (ch - '0');
          SvREFCNT_dec(token); } }
      if(token && ((ch == '.') || (comma_p && (ch == ',')))){ /* Decimal? read fractional part */
        double e = 0.1;
        SvREFCNT_dec(token);
        while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0))
               && (t = SvToken(token)) && (ch = *(t->string))
               && (ch >= '0') && (ch <= '9')) {
          number += (ch - '0')*e; e /= 10;
          SvREFCNT_dec(token); } }
      /*fprintf(stderr,"Floating: %f\n",number);*/
      if(token){
        if(t->catcode != CC_SPACE){
          mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token); }
        SvREFCNT_dec(token); } }
    else if((cc == CC_OTHER) && (index("'`\"",ch))){
      mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token);
      SvREFCNT_dec(token);
      number = gullet_readInteger(aTHX_ gullet, state); } }
  return number; }

SV *
gullet_readFloat(pTHX_ SV * gullet, SV * state){
  int sign = gullet_readOptionalSigns(aTHX_ gullet, state);
  SV * token = gullet_readToken(aTHX_ gullet, state); /* Already X'd by signs!! */
  double number = 0;
  int found = 0;
  SV * regvalue;
  char * allowed = "0123456789'`\"."; /* No comma? */
  UTF8 regtypes[] = {"Number","Dimension","Glue"};
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    char ch = *(t->string);
    mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token);
    SvREFCNT_dec(token);
    if((cc == CC_OTHER) && (index(allowed,ch))){ /* Expect a constant number */
      number = gullet_readFloatingPoint(aTHX_ gullet, state, 0); found=1; }
    else if ((cc == CC_CS)
             && (regvalue = gullet_readRegisterValue(aTHX_ gullet, state, 3, regtypes))){
      number = number_value(aTHX_ regvalue); found=1;
      SvREFCNT_dec(regvalue); } }
  if(found){
    return float_new(aTHX_ sign * number); }
  else {
    warn("expected:<number>: Missing number treated as zero");
    gullet_showContext(aTHX_ gullet);
    return float_new(aTHX_ 0.0); } }

SV *
gullet_readNumber(pTHX_ SV * gullet, SV * state){
  int sign = gullet_readOptionalSigns(aTHX_ gullet, state);
  SV * token = gullet_readToken(aTHX_ gullet, state); /* Already X'd by signs!! */
  int number = 0;
  SV * regvalue;
  int found = 0;
  UTF8 regtypes[] = {"Number","Dimension","Glue"};
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    char ch = *(t->string);
    mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token);
    SvREFCNT_dec(token);
    if((cc == CC_OTHER) && (index("0123456789'`\"",ch))){ /* Expect a constant number */
      number = gullet_readInteger(aTHX_ gullet, state); found=1; }
    else if ((cc == CC_CS)
             && (regvalue = gullet_readRegisterValue(aTHX_ gullet, state, 3, regtypes))){
      number = number_value(aTHX_ regvalue); found=1;
      SvREFCNT_dec(regvalue); } }
  if(found){
    return number_new(aTHX_ sign * number); }
  else {
    warn("expected:<number>: Missing number treated as zero");
    gullet_showContext(aTHX_ gullet);
    return number_new(aTHX_ 0); } }

double
gullet_readUnit(pTHX_ SV * gullet, SV * state, double defaultunit){
  int u = -1;
  SV * regvalue;
  UTF8 regtypes[] = {"Number","Dimension","Glue"};
  if ( (u = gullet_readKeyword(aTHX_ gullet, state, MAX_TEXT_UNITS, UNIT_NAME)) >= 0){
    gullet_skip1Space(aTHX_ gullet, state);
    return UNIT_VALUE[u]; }
  else if( (regvalue = gullet_readRegisterValue(aTHX_ gullet, state, 3,regtypes)) ){
    double unit = number_value(aTHX_ regvalue);
    SvREFCNT_dec(regvalue); 
    return unit; }
  else if(defaultunit != 0.0){
    return defaultunit; }
  else {
    warn("expected:<unit> Illegal unit of measure (pt inserted).");
    gullet_showContext(aTHX_ gullet);
    return 65536; } }

double
gullet_readMuUnit(pTHX_ SV * gullet, SV * state){
  char * units[] = {"mu"};
  /* NOTE: em & ex SHOULD reference to the current font in state! */
  /*double factor = 10.0*SCALED_POINT/18;*/
  int u = -1;
  SV * regvalue;
  UTF8 regtypes[] = {"MuGlue"};
  if ( (u = gullet_readKeyword(aTHX_ gullet, state, 1, units)) >= 0){
    gullet_skip1Space(aTHX_ gullet, state);
    return SCALED_POINT; }
  else if( (regvalue = gullet_readRegisterValue(aTHX_ gullet, state, 1,regtypes)) ){
    double unit = number_value(aTHX_ regvalue);
    SvREFCNT_dec(regvalue); 
    return unit; }
  else {
    warn("expected:<unit> Illegal unit of measure (mu inserted).");
    gullet_showContext(aTHX_ gullet);
    return 10.0*65536/18; } }

void
gullet_readDimensional(pTHX_ SV * gullet, SV * state,
                       int mu_p, int comma_p, int fill_p, double defaultunit,
                       int * value, int * fillcode){
  int sign = gullet_readOptionalSigns(aTHX_ gullet, state);
  SV * token = gullet_readToken(aTHX_ gullet, state); /* Already X'd by signs!! */
  double number = 0;
  int found = 0;
  int needunit = 1;
  int needround = 0;
  SV * regvalue;
  char * allowed = (comma_p ? "0123456789'`\".," : "0123456789'`\".");
  UTF8 regtypes[] = {"Number","Dimension","Glue"};
  UTF8 muregtypes[] = {"Number","MuGlue"};
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    int cc = t->catcode;
    char ch = *(t->string);
    mouth_unreadToken(aTHX_ gullet_getMouth(aTHX_ gullet), token);
    SvREFCNT_dec(token);
    if((cc == CC_OTHER) && (index(allowed,ch))){ /* Expect a constant number */
      number = gullet_readFloatingPoint(aTHX_ gullet, state, comma_p);
      found=1; needunit=1;
      /*needround=1;*/
      int inumber = number;
      needround=(inumber != number); } /* Fishy rounding issues? */
    else if ((cc == CC_CS)
             && (regvalue = gullet_readRegisterValue(aTHX_ gullet, state,
                                                     (mu_p ? 2 : 3),
                                                     (mu_p ? muregtypes : regtypes)))){
      number = number_value(aTHX_ regvalue); found=1;
      needunit = sv_isa(regvalue, "LaTeXML::Common::Number");
      SvREFCNT_dec(regvalue); } }
  if(found){
    double unit = 1.0;
    int got_fill = -1;
    if(needunit){
      /*needround = 1;*/
      char * fills[] = {"filll","fill","fil"};
      if(fill_p && ((got_fill = gullet_readKeyword(aTHX_ gullet, state, 3, fills)) >= 0)){
        unit = 65536.0; }         /* Still need scaled  */
      else if(mu_p){
        unit = gullet_readMuUnit(aTHX_ gullet, state); }
      else {
        unit = gullet_readUnit(aTHX_ gullet, state, defaultunit); } }
    * value  = sign * (number * unit + (needround ? 0.5 : 0.0));
    * fillcode = (got_fill >= 0 ? 3-got_fill : 0);  }
  else {
    warn("expected:<number>: Missing number treated as zero");
    gullet_showContext(aTHX_ gullet);
    * value = 0;
    * fillcode = 0; } }

SV *
gullet_readDimension(pTHX_ SV * gullet, SV * state, int nocomma, double defaultunit){
  int value;
  int fill;
  gullet_readDimensional(aTHX_ gullet, state, 0,1,0,defaultunit, &value,&fill);
  return dimension_new(aTHX_ value); }

SV *
gullet_readGlue(pTHX_ SV * gullet, SV * state){
  int sign = gullet_readOptionalSigns(aTHX_ gullet, state);
  SV * regvalue;
  UTF8 regtypes[] = {"Glue"};
  if ((regvalue = gullet_readRegisterValue(aTHX_ gullet, state,1,regtypes))){ /* Get glue? */
    if(sign < 0){
      SV * neg = glue_negate(aTHX_ regvalue);
      SvREFCNT_dec(regvalue);
      return neg; }
    else {
      return regvalue; } }
  else {
    int value = 0, plusvalue = 0, minusvalue = 0;
    int fill = 0, plusfill = 0,minusfill = 0;
    char * pluskeys[] = {"plus"};
    char * minuskeys[] = {"minus"};
    gullet_readDimensional(aTHX_ gullet, state, 0,1,0, 0.0, &value,&fill);
    if(gullet_readKeyword(aTHX_ gullet, state, 1, pluskeys) == 0){
      gullet_readDimensional(aTHX_ gullet, state, 0,1,1, 0.0, &plusvalue,&plusfill); }
    if(gullet_readKeyword(aTHX_ gullet, state, 1, minuskeys) == 0){
      gullet_readDimensional(aTHX_ gullet, state, 0,1,1, 0.0, &minusvalue,&minusfill); }
    return glue_new(aTHX_ sign * value, plusvalue, plusfill, minusvalue, minusfill); } }

SV *
gullet_readMuGlue(pTHX_ SV * gullet, SV * state){
  int sign = gullet_readOptionalSigns(aTHX_ gullet, state);
  SV * regvalue;
  UTF8 regtypes[] = {"MuGlue"};
  if ((regvalue = gullet_readRegisterValue(aTHX_ gullet, state,1,regtypes))){ /* Get glue? */
    if(sign < 0){
      SV * neg = muglue_negate(aTHX_ regvalue);
      SvREFCNT_dec(regvalue);
      return neg; }
    else {
      return regvalue; } }
  else {
    int value = 0, plusvalue = 0, minusvalue = 0;
    int fill = 0, plusfill = 0,minusfill = 0;
    char * pluskeys[] = {"plus"};
    char * minuskeys[] = {"minus"};
    gullet_readDimensional(aTHX_ gullet, state, 1,1,0, 0.0, &value,&fill);
    if(gullet_readKeyword(aTHX_ gullet, state, 1, pluskeys) == 0){
      gullet_readDimensional(aTHX_ gullet, state, 1,1,1, 0.0, &plusvalue,&plusfill); }
    if(gullet_readKeyword(aTHX_ gullet, state, 1, minuskeys) == 0){
      gullet_readDimensional(aTHX_ gullet, state, 1,1,1, 0.0, &minusvalue,&minusfill); }
    return muglue_new(aTHX_ sign * value, plusvalue, plusfill, minusvalue, minusfill); } }

SV *                            /* Apparently how value of Tokens registers are read  */
gullet_readTokensValue(pTHX_ SV * gullet, SV * state){
  SV * token;
  SV * value;
  UTF8 regtypes[] = {"Tokens"};
  gullet_skipSpaces(aTHX_ gullet, state);
  if( (value = gullet_readRegisterValue(aTHX_ gullet, state, 1, regtypes)) ){
    return value; }
  else if( (token = gullet_readToken(aTHX_ gullet, state)) ){ /* next token already expanded! */
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
    LaTeXML_Core_Token t = SvToken(token);
    if(t->catcode == CC_BEGIN){
      gullet_readBalanced(aTHX_ gullet, state, tokens, 0); }
    else {
      tokens_add_to(aTHX_ tokens, token, 0); }
    value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens);
    return value; }
  else {
    return NULL; } }

SV *
gullet_readValue(pTHX_ SV * gullet, SV * state, UTF8 type){
  SV * value = NULL;
  if(strcmp(type,"Number")==0){
    value = gullet_readNumber(aTHX_ gullet, state); }
  else if(strcmp(type,"Dimension")==0){
    value = gullet_readDimension(aTHX_ gullet, state, 0,0.0); }
  else if(strcmp(type,"Glue")==0){
    value = gullet_readGlue(aTHX_ gullet, state); }
  else if(strcmp(type,"MuGlue")==0){
    value = gullet_readMuGlue(aTHX_ gullet, state); }
  else if(strcmp(type,"Tokens")==0){
    value = gullet_readTokensValue(aTHX_ gullet, state); }
  else if(strcmp(type,"Token")==0){
    value = gullet_readToken(aTHX_ gullet, state); }
  else if(strcmp(type,"any")==0){
    LaTeXML_Core_Tokens tokens = gullet_readArg(aTHX_ gullet, state);
    value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens); }
  else {
    croak("unexpected:%s gullet->readValue didn't expect this type %s",type,type); }
  return value; }

SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn);

int
gullet_readArguments(pTHX_ SV * gullet,  int npara, AV * parameters, SV * fordefn, SV * args[]){
  int ip;
  int nargs = 0;
  SV * state = state_global(aTHX);
  DEBUG_Gullet("readArguments reading %d parameters for %p\n",npara, fordefn);
  for(ip = 0; ip < npara; ip++){
    SV ** ptr = av_fetch(parameters, ip, 0);
    if(! ptr){
      croak("Missing parameter %d",ip); }
    SV * para = * ptr;
    SV * value = parameter_read(aTHX_ para, gullet, state, fordefn);
    HV * para_hash = SvHash(para);
    int store = ( ! ((ptr = hv_fetchs(para_hash,"novalue",0))  && SvTRUE(*ptr)));
    if(store){                  /* Now (maybe) store the argument */
      DEBUG_Gullet("readArguments stored argument %d = %p, for %p\n", nargs, value, fordefn);
      /*if(value){
        SvREFCNT_inc(value); }*/
      args[nargs++] = value; } }
  DEBUG_Gullet("readArguments read %d args (of %d) for %p\n",nargs, npara, fordefn);
  return nargs; }

SV *
gullet_skipConditionalBody(pTHX_ SV * gullet, int nskips, UTF8 sought_ifid){
  SV * state = state_global(aTHX);
  LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  int level = 1;
  int n_ors = 0;
  SV ** ptr;
  SV * start = gullet_getLocator(aTHX_ gullet);
  /* Question: does if_stack need to be a state value, or can it be an object value? */
  SV * sv_ifstack = state_value(aTHX_ state, "if_stack");
  AV * ifstack = SvArray(sv_ifstack);
  ptr = av_fetch(ifstack, 0, 0);
  HV * ifframe = (ptr ? SvHash(*ptr) : NULL);
  ptr = hv_fetchs(ifframe,"ifid",0);
  UTF8 ifid = (ptr ? (UTF8)SvPV_nolen(*ptr) : "lost");
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Core_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
    SV * defn = state_expandable(aTHX_ state, token);
    SV * expansion = NULL;
    UTF8 opcode;
    if(! defn){}
    else if ( ! (expansion = object_get(aTHX_ defn, "expansion"))){
      SvREFCNT_dec(defn); }
    else if(! sv_isa(expansion,"LaTeXML::Core::Opcode")){
      SvREFCNT_dec(defn);
      SvREFCNT_dec(expansion); }
    else if( (opcode = SvPV_nolen(SvRV(expansion)) ) ){
      SvREFCNT_dec(defn);
      SvREFCNT_dec(expansion);
      if (strncmp(opcode,"if",2) == 0) {
        level++; }
      else if (strcmp(opcode, "fi") == 0) {    /*  Found a \fi */
        if (strcmp(ifid,sought_ifid) != 0) {     /* but for different if (nested in test?) */
          /* then DO pop that conditional's frame; it's DONE!*/
          ifframe = SvHash(av_shift(ifstack)); /* shift($ifstack) */
          hv_clear(ifframe);
          SvREFCNT_dec(ifframe);
          ptr = av_fetch(ifstack, 0, 0);
          ifframe = (ptr ? SvHash(*ptr) : NULL);
          ptr = hv_fetchs(ifframe,"ifid",0);
          ifid = (ptr ? (UTF8)SvPV_nolen(*ptr) : "lost"); }
        else if (!--level) { /* If no more nesting, we're done.*/
          ifframe = SvHash(av_shift(ifstack)); /* Done with this frame */
          hv_clear(ifframe);
          SvREFCNT_dec(ifframe);
          SvREFCNT_dec(start);
          SvREFCNT_dec(sv_ifstack);
          return token; } }  /* AND Return the finishing token.*/
      else if (strcmp(opcode,"or")==0) {
        if ((level < 2) && (++n_ors == nskips)) {
          SvREFCNT_dec(start);
          SvREFCNT_dec(sv_ifstack);
          return token; } }
      else if (strcmp(opcode,"else")==0) {
        if((level < 2) && nskips && (strcmp(ifid,sought_ifid) == 0)){
          /* Found \else and we're looking for one?
             Make sure this \else is NOT for a nested \if that is part of the test clause!*/ /*  */
          /* No need to actually call elseHandler, but note that we've seen an \else!*/
          hv_store(ifframe,"elses",5,newSViv(1),0); /* $$stack[0]{elses} = 1;*/
          SvREFCNT_dec(start);
          SvREFCNT_dec(sv_ifstack);
          return token; } } }
    SvREFCNT_dec(token); }
  /* if we fell through..
  Error('expected', '\fi', $gullet, "Missing \\fi or \\else, conditional fell off end",
  "Conditional started at $start"); */
  SvREFCNT_dec(sv_ifstack);
  croak("Missing \\fi or \\else: conditional fell off end from %s",SvPV_nolen(start)); }

  /*======================================================================
    C-level Parameter support */

SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn){
  SV * value = NULL;
  UTF8 spec = object_getPV(aTHX_ parameter,"spec");
  SV * reader = object_get(aTHX_ parameter,"reader");
  UTF8 opcode = NULL;
  parameter_op * op = NULL;
  SV ** ptr;
  int i;
  AV * semiverb = object_getAV(aTHX_ parameter, "semiverbatim");
  if(semiverb){
    int i,nc = av_len(semiverb)+1;
    UTF8 chars[nc];
    int nchars = 0;
    for(i = 0; i < nchars; i++){
      if( (ptr = av_fetch(semiverb,i,0)) ){
        chars[nchars++] = SvPV_nolen(*ptr); } }
    state_beginSemiverbatim(aTHX_ state, nchars, chars);
    SvREFCNT_dec(semiverb); }
  AV * extra = object_getAV(aTHX_ parameter, "extra");
  int nargs = (extra ? av_len(extra)+1 : 0);
  SV * args[nargs];
  if(extra){
    for(i = 0; i < nargs; i++){
      ptr = av_fetch(extra,i,0);
      args[i] = (ptr && SvOK(*ptr) ? *ptr : NULL); }
      SvREFCNT_dec(extra); }
  if(reader && sv_isa(reader,"LaTeXML::Core::Opcode")
     && (opcode = SvPV_nolen(SvRV(reader)))
     && (op = state_lookup_parameter_op(aTHX_ state, opcode))){
    DEBUG_Gullet("readArguments reading parameter %s [opcode=%s] for %p\n",
                 spec, opcode, fordefn);
    value = op(aTHX_ parameter, gullet, state, nargs, args); }
  else if(reader && SvTYPE(SvRV(reader)) == SVt_PVCV){ /* ref $expansion eq 'CODE' */
    DEBUG_Gullet("readArguments reading parameter %s for %p\n", spec, fordefn);
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,1+nargs); PUSHs(gullet);
    for(i=0; i<nargs; i++){
      SV * arg = (args[i] ? args[i] : &PL_sv_undef);
      PUSHs(arg); }
    PUTBACK;
    int nvals = call_sv(reader,G_SCALAR);
    SPAGAIN;
    if(nvals == 0){ }       /* nothing returned? */
    else if(nvals == 1){  
      value = POPs;
      if(! SvOK(value)){
        value = NULL; }
      else {
        SvREFCNT_inc(value); } }
    else {
      /* Or just warn of internal mis-definition? */
      croak("readArguments parameter reader for %p, returned %d values\n", fordefn, nvals); }
    PUTBACK; FREETMPS; LEAVE; }
  else {
    croak("No reader (CODE or Opcode) for parameter %s (%p) (opcode is %s)",spec, parameter, opcode); }
  if((! value) && !object_getBoole(aTHX_ parameter, "optional")){
    /*Error('expected', $self, $gullet,
      "Missing argument " . Stringify($self) . " for " . Stringify($fordefn),
      $gullet->showUnexpected);
      $value = T_OTHER('missing'); */
    croak("expected:argument %s",spec);  }

  if(semiverb){
    /*$value = $value->neutralize(@$semiverbatim) if (ref $value) && ($value->can('neutralize'));*/
    state_endSemiverbatim(aTHX_ state); }
  if(reader){ SvREFCNT_dec(reader); }
  return value; }

SV *                            /* read regular arg {} */
parameter_opcode_arg(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  LaTeXML_Core_Tokens tokens = gullet_readArg(aTHX_ gullet, state);
  if(tokens){
    SV * value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens);
    return value; }
  return NULL; }

SV *                            /* read regular arg {} */
parameter_opcode_xarg(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  LaTeXML_Core_Tokens tokens = gullet_readXArg(aTHX_ gullet, state);
  if(tokens){
    SV * value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens);
    return value; }
  return NULL; }

SV *                            /* read regular arg {} */
parameter_opcode_xbody(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  ENTER;    /* local $LaTeXML::NOEXPAND_THE = undef; */
  SV * noexpandthe = get_sv("LaTeXML::NOEXPAND_THE",0);
  save_item(noexpandthe);
  sv_setsv(noexpandthe,newSViv(1));
  LaTeXML_Core_Tokens tokens = gullet_readXArg(aTHX_ gullet, state);
  LEAVE;
  if(tokens){
    SV * value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens);
    return value; }
  return NULL; }

SV *                            /* read Token */
parameter_opcode_Token(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readToken(aTHX_ gullet, state); }

SV *                            /* read XToken */
parameter_opcode_XToken(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readXToken(aTHX_ gullet, state, 0, 0); }

SV *                            /* read CSName */
parameter_opcode_CSName(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readCSName(aTHX_ gullet, state); }

SV *                            /* Skip spaces */
parameter_opcode_SkipSpaces(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  gullet_skipSpaces(aTHX_ gullet, state);
  return NULL; }

SV *                            /* Skip 1 space */
parameter_opcode_SkipSpace(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
   gullet_skip1Space(aTHX_ gullet, state);
   return NULL; }

SV *                            /* read until next open brace (but don't include it) */
parameter_opcode_UntilBrace(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  LaTeXML_Core_Tokens tokens = gullet_readUntilBrace(aTHX_ gullet, state);
  if(tokens){
    SV * value = newSV(0);
    sv_setref_pv(value, "LaTeXML::Core::Tokens", (void*)tokens);
    return value; }
  return NULL; }

SV *                            /* require a brace (but don't include it) */
parameter_opcode_RequireBrace(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * token;
  LaTeXML_Core_Token t;
  if( (token = gullet_readToken(aTHX_ gullet, state))
      && (t = SvToken(token)) && (t->catcode == CC_BEGIN)){
    gullet_unreadToken(aTHX_ gullet, token);
    SvREFCNT_dec(token);
    /*return token; }*/
    return NULL; }
  else {
    /*croak("expected:{ Expected a { here"); *//* Do we need this? will be handled by parameter_read */
    return NULL; } }

SV *                            /* skip an = */
parameter_opcode_SkipEquals(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  gullet_skipEquals(aTHX_ gullet, state);
  return NULL; }

SV *                            /* skip an = */
parameter_opcode_Match(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  int type[nargs];
  int maxlength = gullet_prepareMatch(aTHX_ gullet, nargs, type, args);
  int match = gullet_readMatch(aTHX_ gullet, state, nargs,maxlength, type, args);
  return (match >= 0 ? SvREFCNT_inc(args[match]) : NULL); }

SV *                            /* skip an = */
parameter_opcode_Until(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  int type[nargs];
  int maxlength = gullet_prepareMatch(aTHX_ gullet, nargs, type, args);
  int match;
  LaTeXML_Core_Tokens tokens
    = gullet_readUntilMatch(aTHX_ gullet, state, 0, nargs,maxlength, type, args, &match);
  if(tokens){
    SV * sv = newSV(0);
    sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
    return sv; }
  else {
    return NULL; } }

SV *                            /* read a Number */
parameter_opcode_Number(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readNumber(aTHX_ gullet, state); }

SV *                            /* read a Dimension */
parameter_opcode_Dimension(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readDimension(aTHX_ gullet, state, 0, 0.0); }

SV *                            /* read a Skip */
parameter_opcode_Glue(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readGlue(aTHX_ gullet, state); }

SV *                            /* read a Muskip */
parameter_opcode_MuGlue(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readMuGlue(aTHX_ gullet, state); }

SV *                            /* Read a Float */
parameter_opcode_Float(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readFloat(aTHX_ gullet, state); }

SV *
parameter_opcode_DefParameters(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readDefParameters(aTHX_ gullet, state); }
  /*======================================================================
    C-level Expandable support */

SV *
expandable_opcode_csname(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * token = args[0];
  SV * meaning = state_meaning(aTHX_ state, token);
  if(meaning){
    SvREFCNT_dec(meaning); }
  else {                        /* Define as \relax, if not already defined. */
    LaTeXML_Core_Token t = SvToken(token);
    SV * relax = state_lookup_noinc(aTHX_ state, "meaning", "\\relax");
    state_assign_internal(aTHX_ state, "meaning", t->string, relax, "local"); }
  return token; }

HV *
expandable_newIfFrame(pTHX_ SV * conditional, SV * token, SV * gullet, SV * state){
  int ifid = state_intval(aTHX_ state, "if_count");
  state_assign_internal(aTHX_ state, "value", "if_count",newSViv(++ifid),"global");
  HV * ifframe = newHV();
  hv_store(ifframe, "token",   5, (token ? SvREFCNT_inc(token) : newSV(0)),0); /* ==undef */
  SV * loc = gullet_getLocator(aTHX_ gullet);
  hv_store(ifframe, "start",   5, loc, 0);
  hv_store(ifframe, "parsing", 7, newSViv(1), 0);
  hv_store(ifframe, "elses",   5, newSViv(0), 0);
  hv_store(ifframe, "ifid",    4, newSViv(ifid), 0);
  LaTeXML_Core_Token t = SvToken(token);    PERL_UNUSED_VAR(t); /* -Wall */
  SV * sv_ifstack = state_value(aTHX_ state, "if_stack");
  AV * ifstack;
  if(sv_ifstack){
    ifstack = SvArray(sv_ifstack); }
  else {
    ifstack = newAV();
    sv_ifstack = newRV_inc((SV *)ifstack);
    state_assign_internal(aTHX_ state, "value", "if_stack", sv_ifstack,"global"); }
  av_unshift(ifstack, 1);
  av_store(ifstack, 0, newRV_inc((SV *)ifframe)); /* why inc? */
  SvREFCNT_dec(sv_ifstack);
  /*fprintf(stderr,"NEWIFFRAME\n");
    Perl_sv_dump(aTHX_ sv_stack);*/
  return ifframe; }

SV *
expandable_getIFFrame(pTHX_ SV * state, UTF8 fortoken){
  SV * * ptr;
  SV * sv_ifstack = state_value(aTHX_ state, "if_stack");
  if(!sv_ifstack){
    croak("Didn't expect %s since we seem not to be in a conditional (no if_stack)",fortoken); }
  /*fprintf(stderr,"GETIFFRAME\n");
    Perl_sv_dump(aTHX_ sv_stack);*/

  AV * stack = SvArray(sv_ifstack);
  ptr = av_fetch(stack, 0, 0);
  if(!ptr){
    croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",fortoken); }
  SvREFCNT_dec(sv_ifstack);
  return *ptr; }
/*return SvHash(*ptr); }*/

SV *
expandable_getActiveIFFrame(pTHX_ SV * state, UTF8 fortoken){
  SV * * ptr;
  SV * sv_ifstack = state_value(aTHX_ state, "if_stack");
  if(!sv_ifstack){
    croak("Didn't expect %s since we seem not to be in a conditional (no if_stack)",fortoken); }
  AV * stack = SvArray(sv_ifstack);
  int i;
  int n = av_len(stack) + 1;
  for(i = 0; i < n; i++){
    ptr = av_fetch(stack, i, 0);
    if(!ptr){
      croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",
            fortoken); }
    else if(object_getBoole(aTHX_ *ptr, "parsing")){
      SvREFCNT_dec(sv_ifstack);
      return *ptr; } }
  croak("Internal error: no \\if frame is open for %s", fortoken);
  SvREFCNT_dec(sv_ifstack);
  return NULL; }

SV *
expandable_opcode_if(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * defnhash = SvHash(expandable);
  SV ** ptr;
  int ip;
  SV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\if");
  UTF8 ifid = object_getPV(aTHX_ ifframe,"ifid");
  object_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));

  SV * test = NULL;
  if( (ptr  = hv_fetchs(defnhash,"test",0)) /* $$expansable{test} */
      && SvOK(*ptr) ){
    test = *ptr; }
  else {
    croak("Missing test!"); }

  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,nargs+1); PUSHs(gullet);
  for(ip=0; ip<nargs; ip++){
    SV * arg = (args[ip] ? args[ip] : &PL_sv_undef);
    PUSHs(arg); }
  PUTBACK;
  int nvals = call_sv(test,G_SCALAR);
  DEBUG_Expandable("code returned %d values\n", nvals);
  SPAGAIN;
  int boolean = 0;
  if(nvals > 0){
    SV * sv = POPs;
    boolean = SvTRUE(sv); }
  PUTBACK; FREETMPS; LEAVE;
  for(ip = 0; ip < nargs; ip++){ /* NOW, we can clean up the args */
    SvREFCNT_dec(args[ip]); }
  if(! boolean){
    SV * t = gullet_skipConditionalBody(aTHX_ gullet, -1, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_iftrue(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iftrue");
  object_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));
  /* do nothing else! */
  return NULL; }

SV *
expandable_opcode_iffalse(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  object_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));
  UTF8 ifid = object_getPV(aTHX_ ifframe,"ifid");
  SV * t = gullet_skipConditionalBody(aTHX_ gullet, -1, ifid);
  if(t){ SvREFCNT_dec(t); }  
  return NULL; }

SV *
expandable_opcode_ifcase(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  object_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));
  UTF8 ifid = object_getPV(aTHX_ ifframe,"ifid");

  /* Better have 1 argument, and it should be a Number! */
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(args[0]); PUTBACK;
  int nvals = call_method("valueOf",G_SCALAR);
  SPAGAIN;
  int nskips = 0;
  if(nvals > 0){
    SV * sv = POPs;
    nskips = SvIV(sv); }
  PUTBACK; FREETMPS; LEAVE;
  int ip;
  for(ip = 0; ip < nargs; ip++){ /* NOW, we can clean up the args */
    SvREFCNT_dec(args[ip]); }
  if(nskips > 0){
    SV * t = gullet_skipConditionalBody(aTHX_ gullet, nskips, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_else(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * frame = expandable_getIFFrame(aTHX_ state, "\\else");
  if(object_getBoole(aTHX_ frame,"parsing")){
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 2);
    SV * relax =  token_new(aTHX_ "\\relax",CC_CS);
    tokens_add_to(aTHX_ tokens, relax,0); SvREFCNT_dec(relax);
    tokens_add_to(aTHX_ tokens, current_token,0);
    SV * result = newSV(0);
    sv_setref_pv(result, "LaTeXML::Core::Tokens", (void*) tokens);
    SvREFCNT_inc(result);
    return result; }
  else if (object_getIV(aTHX_ frame,"elses")){
    croak("extra XXX; already saw \\else for this level"); }
  else {
    UTF8 ifid = object_getPV(aTHX_ frame,"ifid");
    SV * t = gullet_skipConditionalBody(aTHX_ gullet, 0, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_fi(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * frame = expandable_getIFFrame(aTHX_ state, "\\fi");
  if(object_getBoole(aTHX_ frame,"parsing")){
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 2);
    SV * relax = token_new(aTHX_ "\\relax",CC_CS);
    tokens_add_to(aTHX_ tokens, relax,0); SvREFCNT_dec(relax);
    tokens_add_to(aTHX_ tokens, current_token,0);
    SV * result = newSV(0);
    sv_setref_pv(result, "LaTeXML::Core::Tokens", (void*) tokens);
    SvREFCNT_inc(result);
    return result; }
  else {
    SV * sv_ifstack = state_value(aTHX_ state, "if_stack");
    AV * ifstack = SvArray(sv_ifstack);
    SV * ignore = av_shift(ifstack); PERL_UNUSED_VAR(ignore); /* Done with this if frame */
    SvREFCNT_dec(sv_ifstack);  }
  return NULL; }

SV *
expandable_opcode_expandafter(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  /* NOTE: This reads it's own 2 tokens!!! */
  gullet_expandafter(aTHX_ gullet, state);
  return NULL; }

SV *
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS");
  int profiling= state_booleval(aTHX_ state, "PROFILING");
  SV * result = NULL;
  LaTeXML_Core_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Expandable("Invoke Expandable %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{token});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  SV * expansion = object_get(aTHX_ expandable, "expansion");
  UTF8 opcode = NULL;

  if(expansion && (sv_isa(expansion,"LaTeXML::Core::Opcode"))){
    opcode = SvPV_nolen(SvRV(expansion));
    SvREFCNT_dec(expansion); expansion = NULL; }

  /* GENERALIZE this to (before|after)expand ?   BEFORE reading arguments! */
  if(opcode && (strncmp(opcode,"if",2)==0)){ /* Prepare if stack frame for if's */
    HV * ignore = expandable_newIfFrame(aTHX_ expandable, token, gullet, state);
    PERL_UNUSED_VAR(ignore); }
  /* Read arguments */
  int ip;
  int nargs = 0;
  AV * parameters = object_getAV(aTHX_ expandable, "parameters");
  SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
  SV * args[npara];
  if(parameters){       /* If no parameters, nothing to read! */
    DEBUG_Expandable("reading %ld parameters\n", npara);
    nargs = gullet_readArguments(aTHX_ gullet, npara, parameters, token, args);
    DEBUG_Expandable("got %d arguments\n", nargs);
    SvREFCNT_dec(parameters); }

  if(opcode){
    expandable_op * op = state_lookup_expandable_op(aTHX_ state, opcode);
    if(op){
      result = op(aTHX_ token, expandable, gullet, state, nargs, args); }
    else {
      croak("Internal error: Expandable opcode %s has no definition",opcode); } }
  else {
    if(! SvOK(expansion)){      /* empty? */
      SvREFCNT_dec(expansion);
      DEBUG_Expandable("Expansion is empty\n"); }
    else if(SvTYPE(SvRV(expansion)) == SVt_PVCV){ /* ref $expansion eq 'CODE' */
      /* result = tokens_new(  &$expansion($gullet, @args)); */
      DEBUG_Expandable("Expansion is code %p\n", expansion);
      dSP;
      ENTER; SAVETMPS; PUSHMARK(SP);
      EXTEND(SP,nargs+1); PUSHs(gullet);
      for(ip=0; ip<nargs; ip++){
        /* No need for mortal/refcnt stuff, since args will be explicitly decremented later*/
        SV * arg = (args[ip] ? args[ip] : &PL_sv_undef);
        PUSHs(arg); }
      PUTBACK;
      int nvals = call_sv(expansion,G_ARRAY);
      DEBUG_Expandable("code returned %d values\n", nvals);
      SPAGAIN;
      LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ nvals);
      if(nvals > 0){
        SP -= nvals;
        I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
        for(ip = 0; ip < nvals; ip++){
          tokens_add_to(aTHX_ tokens, ST(ip), 0); } }
      result = newSV(0);
      sv_setref_pv(result, "LaTeXML::Core::Tokens", (void*) tokens);
      PUTBACK; FREETMPS; LEAVE;
      if(tracing){
        /* print STDERR "\n" . $self->tracingCSName($token) . ' ==> ' . tracetoString($result) . "\n";
           print STDERR $self->tracingArgs(@args) . "\n" if @args; */ }
      SvREFCNT_dec(expansion); }
    else if(sv_isa(expansion, "LaTeXML::Core::Tokens")) {
      IV tmp = SvIV((SV*)SvRV(expansion));
      LaTeXML_Core_Tokens tokens = INT2PTR(LaTeXML_Core_Tokens, tmp);
      DEBUG_Expandable("Expansion is tokens %p\n", expansion);
      if(tracing){
        /* print STDERR "\n" . $self->tracingCSName($token)
           . ' -> ' . tracetoString($expansion) . "\n";
           print STDERR $self->tracingArgs(@args) . "\n" if @args; */ }
      LaTeXML_Core_Tokens tresult = tokens_substituteParameters(aTHX_ tokens, nargs, args);
      result = newSV(0);
      sv_setref_pv(result, "LaTeXML::Core::Tokens", (void*) tresult);
      SvREFCNT_dec(expansion); }
    else {
      croak("expansion is not CODE or of type LaTeXML::Core::Tokens");
      SvREFCNT_dec(expansion); }
    for(ip = 0; ip < nargs; ip++){ /* NOW, we can clean up the args */
      SvREFCNT_dec(args[ip]); }
    }
   /*
    # Getting exclusive requires dubious Gullet support!
    #####push(@result, T_MARKER($profiled)) if $profiled; */
  DEBUG_Expandable("Returning expansion %p\n", result);
  return result; }

  /*======================================================================
    C-level Primitive support */
void
primitive_opcode_register(pTHX_ SV * token, SV * regdefn, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Core_Boxstack stack){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * stomachhash = SvHash(stomach);
  /* args to register are in args, but not "= value" */
  SV * gullet;
  SV ** ptr;
  if( (ptr  = hv_fetchs(stomachhash,"gullet",0)) && SvOK(*ptr) ){
    gullet = (SV *) *ptr; }
  else {
    croak("Stomach %p has no Gullet!", stomach); }
  UTF8 type = object_getPV(aTHX_ regdefn, "registerType");
  gullet_skipEquals(aTHX_ gullet, state);
  SV * value = gullet_readValue(aTHX_ gullet, state, type);
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,nargs+2); PUSHs(regdefn); PUSHs(value);
  int i;
  for(i=0; i<nargs; i++){
    SV * arg = (args[i] ? args[i] : &PL_sv_undef);
    PUSHs(arg); }
  PUTBACK;
  call_method("setValue",G_DISCARD);
  SPAGAIN; PUTBACK; FREETMPS; LEAVE;
  state_afterAssignment(aTHX_ state); }

void
primitive_invoke(pTHX_ SV * primitive, SV * token, SV * stomach, SV * state,
                 LaTeXML_Core_Boxstack stack){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  int profiling= state_booleval(aTHX_ state, "PROFILING");
  LaTeXML_Core_Token t = SvToken(token);PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Primitive("Invoke Primitive %p %s[%s]\n",primitive,CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  /* Call beforeDigest daemons */
  AV * before = object_getAV(aTHX_ primitive, "beforeDigest");
  if(before){
    DEBUG_Primitive("%p calling beforeDigest %p\n", primitive, before);
    boxstack_callAV(aTHX_ stack, primitive, before, state, stomach, token, 0, NULL);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(before); }
  /* Read arguments */
  AV * parameters = object_getAV(aTHX_ primitive, "parameters");
  SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
  int nargs = 0;
  SV * args[npara];
  if(parameters){       /* If no parameters, nothing to read! */
    SV * gullet = object_get(aTHX_ stomach, "gullet");
    DEBUG_Primitive("reading %ld parameters\n", npara);
    nargs = gullet_readArguments(aTHX_ gullet, npara, parameters, token, args);
    DEBUG_Primitive("got %d arguments\n", nargs);
    SvREFCNT_dec(parameters); }
  /* Call main replacement:  opcode, if defined, or function */
  SV * replacement = object_get(aTHX_ primitive, "replacement");
  if(replacement){
    DEBUG_Primitive("%p calling replacement %p\n", primitive, replacement);
    boxstack_call(aTHX_ stack, primitive, replacement, state, stomach, token, nargs, args);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(replacement); }

  /* Call afterDigest daemons */
  AV * after = object_getAV(aTHX_ primitive, "afterDigest");
  if(after){
    DEBUG_Primitive("%p calling afterDigest %p\n", primitive, after);
    boxstack_callAV(aTHX_ stack, primitive, after, state, stomach, token, nargs, args);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(after); }
  int i;
  for(i = 0; i < nargs; i++){   /* Now cleanup args */
    SvREFCNT_dec(args[i]); }
  DEBUG_Primitive("Primitive %p %s[%s] returned %d boxes\n",
                  primitive,CC_SHORT_NAME[t->catcode],t->string,stack->nboxes);
}

  /*======================================================================
    C-level Stomach support */
SV *
stomach_getLocator(pTHX_ SV * stomach){
  SV * gullet = object_get_noinc(aTHX_ stomach, "gullet");
  if(gullet){
    return gullet_getLocator(aTHX_ gullet); }
  else {
    return newSVpv("Unknown",0); } }

SV *
state_getLocator(pTHX_ SV * state){
  SV * stomach = object_get_noinc(aTHX_ state, "stomach");
  SV * gullet = (stomach ? object_get_noinc(aTHX_ stomach, "gullet") : NULL);
  if(gullet){
    return gullet_getLocator(aTHX_ gullet); }
  else {
    return newSVpv("Unknown",0); } }

void
stomach_defineUndefined(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* $stomach->invokeToken_undefined($token) */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_undefined", state, stomach, token,nargs, args); }

void
stomach_insertComment(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_comment", state, stomach, token,nargs, args); }

void
stomach_insertBox(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_insert", state, stomach, token,nargs, args); }

void                            /* NOTE: Really only for constructors */
stomach_invokeDefinition(pTHX_ SV * stomach, SV * state, SV * token, SV * defn, LaTeXML_Core_Boxstack stack){
  /*  @result = $meaning->invoke($token, $self);
      $STATE->clearPrefixes unless $meaning->isPrefix; */
    /*Clear prefixes unless we just set one.*/
  SV * args[] = {token, defn};
  int nargs = 2;
  boxstack_callmethod(aTHX_ stack, "invokeToken_definition", state, stomach, token, nargs, args); }

int absorbable_cc[] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0};

void
stomach_invokeToken(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* push tokon token stack*/
  /* if maxstack, fatal */
 REINVOKE:
  if(! token){
    return; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  DEBUG_Stomach("Invoke token %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  char * name =
    (ACTIVE_OR_CS [cc]
     || (letter_or_other[cc] && state_booleval(aTHX_ state, "IN_MATH")
         && (state_mathcode(aTHX_ state, t->string) == 0x8000))
     ? t->string
     : EXECUTABLE_NAME[cc]);
  SV * defn = NULL;
  SV * insert_token = NULL;    /* Common case, default */
  if(name && (defn = state_lookup_noinc(aTHX_ state, "meaning", name)) ){
    /* If \let to an executable token, lookup IT's defn! */
    if(sv_isa(defn, "LaTeXML::Core::Token")){
      LaTeXML_Core_Token let = SvToken(defn);
      char * letname;
      SV * letdefn;
      if( (letname = EXECUTABLE_NAME[let->catcode])
          && (letdefn = state_lookup_noinc(aTHX_ state, "meaning", letname)) ){
        if(sv_isa(letdefn, "LaTeXML::Core::Token")){ /* And if that's a token? */
          insert_token = letdefn; /*SvREFCNT_dec(defn);*/ defn = NULL; }
        else {
          defn = letdefn; } }
      else {
        insert_token = defn; defn = NULL; } } }
  else {
    insert_token = token; }
  if(insert_token){
    LaTeXML_Core_Token it = SvToken(insert_token);
    DEBUG_Stomach("Invoke token self-insert %s[%s]\n",CC_SHORT_NAME[it->catcode],it->string); }
  else {
    DEBUG_Stomach("Invoke defn %p [%s]\n", defn, sv_reftype(SvRV(defn),1));
    /*Perl_sv_dump(aTHX_ defn);*/
  }

  if (insert_token) {    /* Common case*/
    LaTeXML_Core_Token it = SvToken(insert_token);
    int icc = it->catcode;
    if (icc == CC_CS) {
      DEBUG_Stomach("Invoking undefined\n");
      stomach_defineUndefined(aTHX_ stomach, state, insert_token, stack); }
    else if (icc == CC_COMMENT) {
      DEBUG_Stomach("Inserting comment\n");
      stomach_insertComment(aTHX_ stomach, state, insert_token, stack); }
    else if (absorbable_cc[icc]) {
      DEBUG_Stomach("Inserting box\n");
      stomach_insertBox(aTHX_ stomach, state, insert_token, stack); }
    else {
      croak("misdefined: The token %s[%s] => %s[%s] should never reach Stomach!",
            CC_SHORT_NAME[t->catcode],t->string,
            CC_SHORT_NAME[it->catcode],it->string); } }
  /* A math-active character will (typically) be a macro,
     but it isn't expanded in the gullet, but later when digesting, in math mode (? I think) */
  else if (object_getBoole(aTHX_ defn,"isExpandable")){
    SvREFCNT_inc(defn);
    SV * gullet = object_get(aTHX_ stomach, "gullet");
    SV * exp = expandable_invoke(aTHX_ defn, token, gullet, state);
    DEBUG_Stomach("Invoking expandable\n");
    gullet_unreadToken(aTHX_ gullet, exp);
    token = gullet_readXToken(aTHX_ gullet, state, 0, 0); /* replace token by it's expansion!!!*/
    /*pop(@{ $$self{token_stack} });*/
    SvREFCNT_dec(gullet);
    SvREFCNT_dec(defn);
    goto REINVOKE; }
  /*  elsif ($meaning->isaDefinition) { */   /* Otherwise, a normal primitive or constructor*/
  /* IF it IS a primitive (not derived from, yet), call direct */
  else if(sv_isa(defn,"LaTeXML::Core::Definition::Primitive")
          || (sv_isa(defn,"LaTeXML::Core::Definition::Register")) ) {
    SvREFCNT_inc(defn);
    primitive_invoke(aTHX_ defn, token, stomach, state, stack);
    if(!(sv_isa(defn,"LaTeXML::Core::Definition::Primitive")
         || (sv_isa(defn,"LaTeXML::Core::Definition::Register")) )){
      fprintf(stderr,"\nOH NO! definition got wrecked:\n"); Perl_sv_dump(aTHX_ defn); }
    if(! object_getBoole(aTHX_ defn, "isPrefix")){
      state_clearPrefixes(aTHX_ state); }
    SvREFCNT_dec(defn);
  }
  else if(sv_derived_from(defn,"LaTeXML::Core::Definition")) {
    SvREFCNT_inc(defn);
    DEBUG_Stomach("Invoking Constructor\n");
    stomach_invokeDefinition(aTHX_ stomach, state, token, defn, stack);
    SvREFCNT_dec(defn); }
  else {
    croak("misdefined: The token %s[%s] => %p [%s] should never reach Stomach!",
          CC_SHORT_NAME[t->catcode],t->string, defn, sv_reftype(SvRV(defn),1)); }
  /*
  if ((scalar(@result) == 1) && (!defined $result[0])) {
  @result = (); }  */                                     /*Just paper over the obvious thing.*/
  /*
  Fatal('misdefined', $token, $self,
    "Execution yielded non boxes",
    "Returned " . join(',', map { "'" . Stringify($_) . "'" }
        grep { (!ref $_) || (!$_->isaBox) } @result))
        if grep { (!ref $_) || (!$_->isaBox) } @result; */
  /*pop(@{ $$self{token_stack} });*/
  /*return @result; */
 }

  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Perl Modules
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/
  /* REMEMBER: DO NOT RETURN NULL!!!! Return &PL_sv_undef !!! */
 # /*======================================================================
 #    LaTeXML::Core::State
 #   ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::State
PROTOTYPES: ENABLE

void
assign_internal(state, table, key, value, ...)
    SV * state;
    UTF8 table;
    UTF8 key;
    SV * value;
  CODE:   
    UTF8 scope = ((items > 4) && SvOK(ST(4)) ? SvPV_nolen(ST(4)) : NULL);
    state_assign_internal(aTHX_ state, table, key, value, scope);

void
pushFrame(state)
    SV * state;
  PPCODE:
    state_pushFrame(aTHX_ state);

void
popFrame(state)
    SV * state;
  PPCODE:
    state_popFrame(aTHX_ state);

int
lookupCatcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_catcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignCatcode(state,string,catcode,...)
    SV * state;
    UTF8 string;
    int catcode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvOK(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_internal(aTHX_ state, "catcode",string,newSViv(catcode),scope);

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
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
assignValue(state,string,value, ...)
    SV * state;
    UTF8 string;
    SV * value;
  CODE:
    UTF8 scope = ((items > 3) && SvOK(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_internal(aTHX_ state, "value", string, value, scope);

SV *
lookupMeaning(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_meaning(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
beginSemiverbatim(state,...)
    SV * state;      
  INIT:
    int nchars = items-1;
    UTF8 chars[items-1];
    int i;
  PPCODE:
    for(i=0; i < nchars; i++){
      SV * sv = ST(i+1);
      chars[i] = SvPV_nolen(sv); }
    state_beginSemiverbatim(aTHX_ state, nchars, chars); 

void
endSemiverbatim(state)
    SV * state;      
  PPCODE:
    state_endSemiverbatim(aTHX_ state); 

void
assignMeaning(state, token, meaning,...)
    SV * state;
    SV * token;
    SV * meaning;
  CODE:
    UTF8 scope = ((items > 3) && SvOK(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    if (! (SvOK(token) && sv_isa(token, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token is not a Token"); }
    if(SvOK(meaning) && sv_isa(meaning, "LaTeXML::Core::Token")
       && token_equals(aTHX_ token,meaning)){
      } /* Hack; ignore assigment to itself */
    else {
      LaTeXML_Core_Token t = SvToken(token);
      UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
      name = (name == NULL ? t->string : name);
      state_assign_internal(aTHX_ state, "meaning", name, meaning, scope); }

void
let(state, token1, token2,...)
    SV * state;
    SV * token1;
    SV * token2;
  CODE:
    UTF8 scope = ((items > 3) && SvOK(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    if (! (SvOK(token1) && sv_isa(token1, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token1 is not a Token"); }
    if (! (SvOK(token2) && sv_isa(token2, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token2 is not a Token"); }
    SV * meaning = state_meaning(aTHX_ state, token2);
    if(meaning && sv_isa(meaning, "LaTeXML::Core::Token")
       && token_equals(aTHX_ token1,meaning)){
    }
    else {
      LaTeXML_Core_Token t1 = SvToken(token1);
      UTF8 name1 = PRIMITIVE_NAME[t1->catcode]; /* getCSName */
      name1 = (name1 == NULL ? t1->string : name1);
      state_assign_internal(aTHX_ state, "meaning", name1, meaning, scope); }
    if(meaning){ SvREFCNT_dec(meaning); }

SV *
lookupExpandable(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_expandable(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
lookupDefinition(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_definition(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
installDefinition(state, definition, ...)
    SV * state;
    SV * definition;
  CODE:
    UTF8 scope = ((items > 2) && SvOK(ST(2)) ? SvPV_nolen(ST(2)) : NULL);
    HV * hash = SvHash(definition);
    SV ** ptr = hv_fetchs(hash,"cs",0);
    if(! ptr){
      croak("Definition doesn't have a CS!"); }
    LaTeXML_Core_Token t = SvToken(*ptr);
    UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
    name = (name == NULL ? t->string : name);
    int nlen = strlen(name);
    char lock[nlen+8];
    strncpy(lock,name,nlen);
    strcpy(lock+nlen,":locked");
    SV * tmp;
    if ( state_booleval(aTHX_ state, lock)
         && ( ! (tmp = get_sv("LaTeXML::Core::State::UNLOCKED",0)) || !SvTRUE(tmp)) ) {
      /*fprintf(stderr,"Ignoring redefinition of %s\n",name);*/
      /*
       if (my $s = $self->getStomach->getGullet->getSource) {
         # report if the redefinition seems to come from document source
         if ((($s eq "Anonymous String") || ($s =~ /\.(tex|bib)$/))
           && ($s !~ /\.code\.tex$/)) {
           Info('ignore', $cs, $self->getStomach, "Ignoring redefinition of $cs"); }
           return; } */
    }
    else {
      state_assign_internal(aTHX_ state, "meaning", name, definition, scope); }

void
afterAssignment(state)
    SV * state;
  PPCODE:
    state_afterAssignment(aTHX_ state);

SV *
getLocator(state)
    SV * state;
  CODE:  
    RETVAL = state_getLocator(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
convertUnit(state,unit)
    SV * state;
    UTF8 unit;
  CODE:
    UTF8 p = unit;
    while(*p){ *p = tolower(*p); p++; }  /* lc(unit)!  Is this safe? in-place ? */
    SV * units = object_get_noinc(aTHX_ state,"units");
    SV * value = object_get(aTHX_ units,unit);
    if(value){
      RETVAL = value; }
    else {
      warn("expected:<unit> Illegal unit of measure '%s', assumning pt.",unit);
      RETVAL = newSVnv(SCALED_POINT); }
  OUTPUT:
    RETVAL

void
installOpcodes(state)
    SV * state;
  CODE:  
    /* Install Expandable Opcodes */
    state_install_expandable_op(aTHX_ state, "CSName",       &expandable_opcode_csname);
    state_install_expandable_op(aTHX_ state, "if",           &expandable_opcode_if);
    state_install_expandable_op(aTHX_ state, "iftrue",       &expandable_opcode_iftrue);
    state_install_expandable_op(aTHX_ state, "iffalse",      &expandable_opcode_iffalse);
    state_install_expandable_op(aTHX_ state, "ifcase",       &expandable_opcode_ifcase);
    state_install_expandable_op(aTHX_ state, "else",         &expandable_opcode_else);
    state_install_expandable_op(aTHX_ state, "or",           &expandable_opcode_else);
    state_install_expandable_op(aTHX_ state, "fi",           &expandable_opcode_fi);
    state_install_expandable_op(aTHX_ state, "expandafter",  &expandable_opcode_expandafter);
    /* Install Parameter Reader Opcodes */
    state_install_parameter_op(aTHX_ state, "Arg",           &parameter_opcode_arg);
    state_install_parameter_op(aTHX_ state, "XArg",          &parameter_opcode_xarg);
    state_install_parameter_op(aTHX_ state, "XBody",         &parameter_opcode_xbody);
    state_install_parameter_op(aTHX_ state, "Token",         &parameter_opcode_Token);
    state_install_parameter_op(aTHX_ state, "XToken",        &parameter_opcode_XToken);
    state_install_parameter_op(aTHX_ state, "CSName",        &parameter_opcode_CSName);
    state_install_parameter_op(aTHX_ state, "SkipSpace",     &parameter_opcode_SkipSpace);
    state_install_parameter_op(aTHX_ state, "SkipSpaces",    &parameter_opcode_SkipSpaces);
    state_install_parameter_op(aTHX_ state, "SkipEquals",    &parameter_opcode_SkipEquals);
    state_install_parameter_op(aTHX_ state, "Match",         &parameter_opcode_Match);
    state_install_parameter_op(aTHX_ state, "Until",         &parameter_opcode_Until);
    state_install_parameter_op(aTHX_ state, "UntilBrace",    &parameter_opcode_UntilBrace);
    state_install_parameter_op(aTHX_ state, "RequireBrace",  &parameter_opcode_RequireBrace);
    state_install_parameter_op(aTHX_ state, "Number",        &parameter_opcode_Number);
    state_install_parameter_op(aTHX_ state, "Dimension",     &parameter_opcode_Dimension);
    state_install_parameter_op(aTHX_ state, "Glue",          &parameter_opcode_Glue);
    state_install_parameter_op(aTHX_ state, "MuGlue",        &parameter_opcode_MuGlue);
    state_install_parameter_op(aTHX_ state, "Float",         &parameter_opcode_Float);
    state_install_parameter_op(aTHX_ state, "DefParameters", &parameter_opcode_DefParameters);
    /* Install Primitive Opcodes */
    state_install_primitive_op(aTHX_ state, "register",      &primitive_opcode_register);
    /* Install Units */
    HV * units = newHV();
    int i;
    for(i = 0; i < MAX_UNITS; i++){
      hv_store(units, UNIT_NAME[i],strlen(UNIT_NAME[i]), newSVnv(UNIT_VALUE[i]),0); }
    HV * hash = SvHash(state);
    hv_store(hash,"units",5,newRV_noinc((SV*)units),0);

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
    if(RETVAL == NULL){ croak("NULL from getMeaningName"); }
  OUTPUT:
    RETVAL

UTF8
getExpandableName(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = (ACTIVE_OR_CS [self->catcode]
              ? self->string
              : EXECUTABLE_NAME[self->catcode]);
    if(RETVAL == NULL){ croak("NULL from getExpandableName"); }
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
     /*RETVAL = token_equals(aTHX_ SvRV(a),SvRV(b)); }*/
     RETVAL = token_equals(aTHX_ a,b); }
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
 #   LaTeXML::Common::Dimension
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Common::Dimension

SV *
formatScaled(sp)
    int sp;
  INIT:
    char buffer[3*sizeof(int)*CHAR_BIT/8 + 2];
    int ptr = number_formatScaled(aTHX_ buffer, sp);
  CODE:
    RETVAL = newSVpv(buffer,ptr);
  OUTPUT:
    RETVAL

SV *
pointformat(sp)
    int sp;
  INIT:
    char buffer[3*sizeof(int)*CHAR_BIT/8 + 2 + 2]; /* 2 extra for 'pt' */
    int ptr = number_formatScaled(aTHX_ buffer, sp);
  CODE:
    buffer[ptr++] = 'p';
    buffer[ptr++] = 't';
    buffer[ptr] = 0;
   /*fprintf(stderr,"POINTFORMAT of %d ==> %s\n",sp,buffer);*/
    RETVAL = newSVpv(buffer,ptr);
  OUTPUT:
    RETVAL

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
      RETVAL = ST(0);
      SvREFCNT_inc(RETVAL); }   /* or mortal? */
    else {
      tokens = tokens_new(aTHX_ items);
      for (i = 0 ; i < items ; i++) {
        SV * sv = newSVsv(ST(i));
        tokens_add_to(aTHX_ tokens,sv,0);
        SvREFCNT_dec(sv); }
     DEBUG_Tokens( "done %d.\n", tokens->ntokens);
     RETVAL = newSV(0);
     sv_setref_pv(RETVAL, "LaTeXML::Core::Tokens", (void*)tokens);
    }
  OUTPUT:
    RETVAL

int
equals(a, b)
    SV * a
    SV * b
  CODE:
   if (SvOK(a) && sv_isa(a, "LaTeXML::Core::Tokens")
       && SvOK(b) && sv_isa(b, "LaTeXML::Core::Tokens")) {
     RETVAL = tokens_equals(aTHX_ SvTokens(a),SvTokens(b)); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

UTF8
toString(tokens)
    LaTeXML_Core_Tokens tokens;
  CODE:
    RETVAL = tokens_toString(aTHX_ tokens);
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
      PUSHs(sv_2mortal(SvREFCNT_inc(self->tokens[i]))); }

void
revert(self)
    LaTeXML_Core_Tokens self
  INIT:                    /* same as unlist */
    int i;
  PPCODE:
    EXTEND(SP, self->ntokens);
    for(i = 0; i < self->ntokens; i++) {
      PUSHs(sv_2mortal(SvREFCNT_inc(self->tokens[i]))); }

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
    int nargs = items-1;
    SV * args[nargs];
  CODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+1);
      if(! SvOK(arg)){
        arg = NULL; }
      args[i] = arg; }
    RETVAL = tokens_substituteParameters(aTHX_ self, nargs, args);
    if(RETVAL == NULL){ croak("NULL from substituteParameters"); }
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
    SV * sv = newSVsv(token);
    tokenstack_push(aTHX_ stack,sv); 
    SvREFCNT_dec(sv);

SV *
pop(stack)
    LaTeXML_Core_Tokenstack stack;
  CODE:
    RETVAL = tokenstack_pop(aTHX_ stack);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Mouth
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Mouth

SV *
new_internal(class,source,short_source,content,saved_state,note_message)
      UTF8 class;
      UTF8 source;
      UTF8 short_source;
      UTF8 content;
      SV * saved_state;
      UTF8 note_message;
  INIT:
    LaTeXML_Core_Mouth mouth
      = mouth_new(aTHX_ source,short_source,content,saved_state,note_message); 
  CODE:
    RETVAL = newSV(0);
    sv_setref_pv(RETVAL, class, (void*)mouth);
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

SV *
getLocator(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:  
    RETVAL = mouth_getLocator(aTHX_ mouth);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

UTF8
getSource(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth->source;
    if(RETVAL == NULL){ croak("NULL from getSource"); }
  OUTPUT:
    RETVAL

UTF8
getShortSource(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->short_source;
    if(RETVAL == NULL){ croak("NULL from getShortSource"); }
  OUTPUT:
    RETVAL

UTF8
getNoteMessage(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->note_message;
    if(RETVAL == NULL){ croak("NULL from getNoteMessage"); }
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
  CODE:
    RETVAL = mouth_readToken(aTHX_ mouth, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
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
    if(RETVAL == NULL){ croak("NULL from readTokens"); }
  OUTPUT:
    RETVAL
  
void
unread(mouth,...)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i));
      mouth_unreadToken(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

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
        RETVAL = newSVpvn_flags(mouth->chars+pstart,n, SVf_UTF8); }
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
  CODE:
    RETVAL = gullet_readToken(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
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
      SV * sv = newSVsv(ST(i));
      mouth_unreadToken(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

SV *
getLocator(gullet)
    SV * gullet;
  CODE:  
    RETVAL = gullet_getLocator(aTHX_ gullet);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
   /*else { sv_2mortal(RETVAL); }  WHY NOT????????*/
  OUTPUT:
    RETVAL

SV *
readXToken(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int toplevel=0,commentsok=0;
  CODE:
    if(items > 1){
      toplevel = SvIV(ST(1));
      if(items > 2){
        commentsok = SvIV(ST(2)); } }
    PUTBACK;
    RETVAL = gullet_readXToken(aTHX_ gullet, state, toplevel, commentsok);
    SPAGAIN;
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
expandafter(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_expandafter(aTHX_ gullet, state);

LaTeXML_Core_Tokens
readXUntilEnd(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readXUntilEnd(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ croak("NULL from readXUntilEnd"); }
  OUTPUT:
    RETVAL

SV *
readNonSpace(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readNonSpace(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
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
    gullet_readBalanced(aTHX_ gullet, state, tokens, 0);
    RETVAL = tokens;
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readXBalanced(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  CODE:
    gullet_readBalanced(aTHX_ gullet, state, tokens, 1);
    RETVAL = tokens;
  OUTPUT:
    RETVAL
    
LaTeXML_Core_Tokens
readArg(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readXArg(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readXArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readUntilBrace(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readUntilBrace(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readUntilBrace"); }
  OUTPUT:
    RETVAL

SV *
readCSName(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readCSName(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
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
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);
    match = gullet_readMatch(aTHX_ gullet, state, nchoices,maxlength, type, choices);
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
  PPCODE:
    DEBUG_Gullet("readUntil: start\n");
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    for(choice = 0; choice < nchoices; choice++){
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);

    LaTeXML_Core_Tokens tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 0, nchoices, maxlength, type, choices, &match);
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
        sv = sv_2mortal(SvREFCNT_inc(choices[match]));
        PUSHs(sv); } }

void
readXUntil(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  PPCODE:
    DEBUG_Gullet("readUntil: start\n");
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    for(choice = 0; choice < nchoices; choice++){
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);

    LaTeXML_Core_Tokens tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 1, nchoices, maxlength, type, choices, &match);
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
        sv = sv_2mortal(SvREFCNT_inc(choices[match]));
        PUSHs(sv); } }

SV *
readKeyword(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    char * choices[nchoices];
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
      choices[choice] = SvPV_nolen(key);
      DEBUG_Gullet("readKeyword: choice %d = %s\n",choice,choices[choice]); }

    /* Common case! */
    match = gullet_readKeyword(aTHX_ gullet, state, nchoices, choices);

   if(match >= 0){
     DEBUG_Gullet("readKeyword: Succeeded choice %d\n",match);
     RETVAL = ST(1+match);
     SvREFCNT_inc(RETVAL); }
   else {
     DEBUG_Gullet("readKeyword: Failed\n");
     RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
readOptionalSigns(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readOptionalSigns(aTHX_ gullet, state_global(aTHX));
  OUTPUT:
    RETVAL

SV *
readNumber(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readNumber(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readDimension(gullet,...)
    SV * gullet;
  INIT:
    int nocomma = 0;
    double defaultunit = 0.0;
  CODE:
    if(items > 1){
      SV * arg = ST(1);
      nocomma = SvOK(arg); }
    if(items > 2){
      SV * arg = ST(1);      
      defaultunit = SvNV(arg); }
    RETVAL = gullet_readDimension(aTHX_ gullet, state_global(aTHX), nocomma, defaultunit);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readGlue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readMuGlue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readMuGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readFloat(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readFloat(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readTokensValue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readTokensValue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readValue(gullet,type)
    SV * gullet;
    UTF8 type;
  CODE:
    RETVAL = gullet_readValue(aTHX_ gullet,state_global(aTHX),type);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readArgument(gullet, parameter, fordefn)
    SV * gullet;
    SV * parameter;
    SV * fordefn;
  CODE:
    RETVAL = parameter_read(aTHX_ parameter, gullet, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
readArguments(gullet, parameters, fordefn)
    SV * gullet;
    SV * parameters;
    SV * fordefn;
  PPCODE:
    if(SvOK(parameters)){       /* If no parameters, nothing to read! */
      AV * params = SvArray(parameters);
      SSize_t npara = av_len(params) + 1;
      SV * values[npara];
      PUTBACK;
      int nargs = gullet_readArguments(aTHX_ gullet, npara, params, fordefn, values);
      SPAGAIN;
      int ip;
      /*fprintf(stderr,"GOT %ld parameters, %d arguments for %s\n",npara,nargs, name);*/
      EXTEND(SP,nargs);
      for(ip = 0; ip < nargs; ip++){
        SV * arg = values[ip];
        if(arg){
          arg =sv_2mortal(arg); }
        else {
          arg = &PL_sv_undef; }
        PUSHs(arg); }
    }

 #/*======================================================================
 #   LaTeXML::Core::Parameter
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Parameter

SV *
read(parameter, gullet, ...)
    SV * gullet;
    SV * parameter;
  INIT:
    SV * fordefn = NULL;
  CODE:
    if(items > 2){
      fordefn = ST(3); }
    RETVAL = parameter_read(aTHX_ parameter, gullet, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL


 #/*======================================================================
 #   LaTeXML::Core::Definition::Expandable
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Definition::Expandable

SV *
new(class,cs,parameters,expansion,...)
    UTF8 class;
    SV * cs;
    SV * parameters;
    SV * expansion;
  INIT:  
    SV * state = state_global(aTHX);
    HV * hash = newHV();
    int i;
  CODE:
    if((items-4) % 2){
      croak("Odd number of hash elements in Expandable->new"); }
    /* tokenize expansion ? */
    /* expansion = Tokens(expansion) if ref expansion Token ? */
    if(!SvOK(cs) || !sv_isa(cs, "LaTeXML::Core::Token")) {
      croak("Undefined cs!\n");}
    if(!SvOK(expansion)){
      expansion = NULL; }
    else if(sv_isa(expansion, "LaTeXML::Core::Token")) {
      LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
      tokens_add_to(aTHX_ tokens,expansion,0);
      expansion = newSV(0);
      sv_setref_pv(expansion, "LaTeXML::Core::Tokens", (void*) tokens); }
      
    /* check expansion balanced */
    if(!SvOK(parameters)){ /* or empty? */
      parameters = NULL; }
    hv_store(hash, "cs",2, SvREFCNT_inc(cs),0);
    if(parameters){
      hv_store(hash,"parameters",10,SvREFCNT_inc(parameters),0); }
    if(expansion){
      hv_store(hash,"expansion",    9,SvREFCNT_inc(expansion),0); }
    hv_store(hash,"locator",      7,state_getLocator(aTHX_ state),0);
    hv_store(hash,"isProtected", 11,newSViv(state_prefix(aTHX_ state, "protected")),0);
    hv_store(hash,"isExpandable",12,newSViv(1),0);
    for(i = 4; i < items; i+=2){
      SV * keysv = ST(i);
      SV * value = ST(i+1);
      if(SvOK(keysv) && SvOK(value)){
        STRLEN keylen;
        UTF8 key = SvPV(ST(i),keylen);
        hv_store(hash,key,keylen,SvREFCNT_inc(value),0); }}
    RETVAL = newRV_noinc((SV*)hash);
    sv_bless(RETVAL, gv_stashpv(class,0));
  OUTPUT:    
    RETVAL
    
void
invoke(self, token, gullet)
    SV * self;
    SV * token;
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    SV * result;
  PPCODE:
    PUTBACK;
    result = expandable_invoke(aTHX_ self, token, gullet, state);
    SPAGAIN;
    if(result){ 
      EXTEND(SP,1);
      PUSHs(sv_2mortal(result)); }

 #/*======================================================================
 #   LaTeXML::Core::Definition::Primitive
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Definition::Primitive

void
invoke(self, token, stomach)
    SV * self;
    SV * token;
    SV * stomach;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
    int i;
  PPCODE:
    /* NOTE: Apparently if you're calling back to Perl, and Perl REallocates the stack
    you can get into trouble with invalid access, etc. The (Extra?!?) wrap of
    PUTBACK/SPAGAIN seems to handle that (even though the called functions use them already).
    See cryptic comments at https://github.com/Perl-XS/notes/issues/7 */
    PUTBACK;
    primitive_invoke(aTHX_ self, token, stomach, state, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

 #/*======================================================================
 #   LaTeXML::Core::Stomach
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Stomach

SV *
getLocator(stomach)
    SV * stomach;
  CODE:  
    RETVAL = stomach_getLocator(aTHX_ stomach);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
invokeToken(stomach, token)
    SV * stomach;
    SV * token;
  INIT:
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
    int i;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    stomach_invokeToken(aTHX_ stomach, state_global(aTHX), token, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

void
invokeInput(stomach)
    SV * stomach;
  INIT:
    SV * state = state_global(aTHX);
    SV * gullet = object_get(aTHX_ stomach, "gullet");
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
    SV * token;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    stack->discard = 1;         /* NO need to accumulate! */
    while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0)) ){
      LaTeXML_Core_Token t = SvToken(token);
      if(t->catcode != CC_SPACE){
        stomach_invokeToken(aTHX_ stomach, state_global(aTHX), token, stack);
      }
      SvREFCNT_dec(token); }
    SvREFCNT_dec(gullet);
    boxstack_DESTROY(aTHX_ stack);  /* DISCARD boxes! */
    SPAGAIN;
