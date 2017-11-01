/*# /=====================================================================\ #
  # |  LaTeXML/src/primitive.c                                            | #
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
  C-level Primitive support */

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
#include "gullet.h"
#include "boxstack.h"
#include "primitive.h"
#include "stomach.h"

void
primitive_opcode_register(pTHX_ SV * token, SV * regdefn, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Core_Boxstack stack){
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  /* args to register are in args, but not "= value" */
  SV * gullet = stomach_gullet(aTHX_ stomach);
  UTF8 type = hash_getPV(aTHX_ SvHash(regdefn), "registerType");
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
  primitive_afterAssignment(aTHX_ state); }

void
primitive_invoke(pTHX_ SV * primitive, SV * token, SV * stomach, SV * state,
                 LaTeXML_Core_Boxstack stack){
  HV * primitive_hash = SvHash(primitive);
  int tracing = state_booleval(aTHX_ state, "TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  int profiling= state_booleval(aTHX_ state, "PROFILING");
  LaTeXML_Core_Token t = SvToken(token);PERL_UNUSED_VAR(t); /* -Wall */
  DEBUG_Primitive("Invoke Primitive %p %s[%s]\n",primitive,CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  /* Call beforeDigest daemons */
  AV * before = hash_getAV(aTHX_ primitive_hash, "beforeDigest");
  if(before){
    DEBUG_Primitive("%p calling beforeDigest %p\n", primitive, before);
    boxstack_callAV(aTHX_ stack, primitive, before, state, stomach, token, 0, NULL);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(before); }
  /* Read arguments */
  AV * parameters = hash_getAV(aTHX_ primitive_hash, "parameters");
  SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
  int nargs = 0;
  SV * args[npara];
  if(parameters){       /* If no parameters, nothing to read! */
    SV * gullet = stomach_gullet(aTHX_ stomach);
    DEBUG_Primitive("reading %ld parameters\n", npara);
    nargs = gullet_readArguments(aTHX_ gullet, npara, parameters, token, args);
    DEBUG_Primitive("got %d arguments\n", nargs);
    SvREFCNT_dec(parameters); }
  /* Call main replacement:  opcode, if defined, or function */
  SV * replacement = hash_get(aTHX_ primitive_hash, "replacement");
  if(replacement){
    DEBUG_Primitive("%p calling replacement %p\n", primitive, replacement);
    boxstack_call(aTHX_ stack, primitive, replacement, state, stomach, token, nargs, args);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(replacement); }

  /* Call afterDigest daemons */
  AV * after = hash_getAV(aTHX_ primitive_hash, "afterDigest");
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

HV * primitive_opcode_table = NULL;

void
primitive_install_op(pTHX_ UTF8 opcode, primitive_op * op){
  if(! primitive_opcode_table){
    primitive_opcode_table = newHV(); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(primitive_opcode_table,opcode,-strlen(opcode),  ref,0);  }

void
primitive_install_opcodes(pTHX){
  /* Install Primitive Opcodes */
  primitive_install_op(aTHX_ "register",      &primitive_opcode_register);
}

primitive_op *
primitive_lookup(pTHX_ UTF8 opcode){
  if(! primitive_opcode_table){
    primitive_install_opcodes(aTHX);
    if(! primitive_opcode_table){
      croak("internal:missing:primitive_opcode_table"); } }
  SV ** ptr = hv_fetch(primitive_opcode_table,opcode,-strlen(opcode),0);
  if(ptr && *ptr && SvOK(*ptr)){
    IV tmp = SvIV((SV*)SvRV(*ptr));
    return INT2PTR(primitive_op *, tmp); }
  return NULL; }

void
primitive_afterAssignment(pTHX_ SV * state){
  SV * after = state_value(aTHX_ state, "afterAssignment");
  if(after){
    state_assign_value(aTHX_ state, "afterAssignment", NULL,"global");
    SV * stomach = state_stomach(aTHX_ state);
    SV * gullet = stomach_gullet(aTHX_ stomach);
    SvREFCNT_dec(stomach);
    gullet_unreadToken(aTHX_ gullet, after);
    SvREFCNT_dec(gullet);
    SvREFCNT_dec(after); } }
