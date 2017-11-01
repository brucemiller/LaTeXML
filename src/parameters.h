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

extern parameter_op *
parameter_lookup(pTHX_ UTF8 opcode);

extern SV *
parameter_read(pTHX_ SV * parameter, SV * gullet, SV * state, SV * fordefn);


#endif
