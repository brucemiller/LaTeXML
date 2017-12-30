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

typedef struct Stomach_struct {
  SV * gullet;
  AV * boxing;
  AV * token_stack;
} T_Stomach;
typedef T_Stomach * LaTeXML_Stomach;

#define isa_Stomach(arg)      ((arg) && sv_isa(arg, "LaTeXML::Core::Stomach"))

#define SvStomach(arg)      INT2PTR(LaTeXML_Stomach,      SvIV((SV*) SvRV(arg)))

extern SV *
stomach_new(pTHX);

extern void
stomach_initialize(pTHX_ SV * stomach, SV * state);

extern SV *
stomach_gullet(pTHX_ SV * stomach);

extern SV *
stomach_getLocator(pTHX_ SV * stomach);

#define stomach_getLocator(stomach)  gullet_getLocator(aTHX_ stomach_gullet(stomach))

extern void
stomach_pushStackFrame(pTHX_ SV * stomach, SV * state, int nobox);

extern void
stomach_popStackFrame(pTHX_ SV * stomach, SV * state, int nobox);

#define stomach_bgroup(stomach, state) stomach_pushStackFrame(stomach, state, 0)

extern void
stomach_egroup(pTHX_ SV * stomach, SV * state);

#define stomach_begingroup(stomach, state) stomach_pushStackFrame(stomach, state, 1)

extern void
stomach_endgroup(pTHX_ SV * stomach, SV * state);

extern void
stomach_beginMode(pTHX_ SV * stomach, SV * state, UTF8 mode);

extern void
stomach_endMode(pTHX_ SV * stomach, SV * state, UTF8 mode);

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

extern SV *
stomach_digest(pTHX_ SV * stomach, SV * state, SV * tokens);

extern LaTeXML_Boxstack
stomach_digestNextBody(pTHX_ SV * stomach, SV * state, SV * terminal);

extern void
stomach_digestThing(pTHX_ SV * stomach, SV * state, SV * thing, LaTeXML_Boxstack stack);
