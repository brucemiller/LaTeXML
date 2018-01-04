/*
       # /=====================================================================\ #
       # |  LaTeXML.xs                                                         | #
       # |                                                                     | #
       # |=====================================================================| #
       # | Part of LaTeXML:                                                    | #
       # |  Public domain software, produced as part of work done by the       | #
       # |  United States Government & not subject to copyright in the US.     | #
       # |---------------------------------------------------------------------| #
       # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
       # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
       # \=========================================================ooo==U==ooo=/ #
  */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "src/errors.h"
#include "src/object.h"
#include "src/tokens.h"
#include "src/numbers.h"
#include "src/tokenstack.h"
#include "src/state.h"
#include "src/boxstack.h"
#include "src/parameters.h"
#include "src/mouth.h"
#include "src/gullet.h"
#include "src/expandable.h"
#include "src/primitive.h"
#include "src/stomach.h"

/*======================================================================
 Towards consistent, predictable API's for both C & Perl,
 in consideration of the fact that there will be a lot of storing/fetching
 pointers to objects in both C structures and Perl Hashes & Arrays,
 as well as creating new objects when required. We need to manage memory
 & refcounts, so, we generally should ALWAYS be working with SV's,
 especially for any object that will be seen by Perl.  But we need to make
 sure that we have an SV that references the correct type of object!

 So, we have to be careful when Perl passes to C (either in XS or when C
 gets results from call_sv or call_method) that the right kind of SV* are being passed.
 * Checking SV*'s for appropriate types, before it gets cast to a C structure!
 * undefs & NULL:  C-level should deal with NULL, so we should use !SvOK => NULL
   Conversely, NULL returned from C should be converted to &PL_sv_undef.
   But we need to be careful when NULL is a recoverable condition,
   before we start following null pointers in C!

 * C-API functions should give the rights to the caller any object(s) returned,
   typically through SvREFCNT_inc (or equivalent).
   The caller either returns the object to it's caller, or uses SvREFCNT_dec
   (or equivalent) when done with the object.
   Exception: functions named with _noinc suffix; use when you know you'll be done
   with the object before anyone will dec its refcnt or Perl will get a chance
   to do any cleanup.  Functions are NOT responsible for managing the REFCNT of arguments!
   Functions that store an object should assure that REFCNT is incremented.

   NOTE: Neither hv_store/hv_fetch (& av) change the reference count on the stored
   SV *, and fetch returns the same SV that was stored.

 * Perl-API functions should always set mortal (eg. sv_2mortal),
   but note that RETVAL will automatically have sv_2mortal applied!

 * BE CAREFUL about putting things like POPs inside something like SvTRUE
   Some of the latter are macros that duplicate it's arguments!!!!!!

Question: Should some of the C API avoid passing pTHX as argument ?
It's not always actually needed or passed through.
But, if we omit it, we need to be predictable.

Major ToDo:
(1) reimplement tracing
(2) develop error & logging API
(3) figure out error recovery
 ======================================================================*/


  /*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Perl Modules
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/
  /* REMEMBER: DO NOT RETURN NULL!!!! Return &PL_sv_undef !!! */
 # /*======================================================================
 #    LaTeXML::Core::State
 #   ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::State
PROTOTYPES: ENABLE

SV *
new_internal(stomach,model)
    SV * stomach;
    SV * model;
  INIT:
    typecheck_xsarg(stomach,undef,Stomach);
    typecheck_xsarg(model,undef,Model);
  CODE:
    RETVAL = state_new(aTHX_ stomach, model);
  OUTPUT:
    RETVAL

SV *
getStomach(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_stomach(aTHX_ state);
    if(! RETVAL){
      croak("internal:stomach State has no stomach!"); }
  OUTPUT:
    RETVAL

SV *
getStomach_noerror(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_stomach(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getModel(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_model(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
getValueKeys(state)
    SV * state;
  INIT:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    HV * hash = xstate->tables[TBL_VALUE];
    HE * entry;
  CODE:
    hv_iterinit(hash);          /* NOT sorted! */
    while( (entry  = hv_iternext(hash)) ){
      int len;
      char * key = hv_iterkey(entry, &len);
      mXPUSHp(key,len); }

void
getKnownScopes(state)
    SV * state;
  INIT:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    HV * hash = xstate->tables[TBL_STASH];
    HE * entry;
  CODE:
    hv_iterinit(hash);          /* NOT sorted! */
    while( (entry  = hv_iternext(hash)) ){
      int len;
      char * key = hv_iterkey(entry, &len);
      mXPUSHp(key,len); }

void
getActiveScopes(state)
    SV * state;
  INIT:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    HV * hash = xstate->tables[TBL_STASH_ACTIVE];
    HE * entry;
  CODE:
    hv_iterinit(hash);          /* NOT sorted! */
    while( (entry  = hv_iternext(hash)) ){
      int len;
      char * key = hv_iterkey(entry, &len);
      mXPUSHp(key,len); }

int
getFrameDepth(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_getFrameDepth(aTHX_ state);
  OUTPUT:
    RETVAL

int
isFrameLocked(state);
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_isFrameLocked(aTHX_ state);
  OUTPUT:
    RETVAL

void
setFrameLock(state, locked);
    SV * state;
    int locked;
  PPCODE:
    typecheck_xsarg(state,State);
    state_setFrameLock(aTHX_ state,locked);

void
pushFrame(state)
    SV * state;
  PPCODE:
    typecheck_xsarg(state,State);
    state_pushFrame(aTHX_ state);

void
popFrame(state)
    SV * state;
  PPCODE:
    typecheck_xsarg(state,State);
    state_popFrame(aTHX_ state);

void
activateScope(state, scope)
   SV * state;
   UTF8 scope;
 CODE:
   typecheck_xsarg(state,State);
   state_activateScope(aTHX_ state, scope);

void
deactivateScope(state, scope)
   SV * state;
   UTF8 scope;
 CODE:
   typecheck_xsarg(state,State);
   state_deactivateScope(aTHX_ state, scope);

SV *
lookupCatcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_CATCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(CC_OTHER); }
  OUTPUT:
    RETVAL

void
assignCatcode(state,string,catcode,...)
    SV * state;
    UTF8 string;
    SV * catcode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(catcode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_CATCODE, string, catcode, scope);

SV *
lookupMathcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_MATHCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(0); }
  OUTPUT:
    RETVAL

void
assignMathcode(state,string,mathcode,...)
    SV * state;
    UTF8 string;
    SV * mathcode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(mathcode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_MATHCODE, string, mathcode, scope);

SV *
lookupSFcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_SFCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(0); }
  OUTPUT:
    RETVAL

void
assignSFcode(state,string,sfcode,...)
    SV * state;
    UTF8 string;
    SV * sfcode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(sfcode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_SFCODE, string, sfcode, scope);

SV *
lookupLCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_LCCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(0); }
  OUTPUT:
    RETVAL

void
assignLCcode(state,string,lccode,...)
    SV * state;
    UTF8 string;
    SV * lccode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(lccode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_LCCODE, string, lccode, scope);

SV *
lookupUCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_UCCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(0); }
  OUTPUT:
    RETVAL

void
assignUCcode(state,string,uccode,...)
    SV * state;
    UTF8 string;
    SV * uccode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(uccode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_UCCODE, string, uccode, scope);

SV *
lookupDelcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_DELCODE, string);
    if(RETVAL == NULL){ RETVAL = newSViv(0); }
  OUTPUT:
    RETVAL

void
assignDelcode(state,string,delcode,...)
    SV * state;
    UTF8 string;
    SV * delcode;
  PPCODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(delcode,int);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_DELCODE, string, delcode, scope);

SV *
lookupValue(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_VALUE, string);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
assignValue(state,string,value, ...)
    SV * state;
    UTF8 string;
    SV * value;
  CODE:
    typecheck_xsarg(state,State);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_VALUE, string, value, scope);

int
isValueBound(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    int frame = (typecheck_optarg(2,"frame",int) ? SvIV(ST(2)) : -1);
  CODE:
    RETVAL = state_isBound(aTHX_ state, TBL_VALUE, string, frame);
  OUTPUT:
    RETVAL

SV *
valueInFrame(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    int frame = (typecheck_optarg(2,"frame",int) ? SvIV(ST(2)) : 0);
  CODE:
    RETVAL = state_lookupInFrame(aTHX_ state, TBL_VALUE, string, frame);
  OUTPUT:
    RETVAL

void
lookupStackedValues(state,string)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    AV * av = state_bindings_noinc(aTHX_ state, TBL_VALUE, string);
    int i;
  PPCODE:
    if(av){
      int n = av_len(av)+1;
      for(i = 0; i < n; i++){
        SV ** ptr = av_fetch(av,i,0);
        SV * value = (ptr && *ptr ? sv_2mortal(SvREFCNT_inc(*ptr)) : &PL_sv_undef);
        XPUSHs(value); } }

void
getProcessing(state)
    SV * state;
  INIT:
    LaTeXML_State xstate = SvState(state);
    LaTeXML_Tokenstack tokens = xstate->processing;
    int i;
    int n = tokens->ntokens;
    int max = n;
  PPCODE:
    if(max > 10) { max = 10; }
    for(i = 0; i < max; i++){
      XPUSHs(tokens->tokens[n-i-1]); }

void
pushValue(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
    int i;
  PPCODE:
    for(i = 2; i < items; i++){
      SV * sv = ST(i);          /* No typecheck; can be anything */
      SvREFCNT_inc(sv);
      av_push(av, sv); }

SV *
popValue(state,string)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
  CODE:
    RETVAL = av_pop(av);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
unshiftValue(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
    int i;
  PPCODE:
    av_unshift(av,items-2);
    for(i = 2; i < items; i++){
      SV * sv = ST(i);          /* No typecheck; can be anything */
      SvREFCNT_inc(sv);
      av_store(av, i-2, sv); }

SV *
shiftValue(state,string)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
  CODE:
    RETVAL = av_shift(av);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
lookupMapping(state,string,key)
    SV * state;
    UTF8 string;
    UTF8 key;
  INIT:
    typecheck_xsarg(state,State);
    HV * hash = state_lookupHV_noinc(aTHX_ state, TBL_VALUE, string);
    SV ** ptr = hv_fetch(hash,key,-strlen(key),0);
  CODE:
    if(ptr && *ptr && SvOK(*ptr)){
      RETVAL = *ptr;  SvREFCNT_inc(RETVAL); }
    else {
       RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void                            
lookupMappingKeys(state,string)
    SV * state;
    UTF8 string;
  INIT:
    typecheck_xsarg(state,State);
    HV * hash = state_lookupHV_noinc(aTHX_ state, TBL_VALUE, string);
    HE * entry;
  PPCODE:
    hv_iterinit(hash);          /* NOT sorted! */
    while( (entry  = hv_iternext(hash)) ){
      int len;
      char * key = hv_iterkey(entry, &len);
      mXPUSHp(key,len); }

void
assignMapping(state,string,key,value)
    SV * state;
    UTF8 string;
    UTF8 key;
    SV * value;
  INIT:
    typecheck_xsarg(state,State);
    HV * hash = state_lookupHV_noinc(aTHX_ state, TBL_VALUE, string);
  PPCODE:
    hv_store(hash,key,-strlen(key),value,0);
    SvREFCNT_inc(value);

SV *
lookupStash(state,string)
    SV * state;
    UTF8 string;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_lookup(aTHX_ state, TBL_STASH, string);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
assignStash(state,string,value, ...)
    SV * state;
    UTF8 string;
    SV * value;
  CODE:
    typecheck_xsarg(state,State);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_STASH, string, value, scope);

SV *
lookupMeaning(state,token)
    SV * state;
    SV * token;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token,Token);
    RETVAL = state_meaning(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
XEquals(state, token1,token2)
    SV * state;
    SV * token1;
    SV * token2;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token1,undef,Token);
    typecheck_xsarg(token2,undef,Token);
    RETVAL = state_XEquals(aTHX_ state, token1, token2);
  OUTPUT:
    RETVAL

int
Equals(token1,token2)
    SV * token1;
    SV * token2;
  CODE:
    typecheck_xsarg(token1,undef,Token);
    typecheck_xsarg(token2,undef,Token);
    RETVAL = state_Equals(aTHX_ token1, token2);
  OUTPUT:
    RETVAL

int
globalFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_GLOBAL;
  OUTPUT:
    RETVAL

void
setGlobalFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_GLOBAL;

int
longFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_LONG;
  OUTPUT:
    RETVAL

void
setLongFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_LONG;

int
outerFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_OUTER;
  OUTPUT:
    RETVAL

void
setOuterFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_OUTER;

int
protectedFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_PROTECTED;
  OUTPUT:
    RETVAL

void
setProtectedFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_PROTECTED;

void
setUnlessFlag(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_UNLESS;

void
clearFlags(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    xstate->flags = 0;

void
beginSemiverbatim(state,...)
    SV * state;      
  INIT:
    typecheck_xsarg(state,State);
    int nchars = items-1;
    UTF8 chars[items-1];
    int i;
  PPCODE:
    for(i=0; i < nchars; i++){
      SV * sv = ST(i+1);
      typecheck_xsarg(sv,string);
      chars[i] = SvPV_nolen(sv); }
    state_beginSemiverbatim(aTHX_ state, nchars, chars); 

void
endSemiverbatim(state)
    SV * state;      
  PPCODE:
    typecheck_xsarg(state,State);
    state_endSemiverbatim(aTHX_ state); 

void
assignMeaning(state, token, meaning,...)
    SV * state;
    SV * token;
    SV * meaning;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token,Token);
    typecheck_xsarg(meaning,undef,Definition);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    if(meaning && isa_Token(meaning) && token_equals(aTHX_ token,meaning)){
      } /* Hack; ignore assigment to itself */
    else {
      LaTeXML_Token t = SvToken(token);
      UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
      name = (name == NULL ? t->string : name);
      state_assign(aTHX_ state, TBL_MEANING, name, meaning, scope); }

void
let(state, token1, token2,...)
    SV * state;
    SV * token1;
    SV * token2;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token1,Token);
    typecheck_xsarg(token2,Token);
    UTF8 scope = (typecheck_optarg(3,"scope",string) ? SvPV_nolen(ST(3)) : NULL);
    SV * meaning = state_meaning(aTHX_ state, token2);
    if(meaning && isa_Token(meaning) && token_equals(aTHX_ token1,meaning)){
    }
    else {
      LaTeXML_Token t1 = SvToken(token1);
      UTF8 name1 = PRIMITIVE_NAME[t1->catcode]; /* getCSName */
      name1 = (name1 == NULL ? t1->string : name1);
      state_assign(aTHX_ state, TBL_MEANING, name1, meaning, scope); }
    if(meaning){ SvREFCNT_dec(meaning); }

SV *
lookupExpandable(state,token)
    SV * state;
    SV * token;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token,Token);
    RETVAL = state_expandable(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
lookupDefinition(state,token)
    SV * state;
    SV * token;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(token,Token);
    RETVAL = state_definition(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
installDefinition(state, definition, ...)
    SV * state;
    SV * definition;
  CODE:
    typecheck_xsarg(state,State);
    typecheck_xsarg(definition,Definition);
    UTF8 scope = (typecheck_optarg(2,"scope",string) ? SvPV_nolen(ST(2)) : NULL);
    state_installDefinition(aTHX_ state, definition, scope);

void
afterAssignment(state)
    SV * state;
  PPCODE:
    typecheck_xsarg(state,State);
    primitive_afterAssignment(aTHX_ state);

SV *
getLocator(state)
    SV * state;
  CODE:  
    typecheck_xsarg(state,State);
    SV * stomach = state_stomach(aTHX_ state);
    SV * gullet =  stomach_gullet(aTHX_ stomach);
    RETVAL = gullet_getLocator(aTHX_ gullet);
    SvREFCNT_dec(stomach); SvREFCNT_dec(gullet);
  OUTPUT:
    RETVAL

SV *
getIfContext(state)
    SV * state;
  CODE:  
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    LaTeXML_IfFrame ifframe = (xstate->ifstack_top > 0 ? xstate->ifstack[xstate->ifstack_top] : NULL);
    if(ifframe){
      LaTeXML_Token t = SvToken(ifframe->token);
      RETVAL = newSVpvf("If %s started at %s",t->string, ifframe->start); }
    else {
      RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
convertUnit(state,unit)
    SV * state;
    UTF8 unit;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_convertUnit(aTHX_ state, unit);
  OUTPUT:
    RETVAL

void
clearStatus(state)
    SV * state;
  CODE:
    typecheck_xsarg(state,State);
    state_clearStatus(aTHX_ state);

void
noteStatus(state,type,...)
    SV * state;
    UTF8 type;
  CODE:
    typecheck_xsarg(state,State);
    if(items > 2){
      int i;
      for(i = 2; i < items; i++){
        typecheck_optarg(i,"text",string);
        state_noteSymbolStatus(aTHX_ state, type, SvPV_nolen(ST(i))); } }
    else {
      state_noteStatus(aTHX_ state, type); }

SV *
getStatus(state,type)
    SV * state;
    UTF8 type;
  CODE:
    typecheck_xsarg(state,State);
    RETVAL = state_getStatus(aTHX_ state, type);
  OUTPUT:
    RETVAL

 # /*======================================================================
 #    LaTeXML::Core::Token 
 #   ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Token

SV *
Token(string, catcode)
    UTF8 string
    int catcode
  CODE:
    RETVAL = token_new(aTHX_ string, catcode);
  OUTPUT:
    RETVAL

SV *
T_LETTER(string)
    UTF8 string

SV *
T_OTHER(string)
    UTF8 string

SV *
T_ACTIVE(string)
    UTF8 string

SV *
T_CS(string)
    UTF8 string

int
getCatcode(token)
    LaTeXML_Token token
  CODE:
    RETVAL = token->catcode;
  OUTPUT:
    RETVAL

UTF8
getString(token)
    LaTeXML_Token token
  CODE:
    RETVAL = token->string;
  OUTPUT:
    RETVAL

UTF8
toString(token)
    LaTeXML_Token token
  CODE:
    RETVAL = token->string;
  OUTPUT:
    RETVAL

int
getCharcode(token)
    LaTeXML_Token token
  CODE:
    RETVAL = (token->catcode == CC_CS ? 256 : (int) token->string [0]);
  OUTPUT:
    RETVAL

UTF8
getCSName(token)
    LaTeXML_Token token
  INIT:
    UTF8 s = PRIMITIVE_NAME[token->catcode];
  CODE:
    RETVAL = (s == NULL ? token->string : s);
  OUTPUT:
    RETVAL 

int
isExecutable(token)
    LaTeXML_Token token
  CODE:
    RETVAL = EXECUTABLE_CATCODE [token->catcode];
  OUTPUT:
    RETVAL

    #    /* Compare two tokens; They are equal if they both have same catcode & string*/
    #    /* [We pretend all SPACE's are the same, since we'd like to hide newline's in there!]*/
    #    /* NOTE: That another popular equality checks whether the "meaning" (defn) are the same.*/
    #    /* That is NOT done here; see Equals(x,y) and XEquals(x,y)*/

int
equals(a, b)
    SV * a
    SV * b
  CODE:
   if (SvOK(a) && isa_Token(a)
       && SvOK(b) && isa_Token(b)) {
     RETVAL = token_equals(aTHX_ a,b); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

void
DESTROY(token)
    LaTeXML_Token token
  CODE:
    token_DESTROY(aTHX_ token);

 #/*======================================================================
 #   LaTeXML::Common::Dimension
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Common::Dimension

SV *
formatScaled(sp)
    int sp;
  INIT:
    char buffer[3*sizeof(int)*CHAR_BIT/8 + 2];
    int ptr = number_formatScaled(aTHX_ buffer, sp);
  CODE:
    RETVAL = newSVpv(buffer,ptr);
  OUTPUT:
    RETVAL

SV *
pointformat(sp)
    int sp;
  INIT:
    char buffer[3*sizeof(int)*CHAR_BIT/8 + 2 + 2]; /* 2 extra for 'pt' */
    int ptr = number_formatScaled(aTHX_ buffer, sp);
  CODE:
    buffer[ptr++] = 'p';
    buffer[ptr++] = 't';
    buffer[ptr] = 0;
   /*fprintf(stderr,"POINTFORMAT of %d ==> %s\n",sp,buffer);*/
    RETVAL = newSVpv(buffer,ptr);
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Tokens
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Tokens

SV *
Tokens(...)
  INIT:
    int i;
    SV * tokens;
  CODE:
    if((items == 1) && isa_Tokens(ST(0))) {
      RETVAL = ST(0);
      SvREFCNT_inc(RETVAL); }   /* or mortal? */
    else {
      tokens = tokens_new(aTHX_ items);
      for (i = 0 ; i < items ; i++) {
        typecheck_optarg(i,"tokens",Token,Tokens);
        SV * sv = newSVsv(ST(i));
        tokens_add_to(aTHX_ tokens,sv,0);
        SvREFCNT_dec(sv); }
      /*DEBUG_Tokens( "done %d.\n", SvTokens(tokens)->ntokens);*/
      RETVAL = tokens; }
  OUTPUT:
    RETVAL

int
equals(a, b)
    SV * a
    SV * b
  CODE:
    typecheck_xsarg(a,Tokens);
    if (SvOK(b) && isa_Tokens(b)) {
     RETVAL = tokens_equals(aTHX_ a, b); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

UTF8
toString(tokens)
    SV * tokens;
  CODE:
    typecheck_xsarg(tokens,Tokens);
    RETVAL = tokens_toString(aTHX_ tokens);
  OUTPUT: 
    RETVAL

void
unlist(tokens)
    SV * tokens
  INIT:
    typecheck_xsarg(tokens,Tokens);
    int i;
    LaTeXML_Tokens xtokens = SvTokens(tokens);
  PPCODE:
    EXTEND(SP, xtokens->ntokens);
    for(i = 0; i < xtokens->ntokens; i++) {
      PUSHs(sv_2mortal(SvREFCNT_inc(xtokens->tokens[i]))); }

void
revert(tokens)
    SV * tokens
  INIT:                    /* same as unlist */
    typecheck_xsarg(tokens,Tokens);
    int i;
    LaTeXML_Tokens xtokens = SvTokens(tokens);
  PPCODE:
    EXTEND(SP, xtokens->ntokens);
    for(i = 0; i < xtokens->ntokens; i++) {
      PUSHs(sv_2mortal(SvREFCNT_inc(xtokens->tokens[i]))); }

int
isBalanced(tokens)
    SV * tokens
  INIT:
    typecheck_xsarg(tokens,Tokens);
    int i, level;
    LaTeXML_Tokens xtokens = SvTokens(tokens);
  CODE:
    level = 0;
    DEBUG_Tokens("\nChecking balance of %d tokens",xtokens->ntokens);
    for (i = 0 ; i < xtokens->ntokens ; i++) {
      LaTeXML_Token t = SvToken(xtokens->tokens[i]);
      int cc = t->catcode;
      DEBUG_Tokens("[%d]",cc);
      if (cc == CC_BEGIN) {
        DEBUG_Tokens("+");
        level++; }
      else if (cc == CC_END) {
        DEBUG_Tokens("-");
        level--; } }
      DEBUG_Tokens("net %d",level);
    RETVAL = (level == 0);
  OUTPUT:
    RETVAL

SV *
substituteParameters(tokens,...)
    SV * tokens
  INIT:
    typecheck_xsarg(tokens,Tokens);
    int i;
    int nargs = items-1;
    SV * args[nargs];
  CODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+1);
      if(! SvOK(arg)){
        arg = NULL; }
      args[i] = arg; }
    /* substitute parameters should check on appropriate args */
    RETVAL = tokens_substituteParameters(aTHX_ tokens, nargs, args);
    if(RETVAL == NULL){ croak("NULL from substituteParameters"); }
  OUTPUT:
    RETVAL

SV *
trim(tokens)
    SV * tokens
  CODE:
    typecheck_xsarg(tokens,Tokens);
    RETVAL = tokens_trim(aTHX_ tokens); 
  OUTPUT:
    RETVAL
  
void
DESTROY(xtokens)
    LaTeXML_Tokens xtokens
  CODE:
    tokens_DESTROY(aTHX_ xtokens);

 #/*======================================================================
 #   LaTeXML::Core::Tokenstack
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Tokenstack

SV *
new()
  INIT:
    LaTeXML_Tokenstack stack;
  CODE:
    stack = tokenstack_new(aTHX);
    RETVAL = newSV(0);
    sv_setref_pv(RETVAL, "LaTeXML::Core::Tokenstack", (void*)stack);
  OUTPUT:
    RETVAL

void
push(stack,token)
    SV * stack;
    SV * token;
  CODE:
    typecheck_xsarg(stack,Tokenstack);
    typecheck_xsarg(token,undef,Token);
    if(token != NULL){
      SV * sv = newSVsv(token); /* Create a "safe" copy(?) */
      tokenstack_push(aTHX_ SvTokenstack(stack),sv); 
      SvREFCNT_dec(sv); }

SV *
pop(stack)
    SV * stack;
  CODE:
    typecheck_xsarg(stack,Tokenstack);
    RETVAL = tokenstack_pop(aTHX_ SvTokenstack(stack));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Mouth
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Mouth

SV *
new_internal(class,source,short_source,content,saved_at_cc,saved_comments,note_message)
      UTF8 class;
      UTF8 source;
      UTF8 short_source;
      UTF8 content;
      int  saved_at_cc;
      int  saved_comments;
      UTF8 note_message;
  CODE:
    RETVAL = mouth_new(aTHX_ class, source,short_source,content,
                       saved_at_cc,saved_comments,note_message); 
  OUTPUT:
    RETVAL

void
DESTROY(xmouth)
    LaTeXML_Mouth xmouth
  CODE:
    mouth_DESTROY(aTHX_ xmouth);

void
finish(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    mouth_finish(aTHX_ mouth);

int
hasMoreInput(mouth)
    SV * mouth
  CODE:
    typecheck_xsarg(mouth,Mouth);
    RETVAL = mouth_hasMoreInput(aTHX_ mouth);
  OUTPUT:
    RETVAL

void
getPosition(mouth)
    SV * mouth;
  PPCODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    EXTEND(SP, 2);
    mPUSHi((IV) xmouth->lineno);
    mPUSHi((IV) xmouth->colno);

void
setAutoclose(mouth, autoclose)
    SV * mouth;
    int autoclose;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    if(autoclose){
      xmouth->flags |= MOUTH_AUTOCLOSE; }
    else {
      xmouth->flags &= ~MOUTH_AUTOCLOSE; }

int
getAutoclose(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_AUTOCLOSE;
  OUTPUT:
    RETVAL

SV *
getPreviousMouth(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    if(xmouth->previous_mouth){
      RETVAL = xmouth->previous_mouth;
      SvREFCNT_inc(RETVAL); }
    else {
      RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
isInteresting(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_INTERESTING;
  OUTPUT:
    RETVAL

SV *
getLocator(mouth)
    SV * mouth;
  CODE:  
    typecheck_xsarg(mouth,Mouth);
    RETVAL = mouth_getLocator(aTHX_ mouth);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

UTF8
getSource(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->source;
    if(RETVAL == NULL){ croak("NULL from getSource"); }
  OUTPUT:
    RETVAL

UTF8
getShortSource(mouth)
    SV * mouth;    
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->short_source;
    if(RETVAL == NULL){ croak("NULL from getShortSource"); }
  OUTPUT:
    RETVAL

UTF8
getNoteMessage(mouth)
    SV * mouth;    
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->note_message;
    if(RETVAL == NULL){ croak("NULL from getNoteMessage"); }
 OUTPUT:
    RETVAL

void
setInput(mouth,input)
    SV * mouth;
    UTF8 input;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    mouth_setInput(aTHX_ mouth,input);

SV *
readToken(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    RETVAL = mouth_readToken(aTHX_ mouth, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL


SV *
readTokens(mouth,...)
    SV * mouth;
  INIT:
    typecheck_xsarg(mouth,Mouth);
    SV * until = (typecheck_optarg(1,"until",Token) ? ST(1) : NULL);
  CODE:
    RETVAL = mouth_readTokens(aTHX_ mouth, state_global(aTHX), until);
    if(RETVAL == NULL){ croak("NULL from readTokens"); }
  OUTPUT:
    RETVAL
  
void
unread(mouth,...)
    SV * mouth;
  INIT:
    typecheck_xsarg(mouth,Mouth);
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      typecheck_optarg(i,"token",Token,Tokens);
      SV * sv = newSVsv(ST(i)); /* Create a "safe" copy(?) */
      mouth_unread(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

void
getPushback(mouth)
    SV * mouth;
  INIT:
    typecheck_xsarg(mouth,Mouth);
    int i,n;
    LaTeXML_Tokenstack pb;
    LaTeXML_Mouth xmouth = SvMouth(mouth);
  PPCODE:
    pb = xmouth->pushback;
    n = pb->ntokens;
    EXTEND(SP, n);
    for(i = n-1; i >= 0; i--) {
      PUSHs(sv_2mortal(tokenstack_pop(aTHX_ pb))); }

int
atEOF(mouth)
    SV * mouth;
  CODE:
    typecheck_xsarg(mouth,Mouth);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_AT_EOF;
  OUTPUT:
    RETVAL

SV *
readRawLine(mouth,...)
    SV * mouth;
  INIT:
    typecheck_xsarg(mouth,Mouth);
    int noread = (items > 1 ? SvTRUE(ST(1)) : 0);
    LaTeXML_Mouth xmouth = SvMouth(mouth);
  CODE:
    /* Peculiar logic: 'noread' really means return the rest of current line,
       if we've alread read something from it */
    if(noread){
      if(xmouth->colno > 0){
        STRLEN pstart = xmouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        RETVAL = newSVpvn_flags(xmouth->chars+pstart,n, SVf_UTF8); }
      else {
        RETVAL = &PL_sv_undef; } }
    else {
      if(xmouth->ptr >= xmouth->nbytes){       /* out of input */
        /* mouth_fetchInput(aTHX_ mouth); }  */
        xmouth->flags |= MOUTH_AT_EOF; }
      if(xmouth->ptr < xmouth->nbytes) { /* If we have input now */
        STRLEN pstart = xmouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        RETVAL = newSVpvn_flags(xmouth->chars+pstart,n, SVf_UTF8); }
      else {
        DEBUG_Mouth("NO MORE RAW\n");
        RETVAL = &PL_sv_undef;; } }
  OUTPUT:
    RETVAL

 #/*======================================================================
 #   LaTeXML::Core::Gullet
 #  ======================================================================*/
MODULE = LaTeXML PACKAGE = LaTeXML::Core::Gullet

SV *
new(class)
    SV * class;
  CODE:
    PERL_UNUSED_VAR(class);
    RETVAL = gullet_new(aTHX);
  OUTPUT:
    RETVAL

void
DESTROY(gullet)
    SV * gullet;
  CODE:
    gullet_DESTROY(aTHX_ gullet);

SV *
readToken(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readToken(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getMouth(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_getMouth(aTHX_ gullet);
    if(!RETVAL) { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
openMouth(gullet,mouth,...)
    SV * gullet;
    SV * mouth;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    int noautoclose = (items > 2 ? SvTRUE(ST(2)) : 0);
  CODE:
    RETVAL = gullet_openMouth(aTHX_ gullet, mouth, noautoclose);
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
closeMouth(gullet, ...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    int forced = (items > 1 ? SvTRUE(ST(1)) : 0);
  CODE:
    gullet_closeMouth(aTHX_ gullet, forced);

void
closeThisMouth(gullet, tomouth)
    SV * gullet;
    SV * tomouth;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    typecheck_xsarg(tomouth,Mouth);
    gullet_closeThisMouth(aTHX_ gullet, tomouth);

void
flush(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    gullet_flush(aTHX_ gullet);

void
unread(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * mouth = gullet_getMouth(aTHX_ gullet);
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i)); /* Create a "safe" copy(?) */
      typecheck_xsarg(sv,Token,Tokens);
      mouth_unread(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

int
ifNext(gullet,token)
    SV * gullet;
    SV * token;
  CODE:  
    typecheck_xsarg(gullet,Gullet);
    typecheck_xsarg(token,Token);
    RETVAL = gullet_ifNext(aTHX_ gullet, state_global(aTHX), token);
  OUTPUT:
    RETVAL

SV *
getLocator(gullet)
    SV * gullet;
  CODE:  
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_getLocator(aTHX_ gullet);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readXToken(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    int toplevel  =(items > 1 ? SvTRUE(ST(1)) : 0);
    int commentsok=(items > 2 ? SvTRUE(ST(2)) : 0);
  CODE:
    PUTBACK;
    RETVAL = gullet_readXToken(aTHX_ gullet, state, toplevel, commentsok);
    SPAGAIN;
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
neutralizeTokens(gullet,tokens)
    SV * gullet;
    SV * tokens;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    typecheck_xsarg(tokens,Tokens);
    RETVAL = gullet_neutralizeTokens(aTHX_ gullet, state_global(aTHX), tokens);
  OUTPUT:
    RETVAL

void
expandafter(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    gullet_expandafter(aTHX_ gullet, state);

SV *
readXUntilEnd(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readXUntilEnd(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ croak("NULL from readXUntilEnd"); }
  OUTPUT:
    RETVAL

SV *
readNonSpace(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readNonSpace(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
skipSpaces(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    gullet_skipSpaces(aTHX_ gullet, state);

void
skip1Space(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    gullet_skip1Space(aTHX_ gullet, state);

SV *
readBalanced(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    SV * tokens = tokens_new(aTHX_ 1);
  CODE:
    gullet_readBalanced(aTHX_ gullet, state, tokens, 0);
    RETVAL = tokens;
  OUTPUT:
    RETVAL

SV *
readXBalanced(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    SV * tokens = tokens_new(aTHX_ 1);
  CODE:
    gullet_readBalanced(aTHX_ gullet, state, tokens, 1);
    RETVAL = tokens;
  OUTPUT:
    RETVAL
    
SV *
readArg(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

SV *
readXArg(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readXArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

SV *
readUntilBrace(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readUntilBrace(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readUntilBrace"); }
  OUTPUT:
    RETVAL

SV *
readOptional(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    SV * defaultx = (typecheck_optarg(1,"default",Token,Tokens) ? ST(1) : NULL);
  CODE:
    RETVAL = gullet_readOptional(aTHX_ gullet, state);
    if(! RETVAL){
      RETVAL = (defaultx ? SvREFCNT_inc(defaultx) : &PL_sv_undef); }
  OUTPUT:
    RETVAL

SV *
readCSName(gullet)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readCSName(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readMatch(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  CODE:
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    DEBUG_Gullet("readMatch: start\n");
    for(choice = 0; choice < nchoices; choice++){
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);
    match = gullet_readMatch(aTHX_ gullet, state, nchoices,maxlength, type, choices);
    if(match >= 0){
      DEBUG_Gullet("readMatch: Succeeded choice %d\n",match);
      RETVAL = ST(1+match);
      SvREFCNT_inc(RETVAL); }
    else {
      DEBUG_Gullet("readMatch: Failed\n");
      RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
readUntil(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  PPCODE:
    DEBUG_Gullet("readUntil: start\n");
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    for(choice = 0; choice < nchoices; choice++){
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);

    SV * tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 0, nchoices, maxlength, type, choices, &match);
    U8 gimme = GIMME_V;
    if(gimme == G_VOID){}
    else if (gimme == G_SCALAR){
      PUSHs(tokens); }
    else {
      EXTEND(SP, 2);
      PUSHs(tokens);
      if(match < 0){
        PUSHs(&PL_sv_undef); }
      else {
        SV * sv = sv_2mortal(SvREFCNT_inc(choices[match]));
        PUSHs(sv); } }

void
readXUntil(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    int type[nchoices];           /* 0 for notmatched, 1 for Token, 2 for Tokens */
    SV * choices[nchoices];
    int maxlength = 0;
    int choice;
    int match;
  PPCODE:
    DEBUG_Gullet("readUntil: start\n");
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    for(choice = 0; choice < nchoices; choice++){
      choices[choice] = ST(1+choice); }
    maxlength = gullet_prepareMatch(aTHX_ gullet, nchoices, type, choices);

    SV * tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 1, nchoices, maxlength, type, choices, &match);
    U8 gimme = GIMME_V;
    if(gimme == G_VOID){}
    else if (gimme == G_SCALAR){
      PUSHs(tokens); }
    else {
      EXTEND(SP, 2);
      PUSHs(tokens);
      if(match < 0){
        PUSHs(&PL_sv_undef); }
      else {
        SV * sv = sv_2mortal(SvREFCNT_inc(choices[match]));
        PUSHs(sv); } }

SV *
readKeyword(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    int nchoices = items-1;
    char * choices[nchoices];
    int choice;
    int match;
  CODE:
    /* prepare for matching by characterizing the candidates, thier types, lengths, etc. */
    DEBUG_Gullet("readKeyword: start\n");
    for(choice = 0; choice < nchoices; choice++){
      SV * key = ST(1+choice);
      if(!SvUTF8(key)){
        key = sv_mortalcopy(key);
        sv_utf8_upgrade(key); }
      choices[choice] = SvPV_nolen(key);
      DEBUG_Gullet("readKeyword: choice %d = %s\n",choice,choices[choice]); }

    /* Common case! */
    match = gullet_readKeyword(aTHX_ gullet, state, nchoices, choices);

   if(match >= 0){
     DEBUG_Gullet("readKeyword: Succeeded choice %d\n",match);
     RETVAL = ST(1+match);
     SvREFCNT_inc(RETVAL); }
   else {
     DEBUG_Gullet("readKeyword: Failed\n");
     RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
readOptionalSigns(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readOptionalSigns(aTHX_ gullet, state_global(aTHX));
  OUTPUT:
    RETVAL

SV *
readNumber(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readNumber(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readDimension(gullet,...)
    SV * gullet;
  INIT:
    typecheck_xsarg(gullet,Gullet);
    int nocomma = (items > 1 ? SvTRUE(ST(1)) : 0);
    double defaultunit = (typecheck_optarg(2,"defaultunit",double) ? SvNV(ST(2)) : 0.0);
  CODE:
    RETVAL = gullet_readDimension(aTHX_ gullet, state_global(aTHX), nocomma, defaultunit);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readGlue(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readMuGlue(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readMuGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readFloat(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readFloat(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readTokensValue(gullet)
    SV * gullet;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readTokensValue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readValue(gullet,type)
    SV * gullet;
    UTF8 type;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    RETVAL = gullet_readValue(aTHX_ gullet,state_global(aTHX),type);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readArgument(gullet, parameter, fordefn)
    SV * gullet;
    SV * parameter;
    SV * fordefn;
  CODE:
    typecheck_xsarg(gullet,Gullet);
    typecheck_xsarg(parameter,Parameter);
    typecheck_xsarg(fordefn,Token,undef);
    if(! SvOK(fordefn)){ fordefn = NULL; }
    RETVAL = parameter_read(aTHX_ parameter, gullet, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
readArguments(gullet, parameters, fordefn)
    SV * gullet;
    SV * parameters;
    SV * fordefn;
  PPCODE:
    typecheck_xsarg(gullet,Gullet);
    typecheck_xsarg(fordefn,Token);
    if(SvOK(parameters)){       /* If no parameters, nothing to read! */
      AV * params = SvArray(parameters);
      SSize_t npara = av_len(params) + 1;
      SV * values[npara];
      PUTBACK;
      int nargs = gullet_readArguments(aTHX_ gullet, state_global(aTHX), npara, params, fordefn, values);
      SPAGAIN;
      int ip;
      /*fprintf(stderr,"GOT %ld parameters, %d arguments for %s\n",npara,nargs, name);*/
      EXTEND(SP,nargs);
      for(ip = 0; ip < nargs; ip++){
        SV * arg = values[ip];
        if(arg){
          arg =sv_2mortal(arg); }
        else {
          arg = &PL_sv_undef; }
        PUSHs(arg); }
    }

 #/*======================================================================
 #   LaTeXML::Core::Parameter
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Parameter

LaTeXML_Parameter
new_internal(spec,...)
    UTF8 spec;
  INIT:
    LaTeXML_Parameter parameter = parameter_new(aTHX_ spec);
  CODE:
    if((items-1) % 2){
      croak("Odd number of values in Parameter_new keyword values"); }
    int i;
    for(i = 1; i < items; i+=2){
      typecheck_optarg(i,"key",string);
      UTF8 key = SvPV_nolen(ST(i));
      SV * value = ST(i+1);
      if(strcmp(key,"reader") == 0){
        if(!value){}
        else if(isa_Opcode(value)){
          UTF8 opcode = SvPV_nolen(SvRV(value));
          parameter->opreader = parameter_lookup(aTHX_ opcode);
          if(! parameter->opreader){
            croak("Parameter %s has an undefined opcode %s",spec,opcode); }}
        else if(isa_CODE(value)){
          SvREFCNT_inc(value);
          parameter->reader = value; }
        else {
          typecheck_xsfatal(value,"reader",Opcode,CODE); } }
      else if(strcmp(key,"semiverbatim") == 0){
        SvREFCNT_inc(value);
        parameter->semiverbatimsv = value;
        AV * semiverb = SvArray(value);
        int i,nc = av_len(semiverb)+1;
        SV ** ptr;
        int nchars = 0;
        Newx(parameter->semiverbatim,nc,UTF8);
        for(i = 0; i < nc; i++){
          if( (ptr = av_fetch(semiverb,i,0)) ){
            SV * ch = *ptr;
            typecheck_xsarg(ch,string);
            parameter->semiverbatim[nchars++] = string_copy(SvPV_nolen(ch)); } }
        parameter->nsemiverbatim = nchars; }
      else if(strcmp(key,"extra") == 0){
        SvREFCNT_inc(value);
        parameter->extrasv = value;
        AV * extra = SvArray(value);
        int i,nc = av_len(extra)+1;
        SV ** ptr;
        int nextra = 0;
        Newx(parameter->extra,nc,PTR_SV);
        for(i = 0; i < nc; i++){
          if( (ptr = av_fetch(extra,i,0)) && *ptr && SvOK(*ptr)){
            SvREFCNT_inc(*ptr);
            parameter->extra[nextra++] = *ptr; }
          else {
            parameter->extra[nextra++] = NULL; } }
        parameter->nextra = nextra; }
      else if(strcmp(key,"optional") == 0){
        if(SvTRUE(value)){ parameter->flags |= PARAMETER_OPTIONAL; }
        else             { parameter->flags &= ~PARAMETER_OPTIONAL; } }
      else if(strcmp(key,"novalue") == 0){
        if(SvTRUE(value)){ parameter->flags |= PARAMETER_NOVALUE; }
        else             { parameter->flags &= ~PARAMETER_NOVALUE; } }
      else if(strcmp(key,"undigested") == 0){
        if(SvTRUE(value)){ parameter->flags |= PARAMETER_UNDIGESTED; }
        else             { parameter->flags &= ~PARAMETER_UNDIGESTED; } }
      else if(strcmp(key,"beforeDigest") == 0){
        SvREFCNT_inc(value);
        parameter->beforeDigest = value; }
      else if(strcmp(key,"afterDigest") == 0){
        SvREFCNT_inc(value);
        parameter->afterDigest = value; }
      else if(strcmp(key,"reversion") == 0){
        SvREFCNT_inc(value);
        parameter->reversion = value; }
      else if(strcmp(key,"type") == 0){
      }
      else {
        fprintf(stderr,"Parameter %s initialization keyword %s unknown\n",spec,key); }
    }
    if(! parameter->reader && !parameter->opreader){
      croak("Parameter %s has no reader!",parameter->spec); }
    RETVAL = parameter;
  OUTPUT:
    RETVAL

void
DESTROY(parameter)
    SV * parameter;
  CODE:
    parameter_DESTROY(aTHX_ parameter);

UTF8
getSpecification(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->spec;
  OUTPUT:
    RETVAL

UTF8
stringify(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->spec;
  OUTPUT:
    RETVAL

SV *
getSemiverbatim(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->semiverbatimsv;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
setupCatcodes(parameter)    
    SV * parameter;
  CODE:
    typecheck_xsarg(parameter,Parameter);
    RETVAL = parameter_setupCatcodes(aTHX_ parameter, state_global(aTHX));
  OUTPUT:
    RETVAL

void
revertCatcodes(parameter)    
    SV * parameter;
  CODE:
    typecheck_xsarg(parameter,Parameter);
    parameter_revertCatcodes(aTHX_ parameter, state_global(aTHX));
    
SV *
getExtra(parameter)
    SV * parameter;
  INIT:
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    typecheck_xsarg(parameter,Parameter);
    RETVAL = param->extrasv;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getBeforeDigest(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->beforeDigest;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getAfterDigest(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->afterDigest;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getReversion(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->reversion;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
getOptional(parameter)
    SV * parameter;
  INIT:
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->flags & PARAMETER_OPTIONAL;
  OUTPUT:
    RETVAL

int
getUndigested(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->flags & PARAMETER_UNDIGESTED;
  OUTPUT:
    RETVAL

int
getNovalue(parameter)
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->flags & PARAMETER_NOVALUE;
  OUTPUT:
    RETVAL

SV *
read(parameter, gullet, ...)
    SV * gullet;
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    typecheck_xsarg(gullet,Gullet);
    /* NOTE: Get straight exactly what fordefn should be (a Token?) and get it CORRECT! */
    SV * fordefn = (typecheck_optarg(2,"fordefn",Token) ? ST(2) : NULL);
  CODE:
    RETVAL = parameter_read(aTHX_ parameter, gullet, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readAndDigest(parameter, stomach, ...)
    SV * stomach;
    SV * parameter;
  INIT:
    typecheck_xsarg(parameter,Parameter);
    typecheck_xsarg(stomach,Stomach);
    SV * fordefn = (typecheck_optarg(2,"fordefn",Token) ? ST(2) : NULL);
    /* NOTE: Get straight exactly what fordefn should be (a Token? Definition?) and get it CORRECT! */
  CODE:
    RETVAL = parameter_readAndDigest(aTHX_ parameter, stomach, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL


 #/*======================================================================
 #   LaTeXML::Core::Definition::Expandable
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Definition::Expandable

SV *
new(class,cs,parameters,expansion,...)
    UTF8 class;
    SV * cs;
    SV * parameters;
    SV * expansion;
  INIT:  
    typecheck_xsarg(expansion,undef,Tokens,Opcode,CODE);
    SV * state = state_global(aTHX);
    LaTeXML_State xstate = SvState(state);
    LaTeXML_Stomach xstomach = SvStomach(xstate->stomach);
    SV * gullet =  xstomach->gullet;
    int i;
  CODE:
    PERL_UNUSED_VAR(class);
    if((items-4) % 2){
      croak("Odd number of hash elements in Expandable->new"); }
    /* tokenize expansion ? */
    /* expansion = Tokens(expansion) if ref expansion Token ? */
    SV * locator = gullet_getLocator(aTHX_ gullet);
    SV * expandable = expandable_new(aTHX_ state, cs, parameters, expansion,locator);
    /* Add other properties */
    HV * hash = SvHash(expandable);
    for(i = 4; i < items; i+=2){
      typecheck_optarg(i,"key",string);
      SV * keysv = ST(i);
      SV * value = ST(i+1);
      if(SvOK(keysv) && SvOK(value)){
        STRLEN keylen;
        UTF8 key = SvPV(ST(i),keylen);
        hv_store(hash,key,keylen,SvREFCNT_inc(value),0); }}
    RETVAL = expandable;
  OUTPUT:    
    RETVAL

void
newInstalled(class,state, scope, cs,parameters,expansion,...)
    UTF8 class;
    SV * state;
    UTF8 scope;
    SV * cs;
    SV * parameters;
    SV * expansion;
  INIT:  
    typecheck_xsarg(expansion,undef,Token,Tokens,Opcode,CODE);
    typecheck_xsarg(state,State);
    LaTeXML_State xstate = SvState(state);
    LaTeXML_Stomach xstomach = SvStomach(xstate->stomach);
    SV * gullet =  xstomach->gullet;
    int i;
  CODE:
    PERL_UNUSED_VAR(class);
    if((items-6) % 2){
      croak("Odd number of hash elements in Expandable->new"); }
    /* tokenize expansion ? */
    /* expansion = Tokens(expansion) if ref expansion Token ? */
    SV * locator = gullet_getLocator(aTHX_ gullet);
    SV * expandable = expandable_new(aTHX_ state, cs, parameters, expansion,locator);
    /* Add other properties */
    HV * hash = SvHash(expandable);
    for(i = 6; i < items; i+=2){
      typecheck_optarg(i,"key",string);
      SV * keysv = ST(i);
      SV * value = ST(i+1);
      if(SvOK(keysv) && SvOK(value)){
        STRLEN keylen;
        UTF8 key = SvPV(ST(i),keylen);
        hv_store(hash,key,keylen,SvREFCNT_inc(value),0); }}
    state_installDefinition(aTHX_ state, expandable, scope);

void
invoke(expandable, token, gullet)
    SV * expandable;
    SV * token;
    SV * gullet;
  INIT:
    typecheck_xsarg(expandable,Expandable);
    typecheck_xsarg(token,undef,Token);
    typecheck_xsarg(gullet,Gullet);
    SV * state = state_global(aTHX);
    SV * result;
  PPCODE:
    PUTBACK;
    if(! token){
      token = hash_get(aTHX_ SvHash(expandable),"cs"); }
    result = expandable_invoke(aTHX_ expandable, token, gullet, state);
    SPAGAIN;
    if(result){ 
      EXTEND(SP,1);
      PUSHs(sv_2mortal(result)); }

 #/*======================================================================
 #   LaTeXML::Core::Definition::Primitive
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Definition::Primitive

void
invoke(primitive, token, stomach)
    SV * primitive;
    SV * token;
    SV * stomach;
  INIT:
    typecheck_xsarg(primitive,Primitive);
    typecheck_xsarg(stomach,Stomach);
    typecheck_xsarg(token,undef,Token);
    SV * state = state_global(aTHX);
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    int i;
  PPCODE:
    /* NOTE: Apparently if you're calling back to Perl, and Perl REallocates the stack
    you can get into trouble with invalid access, etc. The (Extra?!?) wrap of
    PUTBACK/SPAGAIN seems to handle that (even though the called functions use them already).
    See cryptic comments at https://github.com/Perl-XS/notes/issues/7 */
    PUTBACK;
    primitive_invoke(aTHX_ primitive, token, stomach, state, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

SV *
valueOf(reg,...)
    SV * reg;
  INIT:
    typecheck_xsarg(reg,Primitive);
    int nargs = items-1;
    SV * args[nargs];
    int i;
  CODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+1);       /* otherwise, anything */
      args[i] = (SvOK(arg) ? arg : NULL); }
    RETVAL = register_valueOf(aTHX_ reg, state_global(aTHX), nargs, args);
    if(!RETVAL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
setValue(reg, value...)
    SV * reg;
    SV * value;
  INIT:
    typecheck_xsarg(reg,Primitive);
    int nargs = items-2;
    SV * args[nargs];
    int i;
  PPCODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+2);       /* otherwise, anything */
      args[i] = (SvOK(arg) ? arg : NULL); }
    register_setValue(aTHX_ reg, state_global(aTHX), nargs, args, value);
    
 #/*======================================================================
 #   LaTeXML::Core::Stomach
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Stomach

SV *
new(class)
    UTF8 class;
  CODE:  
    PERL_UNUSED_VAR(class);
    RETVAL = stomach_new(aTHX);
  OUTPUT:
    RETVAL

void
initialize(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_initialize(aTHX_ stomach, state_global(aTHX));

SV *
getGullet(stomach)
    SV * stomach;
  INIT: 
    typecheck_xsarg(stomach,Stomach);
    LaTeXML_Stomach xstomach = SvStomach(stomach);
  CODE:  
    RETVAL = xstomach->gullet;
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
    else { SvREFCNT_inc(RETVAL); }
  OUTPUT:
    RETVAL

SV *
getLocator(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    RETVAL = stomach_getLocator(aTHX_ stomach);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
getBoxingLevel(stomach)
    SV * stomach;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    LaTeXML_Stomach xstomach = SvStomach(stomach);
    AV * boxing = xstomach->boxing;
  CODE:  
    RETVAL = av_len(boxing)+1;
  OUTPUT:
    RETVAL

void
pushStackFrame(stomach, ...)
    SV * stomach;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    int nobox = ((items > 1) && SvTRUE(ST(1)) ? 1 : 0);
  CODE:  
    stomach_pushStackFrame(aTHX_ stomach, state_global(aTHX), nobox);

void
popStackFrame(stomach, ...)
    SV * stomach;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    int nobox = ((items > 1) && SvTRUE(ST(1)) ? 1 : 0);
  CODE:  
    stomach_popStackFrame(aTHX_ stomach, state_global(aTHX), nobox);


void
bgroup(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_bgroup(aTHX_ stomach, state_global(aTHX));

void
egroup(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_egroup(aTHX_ stomach, state_global(aTHX));

void
begingroup(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_begingroup(aTHX_ stomach, state_global(aTHX));

void
endgroup(stomach)
    SV * stomach;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_endgroup(aTHX_ stomach, state_global(aTHX));

void
beginMode(stomach, mode)
    SV * stomach;
    UTF8 mode;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_beginMode(aTHX_ stomach, state_global(aTHX),mode);

void
endMode(stomach, mode)
    SV * stomach;
    UTF8 mode;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    stomach_endMode(aTHX_ stomach, state_global(aTHX),mode);

void
invokeToken(stomach, token)
    SV * stomach;
    SV * token;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    typecheck_xsarg(token,Token);
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    int i;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    stomach_invokeToken(aTHX_ stomach, state_global(aTHX), token, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

void
invokeInput(stomach)
    SV * stomach;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    SV * state = state_global(aTHX);
    SV * gullet = stomach_gullet(aTHX_ stomach);
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    SV * token;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    stack->discard = 1;         /* NO need to accumulate! */
    while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0)) ){
      LaTeXML_Token t = SvToken(token);
      if(t->catcode != CC_SPACE){
        stomach_invokeToken(aTHX_ stomach, state_global(aTHX), token, stack);
      }
      SvREFCNT_dec(token); }
    SvREFCNT_dec(gullet);
    boxstack_DESTROY(aTHX_ stack);  /* DISCARD boxes! */
    SPAGAIN;

SV *
digest(stomach,tokens)
    SV * stomach;
    SV * tokens;
  CODE:  
    typecheck_xsarg(stomach,Stomach);
    typecheck_xsarg(tokens,Token,Tokens);
    RETVAL = stomach_digest(aTHX_ stomach, state_global(aTHX), tokens);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
digestNextBody(stomach, ...)
    SV * stomach;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    SV * terminal = (typecheck_optarg(1,"termninal",Token) ? ST(1) : NULL);
    int i;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    LaTeXML_Boxstack stack = stomach_digestNextBody(aTHX_ stomach, state_global(aTHX), terminal);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

void
digestThing(stomach, thing)
    SV * stomach;
    SV * thing;
  INIT:
    typecheck_xsarg(stomach,Stomach);
    int i;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    stomach_digestThing(aTHX_ stomach, state_global(aTHX), thing, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);
