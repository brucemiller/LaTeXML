/*# /=====================================================================\ #
  # |  LaTeXML/src/numbers.h                                              | #
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
  C-Level Numbers, Dimensions ... support
  Strictly speaking, Number should contain int (SViv); others contain SVnv (double) */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "object.h"
#include "numbers.h"

SV *
number_new(pTHX_ int num){
  AV * av = newAV();
  av_push(av, newSViv(num));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Number",0));
  return ref; }

int
number_value(pTHX_ SV * sv){     /* num presumbed to be SViv */
  AV * av = SvArray(sv);
  SV ** ptr;
  if( (ptr = av_fetch(av,0,0)) && SvOK(*ptr)){
    if(SvIOK(*ptr)){
      return SvIV(*ptr); }
    else if (SvNOK(*ptr)){
      return SvNV(*ptr); }
    else {
      croak("Expected an integer"); } }
  return 0; }

int
number_formatScaled(pTHX_ char * buffer, int sp){   /* Knuth's: TeX the Program, algorithm 103 */
  /* buffer should be (at least)  char buffer = [3*sizeof(int)*CHAR_BIT/8 + 2]; */
  int delta = 10;
  int ptr = 0;
  if(sp < 0){
    buffer[ptr++] = '-'; sp = -sp; }
  ptr += sprintf(buffer+ptr,"%d", sp >> 16);
  buffer[ptr++] = '.';
  sp = 10*(sp & 0xFFFF) + 5;
  do {
    if(delta > 0x10000){
      sp = sp + 0100000 - 50000; }  /* round the last digit */
    buffer[ptr++] = '0' + (sp / 0x10000);
    sp = 10 * (sp & 0xFFFF); delta = delta * 10; }
  while( sp > delta );
  buffer[ptr] = 0;
  return ptr; }

SV *
dimension_new(pTHX_ int sp){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Dimension",0));
  return ref; }

SV *
glue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  av_push(av, newSViv(plus));
  av_push(av, newSViv(plusfill));
  av_push(av, newSViv(minus));
  av_push(av, newSViv(minusfill));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Glue",0));
  return ref; }

SV *
glue_negate(pTHX_ SV * glue){
  AV * glue_av = SvArray(glue);
  AV * av = newAV();
  int sp = array_getIV(aTHX_ glue_av, 0);
  int pv = array_getIV(aTHX_ glue_av, 1);
  int pf = array_getIV(aTHX_ glue_av, 2);
  int mv = array_getIV(aTHX_ glue_av, 3);
  int mf = array_getIV(aTHX_ glue_av, 4);
  av_push(av, newSViv(-sp));
  av_push(av, newSViv(-pv));
  av_push(av, newSViv(pf));
  av_push(av, newSViv(-mv));
  av_push(av, newSViv(mf));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Glue",0));
  return ref; }

SV *
muglue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill){
  AV * av = newAV();
  av_push(av, newSViv(sp));
  av_push(av, newSViv(plus));
  av_push(av, newSViv(plusfill));
  av_push(av, newSViv(minus));
  av_push(av, newSViv(minusfill));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Core::MuGlue",0));
  return ref; }

SV *
muglue_negate(pTHX_ SV * muglue){
  AV * muglue_av = SvArray(muglue);
  AV * av = newAV();
  int sp = array_getIV(aTHX_ muglue_av, 0);
  int pv = array_getIV(aTHX_ muglue_av, 1);
  int pf = array_getIV(aTHX_ muglue_av, 2);
  int mv = array_getIV(aTHX_ muglue_av, 3);
  int mf = array_getIV(aTHX_ muglue_av, 4);
  av_push(av, newSViv(-sp));
  av_push(av, newSViv(-pv));
  av_push(av, newSViv(pf));
  av_push(av, newSViv(-mv));
  av_push(av, newSViv(mf));
  /* Note: you can't use sv_setref_pv with an AV or HV! */
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Core::MuGlue",0));
  return ref; }

SV *
float_new(pTHX_ double num){     /* num presumbed to be SViv/SVnv scaled points */
  AV * av = newAV();
  av_push(av, newSVnv(num));
  SV * ref = newRV_noinc((SV*)av);
  sv_bless(ref, gv_stashpv("LaTeXML::Common::Float",0));
  return ref; }

