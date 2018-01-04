/*# /=====================================================================\ #
  # |  LaTeXML/src/expandable.c                                           | #
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
  C-level Expandable support */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "errors.h"
#include "object.h"
#include "numbers.h"
#include "tokens.h"
#include "tokenstack.h"
#include "state.h"
#include "mouth.h"
#include "parameters.h"
#include "expandable.h"
#include "gullet.h"

SV *
expandable_new(pTHX_ SV * state, SV * cs, SV * parameters, SV * expansion, SV * locator){
  LaTeXML_State xstate = SvState(state);
  if(!SvOK(cs) || !isa_Token(cs)) {
    croak("Undefined cs!\n");}
  if(!expansion || !SvOK(expansion)){
    expansion = NULL; }
  else if(isa_Token(expansion)) {
    SV * tokens = tokens_new(aTHX_ 1);
    tokens_add_token(aTHX_ tokens,expansion);
    expansion = tokens; }
      
  /* check expansion balanced ? */
  if(!parameters || !SvOK(parameters)){ /* or empty? */
    parameters = NULL; }

  HV * hash = newHV();
  hv_store(hash, "cs",2, SvREFCNT_inc(cs),0);
  if(parameters){
    hv_store(hash,"parameters",10,SvREFCNT_inc(parameters),0); }
  if(expansion){
    hv_store(hash,"expansion",    9,SvREFCNT_inc(expansion),0); }
  if(locator){
    hv_store(hash,"locator",      7,SvREFCNT_inc(locator), 0); }
  if(xstate->flags & FLAG_PROTECTED){
    hv_store(hash,"isProtected", 11,newSViv(1),0); }
  /*hv_store(hash,"isExpandable",12,newSViv(1),0);*/
  SV * expandable = newRV_noinc((SV*)hash);
  sv_bless(expandable, gv_stashpv("LaTeXML::Core::Definition::Expandable",0));
  return expandable; }
  
int
expandable_equals(pTHX_ SV * expandable, SV * expandable2){
  return state_Equals(aTHX_ hash_get_noinc(aTHX_ SvHash(expandable),"parameters"),
                      hash_get_noinc(aTHX_ SvHash(expandable2),"parameters"))
    && state_Equals(aTHX_ hash_get_noinc(aTHX_ SvHash(expandable),"expansion"),
                    hash_get_noinc(aTHX_ SvHash(expandable2),"expansion")); }

SV *
expandable_opcode_csname(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * token = args[0];
  SV * meaning = state_meaning(aTHX_ state, token);
  if(meaning){
    SvREFCNT_dec(meaning); }
  else {                        /* Define as \relax, if not already defined. */
    LaTeXML_Token t = SvToken(token);
    SV * relax = state_lookup_noinc(aTHX_ state,TBL_MEANING, "\\relax");
    state_assign(aTHX_ state, TBL_MEANING, t->string, relax, "local"); }
  return token; }

LaTeXML_IfFrame
expandable_newIfFrame(pTHX_ SV * conditional, SV * token, SV * gullet, SV * state){
  SV * loc = gullet_getLocator(aTHX_ gullet);
  LaTeXML_IfFrame ifframe = state_pushIfFrame(aTHX_ state, token, SvPV_nolen(loc));
  SvREFCNT_dec(loc);
  return ifframe; }

LaTeXML_IfFrame
expandable_getIFFrame(pTHX_ SV * state, UTF8 fortoken){ /* No refcnt inc! */
  LaTeXML_State xstate = SvState(state);
  if(xstate->ifstack_top < 0){
    croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",
          fortoken); }
  return xstate->ifstack[xstate->ifstack_top]; }

LaTeXML_IfFrame
expandable_getActiveIFFrame(pTHX_ SV * state, SV * fortoken){ /* no refcnt inc */
  LaTeXML_State xstate = SvState(state);
  if(xstate->ifstack_top < 0){
    croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",
          fortoken); }
  int i;
  for(i = xstate->ifstack_top; i >= 0; i--){
    LaTeXML_IfFrame ifframe = xstate->ifstack[i];  
    if(ifframe->parsing){
      return ifframe; } }
  croak("Internal error: no \\if frame is open for %s", fortoken);
  return NULL; }

SV *
expandable_skipConditionalBody(pTHX_ SV * gullet, SV * state, int nskips, int sought_ifid){
  LaTeXML_State xstate = SvState(state);
  SV * mouth = gullet_getMouth(aTHX_ gullet);
  SV * token;
  int level = 1;
  int n_ors = 0;
  SV * start = gullet_getLocator(aTHX_ gullet);
  /* Question: does if_stack need to be a state value, or can it be an object value? */
  LaTeXML_IfFrame ifframe = xstate->ifstack[xstate->ifstack_top];
  int ifid = ifframe->ifid;
  while( (token = mouth_readToken(aTHX_ mouth, state)) ){
    LaTeXML_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
    SV * defn = state_expandable(aTHX_ state, token);
    SV * expansion = NULL;
    UTF8 opcode;
    if(! defn){}
    else if ( ! (expansion = hash_get(aTHX_ SvHash(defn), "expansion"))){
      SvREFCNT_dec(defn); }
    else if(! isa_Opcode(expansion)){
      SvREFCNT_dec(defn);
      SvREFCNT_dec(expansion); }
    else if( (opcode = SvPV_nolen(SvRV(expansion)) ) ){
      SvREFCNT_dec(defn);
      SvREFCNT_dec(expansion);
      if (strncmp(opcode,"if",2) == 0) {
        level++; }
      else if (strcmp(opcode, "fi") == 0) {    /*  Found a \fi */
        if (ifid != sought_ifid) {     /* but for different if (nested in test?) */
          /* then DO pop that conditional's frame; it's DONE!*/
          ifframe = state_popIfFrame(aTHX_ state);
          ifid = ifframe->ifid; }
        else if (!--level) { /* If no more nesting, we're done.*/
          ifframe = state_popIfFrame(aTHX_ state);
          SvREFCNT_dec(start);
          return token; } }  /* AND Return the finishing token.*/
      else if (strcmp(opcode,"or")==0) {
        if ((level < 2) && (++n_ors == nskips)) {
          SvREFCNT_dec(start);
          return token; } }
      else if (strcmp(opcode,"else")==0) {
        if((level < 2) && nskips && (ifid == sought_ifid)){
          /* Found \else and we're looking for one?
             Make sure this \else is NOT for a nested \if that is part of the test clause!*/ /*  */
          /* No need to actually call elseHandler, but note that we've seen an \else!*/
          ifframe->elses++;
          SvREFCNT_dec(start);
          return token; } } }
    SvREFCNT_dec(token); }
  /* if we fell through..
  Error('expected', '\fi', $gullet, "Missing \\fi or \\else, conditional fell off end",
  "Conditional started at $start"); */
  croak("Missing \\fi or \\else: conditional fell off end from %s",SvPV_nolen(start)); }

SV *
expandable_doconditional(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int boolean){
  LaTeXML_State xstate = SvState(state);
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state, current_token);
  ifframe->parsing = 0;
  if(xstate->flags & FLAG_UNLESS){
    boolean = !boolean; }
  if(! boolean){
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, state, -1, ifframe->ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_ifgeneral(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  SV * test = hash_get(aTHX_ SvHash(expandable),"test");
  int ip;
  if(!test) {
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
  int boolean = (nvals > 0 ? SvTRUEx(POPs) : 0);
  PUTBACK; FREETMPS; LEAVE;
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, boolean);
  return NULL; }

SV *
expandable_opcode_iftrue(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, 1);
  return NULL; }

SV *
expandable_opcode_iffalse(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, 0);
  return NULL; }


int
expandable_compare(pTHX_ SV * current_token, SV * state,
                         int nargs, SV ** args){
  int value1 = number_value(aTHX_ args[0]);
  UTF8 comp  = SvToken(args[1])->string;
  int value2 = number_value(aTHX_ args[2]);  
  if      (strcmp(comp,"<")==0){  return value1 < value2; }
  else if (strcmp(comp,"=")==0){  return value1 == value2; }
  else if (strcmp(comp,">")==0){  return value1 > value2; }
  else {
    croak("expected:<relationaltoken> didn't expect '%s'",comp); } }
          
SV *
expandable_opcode_ifnum(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state,
                           expandable_compare(aTHX_ current_token, state, nargs, args));
  return NULL; }

SV *
expandable_opcode_ifdim(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state,
                           expandable_compare(aTHX_ current_token, state, nargs, args));
  return NULL; }

SV *
expandable_opcode_ifodd(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int value = number_value(aTHX_ args[0]);
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, value % 2);
  return NULL; }

SV *
expandable_opcode_ifvmode(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  /* False, until we know what mode we're in! */
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, 0);
  return NULL; }

SV *
expandable_opcode_ifhmode(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  /* False, until we know what mode we're in! */
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, 0);
  return NULL; }

SV *
expandable_opcode_ifinner(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  /* False, until we know what mode we're in! */
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, 0);
  return NULL; }

SV *
expandable_opcode_ifmmode(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int inmath = state_lookupIV(aTHX_ state, TBL_VALUE, "IN_MATH");
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, inmath);
  return NULL; }

SV *
expandable_opcode_ifcat(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  LaTeXML_Token t1 = SvToken(args[0]);
  LaTeXML_Token t2 = SvToken(args[1]);
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state,
                           t1->catcode == t2->catcode);
  return NULL; }

SV *
expandable_opcode_if(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  LaTeXML_Token t1 = SvToken(args[0]);
  LaTeXML_Token t2 = SvToken(args[1]);
  char c1 = (t1->catcode == CC_CS ? 256 : (int) t1->string [0]);
  char c2 = (t2->catcode == CC_CS ? 256 : (int) t2->string [0]);
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, c1 == c2);
  return NULL; }

SV *
expandable_opcode_ifx(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int boolean = state_XEquals(aTHX_ state, args[0], args[1]);
  expandable_doconditional(aTHX_ current_token, expandable, gullet, state, boolean);
  return NULL; }

SV *
expandable_opcode_ifcase(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state,  current_token);
  ifframe->parsing = 0;
  int ifid = ifframe->ifid;
  /* Better have 1 argument, and it should be a Number! */
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(args[0]); PUTBACK;
  int nvals = call_method("valueOf",G_SCALAR);
  SPAGAIN;
  int nskips = 0;
  SV * tmp = NULL;
  if((nvals > 0) && (tmp = POPs) && isa_int(tmp)) {
    nskips = SvIVx(tmp); }
  else {
    typecheck_fatal(tmp,"Result of valueOf","ifcase",int); }
  PUTBACK; FREETMPS; LEAVE;
  if(nskips > 0){
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, state, nskips, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_else(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getIFFrame(aTHX_ state, "\\else");
  if(ifframe->parsing){
    SV * tokens = tokens_new(aTHX_ 2);
    SV * relax =  token_new(aTHX_ "\\relax",CC_CS);
    tokens_add_token(aTHX_ tokens, relax); SvREFCNT_dec(relax);
    tokens_add_token(aTHX_ tokens, current_token);
    return tokens; }
  else if (ifframe->elses){
    croak("extra XXX; already saw \\else for this level"); }
  else {
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, state, 0, ifframe->ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_fi(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getIFFrame(aTHX_ state, "\\fi");
  if(ifframe->parsing){
    SV * tokens = tokens_new(aTHX_ 2);
    SV * relax = token_new(aTHX_ "\\relax",CC_CS);
    tokens_add_token(aTHX_ tokens, relax); SvREFCNT_dec(relax);
    tokens_add_token(aTHX_ tokens, current_token);
    return tokens; }
  else {
    state_popIfFrame(aTHX_ state); }
  return NULL; }

SV *
expandable_opcode_expandafter(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  /* NOTE: This reads it's own 2 tokens!!! */
  gullet_expandafter(aTHX_ gullet, state);
  return NULL; }

SV *
expandable_opcode_the(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing);
  /* Get the value of the register tuple in args[0] */
  /* Nice if we had this better encapsulated somewhere ... */
  AV * regtuple = SvArray(args[0]);
  SV * reg = array_get(aTHX_ regtuple, 0);
  if(! reg){
    croak("Missing register definition to \\advance!"); }
  if(! SvROK(reg) || (SvTYPE(SvRV(reg)) != SVt_PVHV)){
    croak("Wrong kind of register definition to \\the!"); }
  int reg_nargs = av_len(regtuple); /* +1 - 1 */
  SV * reg_args[reg_nargs];
  int i;
  for(i = 0; i < reg_nargs; i++){
    reg_args[i] = array_get(aTHX_ regtuple, i+1); }
  SV * value = register_valueOf(aTHX_ reg, state, reg_nargs, reg_args);
  SV * tokens = tokens_new(aTHX_ 1);
  tokens_add_to(aTHX_ tokens, value, 1); /* Add the value, possibly reverting it */
  SvREFCNT_dec(value);
  SV * noexpand = get_sv("LaTeXML::NOEXPAND_THE",0);
  if(SvOK(noexpand) && SvTRUE(noexpand)){
    SV * newtokens = gullet_neutralizeTokens(aTHX_ gullet, state, tokens);
    SvREFCNT_dec(tokens);
    tokens = newtokens; }
  return tokens; }

void
expandable_showtrace(pTHX_ SV * expandable, SV * token, SV * expansion, int nargs, SV ** args){
  dSP;
  ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,nargs+3); PUSHs(expandable); PUSHs(token); PUSHs(expansion);
  int ip;
  for(ip=0; ip<nargs; ip++){
    SV * arg = (args[ip] ? args[ip] : &PL_sv_undef);
    PUSHs(arg); }
  PUTBACK;
  call_method("showtrace",G_DISCARD);
  SPAGAIN; PUTBACK; FREETMPS; LEAVE;
}

SV *
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state){
  LaTeXML_State xstate = SvState(state);
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS");
  int profiling= xstate->config & CONFIG_PROFILING;
  HV * expandable_hash = SvHash(expandable);
  SV * result = NULL;
  state_startProcessing(aTHX_ state, token);
  LaTeXML_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Expandable("Invoke Expandable %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $XSTATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{token});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  SV * expansion = hash_get(aTHX_ expandable_hash, "expansion");
  UTF8 opcode = NULL;

  if(expansion && (isa_Opcode(expansion))){
    opcode = SvPV_nolen(SvRV(expansion));
    SvREFCNT_dec(expansion); expansion = NULL; }

  /* GENERALIZE this to (before|after)expand ?   BEFORE reading arguments! */
  if(opcode && (strncmp(opcode,"if",2)==0)){ /* Prepare if stack frame for if's */
    LaTeXML_IfFrame ignore = expandable_newIfFrame(aTHX_ expandable, token, gullet, state);
    PERL_UNUSED_VAR(ignore); }
  /* Read arguments */
  int ip;
  int nargs = 0;
  AV * parameters = hash_getAV(aTHX_ expandable_hash, "parameters");
  SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
  SV * args[npara];
  if(parameters){       /* If no parameters, nothing to read! */
    DEBUG_Expandable("reading %ld parameters\n", npara);
    nargs = gullet_readArguments(aTHX_ gullet, state, npara, parameters, token, args);
    DEBUG_Expandable("got %d arguments\n", nargs);
    SvREFCNT_dec(parameters); }

  if(opcode){
    expandable_op * op = expandable_lookup(aTHX_ opcode);
    if(op){
      result = op(aTHX_ token, expandable, gullet, state, nargs, args);
      if(tracing){
        expandable_showtrace(aTHX_ expandable, token, result, nargs,args); }
    }
    else {
      croak("Internal error: Expandable opcode %s has no definition",opcode); } }
  else {
    if(!expansion || ! SvOK(expansion)){      /* empty? */
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
      result = tokens_new(aTHX_ nvals);
      if(nvals > 0){
        SP -= nvals;
        I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
        /* Let tokens_add_to do the type checking? (or better context here?) */
        for(ip = 0; ip < nvals; ip++){
          SV * t = ST(ip);
          /*
          if(! isa_svtype(t,Token,Tokens)){
          typecheck_fatal(t,"Expansion",SvToken(token)->string,Token,Tokens); }*/
          typecheck_value(t,"Expansion",SvToken(token)->string,Token,Tokens);
          tokens_add_to(aTHX_ result, t, 0); } }
      PUTBACK; FREETMPS; LEAVE;
      if(tracing){
        expandable_showtrace(aTHX_ expandable, token, result, nargs,args); }
      SvREFCNT_dec(expansion); }
    else if(isa_Token(expansion)) {
      DEBUG_Expandable("Expansion is token %p\n", expansion);
      if(tracing){
        expandable_showtrace(aTHX_ expandable, token, expansion, nargs,args); }
      result = expansion; }
    else if(isa_Tokens(expansion)) {
      DEBUG_Expandable("Expansion is tokens %p\n", expansion);
      if(tracing){
        expandable_showtrace(aTHX_ expandable, token, expansion, nargs,args); }
      result = tokens_substituteParameters(aTHX_ expansion, nargs, args);
      SvREFCNT_dec(expansion); }
    else {
      Perl_sv_dump(aTHX_ expansion);
      croak("expansion is not CODE or of type LaTeXML::Core::Tokens");
      SvREFCNT_dec(expansion); }
    for(ip = 0; ip < nargs; ip++){ /* NOW, we can clean up the args */
      SvREFCNT_dec(args[ip]); }
    }
   /*
    # Getting exclusive requires dubious Gullet support!
    #####push(@result, T_MARKER($profiled)) if $profiled; */
  state_stopProcessing(aTHX_ state, token);
  DEBUG_Expandable("Returning expansion %p\n", result);
  return result; }


HV * expandable_opcode_table = NULL;

void
expandable_install_op(pTHX_ UTF8 opcode, expandable_op * op){
  if(! expandable_opcode_table){
    expandable_opcode_table = newHV(); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(expandable_opcode_table,opcode,-strlen(opcode),  ref,0);  }

void
expandable_install_opcodes(pTHX){
    /* Install Expandable Opcodes */
    expandable_install_op(aTHX_ "CSName",       &expandable_opcode_csname);
    expandable_install_op(aTHX_ "ifGeneral",    &expandable_opcode_ifgeneral);
    expandable_install_op(aTHX_ "iftrue",       &expandable_opcode_iftrue);
    expandable_install_op(aTHX_ "iffalse",      &expandable_opcode_iffalse);
    expandable_install_op(aTHX_ "ifnum",        &expandable_opcode_ifnum);
    expandable_install_op(aTHX_ "ifdim",        &expandable_opcode_ifdim);
    expandable_install_op(aTHX_ "ifodd",        &expandable_opcode_ifodd);
    expandable_install_op(aTHX_ "ifvmode",      &expandable_opcode_ifvmode);
    expandable_install_op(aTHX_ "ifhmode",      &expandable_opcode_ifhmode);
    expandable_install_op(aTHX_ "ifmmode",      &expandable_opcode_ifmmode);
    expandable_install_op(aTHX_ "ifinner",      &expandable_opcode_ifinner);
    expandable_install_op(aTHX_ "ifcat",        &expandable_opcode_ifcat);
    expandable_install_op(aTHX_ "if",           &expandable_opcode_if);
    expandable_install_op(aTHX_ "ifx",          &expandable_opcode_ifx);
    expandable_install_op(aTHX_ "ifcase",       &expandable_opcode_ifcase);
    expandable_install_op(aTHX_ "else",         &expandable_opcode_else);
    expandable_install_op(aTHX_ "or",           &expandable_opcode_else);
    expandable_install_op(aTHX_ "fi",           &expandable_opcode_fi);
    expandable_install_op(aTHX_ "expandafter",  &expandable_opcode_expandafter);
    expandable_install_op(aTHX_ "the",  &expandable_opcode_the);
}

expandable_op *
expandable_lookup(pTHX_ UTF8 opcode){
  if(! expandable_opcode_table){
    expandable_install_opcodes(aTHX);
    if(! expandable_opcode_table){
      croak("internal:missing:expandable_opcode_table"); } }
  SV ** ptr = hv_fetch(expandable_opcode_table,opcode,-strlen(opcode),0);
  if(ptr && *ptr && SvOK(*ptr)){
    IV tmp = SvIV((SV*)SvRV(*ptr));
    return INT2PTR(expandable_op *, tmp); }
  return NULL; }
