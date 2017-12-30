/*# /=====================================================================\ #
  # |  LaTeXML/src/tokenstack.h                                           | #
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
  Similar to Tokens, but puts tokens in reverse order.

ORRR: should it act more like a mouth, and we'd alternate mouth's & Tokenstack's
rather than embed a tokenstack inside a mouth?
*/

#ifndef TOKENSTACK_H
#define TOKENSTACK_H

#define DEBUG_TOKENSTACKNOT
#ifdef DEBUG_TOKENSTACK
#  define DEBUG_Tokenstack(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Tokenstack 1
#else
#  define DEBUG_Tokenstack(...)
#  define DEBUGGING_Tokenstack 0
#endif

typedef struct Tokenstack_struct {
  int ntokens;
  int nalloc;
  PTR_SV * tokens;
} T_Tokenstack;
typedef T_Tokenstack * LaTeXML_Tokenstack;

#define isa_Tokenstack(arg)   ((arg) && sv_isa(arg, "LaTeXML::Core::Tokenstack"))

#define SvTokenstack(arg) ((LaTeXML_Tokenstack)INT2PTR(LaTeXML_Tokenstack, SvIV((SV*) SvRV(arg))))

#define TOKENSTACK_ALLOC_QUANTUM 10

extern LaTeXML_Tokenstack
tokenstack_new(pTHX);

extern void
tokenstack_DESTROY(pTHX_ LaTeXML_Tokenstack stack);

extern void
tokenstack_pushToken(pTHX_ LaTeXML_Tokenstack stack, SV * token);

extern void
tokenstack_push(pTHX_ LaTeXML_Tokenstack stack, SV * thing);

extern SV *
tokenstack_pop(pTHX_ LaTeXML_Tokenstack stack);

#endif
