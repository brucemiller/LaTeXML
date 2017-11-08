/*# /=====================================================================\ #
  # |  LaTeXML/src/stomach.h                                                | #
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

#ifndef STOMACH_H
#define STOMACH_H

#define DEBUG_STOMACHNOT
#ifdef DEBUG_STOMACH
#  define DEBUG_Stomach(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Stomach 1
#else
#  define DEBUG_Stomach(...)
#  define DEBUGGING_Stomach 0
#endif

extern SV *
stomach_gullet(pTHX_ SV * stomach);

extern SV *
stomach_getLocator(pTHX_ SV * stomach);

extern void
stomach_defineUndefined(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack);

extern void
stomach_insertComment(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack);

extern void
stomach_insertBox(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack);

extern void                            /* NOTE: Really only for constructors */
stomach_invokeDefinition(pTHX_ SV * stomach, SV * state, SV * token, SV * defn, LaTeXML_Boxstack stack);

extern void
stomach_invokeToken(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack);
#endif
