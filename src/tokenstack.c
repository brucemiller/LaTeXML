/*# /=====================================================================\ #
  # |  LaTeXML/src/tokenstack.c                                           | #
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
  C-Level Tokenstack support 
  Similar to Tokens, but puts tokens in reverse order */

#define TOKENSTACK_ALLOC_QUANTUM 10
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "errors.h"
#include "object.h"
#include "tokens.h"
#include "tokenstack.h"

LaTeXML_Tokenstack
tokenstack_new(pTHX) {
  LaTeXML_Tokenstack stack;
  Newxz(stack,1, T_Tokenstack);
  DEBUG_Tokenstack("New tokenstack %p\n",stack);
  stack->nalloc = TOKENSTACK_ALLOC_QUANTUM;
  Newx(stack->tokens, stack->nalloc, PTR_SV);
  return stack; }

void
tokenstack_DESTROY(pTHX_ LaTeXML_Tokenstack stack){
  int i;
  for (i = 0 ; i < stack->ntokens ; i++) {
    SvREFCNT_dec(stack->tokens[i]); }
  Safefree(stack->tokens);
  Safefree(stack); }

void
tokenstack_pushToken(pTHX_ LaTeXML_Tokenstack stack, SV * token) {
  DEBUG_Tokenstack("Tokenstack push token %p: %p ",stack,token);
  if(stack->ntokens >= stack->nalloc){
    stack->nalloc += TOKENSTACK_ALLOC_QUANTUM;
    Renew(stack->tokens, stack->nalloc, PTR_SV); }
  /* NOTE: Beware Tokens coming from Perl: use newSVsv (else the SV can change behind your back */
  SvREFCNT_inc(token);
  stack->tokens[stack->ntokens++] = token; }

void
tokenstack_push(pTHX_ LaTeXML_Tokenstack stack, SV * thing) {
  DEBUG_Tokenstack("Tokenstack push %p: %p ",stack,thing);
  if (isa_Token(thing)) {
    DEBUG_Tokenstack( "Token.");
    if(stack->ntokens >= stack->nalloc){
      stack->nalloc += TOKENSTACK_ALLOC_QUANTUM;
      Renew(stack->tokens, stack->nalloc, PTR_SV); }
    /* NOTE: Beware Tokens coming from Perl: use newSVsv (else the SV can change behind your back */
    SvREFCNT_inc(thing);
    stack->tokens[stack->ntokens++] = thing; }
  else if (isa_Tokens(thing)) {
    LaTeXML_Tokens xtokens = SvTokens(thing);
    int n = xtokens->ntokens;
    int i;
    DEBUG_Tokenstack( "Tokens(%d): ", n);
    if(n > 0){
      stack->nalloc += n-1;
      Renew(stack->tokens, stack->nalloc, PTR_SV);
      for (i = n-1 ; i >= 0 ; i--) {
        DEBUG_Tokenstack( "adding item %d; ",i);
        SvREFCNT_inc(xtokens->tokens[i]);
        stack->tokens[stack->ntokens++] = xtokens->tokens[i]; } } }
  else {
    /* Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))*/
    croak("Tokens push: Expected a Token, got %s (%p)",SvPV_nolen(thing), thing); }
  DEBUG_Tokenstack("Done pushing.\n");
}

SV *
tokenstack_pop(pTHX_ LaTeXML_Tokenstack stack) {
  DEBUG_Tokenstack("Tokenstack pop %p\n",stack);
  if(stack->ntokens > 0){
    SV * token = stack->tokens[--stack->ntokens];
    stack->tokens[stack->ntokens+1] = NULL;
    return token; }
  else {
    return NULL; } }

