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
#include "boxstack.h"
#include "stomach.h"
#include "parameters.h"

LaTeXML_Parameter
parameter_new(pTHX_ UTF8 spec){
  LaTeXML_Parameter parameter;
  Newxz(parameter, 1, T_Parameter);
  parameter->spec = string_copy(spec);
  parameter->reader = NULL;
  parameter->opreader = NULL;
  parameter->flags = 0;
  parameter->semiverbatim = NULL;
  parameter->extra = NULL;
  parameter->beforeDigest = NULL;
  parameter->afterDigest = NULL;
  parameter->reversion = NULL;
  return parameter; }

void
parameter_DESTROY(pTHX_ SV * parameter){
  LaTeXML_Parameter xparameter = SvParameter(parameter);  
  if(xparameter->spec        ){ Safefree(xparameter->spec); }
  if(xparameter->reader      ){ SvREFCNT_dec(xparameter->reader); }
  if(xparameter->semiverbatim){ Safefree(xparameter->semiverbatim); }
  if(xparameter->extra       ){ Safefree(xparameter->extra); }
  if(xparameter->beforeDigest){ SvREFCNT_dec(xparameter->beforeDigest); }
  if(xparameter->afterDigest ){ SvREFCNT_dec(xparameter->afterDigest); }
  if(xparameter->reversion   ){ SvREFCNT_dec(xparameter->reversion); }
  Safefree(xparameter); }

int
parameter_equals(pTHX_ SV * parameter, SV * other){
  LaTeXML_Parameter xparameter = SvParameter(parameter);  
  LaTeXML_Parameter xother     = SvParameter(other);  
  return strcmp(xparameter->spec, xother->spec) == 0; }

int
parameter_setupCatcodes(pTHX_ SV * parameter, SV * state){
  LaTeXML_Parameter xparameter = SvParameter(parameter);
  if(xparameter->semiverbatim){
    state_beginSemiverbatim(aTHX_ state, xparameter->nsemiverbatim, xparameter->semiverbatim);
    return 1; }
  return 0; }

void
parameter_revertCatcodes(pTHX_ SV * parameter, SV * state){
  LaTeXML_Parameter xparameter = SvParameter(parameter);
  if(xparameter->semiverbatim){
    state_endSemiverbatim(aTHX_ state); } }

int NEUTRALIZABLE[] = {
  0, 0, 0, 1,
  1, 0, 1, 1,
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0};

SV *
parameter_neutralize(pTHX_ SV * state, SV * tokens){
  if(isa_Tokens(tokens)){
    LaTeXML_Tokens xtokens = SvTokens(tokens);
    SV * newtokens = tokens_new(aTHX_ xtokens->ntokens);
    LaTeXML_Tokens xnewtokens = SvTokens(newtokens);
    int i;
    for(i = 0; i < xtokens->ntokens; i++){
      SV * token = xtokens->tokens[i];
      LaTeXML_Token xtoken = SvToken(token);
      if(! NEUTRALIZABLE[xtoken->catcode]){
        xnewtokens->tokens[xnewtokens->ntokens++] = SvREFCNT_inc(token); }
      else {
        int newcc = state_catcode(aTHX_ state, xtoken->string);
        if(newcc == xtoken->catcode){
          xnewtokens->tokens[xnewtokens->ntokens++] = SvREFCNT_inc(token); }
        else {
          xnewtokens->tokens[xnewtokens->ntokens++] = token_new(aTHX_ xtoken->string,newcc); } } }
    return newtokens; }
  else {
    return SvREFCNT_inc(tokens); } } /* whatever it is */
  
SV *
parameter_read_internal(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn){
  LaTeXML_Parameter xparameter = SvParameter(parameter);
  SV * value = NULL;
  if(xparameter->opreader){
    DEBUG_Gullet("readArguments reading parameter %s for %s, opcode %p\n",
                 xparameter->spec, TokenName(fordefn), xparameter->opreader);
    value = xparameter->opreader(aTHX_ parameter, gullet, state,
                                xparameter->nextra, xparameter->extra); }
  else if(xparameter->reader){
    DEBUG_Gullet("readArguments reading parameter %s for %s, code = %p\n",
                 xparameter->spec, TokenName(fordefn), xparameter->reader);
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,1+xparameter->nextra); PUSHs(gullet);
    int i;
    for(i=0; i<xparameter->nextra; i++){
      SV * arg = xparameter->extra[i];
      if(!arg){ arg = &PL_sv_undef; }
      PUSHs(arg); }
    PUTBACK;
    if(0){ fprintf(stderr,"PERL READER for %s\n",xparameter->spec); }
    int nvals = call_sv(xparameter->reader,G_SCALAR);
    SPAGAIN;
    if(nvals == 0){ }       /* nothing returned? */
    else if(nvals == 1){    /* pretty much can return anything? */
      value = POPs;
      if(! SvOK(value)){
        value = NULL; }
      else {
        SvREFCNT_inc(value); } }
    else {
      /* Or just warn of internal mis-definition? */
      croak("readArguments parameter reader for %s, returned %d values\n", TokenName(fordefn), nvals); }
    PUTBACK; FREETMPS; LEAVE; }
  else {
    croak("No reader (CODE or Opcode) for parameter %s (%p)",xparameter->spec, parameter); }
  return value; }

SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn){
  LaTeXML_Parameter xparameter = SvParameter(parameter);
  if(xparameter->semiverbatim){
    parameter_setupCatcodes(aTHX_ parameter, state); }
  SV * value = parameter_read_internal(aTHX_ parameter, gullet, state, fordefn);
  if((! value) && ! (xparameter->flags & PARAMETER_OPTIONAL)){
    /*Error('expected', $self, $gullet,
      "Missing argument " . Stringify($self) . " for " . Stringify($fordefn),
      $xgullet->showUnexpected);
      $value = T_OTHER('missing'); */
    croak("expected:argument %s",xparameter->spec);  }

  if(xparameter->semiverbatim){
    /*$value = $value->neutralize(@$semiverbatim) if (ref $value) && ($value->can('neutralize'));*/
    SV * oldvalue = value;
    if(value){
      value = parameter_neutralize(aTHX_ state, value);
      SvREFCNT_dec(oldvalue); }
    state_endSemiverbatim(aTHX_ state); }
  return value; }

SV *
parameter_readAndDigest(pTHX_ SV * parameter, SV * stomach, SV * state, SV * fordefn){
  LaTeXML_Parameter xparameter = SvParameter(parameter);
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  LaTeXML_Boxstack stack = boxstack_new(aTHX);
  if(xparameter->semiverbatim){
    parameter_setupCatcodes(aTHX_ parameter, state); }
  SV * value = parameter_read_internal(aTHX_ parameter, xstomach->gullet, state, fordefn);
  if((! value) && ! (xparameter->flags & PARAMETER_OPTIONAL)){

    croak("expected:argument %s",xparameter->spec);  }

  /* Question: maybe even before read??? */
  stack->discard = 1;
  if(xparameter->beforeDigest){ /* Can I pass parameter here??? */
    /*  NOT AV's ... YET?
        boxstack_callAV(aTHX_ stack, parameter, SvArray(xparameter->beforeDigest),
      state, stomach, fordefn, 0, NULL); }*/
    boxstack_call(aTHX_ stack, fordefn, state,
                  parameter, xparameter->beforeDigest, stomach, 0, NULL); }

  if(value && xparameter->semiverbatim){
    /*$value = $value->neutralize(@$semiverbatim) if (ref $value) && ($value->can('neutralize'));*/
    SV * oldvalue = value;
    value = parameter_neutralize(aTHX_ state, value);
    SvREFCNT_dec(oldvalue); }
  stack->discard = 0;
  if(value && !(xparameter->flags & PARAMETER_UNDIGESTED)){
    stomach_digestThing(aTHX_ stomach, state, value, stack);
    value = stack->boxes[0]; }
  stack->discard = 1;
  if(xparameter->afterDigest){
    /* boxstack_callAV(aTHX_ stack, parameter, SvArray(xparameter->afterDigest),
       state, stomach, fordefn, 0, NULL); } */
    boxstack_call(aTHX_ stack, fordefn, state,
                  parameter, xparameter->afterDigest, stomach, 0, NULL); }
  if(xparameter->semiverbatim){
    state_endSemiverbatim(aTHX_ state); }
  return value; }

SV *                            /* read regular arg {}  or {othertype}*/
parameter_opcode_arg(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * tokens = gullet_readArg(aTHX_ gullet, state);
  SV * innersv = (nargs > 0 ? args[0] : NULL);
  if(tokens){
    if(! innersv){             /* No inner parameters spec provided? */
      return tokens; }
    else {
      AV * inner = SvArray(innersv);
      SSize_t n_inner = av_len(inner) + 1;
      SV * inner_args[n_inner];
      int n_inner_args = 0;
      SV * mouth = gullet_openMouth(aTHX_ gullet, tokens, 1);
      n_inner_args = gullet_readArguments(aTHX_ gullet, state, n_inner, inner, NULL, inner_args);
      gullet_skipSpaces(aTHX_ gullet, state);
      gullet_closeThisMouth(aTHX_ gullet, mouth);
      SvREFCNT_dec(mouth);
      return (n_inner_args > 0 ? inner_args[0] : NULL); } }
  return NULL; }

SV *                            /* read regular arg {} */
parameter_opcode_xarg(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readXArg(aTHX_ gullet, state); }

SV *                            /* read regular arg {} */
parameter_opcode_xbody(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  ENTER;    /* local $LaTeXML::NOEXPAND_THE = undef; */
  SV * noexpandthe = get_sv("LaTeXML::NOEXPAND_THE",0);
  save_item(noexpandthe);
  sv_setsv(noexpandthe,newSViv(1));
  SV * tokens = gullet_readXArg(aTHX_ gullet, state);
  LEAVE;
  return tokens; }

SV *                            /* read Token */
parameter_opcode_Token(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readToken(aTHX_ gullet, state); }

SV *                            /* read XToken */
parameter_opcode_XToken(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  return gullet_readXToken(aTHX_ gullet, state, 0, 0); }


SV *                            /* read Token */
parameter_opcode_DefToken(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * token = gullet_readToken(aTHX_ gullet, state);
  LaTeXML_Token t;
  while(token && (t = SvToken(token)) && (t->catcode == CC_BEGIN)){
    gullet_skipSpaces(aTHX_ gullet, state);
    SV * tokens = tokens_new(aTHX_ 1);
    LaTeXML_Tokens xtokens = SvTokens(tokens);
    gullet_readBalanced(aTHX_ gullet,state,tokens,0);
    if(xtokens->ntokens){
      token = xtokens->tokens[0];
      int i;
      for(i = xtokens->ntokens-1; i > 0; i--){
        gullet_unreadToken(aTHX_ gullet, xtokens->tokens[i]); } }
    else {
      token = NULL; }
    SvREFCNT_dec(tokens); }
  return token; }

SV *                            /* read Token */
parameter_opcode_Optional(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * tokens = gullet_readOptional(aTHX_ gullet, state);
  SV * defaultsv = (nargs > 0 ? args[0] : NULL);
  SV * innersv   = (nargs > 1 ? args[1] : NULL);
  if(tokens){
    if(! innersv){             /* No inner parameters spec provided? */
      return tokens; }
    else {
      AV * inner = SvArray(innersv);
      SSize_t n_inner = av_len(inner) + 1;
      SV * inner_args[n_inner];
      int n_inner_args = 0;
      SV * mouth = gullet_openMouth(aTHX_ gullet, tokens, 1);
      n_inner_args = gullet_readArguments(aTHX_ gullet, state, n_inner, inner, NULL, inner_args);
      gullet_skipSpaces(aTHX_ gullet, state);
      gullet_closeThisMouth(aTHX_ gullet, mouth);
      SvREFCNT_dec(mouth);
      return (n_inner_args > 0 ? inner_args[0] : NULL); } }
  else if(defaultsv){
    SvREFCNT_inc(defaultsv);
    return defaultsv; }
  else {
    return NULL; } }

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
  return gullet_readUntilBrace(aTHX_ gullet, state); }

SV *                            /* require a brace (but don't include it) */
parameter_opcode_RequireBrace(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * token;
  LaTeXML_Token t;
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

SV *                            /* skip an "by" */
parameter_opcode_SkipBy(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  UTF8 choices[] = {"by"};
  gullet_readKeyword(aTHX_ gullet, state,1,choices);
  return NULL; }

SV *                            /* skip an "by" */
parameter_opcode_SkipTo(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  UTF8 choices[] = {"to"};
  gullet_readKeyword(aTHX_ gullet, state,1,choices);
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
  return gullet_readUntilMatch(aTHX_ gullet, state, 0, nargs,maxlength, type, args, &match); }

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

SV *
parameter_opcode_Register(pTHX_ SV * parameter, SV * gullet, SV * state, int nargs, SV ** args){
  SV * token;
  SV * defn;
  HV * defn_hash;
  if( (token = gullet_readXToken(aTHX_ gullet, state, 0, 0)) ){
    if ( (defn = state_definition(aTHX_ state, token))
         && (defn_hash = SvHash(defn))
         && (hash_getPV(aTHX_ defn_hash, "registerType"))){
      AV * reg = newAV();
      av_push(reg,defn);
      AV * parameters = hash_getAV(aTHX_ defn_hash,"parameters");
      SSize_t npara = (parameters ? av_len(parameters) + 1 : 0);
      SV * args[npara];
      int nargs = 0;
      if(parameters){
        nargs = gullet_readArguments(aTHX_ gullet, state, npara, parameters, token, args);
        int i;
        for(i = 0; i < nargs; i++){
          av_push(reg, args[i]); } }
      SvREFCNT_dec(token);
      return newRV_noinc((SV*)reg); }
    SvREFCNT_dec(token); }
  /* Eventually, possibly, create a register and fall back? */
  croak("Expected a register"); }

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
  parameter_install_op(aTHX_ "DefToken",      &parameter_opcode_DefToken);
  parameter_install_op(aTHX_ "CSName",        &parameter_opcode_CSName);
  parameter_install_op(aTHX_ "SkipSpace",     &parameter_opcode_SkipSpace);
  parameter_install_op(aTHX_ "SkipSpaces",    &parameter_opcode_SkipSpaces);
  parameter_install_op(aTHX_ "SkipEquals",    &parameter_opcode_SkipEquals);
  parameter_install_op(aTHX_ "SkipBy",        &parameter_opcode_SkipBy);
  parameter_install_op(aTHX_ "SkipTo",        &parameter_opcode_SkipTo);
  parameter_install_op(aTHX_ "Match",         &parameter_opcode_Match);
  parameter_install_op(aTHX_ "Until",         &parameter_opcode_Until);
  parameter_install_op(aTHX_ "UntilBrace",    &parameter_opcode_UntilBrace);
  parameter_install_op(aTHX_ "Optional",      &parameter_opcode_Optional);
  parameter_install_op(aTHX_ "RequireBrace",  &parameter_opcode_RequireBrace);
  parameter_install_op(aTHX_ "Number",        &parameter_opcode_Number);
  parameter_install_op(aTHX_ "Dimension",     &parameter_opcode_Dimension);
  parameter_install_op(aTHX_ "Glue",          &parameter_opcode_Glue);
  parameter_install_op(aTHX_ "MuGlue",        &parameter_opcode_MuGlue);
  parameter_install_op(aTHX_ "Float",         &parameter_opcode_Float);
  parameter_install_op(aTHX_ "DefParameters", &parameter_opcode_DefParameters);
  parameter_install_op(aTHX_ "Register",      &parameter_opcode_Register);
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
