/*# /=====================================================================\ #
  # |  LaTeXML/src/expandable.h                                           | #
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
  C-level Expandable support */

#ifndef EXPANDABLE_H
#define EXPANDABLE_H

#define DEBUG_EXPANDABLENOT
#ifdef DEBUG_EXPANDABLE
#  define DEBUG_Expandable(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Expandable 1
#else
#  define DEBUG_Expandable(...)
#  define DEBUGGING_Expandable 0
#endif

/* SV * expandable_op(aTHX_ token, expandable_defn, gullet, state, nargs, args)*/
/* And, perhaps eventually, Tokens to accumulate results? */
typedef SV * expandable_op(pTHX_ SV *, SV *, SV *, SV *, int, SV **);

extern expandable_op *
expandable_lookup(pTHX_ UTF8 opcode);

extern SV *
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state);

#endif
