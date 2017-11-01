/*# /=====================================================================\ #
  # |  LaTeXML/src/gullet.c                                               | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ #  */

/*======================================================================
  C-level Gullet support */


#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "object.h"
#include "tokens.h"
#include "tokenstack.h"
#include "numbers.h"
#include "state.h"
#include "mouth.h"
#include "parameters.h"
#include "gullet.h"

LaTeXML_Core_Mouth
gullet_getMouth(pTHX_ SV * gullet){ /* Warning: NO refcnt */
  HV * gullet_hash = SvHash(gullet);
  SV * mouth = hash_get_noinc(aTHX_ gullet_hash, "mouth");
  if(! mouth){
    croak("Gullet doesn't have an mouth!"); }
  return SvMouth(mouth); }

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

/* This really should be in parameters.c, but the API is sooo \def oriented? */
void
gullet_addnewparameter(pTHX_ AV * parameters, SV * state,
                       UTF8 type, LaTeXML_Core_Tokens extra, int novalue){
  HV * hash = newHV();
  HV * types = state_valueHV_noinc(aTHX_ state, "PARAMETER_TYPES");
  HV * desc;
  /* Lookup type in PARAMETER_TYPES and copy keys & values to new hash */
  if(types && (desc = hash_getHV_noinc(aTHX_ types, type))){
    hv_iterinit(desc);
    I32 keylen;
    UTF8 key;
    SV * value;
    while( (value = hv_iternextsv(desc, &key,&keylen)) ){
      SvREFCNT_inc(value);
      hv_store(hash,key,keylen,value,0); }; }
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
  HV * defn_hash;
  UTF8 type = NULL;
  if( (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ) {
    if ( (defn = state_definition(aTHX_ state, token))
         && (defn_hash = SvHash(defn))
         && (type = hash_getPV(aTHX_ defn_hash, "registerType"))){
      int typeok = 0;
      int i;
      for(i = 0; i < ntypes ; i++){
        if(strcmp(type,regtypes[i])==0){
          typeok = 1;
          break; }}
      if(typeok){
        /* $defn->valueOf($defn->readArguments($self));*/
        AV * parameters = hash_getAV(aTHX_ defn_hash,"parameters");
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

double                          /* private */
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

void                            /* private */
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


