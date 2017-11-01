/*# /=====================================================================\ #
  # |  LaTeXML/src/tokens.c                                               | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ # */

/*======================================================================
  C-Level Token and Tokens support */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "object.h"
#include "tokens.h"

/*======================================================================
    C-level Token data */

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
