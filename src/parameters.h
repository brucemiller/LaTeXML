/*# /=====================================================================\ #
  # |  LaTeXML/src/parameters.h                                           | #
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

#ifndef PARAMETERS_H
#define PARAMETERS_H

/* SV * parameter_op(aTHX_ parameter, gullet, state, nargs, args) */
typedef SV * parameter_op(pTHX_ SV *, SV *, SV *, int, SV **);  

typedef struct Parameter_struct {
  UTF8 spec;
  SV * reader;
  parameter_op * opreader;
  int flags;
  SV * semiverbatimsv;            /* Duplicated until completely within the C */
  int nsemiverbatim;              /* -1 means need semiverbatim, but no extra tokens */
  UTF8 * semiverbatim;
  SV * extrasv;
  int nextra;
  SV ** extra;
  SV * beforeDigest;
  SV * afterDigest;
  SV * reversion;
} T_Parameter;
typedef T_Parameter * LaTeXML_Parameter;

#define isa_Parameter(arg)    ((arg) && sv_isa(arg, "LaTeXML::Core::Parameter"))

#define SvParameter(arg)      ((LaTeXML_Parameter)INT2PTR(LaTeXML_Parameter,SvIV((SV*) SvRV(arg))))

#define PARAMETER_OPTIONAL   0x01
#define PARAMETER_NOVALUE    0x02
#define PARAMETER_UNDIGESTED 0x04

extern LaTeXML_Parameter
parameter_new(pTHX_ UTF8 spec);

extern void
parameter_DESTROY(pTHX_ SV * parameter);

extern int
parameter_equals(pTHX_ SV * parameter, SV * other);

extern parameter_op *
parameter_lookup(pTHX_ UTF8 opcode);

extern int
parameter_setupCatcodes(pTHX_ SV * parameter, SV * state);

extern void
parameter_revertCatcodes(pTHX_ SV * parameter, SV * state);

extern SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn);

extern SV *
parameter_readAndDigest(pTHX_ SV * parameter, SV * stomach, SV * state, SV * fordefn);

#endif
