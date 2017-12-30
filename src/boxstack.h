/*# /=====================================================================\ #
  # |  LaTeXML/src/boxstack.h                                             | #
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

#ifndef BOXSTACK_H
#define BOXSTACK_H

#define DEBUG_BOXSTACKNOT
#ifdef DEBUG_BOXSTACK
#  define DEBUG_Boxstack(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Boxstack 1
#else
#  define DEBUG_Boxstack(...)
#  define DEBUGGING_Boxstack 0
#endif

typedef struct Boxstack_struct {
  int nboxes;
  int nalloc;
  int discard;
  PTR_SV * boxes;
} T_Boxstack;
typedef T_Boxstack * LaTeXML_Boxstack;

extern LaTeXML_Boxstack
boxstack_new(pTHX);

extern void
boxstack_DESTROY(pTHX_ LaTeXML_Boxstack stack);

extern void
boxstack_push(pTHX_ LaTeXML_Boxstack stack, SV * box);

/* Invoke a Stomach->method to produce boxes */
extern void                            /* Horrible naming!!! */
boxstack_callmethod(pTHX_ LaTeXML_Boxstack stack, SV * token, SV * state,
                    SV * object, UTF8 method, int nargs, SV ** args);

/* Call a primitive's replacement sub (OPCODE or CODE) on the given arguments */
extern void                            /* Horrible naming!!! */
boxstack_call(pTHX_ LaTeXML_Boxstack stack, SV * token, SV * state,
              SV * primitive, SV * sub, SV * stomach, 
              int nargs, SV ** args);
extern void
boxstack_callAV(pTHX_ LaTeXML_Boxstack stack, SV * token, SV * state, 
                SV * primitive, AV * subs, SV * stomach, int nargs, SV ** args);

#endif
