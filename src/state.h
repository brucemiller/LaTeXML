/*# /=====================================================================\ #
  # |  LaTeXML/src/state.h                                                | #
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
  C-level State support */

#ifndef STATE_H
#define STATE_H

#define DEBUG_STATENOT
#ifdef DEBUG_STATE
#  define DEBUG_State(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_State 1
#else
#  define DEBUG_State(...)
#  define DEBUGGING_State 0
#endif

#define SCALED_POINT 65536
#define POINTS_PER_INCH 72.27

#define MAX_TEXT_UNITS 20
#define MAX_UNITS 21
extern UTF8 UNIT_NAME[];
extern double UNIT_VALUE[];

extern SV *
state_global(pTHX);

extern SV *
state_stomach(pTHX_ SV * state);

extern SV *
state_stomach_noerror(pTHX_ SV * state);

extern SV *
state_model(pTHX_ SV * state);

extern HV *
state_valueTable_noinc(pTHX_ SV * state);

extern HV *
state_stashTable_noinc(pTHX_ SV * state);

extern HV *
state_activeStashTable_noinc(pTHX_ SV * state);

/* NOTE: The next 3 should NOT be exported!!! (so we can internalize the tables) */
extern SV *                            /* WARNING: No refcnt increment here!!! */
state_lookup_noinc(pTHX_ SV * state, UTF8 table, UTF8 string);

extern SV *
state_lookup(pTHX_ SV * state, UTF8 table, UTF8 string);

extern void
state_assign_internal(pTHX_ SV * state, UTF8 table, UTF8 key, SV * value, UTF8 scope);

extern void
state_activateScope(pTHX_ SV * state, UTF8 scope);

extern void
state_deactivateScope(pTHX_ SV * state, UTF8 scope);

extern int
state_getFrameDepth(pTHX_ SV * state);

extern int
state_isFrameLocked(pTHX_ SV * state);

extern void
state_setFrameLock(pTHX_ SV * state, int lock);

extern void
state_pushFrame(pTHX_ SV * state);

extern void
state_popFrame(pTHX_ SV * state);

extern SV *
state_value(pTHX_ SV * state, UTF8 string);

extern void
state_assign_value(pTHX_ SV * state, UTF8 string, SV * value, UTF8 scope);

extern SV *
state_value_noinc(pTHX_ SV * state, UTF8 string);

extern int
state_isValueBound(pTHX_ SV * state, UTF8 string, int frame);

extern SV *
state_valueInFrame(pTHX_ SV * state, UTF8 string, int frame);

extern AV * 
state_boundValues_noinc(pTHX_ SV * state, UTF8 string);

extern int
state_intval(pTHX_ SV * state, UTF8 string);

extern int
state_booleval(pTHX_ SV * state, UTF8 string);

extern AV * 
state_valueAV_noinc(pTHX_ SV * state, UTF8 string);

extern HV *
state_valueHV_noinc(pTHX_ SV * state, UTF8 string);

extern SV *
state_stash(pTHX_ SV * state, UTF8 string);

extern void
state_assign_stash(pTHX_ SV * state, UTF8 string, SV * value, UTF8 scope);

extern int
state_catcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_catcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern int
state_mathcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_mathcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern int
state_SFcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_SFcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern int
state_LCcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_LCcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern int
state_UCcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_UCcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern int
state_Delcode(pTHX_ SV * state, UTF8 string);

extern void
state_assign_Delcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope);

extern void
state_beginSemiverbatim(pTHX_ SV * state, int nchars, char ** chars);

extern void
state_endSemiverbatim(pTHX_ SV * state);
  
extern SV *
state_meaning_internal(pTHX_ SV * state, UTF8 name);

extern SV *
state_meaning(pTHX_ SV * state, SV * token);

extern void
state_assign_meaning(pTHX_ SV * state, UTF8 name, SV * meaning, UTF8 scope);

extern int
state_globalFlag(pTHX_ SV * state);

extern void
state_setGlobalFlag(pTHX_ SV * state);

extern int
state_longFlag(pTHX_ SV * state);

extern void
state_setLongFlag(pTHX_ SV * state);

extern int
state_outerFlag(pTHX_ SV * state);

extern void
state_setOuterFlag(pTHX_ SV * state);

extern int
state_protectedFlag(pTHX_ SV * state);

extern void
state_setProtectedFlag(pTHX_ SV * state);

extern void
state_clearFlags(pTHX_ SV * state);

extern SV *
state_definition(pTHX_ SV * state, SV * token);

extern SV *
state_expandable(pTHX_ SV * state, SV * token);

extern SV *
state_convertUnit(pTHX_ SV * state, UTF8 unit);

extern void
state_noteStatus(pTHX_ SV * state, UTF8 type);

extern void
state_noteSymbolStatus(pTHX_ SV * state, UTF8 type, UTF8 symbol);

extern SV *
state_getStatus(pTHX_ SV * state, UTF8 type);

#endif
