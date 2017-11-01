/*# /=====================================================================\ #
  # |  LaTeXML/src/gullet.h                                               | #
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
  C-level Gullet support */

#ifndef GULLET_H
#define GULLET_H

#define DEBUG_GULLETNOT
#ifdef DEBUG_GULLET
#  define DEBUG_Gullet(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Gullet 1
#else
#  define DEBUG_Gullet(...)
#  define DEBUGGING_Gullet 0
#endif

extern LaTeXML_Core_Mouth
gullet_getMouth(pTHX_ SV * gullet); /* Warning: NO refcnt */

extern SV *
gullet_getLocator(pTHX_ SV * gullet);

extern LaTeXML_Core_Tokenstack
gullet_getPendingComments(pTHX_ SV * gullet);

extern void
gullet_stopProfiling(pTHX_ SV * gullet, SV * marker);

extern SV *
gullet_readToken(pTHX_ SV * gullet, SV * state);

extern void
gullet_unreadToken(pTHX_ SV * gullet, SV * token);

extern void                            /* Show next tokens; risky if followed by catcode changes! */
gullet_showContext(pTHX_ SV * gullet);

extern int
gullet_nextMouth(pTHX_ SV * gullet);

extern SV *
expandable_invoke(pTHX_ SV * expandable, SV * token, SV * gullet, SV * state);

extern SV *
gullet_readXToken(pTHX_ SV * gullet, SV * state, int toplevel, int commentsok);

extern void
gullet_expandafter(pTHX_ SV * gullet, SV * state);

extern void
gullet_readBalanced(pTHX_ SV * gullet, SV * state, LaTeXML_Core_Tokens tokens, int expanded);

extern SV *
gullet_readNonSpace(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readXNonSpace(pTHX_ SV * gullet, SV * state);

extern void
gullet_skipSpaces(pTHX_ SV * gullet, SV * state);

extern void
gullet_skip1Space(pTHX_ SV * gullet,  SV * state);

extern void
gullet_skipEquals(pTHX_ SV * gullet,  SV * state);

extern LaTeXML_Core_Tokens
gullet_readArg(pTHX_ SV * gullet, SV * state);

extern LaTeXML_Core_Tokens
gullet_readXArg(pTHX_ SV * gullet, SV * state);

extern LaTeXML_Core_Tokens
gullet_readXUntilEnd(pTHX_ SV * gullet, SV * state);

extern LaTeXML_Core_Tokens
gullet_readUntilBrace(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readCSName(pTHX_ SV * gullet, SV * state);

extern int                            /* fill in type, prepare choices; return max length */
gullet_prepareMatch(pTHX_ SV * gullet, int nchoices, int * type, SV ** choices);

extern int  /* Note readMatch returns -1 for failure, otherwise the index of the match */
gullet_readMatch(pTHX_ SV * gullet, SV * state,
                 int nchoices, int maxlength, int type[], SV * choices[]);

extern LaTeXML_Core_Tokens  /* Note readMatch returns -1 for failure, otherwise the index of the match */
gullet_readUntilMatch(pTHX_ SV * gullet, SV * state, int expanded,
                      int nchoices, int maxlength, int type[], SV * choices[],
                      int * match);
extern int
gullet_readKeyword(pTHX_ SV * gullet, SV * state, int nchoices, char * choices[]);

extern SV *
gullet_readDefParameters(pTHX_ SV * gullet, SV * state);

extern int
gullet_readOptionalSigns(pTHX_ SV * gullet, SV * state);

extern int
gullet_readArguments(pTHX_ SV * gullet,  int npara, AV * parameters, SV * fordefn, SV * args[]);

extern SV *
gullet_readRegisterValue(pTHX_ SV * gullet, SV * state, int ntypes, UTF8 * regtypes);

extern int
gullet_readInteger(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readFloat(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readNumber(pTHX_ SV * gullet, SV * state);

extern double
gullet_readUnit(pTHX_ SV * gullet, SV * state, double defaultunit);

extern double
gullet_readMuUnit(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readDimension(pTHX_ SV * gullet, SV * state, int nocomma, double defaultunit);

extern SV *
gullet_readGlue(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readMuGlue(pTHX_ SV * gullet, SV * state);

extern SV *                            /* Apparently how value of Tokens registers are read  */
gullet_readTokensValue(pTHX_ SV * gullet, SV * state);

extern SV *
gullet_readValue(pTHX_ SV * gullet, SV * state, UTF8 type);

extern int
gullet_readArguments(pTHX_ SV * gullet,  int npara, AV * parameters, SV * fordefn, SV * args[]);

#endif

