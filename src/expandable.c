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
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  SV * token = args[0];
  SV * meaning = state_meaning(aTHX_ state, token);
  if(meaning){
    SvREFCNT_dec(meaning); }
  else {                        /* Define as \relax, if not already defined. */
    LaTeXML_Core_Token t = SvToken(token);
    SV * relax = state_meaning_internal(aTHX_ state, "\\relax");
    state_assign_meaning(aTHX_ state, t->string, relax, "local"); }
  return token; }

HV *
expandable_newIfFrame(pTHX_ SV * conditional, SV * token, SV * gullet, SV * state){
  int ifid = state_intval(aTHX_ state, "if_count");
  state_assign_value(aTHX_ state, "if_count",newSViv(++ifid),"global");
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
    state_assign_value(aTHX_ state, "if_stack", sv_ifstack,"global"); }
  av_unshift(ifstack, 1);
  av_store(ifstack, 0, newRV_inc((SV *)ifframe)); /* why inc? */
  SvREFCNT_dec(sv_ifstack);
  /*fprintf(stderr,"NEWIFFRAME\n");
    Perl_sv_dump(aTHX_ sv_stack);*/
  return ifframe; }

HV *
expandable_getIFFrame(pTHX_ SV * state, UTF8 fortoken){ /* No refcnt inc! */
  AV * ifstack = state_valueAV_noinc(aTHX_ state, "if_stack");
  HV * frame = array_getHV_noinc(aTHX_ ifstack, 0);
  if(!frame){
    croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",
          fortoken); }
  return frame; }

HV *
expandable_getActiveIFFrame(pTHX_ SV * state, UTF8 fortoken){ /* no refcnt inc */
  AV * ifstack = state_valueAV_noinc(aTHX_ state, "if_stack");
  int i;
  int n = av_len(ifstack) + 1;
  for(i = 0; i < n; i++){
    HV * frame = array_getHV_noinc(aTHX_ ifstack, i);
    if(!frame){
      croak("Didn't expect %s since we seem not to be in a conditional (no frame in if_stack)",
            fortoken); }
    else if(hash_getBoole(aTHX_ frame, "parsing")){
      return frame; } }
  croak("Internal error: no \\if frame is open for %s", fortoken);
  return NULL; }

SV *
expandable_skipConditionalBody(pTHX_ SV * gullet, int nskips, UTF8 sought_ifid){
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

SV *
expandable_opcode_if(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * defnhash = SvHash(expandable);
  SV ** ptr;
  int ip;
  HV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\if");
  UTF8 ifid = hash_getPV(aTHX_ ifframe,"ifid");
  hash_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));

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
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, -1, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_iftrue(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iftrue");
  hash_put_noinc(aTHX_ ifframe,"parsing",NULL);
  /* do nothing else! */
  return NULL; }

SV *
expandable_opcode_iffalse(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  hash_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));
  UTF8 ifid = hash_getPV(aTHX_ ifframe,"ifid");
  SV * t = expandable_skipConditionalBody(aTHX_ gullet, -1, ifid);
  if(t){ SvREFCNT_dec(t); }  
  return NULL; }

SV *
expandable_opcode_ifcase(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * ifframe = expandable_getActiveIFFrame(aTHX_ state,  "some \\iffalse");
  hash_put_noinc(aTHX_ ifframe,"parsing",newSViv(0));
  UTF8 ifid = hash_getPV(aTHX_ ifframe,"ifid");

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
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, nskips, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_else(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * frame = expandable_getIFFrame(aTHX_ state, "\\else");
  if(hash_getBoole(aTHX_ frame,"parsing")){
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 2);
    SV * relax =  token_new(aTHX_ "\\relax",CC_CS);
    tokens_add_to(aTHX_ tokens, relax,0); SvREFCNT_dec(relax);
    tokens_add_to(aTHX_ tokens, current_token,0);
    SV * result = newSV(0);
    sv_setref_pv(result, "LaTeXML::Core::Tokens", (void*) tokens);
    SvREFCNT_inc(result);
    return result; }
  else if (hash_getIV(aTHX_ frame,"elses")){
    croak("extra XXX; already saw \\else for this level"); }
  else {
    UTF8 ifid = hash_getPV(aTHX_ frame,"ifid");
    SV * t = expandable_skipConditionalBody(aTHX_ gullet, 0, ifid);
    if(t){ SvREFCNT_dec(t); } }
  return NULL; }

SV *
expandable_opcode_fi(pTHX_ SV * current_token, SV * expandable, SV * gullet, SV * state,
                         int nargs, SV ** args){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  HV * frame = expandable_getIFFrame(aTHX_ state, "\\fi");
  if(hash_getBoole(aTHX_ frame,"parsing")){
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
  HV * expandable_hash = SvHash(expandable);
  SV * result = NULL;
  LaTeXML_Core_Token t = SvToken(token); PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Expandable("Invoke Expandable %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{token});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  SV * expansion = hash_get(aTHX_ expandable_hash, "expansion");
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
  AV * parameters = hash_getAV(aTHX_ expandable_hash, "parameters");
  SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
  SV * args[npara];
  if(parameters){       /* If no parameters, nothing to read! */
    DEBUG_Expandable("reading %ld parameters\n", npara);
    nargs = gullet_readArguments(aTHX_ gullet, npara, parameters, token, args);
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
