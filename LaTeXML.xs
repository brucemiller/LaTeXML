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
#else
#  define DEBUG_Token(...)
#endif

#define DEBUG_TOKENSNOT
#ifdef DEBUG_TOKENS
#  define DEBUG_Tokens(...) fprintf(stderr, __VA_ARGS__)
#else
#  define DEBUG_Tokens(...)
#endif

#define DEBUG_TONGUENOT
#ifdef DEBUG_TONGUE
#  define DEBUG_Tongue(...) fprintf(stderr, __VA_ARGS__)
#else
#  define DEBUG_Tongue(...)
#endif

  /* Perhaps we should be using SV * ?  We're losing the unicode setting of the string! */
  /* Also: currently we copy string & free on DESTROY; Do getString (etal) need to copy? */
  /* the C ends up with sv_setpv, which(apparently) copies the string into the PV(string var) */
typedef char * UTF8;
typedef struct Token_struct {
  int catcode;
  UTF8 string;
} T_Token;

typedef SV * PTR_SV;
typedef struct Tokens_struct {
  int ntokens;
  PTR_SV * tokens;
} T_Tokens;

typedef struct Tongue_struct {
  int lineno;
  STRLEN colno;
  UTF8 chars;
  STRLEN bufsize;
  STRLEN ptr;
  STRLEN nbytes;
  STRLEN prev_nbytes;
  STRLEN prev_ncols;
} T_Tongue;

typedef T_Token  * LaTeXML_Core_Token;
typedef T_Tokens * LaTeXML_Core_Tokens;
typedef T_Tongue * LaTeXML_Core_Mouth_Tongue;

     /* You'll often need SvRV(arg) */
#define SvToken(arg) INT2PTR(LaTeXML_Core_Token, SvIV((SV*) arg))
#define SvTokens(arg) INT2PTR(LaTeXML_Core_Tokens, SvIV((SV*) arg))
#define SvTongue(arg) INT2PTR(LaTeXML_Core_Mouth_Tongue, SvIV((SV*) arg))

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

  /*======================================================================
    C-level Token support */
LaTeXML_Core_Token
make_token(UTF8 string, int catcode){
  /*check string not null ? */
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
  return token; }

#define T_LETTER(arg) (make_token((arg), 11))
#define T_OTHER(arg)  (make_token((arg), 12))
#define T_ACTIVE(arg) (make_token((arg), 13))
#define T_CS(arg)     (make_token((arg), 16))

  /*======================================================================
    C-Level Tokens support */
  /* Note peculiar pre-allocation strategy for nalloc!
     it is expected that the caller has allocated enough room for it's arguments
     assuming they are Token's; add_to_tokens will grow if it encounters Tokens/Reversions */
void
add_to_tokens(LaTeXML_Core_Tokens tokens, int * nalloc, SV * thing, int revert) {
  dTHX;                         /* perhaps want to look into pTHX, perl context, etc??? */
  DEBUG_Tokens("\nAdding to tokens:");
  if (sv_isa(thing, "LaTeXML::Core::Token")) {
    DEBUG_Tokens( "Token.");
    thing = SvRV(thing);
    SvREFCNT_inc(thing);
    tokens->tokens[tokens->ntokens++] = thing; }
  else if (sv_isa(thing, "LaTeXML::Core::Tokens")) {
    LaTeXML_Core_Tokens toks = SvTokens(SvRV(thing));
    int n = toks->ntokens;
    int i;
    DEBUG_Tokens( "Tokens(%d): ", n);
    if(n > 0){
      Renew(tokens->tokens, (*nalloc)+= n-1, PTR_SV);
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
    Renew(tokens->tokens, (*nalloc)+= nvals-1, PTR_SV);    
    for(i=0; i<nvals; i++){
      add_to_tokens(tokens, nalloc, ST(i), revert); }
    PUTBACK; FREETMPS; LEAVE; }
  else {
    /* Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))*/
    croak("Tokens: Expected a Token, got ???"); }
  DEBUG_Tokens( "Done adding.");
}

  /*======================================================================
    C-level Mouth/Tongue support */

int
lookupCatcode(SV * state, UTF8 string){
  int cc,nvals;
  SV * s;
  dTHX; dSP;
  DEBUG_Tongue("Catcode of %s",string);
  ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(state);
  s = newSVpv(string,0); SvUTF8_on(s);
  PUSHs(sv_2mortal(s));
  PUTBACK;
  nvals = call_pv("LaTeXML::Core::State::lookupCatcode", G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    cc = CC_OTHER; }            /* reasonable default? */
  else {
    SV * sv = POPs;
    cc = (SvOK(sv) ? SvIV(sv) : CC_OTHER); }
  DEBUG_Tongue("=> %s\n",CC_SHORT_NAME[cc]);
  PUTBACK; FREETMPS; LEAVE;
  return cc; }

int
lookupInteger(SV * state, UTF8 string){
  int v,nvals;
  SV * s;
  dTHX; dSP;
  DEBUG_Tongue("Lookup %s",string);
  ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(state);
  s = newSVpv(string,0); SvUTF8_on(s);
  PUSHs(sv_2mortal(newSVpv(string,0)));
  PUTBACK;
  nvals = call_pv("LaTeXML::Core::State::lookupValue", G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    v = 0; }
  else {
    SV * sv = POPs;
    v = (SvOK(sv) ? SvIV(sv) : 0); }
  DEBUG_Tongue("=> %d\n",v);
  PUTBACK; FREETMPS; LEAVE;
  return v; }

int
lookupBoolean(SV * state, UTF8 string){
  int v,nvals;
  SV * s;
  dTHX; dSP;
  DEBUG_Tongue("Lookup %s",string);
  ENTER; SAVETMPS; PUSHMARK(SP); EXTEND(SP,1);
  PUSHs(state);
  s = newSVpv(string,0); SvUTF8_on(s);
  PUSHs(sv_2mortal(s));
  PUTBACK;
  nvals = call_pv("LaTeXML::Core::State::lookupValue", G_ARRAY);
  SPAGAIN;
  if(nvals < 1){
    v = 0; }
  else {
    SV * sv = POPs;
    v = (SvOK(sv) && SvTRUE(sv) ? 1 : 0); }
  DEBUG_Tongue("=> %d\n",v);
  PUTBACK; FREETMPS; LEAVE;
  return v; }

UTF8
getMouthShortsource(SV * mouth){
  HV * hash;
  SV ** ptr;
  dTHX;
  hash = MUTABLE_HV(SvRV(mouth));
  ptr  = hv_fetchs(hash,"shortsource",0);
  return (ptr ? (UTF8)SvPV_nolen(*ptr) : NULL); }

LaTeXML_Core_Mouth_Tongue
getMouthTongue(SV * mouth){
  HV * hash;
  SV ** ptr;
  dTHX;
  hash = MUTABLE_HV(SvRV(mouth));
  ptr  = hv_fetchs(hash,"tongue",0);
  if(! ptr){
    croak("Mouth doesn't have a tongue!"); }
  return SvTongue(SvRV(*ptr)); }

  /* Since readToken looks ahead, we'll need to be able to undo the effects of nextChar! */
int
readChar(SV * state, LaTeXML_Core_Mouth_Tongue tongue, char * character, int * catcode){
  dTHX;
  if(tongue->ptr < tongue->nbytes){
    STRLEN ch_len;
    int nca = 0;                /* # chars advanced in buffer */
    int nba = 0;                /* # bytes advanced */
    int nbr = 0;                /* # bytes returned */
    ch_len = UTF8SKIP(tongue->chars+tongue->ptr);
    CopyChar(tongue->chars+tongue->ptr,character,ch_len);
    DEBUG_Tongue("NEXT examine '%s', %lu bytes\n",character, ch_len);
    nca ++;
    nba += ch_len;
    nbr += ch_len;
    *catcode = lookupCatcode(state,character);
    if((*catcode == CC_SUPER)          /* Check for ^^hex or ^^<ctrl> */
       && (tongue->ptr + nba + ch_len + 1 <= tongue->nbytes)       /* at least 2 more chars? */
       && ( ((ch_len == 1) && (*character == *(tongue->chars+tongue->ptr+nba)))
           || (strncmp(character,tongue->chars+tongue->ptr + nba,ch_len)==0)) ){ /* check if same */
      DEBUG_Tongue("NEXT saw ^^\n");
      nba += ch_len;
      nca ++;
      /* Look for 2 lower-case hex or 1 control char (pure ASCII!) */
      char c1,c2;
      UV code;
      if((tongue->ptr + nba + 2 <= tongue->nbytes)
         && (c1 = * (tongue->chars+tongue->ptr + nba))
         && ( ((c1 = c1-'0') >= 0) && ((c1 <= 9) || (((c1 = c1-'a'+'0'+10) >=10) && (c1 <= 15))))
         && (c2 = * (tongue->chars+tongue->ptr + nba + 1))
         && ( ((c2 = c2-'0') >= 0) && ((c2 <= 9) || (((c2 = c2-'a'+'0'+10) >=10) && (c2 <= 15)))) ){
        nba += 2;
        nca += 2;
        code = c1*16+c2; }
      else {
        c1 = * (tongue->chars+tongue->ptr + nba);
        nba ++;
        nca ++;
        code = (c1 > 64 ? c1 - 64 : c1 + 64); } /* ???? */
      /* Code point could have 8th bit, turn to multibyte unicode! */
      nbr = UVCHR_SKIP(code);
      uvchr_to_utf8((U8 *)character,code);
      *catcode = lookupCatcode(state,character); }
    DEBUG_Tongue("NEXT Succeed %d bytes, %d chars advanced => '%s', %d bytes\n",
                 nba,nca,character,nbr);
    tongue->ptr += nba;
    tongue->colno += nca;
    tongue->prev_nbytes = nba;
    tongue->prev_ncols = nca;
    return nbr; }
  else {
    DEBUG_Tongue("NEXT Failed\n");
    return 0; } }

  /* Put back the previously parsed character.  Would be nice to save it for next call,
     but the catcodes can (& will) change by then! */
void
unreadChar(LaTeXML_Core_Mouth_Tongue tongue){
  DEBUG_Tongue("PUTBack %d bytes, %d chars\n",tongue->prev_nbytes,tongue->prev_ncols);
  tongue->ptr   -= tongue->prev_nbytes;
  tongue->colno -= tongue->prev_ncols;
  tongue->prev_nbytes = 0;
  tongue->prev_ncols = 0;
}

int
readLine(SV * mouth, LaTeXML_Core_Mouth_Tongue tongue){
  int nvals;
  char * line;
  SV * sv;
  dTHX; dSP;
  DEBUG_Tongue("Tongue: readLine\n");
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
      char c;
      if(! SvUTF8(sv)) {
        sv = sv_mortalcopy(sv);
        sv_utf8_upgrade(sv); }
      line = (UTF8)SvPV_nolen(sv);
      DEBUG_Tongue("Got line '%s'\n",line);
      tongue->lineno++;
      tongue->colno = 0;
      tongue->nbytes = strlen(line);
      DEBUG_Tongue("length %lu;",tongue->nbytes);
      if(tongue->nbytes > tongue->bufsize){ /* Check if buffer big enough. */
        if(tongue->bufsize == 0){    /* first line? new buffer */
          Newx(tongue->chars, (tongue->nbytes + 2), char); }
        else {                    /* Else, grow if needed */
          Newx(tongue->chars, (tongue->nbytes + 2), char); }
        tongue->bufsize = tongue->nbytes; }
      CopyChar(line,tongue->chars,tongue->nbytes);
      tongue->ptr = 0;
      /* normalize line end. */
      while((tongue->nbytes > 0)
            && ( ((c = *(tongue->chars+tongue->nbytes - 1)) == ' ') || ((c >= 11) && (c <= 13)) ) ){
        tongue->nbytes--; }
      if((tongue->nbytes > 0)     /* keep Trailing control space */
         && (*(tongue->chars+tongue->nbytes - 1) == '\\')
         && (*(tongue->chars+tongue->nbytes) == ' ')) {
        tongue->nbytes++; }
      DEBUG_Tongue("SET LINE to %lu bytes, '%s'\n", tongue->nbytes, line);
      CopyChar("\r",tongue->chars+tongue->nbytes,1); tongue->nbytes++;/* Append \r */
    } }
  PUTBACK; FREETMPS; LEAVE;
  if(line == NULL){
    DEBUG_Tongue("No remaining input\n");
    return 0; }
  else {
    return 1; } }

  /*======================================================================
    Perl Modules */

  
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
    DEBUG_Token("DESTROY Token %s[%s]!\n",CC_SHORT_NAME[self->catcode],self->string);
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
    LaTeXML_Core_Tokens tokens;
    int nalloc;
  CODE:
    if((items == 1) && sv_isa(ST(0), "LaTeXML::Core::Tokens")) {
      SvREFCNT_inc(ST(0));
      RETVAL = ST(0); }
    else {
      Newxz(tokens,1, T_Tokens);
      if(items > 0){
        Newx(tokens->tokens,nalloc=items, PTR_SV); }
      DEBUG_Tokens( "\nCreate Tokens(%d): ", items);
      for (i = 0 ; i < items ; i++) {
        add_to_tokens(tokens,&nalloc,ST(i),0); }
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
    int nalloc;
  CODE:
    Newxz(tokens,1,T_Tokens);
    if(self->ntokens > 0){
      Newx(tokens->tokens,nalloc=self->ntokens, PTR_SV); }
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
            add_to_tokens(tokens,&nalloc, ST(argn), 1); } }
      } }
    DEBUG_Tokens("done\n");
    RETVAL = tokens;
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
  CODE:
    DEBUG_Tokens("DESTROY Tokens(%d)",self->ntokens);
    for (i = 0 ; i < self->ntokens ; i++) {
      SvREFCNT_dec(self->tokens[i]); }
    Safefree(self->tokens);
    Safefree(self);

MODULE = LaTeXML PACKAGE = LaTeXML::Core::Mouth::Tongue

LaTeXML_Core_Mouth_Tongue
new()
  INIT:
    LaTeXML_Core_Mouth_Tongue tongue;
  CODE:
    Newxz(tongue,1,T_Tongue);
    DEBUG_Tongue("Creating TONGUE!\n");
    Newxz(tongue->chars,3,char);
    tongue->bufsize=3;
    RETVAL = tongue;
  OUTPUT:
    RETVAL

void
finish(tongue)
    LaTeXML_Core_Mouth_Tongue tongue;
  CODE:
    DEBUG_Tongue("Finished with Tongue\n");
    tongue->lineno = 0;
    tongue->colno = 0;
    /*if(tongue->chars != NULL){
      safefree(tongue->chars); } *//* should reuse if long enough?  */
    /*tongue->chars = NULL;*/
    tongue->nbytes = 0;
    tongue->ptr = 0;

int
hasMoreInput(tongue)
    LaTeXML_Core_Mouth_Tongue tongue
  CODE:
    RETVAL = tongue->ptr < tongue->nbytes;
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Mouth_Tongue self
  CODE:
    /*SvREFCNT_dec(self->mouth); */
    Safefree(self->chars);
    Safefree(self);

MODULE = LaTeXML PACKAGE = LaTeXML::Core::Mouth

void
getPosition(mouth)
    SV * mouth;
  INIT:
    LaTeXML_Core_Mouth_Tongue tongue;    
  PPCODE:
    tongue = getMouthTongue(mouth);
    EXTEND(SP, 2);
    mPUSHi((IV) tongue->lineno);
    mPUSHi((IV) tongue->colno);

LaTeXML_Core_Token
readToken(mouth)
    SV * mouth;
  INIT:
    LaTeXML_Core_Mouth_Tongue tongue;
    char ch[UTF8_MAXBYTES+1];
    int  cc;
    STRLEN nbytes;
    STRLEN startcol;
    SV * state;
  CODE:
    state = get_sv("STATE",0);
    tongue = getMouthTongue(mouth);
    startcol = tongue->colno;
    RETVAL = NULL;
    while(RETVAL == NULL){
      DEBUG_Tongue("READ Token\n");
      if((nbytes = readChar(state,tongue,ch,&cc))){
        if((startcol == 0) && (cc == CC_SPACE)){ /* Ignore leading spaces */
          while((nbytes = readChar(state,tongue,ch,&cc) && (cc == CC_SPACE))){
          } }
        if(CC_TrivialRead[cc]){   /* Common, trivial case first */
          DEBUG_Tongue("Token[%s,%s]\n",ch,CC_SHORT_NAME[cc]);
          RETVAL = make_token(ch,cc); }
        else if(cc == CC_ESCAPE){
          char buffer[tongue->nbytes+1];  /* room for whole line. */
          STRLEN p;
          buffer[0]='\\'; p = 1; buffer[p]=0; /* Store \, 'cause CS are stored that way */
          DEBUG_Tongue("ESCAPE '%s'\n",buffer);
          if((nbytes = readChar(state,tongue,buffer+p,&cc))){
            p+=nbytes;
            if(cc == CC_LETTER){
              while((nbytes = readChar(state,tongue,buffer+p,&cc)) && (cc == CC_LETTER)){
                p+=nbytes; }
              *(buffer+p)=0;    /* terminate the CS, in case we just added a non-letter */
              /* if peeked char was space, skip spaces */
              while((cc == CC_SPACE) && (nbytes = readChar(state,tongue,ch,&cc)) ){
              }
              /* In \read & we get EOL, we'll put it back to turn into a space; otherwise remove it */
              if ((cc == CC_EOL) && !(lookupInteger(state,"PRESERVE_NEWLINES") > 1)) {
                nbytes = 0; }    /* so it will NOT be put back  */
              if(nbytes) {        /* put back last non-letter, non-space peeked char, if any */
                unreadChar(tongue); } }
          }
          else {
            croak("Missing character following escape char %s",ch); }
          DEBUG_Tongue("Token[%s,%s]\n",buffer,CC_SHORT_NAME[CC_CS]);
          RETVAL = make_token(buffer,CC_CS); }
        else if (cc == CC_SPACE){
          DEBUG_Tongue("SPACE\n");
          RETVAL = make_token(ch,cc);
          while((nbytes = readChar(state,tongue,ch,&cc)) /* skip following spaces */
                && ((cc == CC_SPACE) || (cc == CC_EOL)) ){
          }
          if(nbytes){           /* put back non-space (if any) */
            unreadChar(tongue); } }
        else if (cc == CC_COMMENT){
          DEBUG_Tongue("Comment '%s'\n",tongue->chars+tongue->ptr);
          if((tongue->ptr +1 < tongue->nbytes) /* More than just CR? */
             && lookupBoolean(state,"INCLUDE_COMMENTS")){
            char buffer[tongue->nbytes+1];  /* room for whole line. */
            int n = tongue->nbytes-tongue->ptr;
            buffer[0]='%';
            Copy(tongue->chars+tongue->ptr,buffer+1,n,char);
            n ++;
            if(buffer[n-1] == '\r'){
              n--; }
            buffer[n] = 0;
            RETVAL = make_token(buffer,cc); }
          tongue->ptr = tongue->nbytes; }
        else if (cc == CC_EOL){
          DEBUG_Tongue("EOL @ %lu\n",tongue->colno);
          if(startcol == 0){
            RETVAL = T_CS("\\par"); }
          else if(lookupInteger(state,"PRESERVE_NEWLINES")){
            RETVAL = make_token("\n",CC_SPACE); }
          else {
            RETVAL = make_token(" ",CC_SPACE); } }
        else if (cc == CC_IGNORE){
          DEBUG_Tongue("IGNORE\n"); }
        else if (cc == CC_INVALID){
          DEBUG_Tongue("INVALID\n");
          RETVAL = make_token(ch,CC_OTHER); } /* ? */
        else {
          DEBUG_Tongue("No proper Catcode '%d'\n",cc); }
        }
      else {                    /* Try for next line. */
        if(! readLine(mouth,tongue)){
          break; }
        if(((tongue->lineno % 25) == 0) && lookupBoolean(state,"INCLUDE_COMMENTS")){
          char * source = getMouthShortsource(mouth);
          if(source != NULL){
            char * comment = form("**** %s Line %d ****",source,tongue->lineno);
            RETVAL = make_token(comment, CC_COMMENT); } }
        else {
          startcol = tongue->colno; } } }
  OUTPUT:
    RETVAL

UTF8
readRawLine(mouth,...)
    SV * mouth;
  INIT:
    LaTeXML_Core_Mouth_Tongue tongue;
    int noread = 0;
  CODE:
    if(items > 1){
      noread = SvIV(ST(1)); }
    tongue = getMouthTongue(mouth);
    if((tongue->ptr >= tongue->nbytes) && noread){ /* out of input, but don't want a new line */
      RETVAL = ""; }      
    else if(tongue->ptr >= tongue->nbytes){ /* otherwise read a line, if needed */
      readLine(mouth,tongue); }
    if(tongue->ptr < tongue->nbytes) { /* If we have input now */
      RETVAL = tongue->chars+tongue->ptr;
      tongue->ptr = tongue->nbytes;
      if(*(tongue->chars+tongue->ptr-1) == '\r'){ /* cut off trailing \r */
        *(tongue->chars+tongue->ptr-1) = 0; } }
    else {
      RETVAL = NULL; }
  OUTPUT:
    RETVAL
    
