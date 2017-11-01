/*# /=====================================================================\ #
  # |  LaTeXML/src/parameters.c                                           | #
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
  C-level Parameter support */

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
#include "parameters.h"

SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn){
  SV * value = NULL;
  HV * parameter_hash = SvHash(parameter);
  UTF8 spec = hash_getPV(aTHX_ parameter_hash,"spec");
  SV * reader = hash_get(aTHX_ parameter_hash,"reader");
  UTF8 opcode = NULL;
  parameter_op * op = NULL;
  SV ** ptr;
  int i;
  AV * semiverb = hash_getAV(aTHX_ parameter_hash, "semiverbatim");
  if(semiverb){
    int i,nc = av_len(semiverb)+1;
    UTF8 chars[nc];
    int nchars = 0;
    for(i = 0; i < nchars; i++){
      if( (ptr = av_fetch(semiverb,i,0)) ){
        chars[nchars++] = SvPV_nolen(*ptr); } }
    state_beginSemiverbatim(aTHX_ state, nchars, chars);
    SvREFCNT_dec(semiverb); }
  AV * extra = hash_getAV(aTHX_ parameter_hash, "extra");
  int nargs = (extra ? av_len(extra)+1 : 0);
  SV * args[nargs];
  if(extra){
    for(i = 0; i < nargs; i++){
      ptr = av_fetch(extra,i,0);
      args[i] = (ptr && SvOK(*ptr) ? *ptr : NULL); }
      SvREFCNT_dec(extra); }
  if(reader && sv_isa(reader,"LaTeXML::Core::Opcode")
     && (opcode = SvPV_nolen(SvRV(reader)))
     && (op = parameter_lookup(aTHX_ opcode))){
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
  if((! value) && !hash_getBoole(aTHX_ parameter_hash, "optional")){
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


HV * parameter_opcode_table = NULL;

void
parameter_install_op(pTHX_ UTF8 opcode, parameter_op * op){
  if(! parameter_opcode_table){
    parameter_opcode_table = newHV(); }
  SV * ref = newSV(0);
  sv_setref_pv(ref, NULL, (void*)op);
  hv_store(parameter_opcode_table,opcode,-strlen(opcode),  ref,0);  }

void
parameter_install_opcodes(pTHX){
  /* Install Parameter Reader Opcodes */
  parameter_install_op(aTHX_ "Arg",           &parameter_opcode_arg);
  parameter_install_op(aTHX_ "XArg",          &parameter_opcode_xarg);
  parameter_install_op(aTHX_ "XBody",         &parameter_opcode_xbody);
  parameter_install_op(aTHX_ "Token",         &parameter_opcode_Token);
  parameter_install_op(aTHX_ "XToken",        &parameter_opcode_XToken);
  parameter_install_op(aTHX_ "CSName",        &parameter_opcode_CSName);
  parameter_install_op(aTHX_ "SkipSpace",     &parameter_opcode_SkipSpace);
  parameter_install_op(aTHX_ "SkipSpaces",    &parameter_opcode_SkipSpaces);
  parameter_install_op(aTHX_ "SkipEquals",    &parameter_opcode_SkipEquals);
  parameter_install_op(aTHX_ "Match",         &parameter_opcode_Match);
  parameter_install_op(aTHX_ "Until",         &parameter_opcode_Until);
  parameter_install_op(aTHX_ "UntilBrace",    &parameter_opcode_UntilBrace);
  parameter_install_op(aTHX_ "RequireBrace",  &parameter_opcode_RequireBrace);
  parameter_install_op(aTHX_ "Number",        &parameter_opcode_Number);
  parameter_install_op(aTHX_ "Dimension",     &parameter_opcode_Dimension);
  parameter_install_op(aTHX_ "Glue",          &parameter_opcode_Glue);
  parameter_install_op(aTHX_ "MuGlue",        &parameter_opcode_MuGlue);
  parameter_install_op(aTHX_ "Float",         &parameter_opcode_Float);
  parameter_install_op(aTHX_ "DefParameters", &parameter_opcode_DefParameters);
}

parameter_op *
parameter_lookup(pTHX_ UTF8 opcode){
  if(! parameter_opcode_table){
    parameter_install_opcodes(aTHX);
    if(! parameter_opcode_table){
      croak("internal:missing:parameter_opcode_table"); } }
  SV ** ptr = hv_fetch(parameter_opcode_table,opcode,-strlen(opcode),0);
  if(ptr && *ptr && SvOK(*ptr)){
    IV tmp = SvIV((SV*)SvRV(*ptr));
    return INT2PTR(parameter_op *, tmp); }
  return NULL; }
