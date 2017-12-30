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
#include "errors.h"
#include "object.h"
#include "numbers.h"
#include "tokens.h"
#include "tokenstack.h"
#include "state.h"
#include "mouth.h"
#include "gullet.h"
#include "boxstack.h"
#include "expandable.h"
#include "primitive.h"
#include "stomach.h"

int
primitive_equals(pTHX_ SV * primitive, SV * primitive2){
  return state_Equals(aTHX_ hash_get_noinc(aTHX_ SvHash(primitive),"parameters"),
                      hash_get_noinc(aTHX_ SvHash(primitive2),"parameters"))
    /* and maybe getter, setter ??? */
    && state_Equals(aTHX_ hash_get_noinc(aTHX_ SvHash(primitive),"replacement"),
                    hash_get_noinc(aTHX_ SvHash(primitive2),"replacement")); }

  
void
primitive_opcode_begingroup(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  stomach_begingroup(aTHX_ stomach, state); }

void
primitive_opcode_endgroup(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  stomach_endgroup(aTHX_ stomach, state); }

void
primitive_opcode_register(pTHX_ SV * token, SV * reg, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  /* args to register are in args, but not "= value" */
  SV * gullet = stomach_gullet(aTHX_ stomach);
  UTF8 type = hash_getPV(aTHX_ SvHash(reg), "registerType");
  gullet_skipEquals(aTHX_ gullet, state);
  SV * value = gullet_readValue(aTHX_ gullet, state, type);
  register_setValue(aTHX_ reg, state, nargs, args, value);
  primitive_afterAssignment(aTHX_ state); }

void
primitive_opcode_advance(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing);
 /* -Wall */
  /* arg[0] == [reg_defn, reg_args....]  */
  if(nargs != 1){
    croak("Missing argument to \\advance"); }
  SV * gullet = stomach_gullet(aTHX_ stomach);
  AV * regtuple = SvArray(args[0]);
  SV * reg = array_get(aTHX_ regtuple, 0);
  if(! reg){
    croak("Missing register definition to \\advance!"); }
  if(! SvROK(reg) || (SvTYPE(SvRV(reg)) != SVt_PVHV)){
    croak("Wrong kind of register definition to \\advance!"); }
  int reg_nargs = av_len(regtuple); /* +1 - 1 */
  SV * reg_args[reg_nargs];
  int i;
  for(i = 0; i < reg_nargs; i++){
    reg_args[i] = array_get(aTHX_ regtuple, i+1); }
  UTF8 type = hash_getPV(aTHX_ SvHash(reg), "registerType");
  gullet_skipEquals(aTHX_ gullet, state);
  SV * addend = gullet_readValue(aTHX_ gullet, state, type);
  SV * old = register_valueOf(aTHX_ reg, state, reg_nargs, reg_args);
  SV * new = old;
  if(     strcmp(type,"Number"   )==0){ new = number_add(aTHX_ old, addend); }
  else if(strcmp(type,"Dimension")==0){ new = dimension_add(aTHX_ old, addend); }
  else if(strcmp(type,"Glue"     )==0){ new = glue_add(aTHX_ old, addend); }
  else if(strcmp(type,"MuGlue"   )==0){ new = muglue_add(aTHX_ old, addend); }
  else {
    croak("Advance of unexpected register type %s",type); }
  register_setValue(aTHX_ reg, state, reg_nargs, reg_args, new);
  /* Now can cleanup reg_args ??? */
  primitive_afterAssignment(aTHX_ state);
}

void
primitive_opcode_multiply(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing);
 /* -Wall */
  /* arg[0] == [reg_defn, reg_args....]  */
  if(nargs != 2){
    croak("Missing argument to \\multiply"); }
  AV * regtuple = SvArray(args[0]);
  SV * reg = array_get(aTHX_ regtuple, 0);
  if(! reg){
    croak("Missing register definition to \\multiply!"); }
  if(! SvROK(reg) || (SvTYPE(SvRV(reg)) != SVt_PVHV)){
    croak("Wrong kind of register definition to \\multiply!"); }
  int reg_nargs = av_len(regtuple); /* +1 - 1 */
  SV * reg_args[reg_nargs];
  int i;
  for(i = 0; i < reg_nargs; i++){
    reg_args[i] = array_get(aTHX_ regtuple, i+1); }
  int scale = number_value(aTHX_ args[1]);
  UTF8 type = hash_getPV(aTHX_ SvHash(reg), "registerType");
  SV * old = register_valueOf(aTHX_ reg, state, reg_nargs, reg_args);
  SV * new = old;
  if(     strcmp(type,"Number"   )==0){ new = number_scale(aTHX_ old, scale); }
  else if(strcmp(type,"Dimension")==0){ new = dimension_scale(aTHX_ old, scale); }
  else if(strcmp(type,"Glue"     )==0){ new = glue_scale(aTHX_ old, scale); }
  else if(strcmp(type,"MuGlue"   )==0){ new = muglue_scale(aTHX_ old, scale); }
  else {
    croak("Advance of unexpected register type %s",type); }
  register_setValue(aTHX_ reg, state, reg_nargs, reg_args, new);
  /* Now can cleanup reg_args ??? */
  primitive_afterAssignment(aTHX_ state);
}

void
primitive_opcode_divide(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing);
 /* -Wall */
  /* arg[0] == [reg_defn, reg_args....]  */
  if(nargs != 2){
    croak("Missing argument to \\divide"); }
  AV * regtuple = SvArray(args[0]);
  SV * reg = array_get(aTHX_ regtuple, 0);
  if(! reg){
    croak("Missing register definition to \\divide!"); }
  if(! SvROK(reg) || (SvTYPE(SvRV(reg)) != SVt_PVHV)){
    croak("Wrong kind of register definition to \\divide!"); }
  int reg_nargs = av_len(regtuple); /* +1 - 1 */
  SV * reg_args[reg_nargs];
  int i;
  for(i = 0; i < reg_nargs; i++){
    reg_args[i] = array_get(aTHX_ regtuple, i+1); }
  int scale = number_value(aTHX_ args[1]);
  if(scale == 0){
    croak("Attempted division by 0; assuming 1"); /* should just warn */
    scale = 1; }
  UTF8 type = hash_getPV(aTHX_ SvHash(reg), "registerType");
  SV * old = register_valueOf(aTHX_ reg, state, reg_nargs, reg_args);
  SV * new = old;
  if(     strcmp(type,"Number"   )==0){ new = number_divide(aTHX_ old, scale); }
  else if(strcmp(type,"Dimension")==0){ new = dimension_divide(aTHX_ old, scale); }
  else if(strcmp(type,"Glue"     )==0){ new = glue_divide(aTHX_ old, scale); }
  else if(strcmp(type,"MuGlue"   )==0){ new = muglue_divide(aTHX_ old, scale); }
  else {
    croak("Advance of unexpected register type %s",type); }
  register_setValue(aTHX_ reg, state, reg_nargs, reg_args, new);
  primitive_afterAssignment(aTHX_ state);
}

void
primitive_opcode_global(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  LaTeXML_State xstate = SvState(state);
  xstate->flags |= FLAG_GLOBAL; }

void
primitive_opcode_long(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  LaTeXML_State xstate = SvState(state);
  xstate->flags |= FLAG_LONG; }

void
primitive_opcode_outer(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  LaTeXML_State xstate = SvState(state);
  xstate->flags |= FLAG_OUTER; }

void
primitive_opcode_def(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  if(nargs != 3){
    croak("Bad \\def missing stuff"); }
  SV * cs         = args[0];
  SV * parameters = args[1];
  SV * expansion  = args[2];
  SV * locator = gullet_getLocator(aTHX_ xstomach->gullet);

  SV * expandable = expandable_new(aTHX_ state, cs, parameters, expansion, locator);
  state_installDefinition(aTHX_ state, expandable, NULL);
  primitive_afterAssignment(aTHX_ state); }

void
primitive_opcode_gdef(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  if(nargs != 3){
    croak("Bad \\def missing stuff"); }
  SV * cs         = args[0];
  SV * parameters = args[1];
  SV * expansion  = args[2];
  SV * locator = gullet_getLocator(aTHX_ xstomach->gullet);

  SV * expandable = expandable_new(aTHX_ state, cs, parameters, expansion, locator);
  state_installDefinition(aTHX_ state, expandable, "global");
  primitive_afterAssignment(aTHX_ state); }

void
primitive_opcode_let(pTHX_ SV * token, SV * primitive, SV * stomach, SV * state,
                          int nargs, SV ** args, LaTeXML_Boxstack stack){
  SV * token1 = args[0];
  SV * token2 = args[1];
  SV * meaning = state_meaning(aTHX_ state, token2);
  if(meaning && isa_Token(meaning) && token_equals(aTHX_ token1,meaning)){
  }
  else {
    LaTeXML_Token t1 = SvToken(token1);
    UTF8 name1 = PRIMITIVE_NAME[t1->catcode]; /* getCSName */
    name1 = (name1 == NULL ? t1->string : name1);
    state_assign(aTHX_ state, TBL_MEANING, name1, meaning, NULL); }
  if(meaning){ SvREFCNT_dec(meaning); }
  primitive_afterAssignment(aTHX_ state); }

void
primitive_invoke(pTHX_ SV * primitive, SV * token, SV * stomach, SV * state,
                 LaTeXML_Boxstack stack){
  LaTeXML_State xstate = SvState(state);
  HV * primitive_hash = SvHash(primitive);
  int tracing = state_lookupBoole(aTHX_ state, TBL_VALUE,"TRACINGMACROS"); PERL_UNUSED_VAR(tracing); /* -Wall */
  int profiling= xstate->config & CONFIG_PROFILING;
  LaTeXML_Token t = SvToken(token);PERL_UNUSED_VAR(t); /* -Wall */
  ENTER;  SV * current_token = get_sv("LaTeXML::CURRENT_TOKEN",1); save_item(current_token);
  sv_setsv(current_token, token);

  DEBUG_Primitive("Invoke Primitive %p %s[%s]\n",primitive,CC_SHORT_NAME[t->catcode],t->string);
  if(profiling){
    /*my $profiled = $XSTATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
      state_startProfiling(aTHX_ profiled,"expand"); */ }
  /* Call beforeDigest daemons */
  AV * before = hash_getAV(aTHX_ primitive_hash, "beforeDigest");
  if(before){
    DEBUG_Primitive("%p calling beforeDigest %p\n", primitive, before);
    boxstack_callAV(aTHX_ stack, token, state, primitive, before, stomach, 0, NULL);
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
    nargs = gullet_readArguments(aTHX_ gullet, state, npara, parameters, token, args);
    DEBUG_Primitive("got %d arguments\n", nargs);
    SvREFCNT_dec(parameters); }
  /* Call main replacement:  opcode, if defined, or function */
  SV * replacement = hash_get(aTHX_ primitive_hash, "replacement");
  if(replacement){
    DEBUG_Primitive("%p calling replacement %p\n", primitive, replacement);
    boxstack_call(aTHX_ stack, token, state, primitive, replacement, stomach, nargs, args);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(replacement); }

  /* Call afterDigest daemons */
  AV * after = hash_getAV(aTHX_ primitive_hash, "afterDigest");
  if(after){
    DEBUG_Primitive("%p calling afterDigest %p\n", primitive, after);
    boxstack_callAV(aTHX_ stack, token, state, primitive, after, stomach, nargs, args);
    DEBUG_Primitive("%p now has %d boxes\n",primitive,stack->nboxes);
    SvREFCNT_dec(after); }
  int i;
  for(i = 0; i < nargs; i++){   /* Now cleanup args */
    SvREFCNT_dec(args[i]); }
  DEBUG_Primitive("Primitive %p %s[%s] returned %d boxes\n",
                  primitive,CC_SHORT_NAME[t->catcode],t->string,stack->nboxes);
  LEAVE;
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
  primitive_install_op(aTHX_ "begingroup",    &primitive_opcode_begingroup);
  primitive_install_op(aTHX_ "endgroup",      &primitive_opcode_endgroup);
  primitive_install_op(aTHX_ "register",      &primitive_opcode_register);
  primitive_install_op(aTHX_ "advance",       &primitive_opcode_advance);
  primitive_install_op(aTHX_ "multiply",      &primitive_opcode_multiply);
  primitive_install_op(aTHX_ "divide",        &primitive_opcode_divide);
  primitive_install_op(aTHX_ "global",        &primitive_opcode_global);
  primitive_install_op(aTHX_ "long",          &primitive_opcode_long);
  primitive_install_op(aTHX_ "outer",         &primitive_opcode_outer);
  primitive_install_op(aTHX_ "def",           &primitive_opcode_def);
  primitive_install_op(aTHX_ "gdef",          &primitive_opcode_gdef);
  primitive_install_op(aTHX_ "let",           &primitive_opcode_let);
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
  SV * after = state_lookup(aTHX_ state,TBL_VALUE, "afterAssignment");
  if(after){
    state_assign(aTHX_ state, TBL_VALUE, "afterAssignment", NULL,"global");
    SV * stomach = state_stomach(aTHX_ state);
    SV * gullet = stomach_gullet(aTHX_ stomach);
    SvREFCNT_dec(stomach);
    gullet_unread(aTHX_ gullet, after);
    SvREFCNT_dec(gullet);
    SvREFCNT_dec(after); } }
