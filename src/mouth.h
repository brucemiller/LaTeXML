/*# /=====================================================================\ #
  # |  LaTeXML/src/mouth.h                                                | #
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
  C-level Mouth support */

#ifndef MOUTH_H
#define MOUTH_H

#define DEBUG_MOUTHNOT
#ifdef DEBUG_MOUTH
#  define DEBUG_Mouth(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Mouth 1
#else
#  define DEBUG_Mouth(...)
#  define DEBUGGING_Mouth 0
#endif

typedef enum {
  MOUTH_BASE        = 0x01,
  MOUTH_AT_EOF      = 0x02,
  MOUTH_AUTOCLOSE   = 0x04,
  MOUTH_INTERESTING = 0x08
} T_MouthFlags;

typedef struct Mouth_struct {
  UTF8 source;
  UTF8 short_source;
  int saved_at_cc;
  int saved_comments;
  UTF8 note_message;
  int lineno;
  STRLEN colno;
  UTF8 chars;
  STRLEN bufsize;
  STRLEN ptr;
  STRLEN nbytes;
  STRLEN prev_ptr;
  STRLEN prev_colno;
  int prev_lineno;
  int flags;
  LaTeXML_Tokenstack pushback;
  SV * previous_mouth;          /* Better be a mouth of SOME class! */
} T_Mouth;
typedef T_Mouth * LaTeXML_Mouth;

#define isa_Mouth(arg)        ((arg) && sv_derived_from(arg, "LaTeXML::Core::Mouth"))

#define SvMouth(arg)      ((LaTeXML_Mouth)INT2PTR(LaTeXML_Mouth, SvIV((SV*) SvRV(arg))))

extern void
mouth_setInput(pTHX_ SV * mouth, UTF8 input);

extern SV *
mouth_new(pTHX_ UTF8 class, UTF8 source, UTF8 short_source, UTF8 content,
          int saved_at_cc, int saved_comments, UTF8 note_message);

extern void
mouth_DESTROY(pTHX_ LaTeXML_Mouth mouth);

extern void
mouth_finish(pTHX_ SV * mouth);

extern void
mouth_setInput(pTHX_ SV * mouth, UTF8 input);

extern int
mouth_hasMoreInput(pTHX_ SV * mouth);

extern SV *
mouth_getLocator(pTHX_ SV * mouth);

  /* Since readToken looks ahead, we'll need to be able to undo the effects of mouth_readChar! */
extern int
mouth_readChar(pTHX_ SV * mouth, SV * state, char * character, int * catcode);
  /* Put back the previously parsed character.  Would be nice to save it for next call,
     but the catcodes can (& will) change by then! */

extern void
mouth_unreadChar(pTHX_ SV * mouth);

extern int
mouth_readLine(pTHX_ SV * mouth);

/*
extern int
mouth_fetchInput(pTHX_ SV * mouth);
*/

extern void
mouth_unreadToken(pTHX_ SV * mouth, SV * token);

extern void
mouth_unread(pTHX_ SV * mouth, SV * thing);

extern SV *
mouth_readToken(pTHX_ SV * mouth, SV * state);

extern SV *
mouth_readTokens(pTHX_ SV * mouth, SV * state, SV * until);

#endif
