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

typedef enum {
  TBL_VALUE    = 0,
  TBL_MEANING  = 1,
  TBL_CATCODE  = 2,
  TBL_MATHCODE = 3,
  TBL_SFCODE   = 4,
  TBL_LCCODE   = 5,
  TBL_UCCODE   = 6,
  TBL_DELCODE  = 7,
  TBL_STASH    = 8,
  TBL_STASH_ACTIVE = 9
} T_TableIndex;
#define MAX_TABLES 10
typedef HV * T_Tables[MAX_TABLES];
typedef T_Tables * LaTeXML_Tables;

typedef struct Frame_struct {
  int locked;
  HV * tables[MAX_TABLES];
} T_Frame;
typedef T_Frame * LaTeXML_Frame;  

typedef struct IfFrame_struct {
  int ifid;
  SV * token;
  UTF8 start;
  int parsing;
  int elses;
} T_IfFrame;
typedef T_IfFrame * LaTeXML_IfFrame;  

typedef struct State_struct {
  HV * tables[MAX_TABLES];
  int n_stack_alloc;
  int stack_top;
  LaTeXML_Frame * stack;
  int if_count;
  int n_ifstack_alloc;
  int ifstack_top;
  LaTeXML_IfFrame * ifstack;
  HV * status;
  SV * stomach;
  SV * model;
  LaTeXML_Tokenstack processing;
  int flags;
  int config;
  HV * units;
} T_State;
typedef T_State * LaTeXML_State;

#define isa_State(arg)        ((arg) && sv_isa(arg, "LaTeXML::Core::State"))

#define SvState(arg)      ((LaTeXML_State)INT2PTR(LaTeXML_State, SvIV((SV*) SvRV(arg))))

#define FLAG_GLOBAL    0x01
#define FLAG_LONG      0x02
#define FLAG_OUTER     0x04
#define FLAG_PROTECTED 0x08
#define FLAG_UNLESS    0x10

#define CONFIG_PROFILING 0x01

extern SV *
state_new(pTHX_ SV * stomach, SV * model);

extern SV *
state_global(pTHX);

extern SV *
state_stomach(pTHX_ SV * state);

extern SV *
state_model(pTHX_ SV * state);

/* NOTE: The next 3 should NOT be exported!!! (so we can internalize the tables) */
extern SV *                            /* WARNING: No refcnt increment here!!! */
state_lookup_noinc(pTHX_ SV * state, int tableid, UTF8 string);

extern SV *
state_lookup(pTHX_ SV * state, int tableid, UTF8 string);

extern UTF8
state_lookupPV(pTHX_ SV * state, int tableid, UTF8 string);

extern int
state_lookupIV(pTHX_ SV * state, int tableid, UTF8 string);

extern int
state_lookupBoole(pTHX_ SV * state, int tableid, UTF8 string);

extern AV * 
state_lookupAV_noinc(pTHX_ SV * state, int tableid, UTF8 string);

extern HV *
state_lookupHV_noinc(pTHX_ SV * state, int tableid, UTF8 string);

extern void
state_assign(pTHX_ SV * state, int tableid, UTF8 key, SV * value, UTF8 scope);

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

extern LaTeXML_IfFrame
state_pushIfFrame(pTHX_ SV * state, SV * token, UTF8 loc);

extern LaTeXML_IfFrame
state_popIfFrame(pTHX_ SV * state);

extern int
state_isBound(pTHX_ SV * state, int tableid, UTF8 string, int frame);

extern SV *
state_lookupInFrame(pTHX_ SV * state, int tableid, UTF8 string, int frame);

extern AV * 
state_bindings_noinc(pTHX_ SV * state, int tableid, UTF8 string);

extern void
state_startProcessing(pTHX_ SV * state, SV * token);

extern void
state_stopProcessing(pTHX_ SV * state, SV * token);

extern int
state_catcode(pTHX_ SV * state, UTF8 string);

extern void
state_beginSemiverbatim(pTHX_ SV * state, int nchars, char ** chars);

extern void
state_endSemiverbatim(pTHX_ SV * state);
  
extern SV *
state_meaning(pTHX_ SV * state, SV * token);

extern int
state_Equals(pTHX_ SV * thing1, SV * thing2);

extern int
state_XEquals(pTHX_ SV * state, SV * token1, SV * token2);

extern SV *
state_definition(pTHX_ SV * state, SV * token);

extern void
state_installDefinition(pTHX_ SV * state, SV * definition, UTF8 scope);

extern SV *
state_expandable(pTHX_ SV * state, SV * token);

extern SV *
state_convertUnit(pTHX_ SV * state, UTF8 unit);

extern void
state_clearStatus(pTHX_ SV * statesv);

extern void
state_noteStatus(pTHX_ SV * state, UTF8 type);

extern void
state_noteSymbolStatus(pTHX_ SV * state, UTF8 type, UTF8 symbol);

extern SV *
state_getStatus(pTHX_ SV * state, UTF8 type);

extern void
state_setProfiling(pTHX_ SV * state, int profiling);

extern int
state_getProfiling(pTHX_ SV * state);

extern SV *
register_valueOf(pTHX_ SV * reg, SV * state, int nargs, SV ** args);

extern void
register_setValue(pTHX_ SV * reg, SV * state, int nargs, SV ** args, SV * value);

#endif
