/*# /=====================================================================\ #
  # |  LaTeXML/src/errors.c                                               | #
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
  C-level Error handling support */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "errors.h"

void *
typecheck_croak(pTHX_ const char * const what, const char * const actualtype,
                const char * const where, const char * const loc, const char * const expected){
  croak("%s gave %s in %s%s\nexpected %s", what, actualtype,where,loc,expected);
  return NULL; }

#define MAXWHERE 80
char where_buffer[MAXWHERE];

const char *
where_from_cv(pTHX_ const CV *const cv){
  const GV *const gv = CvGV(cv);
  PERL_ARGS_ASSERT_CROAK_XS_USAGE;
  if (gv) {
    const char *const gvname = GvNAME(gv);
    const HV *const stash = GvSTASH(gv);
    const char *const hvname = stash ? HvNAME(stash) : NULL;
    if (hvname) {
      snprintf(where_buffer,MAXWHERE,"%s::%s", hvname, gvname);
      return where_buffer; }
    else {
      return gvname; } }
  else {
    snprintf(where_buffer,MAXWHERE,"CODE(0x%"UVxf")", PTR2UV(cv));
    return where_buffer; } }

const char *
actualtype_from_sv(pTHX_ const SV *arg){
  return (arg ? (SvROK(arg) ? sv_reftype(SvRV(arg),1)
                 : (SvOK(arg) ? sv_reftype(arg,1) : "undef"))
          : "nothing"); }
  
