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
#include "object.h"
#include "tokens.h"
#include "tokenstack.h"
#include "state.h"
#include "mouth.h"
#include "parameters.h"
#include "expandable.h"
#include "gullet.h"

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
expandable_getActiveIFFrame(pTHX_ SV * state, UTF8 fortoken){ /* no refcnt inc */
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
    else if(! sv_isa(expansion,"LaTeXML::Core::Opcode")){
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
expandable_opcode_if(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * defnhash = SvHash(expandable);
  SV ** ptr;
  int ip;
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\if");
  int ifid = ifframe->ifid;
  ifframe->parsing = 0;
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
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, state, -1, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_iftrue(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iftrue");
  ifframe->parsing = 0;
  /* do nothing else! */
  return NULL; }

SV *
expandable_opcode_iffalse(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  ifframe->parsing = 0;
  SV * t = expandable_skipConditionalBody(aTHX_ gullet, state, -1, ifframe->ifid);
  if(t){ SvREFCNT_dec(t); }
  return NULL; }

SV *
expandable_opcode_ifcase(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  LaTeXML_IfFrame ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  ifframe->parsing = 0;
  int ifid = ifframe->ifid;
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
    tokens_add_to(aTHX_ tokens, relax,0); SvREFCNT_dec(relax);
    tokens_add_to(aTHX_ tokens, current_token,0);
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
    tokens_add_to(aTHX_ tokens, relax,0); SvREFCNT_dec(relax);
    tokens_add_to(aTHX_ tokens, current_token,0);
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
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state){
  LaTeXML_State xstate = SvState(state);
  int tracing = state_lookupBoole(aTHX_ state,TBL_VALUE, "TRACINGMACROS");
  int profiling= xstate->config & CONFIG_PROFILING;
  HV * expandable_hash = SvHash(expandable);
  SV * result = NULL;
  LaTeXML_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Expandable("Invoke Expandable %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $XSTATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{token});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  SV * expansion = hash_get(aTHX_ expandable_hash, "expansion");
  UTF8 opcode = NULL;

  if(expansion && (sv_isa(expansion,"LaTeXML::Core::Opcode"))){
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
      result = tokens_new(aTHX_ nvals);
      if(nvals > 0){
        SP -= nvals;
        I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
        for(ip = 0; ip < nvals; ip++){
          tokens_add_to(aTHX_ result, ST(ip), 0); } }
      PUTBACK; FREETMPS; LEAVE;
      if(tracing){
        /* print STDERR "\n" . $self->tracingCSName($token) . ' ==> ' . tracetoString($result) . "\n";
           print STDERR $self->tracingArgs(@args) . "\n" if @args; */ }
      SvREFCNT_dec(expansion); }
    else if(sv_isa(expansion, "LaTeXML::Core::Token")) {
      DEBUG_Expandable("Expansion is token %p\n", expansion);
      if(tracing){
        /* print STDERR "\n" . $self->tracingCSName($token)
           . ' -> ' . tracetoString($expansion) . "\n";
           print STDERR $self->tracingArgs(@args) . "\n" if @args; */ }
      result = expansion; }
    else if(sv_isa(expansion, "LaTeXML::Core::Tokens")) {
      DEBUG_Expandable("Expansion is tokens %p\n", expansion);
      if(tracing){
        /* print STDERR "\n" . $self->tracingCSName($token)
           . ' -> ' . tracetoString($expansion) . "\n";
           print STDERR $self->tracingArgs(@args) . "\n" if @args; */ }
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
    expandable_install_op(aTHX_ "if",           &expandable_opcode_if);
    expandable_install_op(aTHX_ "iftrue",       &expandable_opcode_iftrue);
    expandable_install_op(aTHX_ "iffalse",      &expandable_opcode_iffalse);
    expandable_install_op(aTHX_ "ifcase",       &expandable_opcode_ifcase);
    expandable_install_op(aTHX_ "else",         &expandable_opcode_else);
    expandable_install_op(aTHX_ "or",           &expandable_opcode_else);
    expandable_install_op(aTHX_ "fi",           &expandable_opcode_fi);
    expandable_install_op(aTHX_ "expandafter",  &expandable_opcode_expandafter);
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
