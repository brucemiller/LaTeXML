/*# /=====================================================================\ #
  # |  LaTeXML/src/boxstack.c                                             | #
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
  C-level Boxstack support;
  accumulator for boxes/whatsit's resulting from Primitives & Constructors */

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

#define BOXSTACK_ALLOC_QUANTUM 10

LaTeXML_Boxstack
boxstack_new(pTHX) {
  LaTeXML_Boxstack stack;
  Newxz(stack,1, T_Boxstack);
  DEBUG_Boxstack("New boxstack %p\n",stack);
  stack->nalloc = BOXSTACK_ALLOC_QUANTUM;
  Newx(stack->boxes, stack->nalloc, PTR_SV);
  return stack; }

void
boxstack_DESTROY(pTHX_ LaTeXML_Boxstack stack){
  int i;
  for (i = 0 ; i < stack->nboxes ; i++) {
    SvREFCNT_dec(stack->boxes[i]); }
  Safefree(stack->boxes);
  Safefree(stack); }

/* Invoke a Stomach->method to produce boxes */
void                            /* Horrible naming!!! */
boxstack_callmethod(pTHX_ LaTeXML_Boxstack stack, UTF8 method,
              SV * state, SV * stomach, SV * token,
              int nargs, SV ** args) {
  DEBUG_Boxstack("Boxstack %p call %s on %d args\n",stack,method,nargs);
  int i;
  DEBUG_Boxstack("Replacement is METHOD %s\n", method);
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,nargs+1); PUSHs(stomach); 
  for(i=0; i<nargs; i++){
    SV * arg = (args[i] ? args[i] : &PL_sv_undef);
    PUSHs(arg); }
  PUTBACK;
  if(stack->discard){
    call_method(method,G_DISCARD);
    DEBUG_Boxstack("code returned, discarding values\n");
    SPAGAIN; }
  else {
    int nvals = call_method(method,G_ARRAY);
    DEBUG_Boxstack("code returned %d values\n", nvals);
    SPAGAIN;
    if(stack->nboxes+nvals >= stack->nalloc){
      stack->nalloc += nvals;
      Renew(stack->boxes, stack->nalloc, PTR_SV); }
    SP -= nvals;
    I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
    for(i = 0; i < nvals; i++){
      SV * box = ST(i);
      if (box && SvOK(box)){
        DEBUG_Boxstack("Box %s.",sv_reftype(SvRV(box),1));
        /*box = SvRV(box);  ????? */
        SvREFCNT_inc(box);
        stack->boxes[stack->nboxes++] = box; } } }
  PUTBACK; FREETMPS; LEAVE;
  DEBUG_Boxstack("Done accumulating.\n"); }

/* Call a primitive's replacement sub (OPCODE or CODE) on the given arguments */
void                            /* Horrible naming!!! */
boxstack_call(pTHX_ LaTeXML_Boxstack stack, SV * primitive, SV * sub,
              SV * state, SV * stomach, SV * token,
              int nargs, SV ** args) {
  DEBUG_Boxstack("Boxstack %p call %p on %d args\n",stack,sub,nargs);
  int i;
  if(! SvOK(sub)){      /* empty? */
    DEBUG_Boxstack("Replacement is undef\n");
    return; }
  else if(sv_isa(sub,"LaTeXML::Core::Opcode")){
    UTF8 opcode = SvPV_nolen(SvRV(sub));
    DEBUG_Boxstack("Replacement is opcode %s\n", opcode);
    primitive_op * op = primitive_lookup(aTHX_ opcode);
    if(op){
      op(aTHX_ token, primitive, stomach, state, nargs, args, stack); }
    else {
      croak("Internal error: Primitive opcode %s has no definition",opcode); } }
  else if(SvTYPE(SvRV(sub)) == SVt_PVCV){ /* ref $expansion eq 'CODE' */
    DEBUG_Boxstack("Replacement is CODE %p\n", sub);
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,nargs+1); PUSHs(stomach); 
    for(i=0; i<nargs; i++){
      SV * arg = (args[i] ? args[i] : &PL_sv_undef);
      PUSHs(arg); }
    PUTBACK;
    if(stack->discard){
      call_sv(sub,G_DISCARD);
      DEBUG_Boxstack("code returned discarding values\n");
      SPAGAIN; }
    else {
      int nvals = call_sv(sub,G_ARRAY);
      DEBUG_Boxstack("code returned %d values\n", nvals);
      SPAGAIN;
      if(stack->nboxes+nvals >= stack->nalloc){
        stack->nalloc += nvals;
        Renew(stack->boxes, stack->nalloc, PTR_SV); }
      SP -= nvals;
      I32 ax = (SP - PL_stack_base) + 1; /* Hackery to read return in reverse using ST! */
      for(i = 0; i < nvals; i++){
        SV * box = ST(i);
        if (box && SvOK(box)){
          DEBUG_Boxstack("Box.");
          /*box = SvRV(box);  ????? */
          SvREFCNT_inc(box);
          stack->boxes[stack->nboxes++] = box; } } }
    PUTBACK; FREETMPS; LEAVE;
    DEBUG_Boxstack("Done accumulating.\n"); }
  else {
    LaTeXML_Token t = SvToken(token);
    croak("Boxstack replacement for %s is not CODE or Opcode: %p",t->string, sub); } }


void
boxstack_callAV(pTHX_ LaTeXML_Boxstack stack, SV * primitive, AV * subs,
                SV * state, SV * stomach, SV * token,
                int nargs, SV ** args) {
  int i;
  if(subs){
    SSize_t nsubs = av_len(subs) + 1;
    DEBUG_Boxstack("Boxstack %p calling %ld subs\n",stack,nsubs);
    for(i = 0; i < nsubs; i++){
      SV ** ptr = av_fetch(subs,i,0);
      if(*ptr && SvOK(*ptr)){
        SV * sub = *ptr;
        boxstack_call(aTHX_ stack, primitive, sub, state, stomach, token, nargs, args); } }
    DEBUG_Boxstack("Boxstack %p done calling %ld subs\n",stack,nsubs); }
}

