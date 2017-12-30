/*# /=====================================================================\ #
  # |  LaTeXML/src/tokens.h                                               | #
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
  C-Level Token and Tokens support */

/* Tokens are immutable once created & returned to Perl. */
#ifndef TOKENS_H
#define TOKENS_H

#define DEBUG_TOKENNOT
#ifdef DEBUG_TOKEN
#  define DEBUG_Token(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Token 1
#else
#  define DEBUG_Token(...)
#  define DEBUGGING_Token 0
#endif

#define DEBUG_TOKENSNOT
#ifdef DEBUG_TOKENS
#  define DEBUG_Tokens(...) fprintf(stderr, __VA_ARGS__)
#  define DEBUGGING_Tokens 1
#else
#  define DEBUG_Tokens(...)
#  define DEBUGGING_Tokens 0
#endif

typedef SV * PTR_SV;

/*======================================================================
  Token */

/* Currently we copy string & free on DESTROY; Do getString (etal) need to copy? */
/* the C ends up with sv_setpv, which(apparently) copies the string into the PV(string var) */
/*
typedef struct Token_struct {
  int catcode;
  UTF8 string;
} T_Token;
typedef T_Token  * LaTeXML_Token;
*/
typedef struct Token_struct {
  int catcode;
  char string[];
} T_Token;
typedef T_Token  * LaTeXML_Token;

typedef struct Tokens_struct {
  int ntokens;
  int nalloc;
  PTR_SV * tokens;
} T_Tokens;
typedef T_Tokens * LaTeXML_Tokens;

#define isa_Token(arg)        ((arg) && sv_isa(arg, "LaTeXML::Core::Token"))
#define isa_Tokens(arg)       ((arg) && sv_isa(arg, "LaTeXML::Core::Tokens"))

#define SvTokens(arg)     ((LaTeXML_Tokens)INT2PTR(LaTeXML_Tokens, SvIV((SV*) SvRV(arg))))
#define SvToken(arg)      ((LaTeXML_Token) INT2PTR(LaTeXML_Token,  SvIV((SV*) SvRV(arg))))

typedef enum {
    CC_ESCAPE      =  0,
    CC_BEGIN       =  1,
    CC_END         =  2,
    CC_MATH        =  3,
    CC_ALIGN       =  4,
    CC_EOL         =  5,
    CC_PARAM       =  6,
    CC_SUPER       =  7,
    CC_SUB         =  8,
    CC_IGNORE      =  9,
    CC_SPACE       = 10,
    CC_LETTER      = 11,
    CC_OTHER       = 12,
    CC_ACTIVE      = 13,
    CC_COMMENT     = 14,
    CC_INVALID     = 15,
    CC_CS          = 16,
    CC_NOTEXPANDED = 17,
    CC_MARKER      = 18,
    CC_MAX         = 18
} T_Catcode;

/* Categorization of Category codes */
extern int EXECUTABLE_CATCODE[];
extern int ACTIVE_OR_CS[];
extern UTF8 standardchar[];
extern UTF8 CC_NAME[];
extern UTF8 PRIMITIVE_NAME[];
extern UTF8 EXECUTABLE_NAME[];
extern UTF8 CC_SHORT_NAME[];

extern SV *
token_new(pTHX_ UTF8 string, int catcode);
extern void
token_DESTROY(pTHX_ LaTeXML_Token token);

#define T_LETTER(arg) (token_new(aTHX_ (arg), 11))
#define T_OTHER(arg)  (token_new(aTHX_ (arg), 12))
#define T_ACTIVE(arg) (token_new(aTHX_ (arg), 13))
#define T_CS(arg)     (token_new(aTHX_ (arg), 16))

#define TokenName(arg) (arg ? SvToken(arg)->string : "Unknown")
extern int
token_equals(pTHX_ SV * a, SV * b);

/*======================================================================
  Tokens */
/*   Note peculiar pre-allocation strategy for nalloc!
   it is expected that the caller has allocated enough room for it's arguments
   assuming they are Token's; add_to_tokens will grow if it encounters Tokens/Reversions */

extern SV *
tokens_new(pTHX_ int nalloc);

extern void
tokens_DESTROY(pTHX_ LaTeXML_Tokens xtokens);

extern UTF8                            /* NOTE: This returns a newly allocated string! */
tokens_toString(pTHX_ SV * tokens);

extern int
tokens_equals(pTHX_ SV * a, SV * b);

extern void
tokens_shrink(pTHX_ SV * tokens);

extern void
tokens_add_token(pTHX_ SV * tokens, SV * token);

extern void                            /* adds in-place */
tokens_add_to(pTHX_ SV * tokens, SV * thing, int revert);

extern void                            /* Modifies in-place */
tokens_trimBraces(pTHX_ SV * tokens);

extern void                            /* Remove trailing spaces, in-place */
tokens_trimright(pTHX_ SV * tokens);

extern SV * /* trim's left/right space, then braces; creates NEW tokens */
tokens_trim(pTHX_ SV * tokens);

extern SV *
tokens_substituteParameters(pTHX_ SV * tokens, int nargs, SV **args);

#endif
