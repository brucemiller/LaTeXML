/*# /=====================================================================\ #
  # |  LaTeXML/src/primitive.h                                            | #
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
  C-level Primitive support */

#ifndef PRIMITIVE_H
#define PRIMITIVE_H

#define DEBUG_PRIMITIVENOT
#ifdef DEBUG_PRIMITIVE
#  define DEBUG_Primitive(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Primitive 1
#else
#  define DEBUG_Primitive(...)
#  define DEBUGGING_Primitive 0
#endif

/* void primitive_op(aTHX_ token, primitive_defn, stomach, state, nargs, args, resultstack)*/
typedef void primitive_op(pTHX_ SV *, SV *, SV *, SV *, int, SV **, LaTeXML_Core_Boxstack);

extern primitive_op *
primitive_lookup(pTHX_ UTF8 opcode);

extern void
primitive_invoke(pTHX_ SV * primitive, SV * token, SV * stomach, SV * state,
                 LaTeXML_Core_Boxstack stack);

extern void
primitive_afterAssignment(pTHX_ SV * state);

#endif
