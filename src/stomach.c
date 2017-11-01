/*# /=====================================================================\ #
  # |  LaTeXML/src/stomach.c                                                | #
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
  C-level Stomach support */

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

SV *
stomach_gullet(pTHX_ SV * stomach){
  SV * gullet = hash_get(aTHX_ SvHash(stomach),"gullet");
  if(! gullet){
    croak("internal:stomach Stomach has no Gullet!"); }
  return gullet; }

SV *
stomach_getLocator(pTHX_ SV * stomach){
  return gullet_getLocator(aTHX_ stomach_gullet(aTHX_ stomach)); }

void
stomach_defineUndefined(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* $stomach->invokeToken_undefined($token) */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_undefined", state, stomach, token,nargs, args); }

void
stomach_insertComment(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_comment", state, stomach, token,nargs, args); }

void
stomach_insertBox(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, "invokeToken_insert", state, stomach, token,nargs, args); }

void                            /* NOTE: Really only for constructors */
stomach_invokeDefinition(pTHX_ SV * stomach, SV * state, SV * token, SV * defn, LaTeXML_Core_Boxstack stack){
  SV * args[] = {token, defn};
  int nargs = 2;
  boxstack_callmethod(aTHX_ stack, "invokeToken_definition", state, stomach, token, nargs, args); }

int absorbable_cc[] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0};

int letter_or_other[] = {
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 1,
  1, 0, 0, 0,
  0, 0};

void
stomach_invokeToken(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Core_Boxstack stack){
  /* push tokon token stack*/
  /* if maxstack, fatal */
 REINVOKE:
  if(! token){
    return; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  DEBUG_Stomach("Invoke token %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  char * name =
    (ACTIVE_OR_CS [cc]
     || (letter_or_other[cc] && state_booleval(aTHX_ state, "IN_MATH")
         && (state_mathcode(aTHX_ state, t->string) == 0x8000))
     ? t->string
     : EXECUTABLE_NAME[cc]);
  SV * defn = NULL;
  SV * insert_token = NULL;    /* Common case, default */
  if(name && (defn = state_meaning_internal(aTHX_ state, name)) ){
    /* If \let to an executable token (typically $, {,}, etc), lookup IT's defn! */
    if(sv_isa(defn, "LaTeXML::Core::Token")){
      LaTeXML_Core_Token let = SvToken(defn);
      char * letname;
      SV * letdefn;
      if( (letname = EXECUTABLE_NAME[let->catcode])
          && (letdefn = state_meaning_internal(aTHX_ state, letname)) ){
        if(sv_isa(letdefn, "LaTeXML::Core::Token")){ /* And if that's a token? */
          insert_token = letdefn; /*SvREFCNT_dec(defn);*/ defn = NULL; }
        else {
          defn = letdefn; } }
      else {
        insert_token = defn; defn = NULL; } } }
  else {
    insert_token = token; }
  if(insert_token){
    /*LaTeXML_Core_Token it = SvToken(insert_token);*/
    DEBUG_Stomach("Invoke token self-insert %s[%s]\n",CC_SHORT_NAME[it->catcode],it->string); }
  else {
    DEBUG_Stomach("Invoke defn %p [%s]\n", defn, sv_reftype(SvRV(defn),1));
    /*Perl_sv_dump(aTHX_ defn);*/
  }
  HV * defn_hash = (defn ? SvHash(defn) : NULL);
  if (insert_token) {    /* Common case*/
    LaTeXML_Core_Token it = SvToken(insert_token);
    int icc = it->catcode;
    if (icc == CC_CS) {
      DEBUG_Stomach("Invoking undefined\n");
      stomach_defineUndefined(aTHX_ stomach, state, insert_token, stack); }
    else if (icc == CC_COMMENT) {
      DEBUG_Stomach("Inserting comment\n");
      stomach_insertComment(aTHX_ stomach, state, insert_token, stack); }
    else if (absorbable_cc[icc]) {
      DEBUG_Stomach("Inserting box\n");
      stomach_insertBox(aTHX_ stomach, state, insert_token, stack); }
    else {
      croak("misdefined: The token %s[%s] => %s[%s] should never reach Stomach!",
            CC_SHORT_NAME[t->catcode],t->string,
            CC_SHORT_NAME[it->catcode],it->string); } }
  /* A math-active character will (typically) be a macro,
     but it isn't expanded in the gullet, but later when digesting, in math mode (? I think) */
  else if (hash_getBoole(aTHX_ defn_hash,"isExpandable")){
    SvREFCNT_inc(defn);
    SV * gullet = stomach_gullet(aTHX_ stomach);
    SV * exp = expandable_invoke(aTHX_ defn, token, gullet, state);
    DEBUG_Stomach("Invoking expandable\n");
    gullet_unreadToken(aTHX_ gullet, exp);
    token = gullet_readXToken(aTHX_ gullet, state, 0, 0); /* replace token by it's expansion!!!*/
    /*pop(@{ $$self{token_stack} });*/
    SvREFCNT_dec(gullet);
    SvREFCNT_dec(defn);
    goto REINVOKE; }
  /*  elsif ($meaning->isaDefinition) { */   /* Otherwise, a normal primitive or constructor*/
  /* IF it IS a primitive (not derived from, yet), call direct */
  else if(sv_isa(defn,"LaTeXML::Core::Definition::Primitive")
          || (sv_isa(defn,"LaTeXML::Core::Definition::Register")) ) {
    SvREFCNT_inc(defn);
    primitive_invoke(aTHX_ defn, token, stomach, state, stack);
    if(!(sv_isa(defn,"LaTeXML::Core::Definition::Primitive")
         || (sv_isa(defn,"LaTeXML::Core::Definition::Register")) )){
      fprintf(stderr,"\nOH NO! definition got wrecked:\n"); Perl_sv_dump(aTHX_ defn); }
    if(! hash_getBoole(aTHX_ defn_hash, "isPrefix")){
      state_clearFlags(aTHX_ state); }
    SvREFCNT_dec(defn);
  }
  else if(sv_derived_from(defn,"LaTeXML::Core::Definition")) {
    SvREFCNT_inc(defn);
    DEBUG_Stomach("Invoking Constructor\n");
    stomach_invokeDefinition(aTHX_ stomach, state, token, defn, stack);
    SvREFCNT_dec(defn); }
  else {
    croak("misdefined: The token %s[%s] => %p [%s] should never reach Stomach!",
          CC_SHORT_NAME[t->catcode],t->string, defn, sv_reftype(SvRV(defn),1)); }
  /*
  if ((scalar(@result) == 1) && (!defined $result[0])) {
  @result = (); }  */                                     /*Just paper over the obvious thing.*/
  /*
  Fatal('misdefined', $token, $self,
    "Execution yielded non boxes",
    "Returned " . join(',', map { "'" . Stringify($_) . "'" }
        grep { (!ref $_) || (!$_->isaBox) } @result))
        if grep { (!ref $_) || (!$_->isaBox) } @result; */
  /*pop(@{ $$self{token_stack} });*/
  /*return @result; */
 }

