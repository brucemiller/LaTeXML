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

#include "src/object.h"
#include "src/tokens.h"
#include "src/numbers.h"
#include "src/state.h"
#include "src/tokenstack.h"
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
  CODE:
    RETVAL = state_new(aTHX_ stomach, model);
  OUTPUT:
    RETVAL

SV *
getStomach(state)
    SV * state;
  CODE:
    RETVAL = state_stomach(aTHX_ state);
    if(! RETVAL){
      croak("internal:stomach State has no stomach!"); }
  OUTPUT:
    RETVAL

SV *
getStomach_noerror(state)
    SV * state;
  CODE:
    RETVAL = state_stomach(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getModel(state)
    SV * state;
  CODE:
    RETVAL = state_model(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
getValueKeys(state)
    SV * state;
  INIT:
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
    RETVAL = state_getFrameDepth(aTHX_ state);
  OUTPUT:
    RETVAL

int
isFrameLocked(state);
    SV * state;
  CODE:
    RETVAL = state_isFrameLocked(aTHX_ state);
  OUTPUT:
    RETVAL

void
setFrameLock(state, locked);
    SV * state;
    int locked;
  PPCODE:
    state_setFrameLock(aTHX_ state,locked);

void
pushFrame(state)
    SV * state;
  PPCODE:
    state_pushFrame(aTHX_ state);

void
popFrame(state)
    SV * state;
  PPCODE:
    state_popFrame(aTHX_ state);

void
activateScope(state, scope)
   SV * state;
   UTF8 scope;
 CODE:
   state_activateScope(aTHX_ state, scope);

void
deactivateScope(state, scope)
   SV * state;
   UTF8 scope;
 CODE:
   state_deactivateScope(aTHX_ state, scope);

SV *
lookupCatcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(catcode) && !SvIOKp(catcode)){
      croak("Catcode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_CATCODE, string, catcode, scope);

SV *
lookupMathcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(mathcode) && !SvIOKp(mathcode)){
      croak("Mathcode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_MATHCODE, string, mathcode, scope);

SV *
lookupSFcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(sfcode) && !SvIOKp(sfcode)){
      croak("SFcode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_SFCODE, string, sfcode, scope);

SV *
lookupLCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(lccode) && !SvIOKp(lccode)){
      croak("lccode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_LCCODE, string, lccode, scope);

SV *
lookupUCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(uccode) && !SvIOKp(uccode)){
      croak("uccode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_UCCODE, string, uccode, scope);

SV *
lookupDelcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    if(SvOK(delcode) && !SvIOKp(delcode)){
      croak("delcode expected a number"); }
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_DELCODE, string, delcode, scope);

SV *
lookupValue(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_VALUE, string, value, scope);

int
isValueBound(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    int frame = ((items > 2) && SvOK(ST(2)) ? SvIV(ST(2)) : -1);
  CODE:
    RETVAL = state_isBound(aTHX_ state, TBL_VALUE, string, frame);
  OUTPUT:
    RETVAL

SV *
valueInFrame(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    int frame = ((items > 2) && SvOK(ST(2)) ? SvIV(ST(2)) : 0);
  CODE:
    RETVAL = state_lookupInFrame(aTHX_ state, TBL_VALUE, string, frame);
  OUTPUT:
    RETVAL

void
lookupStackedValues(state,string)
    SV * state;
    UTF8 string;
  INIT:
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
pushValue(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
    int i;
  PPCODE:
    for(i = 2; i < items; i++){
      SV * sv = ST(i);
      SvREFCNT_inc(sv);
      av_push(av, sv); }

SV *
popValue(state,string)
    SV * state;
    UTF8 string;
  INIT:
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
    AV * av = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, string);
    int i;
  PPCODE:
    av_unshift(av,items-2);
    for(i = 2; i < items; i++){
      SV * sv = ST(i);
      SvREFCNT_inc(sv);
      av_store(av, i-2, sv); }

SV *
shiftValue(state,string)
    SV * state;
    UTF8 string;
  INIT:
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
    HV * hash = state_lookupHV_noinc(aTHX_ state, TBL_VALUE, string);
  PPCODE:
    hv_store(hash,key,-strlen(key),value,0);
    SvREFCNT_inc(value);

SV *
lookupStash(state,string)
    SV * state;
    UTF8 string;
  CODE:
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
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign(aTHX_ state, TBL_STASH, string, value, scope);

SV *
lookupMeaning(state,token)
    SV * state;
    SV * token;
  CODE:
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
    RETVAL = state_XEquals(aTHX_ state, token1, token2);
  OUTPUT:
    RETVAL

int
Equals(token1,token2)
    SV * token1;
    SV * token2;
  CODE:
    RETVAL = state_Equals(aTHX_ token1, token2);
  OUTPUT:
    RETVAL

int
globalFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_GLOBAL;
  OUTPUT:
    RETVAL

void
setGlobalFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_GLOBAL;

int
longFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_LONG;
  OUTPUT:
    RETVAL

void
setLongFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_LONG;

int
outerFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_OUTER;
  OUTPUT:
    RETVAL

void
setOuterFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_OUTER;

int
protectedFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    RETVAL = xstate->flags & FLAG_PROTECTED;
  OUTPUT:
    RETVAL

void
setProtectedFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_PROTECTED;

void
setUnlessFlag(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags |= FLAG_UNLESS;

void
clearFlags(state)
    SV * state;
  CODE:
    LaTeXML_State xstate = SvState(state);
    xstate->flags = 0;

void
beginSemiverbatim(state,...)
    SV * state;      
  INIT:
    int nchars = items-1;
    UTF8 chars[items-1];
    int i;
  PPCODE:
    for(i=0; i < nchars; i++){
      SV * sv = ST(i+1);
      chars[i] = SvPV_nolen(sv); }
    state_beginSemiverbatim(aTHX_ state, nchars, chars); 

void
endSemiverbatim(state)
    SV * state;      
  PPCODE:
    state_endSemiverbatim(aTHX_ state); 

void
assignMeaning(state, token, meaning,...)
    SV * state;
    SV * token;
    SV * meaning;
  CODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    if (! (SvOK(token) && sv_isa(token, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token is not a Token"); }
    if(SvOK(meaning) && sv_isa(meaning, "LaTeXML::Core::Token")
       && token_equals(aTHX_ token,meaning)){
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
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    if (! (SvOK(token1) && sv_isa(token1, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token1 is not a Token"); }
    if (! (SvOK(token2) && sv_isa(token2, "LaTeXML::Core::Token")) ) {
      croak("assignMeaning token2 is not a Token"); }
    SV * meaning = state_meaning(aTHX_ state, token2);
    if(meaning && sv_isa(meaning, "LaTeXML::Core::Token")
       && token_equals(aTHX_ token1,meaning)){
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
    RETVAL = state_expandable(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
lookupDefinition(state,token)
    SV * state;
    SV * token;
  CODE:
    RETVAL = state_definition(aTHX_ state, token);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
installDefinition(state, definition, ...)
    SV * state;
    SV * definition;
  CODE:
    UTF8 scope = ((items > 2) && SvTRUE(ST(2)) ? SvPV_nolen(ST(2)) : NULL);
    state_installDefinition(aTHX_ state, definition, scope);

void
afterAssignment(state)
    SV * state;
  PPCODE:
    primitive_afterAssignment(aTHX_ state);

SV *
getLocator(state)
    SV * state;
  CODE:  
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
    RETVAL = state_convertUnit(aTHX_ state, unit);
  OUTPUT:
    RETVAL

void
clearStatus(state,...)
    SV * state;
  CODE:
    state_clearStatus(aTHX_ state);

void
noteStatus(state,type,...)
    SV * state;
    UTF8 type;
  CODE:
    if(items > 2){
      int i;
      for(i = 2; i < items; i++){
        state_noteSymbolStatus(aTHX_ state, type, SvPV_nolen(ST(i))); } }
    else {
      state_noteStatus(aTHX_ state, type); }

SV *
getStatus(state,type)
    SV * state;
    UTF8 type;
  CODE:
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
   if (SvOK(a) && sv_isa(a, "LaTeXML::Core::Token")
       && SvOK(b) && sv_isa(b, "LaTeXML::Core::Token")) {
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
    if((items == 1) && sv_isa(ST(0), "LaTeXML::Core::Tokens")) {
      RETVAL = ST(0);
      SvREFCNT_inc(RETVAL); }   /* or mortal? */
    else {
      tokens = tokens_new(aTHX_ items);
      for (i = 0 ; i < items ; i++) {
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
   if (SvOK(a) && sv_isa(a, "LaTeXML::Core::Tokens")
       && SvOK(b) && sv_isa(b, "LaTeXML::Core::Tokens")) {
     RETVAL = tokens_equals(aTHX_ a, b); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

UTF8
toString(tokens)
    SV * tokens;
  CODE:
    RETVAL = tokens_toString(aTHX_ tokens);
  OUTPUT: 
    RETVAL

void
unlist(tokens)
    SV * tokens
  INIT:
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
    int i;
    int nargs = items-1;
    SV * args[nargs];
  CODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+1);
      if(! SvOK(arg)){
        arg = NULL; }
      args[i] = arg; }
    RETVAL = tokens_substituteParameters(aTHX_ tokens, nargs, args);
    if(RETVAL == NULL){ croak("NULL from substituteParameters"); }
  OUTPUT:
    RETVAL

SV *
trim(tokens)
    SV * tokens
  CODE:
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
    LaTeXML_Tokenstack stack;
    SV * token;
  CODE:
    SV * sv = newSVsv(token); /* Create a "safe" copy(?) */
    tokenstack_push(aTHX_ stack,sv); 
    SvREFCNT_dec(sv);

SV *
pop(stack)
    LaTeXML_Tokenstack stack;
  CODE:
    RETVAL = tokenstack_pop(aTHX_ stack);
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
    mouth_finish(aTHX_ mouth);

int
hasMoreInput(mouth)
    SV * mouth
  CODE:
    RETVAL = mouth_hasMoreInput(aTHX_ mouth);
  OUTPUT:
    RETVAL

void
getPosition(mouth)
    SV * mouth;
  PPCODE:
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    EXTEND(SP, 2);
    mPUSHi((IV) xmouth->lineno);
    mPUSHi((IV) xmouth->colno);

void
setAutoclose(mouth, autoclose)
    SV * mouth;
    int autoclose;
  CODE:
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    if(autoclose){
      xmouth->flags |= MOUTH_AUTOCLOSE; }
    else {
      xmouth->flags &= ~MOUTH_AUTOCLOSE; }

int
getAutoclose(mouth)
    SV * mouth;
  CODE:
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_AUTOCLOSE;
  OUTPUT:
    RETVAL

SV *
getPreviousMouth(mouth)
    SV * mouth;
  CODE:
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
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_INTERESTING;
  OUTPUT:
    RETVAL

SV *
getLocator(mouth)
    SV * mouth;
  CODE:  
    RETVAL = mouth_getLocator(aTHX_ mouth);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

UTF8
getSource(mouth)
    SV * mouth;
  CODE:
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->source;
    if(RETVAL == NULL){ croak("NULL from getSource"); }
  OUTPUT:
    RETVAL

UTF8
getShortSource(mouth)
    SV * mouth;    
  CODE:
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->short_source;
    if(RETVAL == NULL){ croak("NULL from getShortSource"); }
  OUTPUT:
    RETVAL

UTF8
getNoteMessage(mouth)
    SV * mouth;    
  CODE:
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
    mouth_setInput(aTHX_ mouth,input);

SV *
readToken(mouth)
    SV * mouth;
  CODE:
    RETVAL = mouth_readToken(aTHX_ mouth, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL


SV *
readTokens(mouth,...)
    SV * mouth;
  INIT:
    SV * until = NULL;
  CODE:
    if(items > 1){
      until = ST(1); }
    RETVAL = mouth_readTokens(aTHX_ mouth, state_global(aTHX), until);
    if(RETVAL == NULL){ croak("NULL from readTokens"); }
  OUTPUT:
    RETVAL
  
void
unread(mouth,...)
    SV * mouth;
  INIT:
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i)); /* Create a "safe" copy(?) */
      mouth_unread(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

void
getPushback(mouth)
    SV * mouth;
  INIT:
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
    LaTeXML_Mouth xmouth = SvMouth(mouth);
    RETVAL = xmouth->flags & MOUTH_AT_EOF;
  OUTPUT:
    RETVAL

SV *
readRawLine(mouth,...)
    SV * mouth;
  INIT:
    int noread = 0;
    LaTeXML_Mouth xmouth = SvMouth(mouth);
  CODE:
    if(items > 1){
      noread = SvIV(ST(1)); }
    /* Peculiar logic: 'noread' really means return the rest of current line,
       if we've alread read something from it */
    if(noread){
      if(xmouth->colno > 0){
        STRLEN pstart = xmouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        /*
        if(n==0){ fprintf(stderr,"KEEP RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(xmouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"KEEP RAW: '%s'\n",buffer); }
              */
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
        /*
        if(n==0){ fprintf(stderr,"READ RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(xmouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"READ RAW: '%s'\n",buffer); }
               */
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
    RETVAL = gullet_readToken(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getMouth(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_getMouth(aTHX_ gullet);
    if(!RETVAL) { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
openMouth(gullet,mouth,...)
    SV * gullet;
    SV * mouth;
  INIT:
    int noautoclose = (items > 2 ? SvIV(ST(2)) : 0);
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
    int forced = (items > 1 ? SvIV(ST(1)) : 0);
  CODE:
    gullet_closeMouth(aTHX_ gullet, forced);

void
closeThisMouth(gullet, tomouth)
    SV * gullet;
    SV * tomouth;
  CODE:
    gullet_closeThisMouth(aTHX_ gullet, tomouth);

void
flush(gullet)
    SV * gullet;
  CODE:
    gullet_flush(aTHX_ gullet);

void
unread(gullet,...)
    SV * gullet;
  INIT:
    SV * mouth = gullet_getMouth(aTHX_ gullet);
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i)); /* Create a "safe" copy(?) */
      mouth_unread(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

int
ifNext(gullet,token)
    SV * gullet;
    SV * token;
  CODE:  
    RETVAL = gullet_ifNext(aTHX_ gullet, state_global(aTHX), token);
  OUTPUT:
    RETVAL

SV *
getLocator(gullet)
    SV * gullet;
  CODE:  
    RETVAL = gullet_getLocator(aTHX_ gullet);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readXToken(gullet,...)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    int toplevel=0,commentsok=0;
  CODE:
    if(items > 1){
      toplevel = SvIV(ST(1));
      if(items > 2){
        commentsok = SvIV(ST(2)); } }
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
    RETVAL = gullet_neutralizeTokens(aTHX_ gullet, state_global(aTHX), tokens);
  OUTPUT:
    RETVAL

void
expandafter(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_expandafter(aTHX_ gullet, state);

SV *
readXUntilEnd(gullet)
    SV * gullet;
  CODE:
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
    RETVAL = gullet_readNonSpace(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
skipSpaces(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_skipSpaces(aTHX_ gullet, state);

void
skip1Space(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_skip1Space(aTHX_ gullet, state);

SV *
readBalanced(gullet)
    SV * gullet;
  INIT:
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
    SV * state = state_global(aTHX);
    SV * defaultx = (items > 1 ? ST(2) : NULL);
  CODE:
    RETVAL = gullet_readOptional(aTHX_ gullet, state);
    if(! RETVAL){
      if(defaultx && SvOK(defaultx)){
        SvREFCNT_inc(defaultx);
        RETVAL = defaultx; }
      else {
        RETVAL = &PL_sv_undef; } }
  OUTPUT:
    RETVAL

SV *
readCSName(gullet)
    SV * gullet;
  INIT:
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
    RETVAL = gullet_readOptionalSigns(aTHX_ gullet, state_global(aTHX));
  OUTPUT:
    RETVAL

SV *
readNumber(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readNumber(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readDimension(gullet,...)
    SV * gullet;
  INIT:
    int nocomma = 0;
    double defaultunit = 0.0;
  CODE:
    if(items > 1){
      SV * arg = ST(1);
      nocomma = SvOK(arg); }
    if(items > 2){
      SV * arg = ST(1);      
      defaultunit = SvNV(arg); }
    RETVAL = gullet_readDimension(aTHX_ gullet, state_global(aTHX), nocomma, defaultunit);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readGlue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readMuGlue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readMuGlue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readFloat(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readFloat(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readTokensValue(gullet)
    SV * gullet;
  CODE:
    RETVAL = gullet_readTokensValue(aTHX_ gullet, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readValue(gullet,type)
    SV * gullet;
    UTF8 type;
  CODE:
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
      UTF8 key = SvPV_nolen(ST(i));
      SV * value = ST(i+1);
      if(strcmp(key,"reader") == 0){
        if(value && sv_isa(value,"LaTeXML::Core::Opcode")){
          UTF8 opcode = SvPV_nolen(SvRV(value));
          parameter->opreader = parameter_lookup(aTHX_ opcode);
          if(! parameter->opreader){
            croak("Parameter %s has an undefined opcode %s",spec,opcode); }}
        else if(value && SvTYPE(SvRV(value)) == SVt_PVCV){
          SvREFCNT_inc(value);
          parameter->reader = value; }
        else {
          croak("Parameter %s has reader which is not an opcode or CODE",spec); } }
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
            parameter->semiverbatim[nchars++] = string_copy(SvPV_nolen(*ptr)); } }
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
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->spec;
  OUTPUT:
    RETVAL

UTF8
stringify(parameter)
    SV * parameter;
  INIT:
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->spec;
  OUTPUT:
    RETVAL

SV *
getSemiverbatim(parameter)
    SV * parameter;
  INIT:
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
    RETVAL = parameter_setupCatcodes(aTHX_ parameter, state_global(aTHX));
  OUTPUT:
    RETVAL

void
revertCatcodes(parameter)    
    SV * parameter;
  CODE:
    parameter_revertCatcodes(aTHX_ parameter, state_global(aTHX));
    
SV *
getExtra(parameter)
    SV * parameter;
  INIT:
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->extrasv;
    if(RETVAL){ SvREFCNT_inc(RETVAL); }
    else { RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getBeforeDigest(parameter)
    SV * parameter;
  INIT:
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
    LaTeXML_Parameter param = SvParameter(parameter);
  CODE:
    RETVAL = param->flags & PARAMETER_UNDIGESTED;
  OUTPUT:
    RETVAL

int
getNovalue(parameter)
    SV * parameter;
  INIT:
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
    SV * fordefn = NULL;
  CODE:
    if(items > 2){
      fordefn = ST(2); }
    RETVAL = parameter_read(aTHX_ parameter, gullet, state_global(aTHX), fordefn);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
readAndDigest(parameter, stomach, ...)
    SV * stomach;
    SV * parameter;
  INIT:
    SV * fordefn = NULL;
  CODE:
    if(items > 2){
      fordefn = ST(2); }
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
    SV * state = state_global(aTHX);
    SV * result;
  PPCODE:
    PUTBACK;
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
    int nargs = items-1;
    SV * args[nargs];
    int i;
  CODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+1);
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
    int nargs = items-2;
    SV * args[nargs];
    int i;
  PPCODE:
    for(i = 0; i < nargs; i++){
      SV * arg = ST(i+2);
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
    stomach_initialize(aTHX_ stomach, state_global(aTHX));

SV *
getGullet(stomach)
    SV * stomach;
  INIT: 
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
    RETVAL = stomach_getLocator(aTHX_ stomach);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

int
getBoxingLevel(stomach)
    SV * stomach;
  INIT:
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
    int nobox = ((items > 1) && SvTRUE(ST(1)) ? 1 : 0);
  CODE:  
    stomach_pushStackFrame(aTHX_ stomach, state_global(aTHX), nobox);

void
popStackFrame(stomach, ...)
    SV * stomach;
  INIT:
    int nobox = ((items > 1) && SvTRUE(ST(1)) ? 1 : 0);
  CODE:  
    stomach_popStackFrame(aTHX_ stomach, state_global(aTHX), nobox);


void
bgroup(stomach)
    SV * stomach;
  CODE:  
    stomach_bgroup(aTHX_ stomach, state_global(aTHX));

void
egroup(stomach)
    SV * stomach;
  CODE:  
    stomach_egroup(aTHX_ stomach, state_global(aTHX));

void
begingroup(stomach)
    SV * stomach;
  CODE:  
    stomach_begingroup(aTHX_ stomach, state_global(aTHX));

void
endgroup(stomach)
    SV * stomach;
  CODE:  
    stomach_endgroup(aTHX_ stomach, state_global(aTHX));

void
beginMode(stomach, mode)
    SV * stomach;
    UTF8 mode;
  CODE:  
    stomach_beginMode(aTHX_ stomach, state_global(aTHX),mode);

void
endMode(stomach, mode)
    SV * stomach;
    UTF8 mode;
  CODE:  
    stomach_endMode(aTHX_ stomach, state_global(aTHX),mode);

void
invokeToken(stomach, token)
    SV * stomach;
    SV * token;
  INIT:
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
    RETVAL = stomach_digest(aTHX_ stomach, state_global(aTHX), tokens);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
digestNextBody(stomach, ...)
    SV * stomach;
  INIT:
    SV * terminal = ((items > 1) && SvOK(ST(1)) ? ST(1) : NULL);
    int i;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    if(terminal && !(sv_isa(terminal,"LaTeXML::Core::Token"))){
      croak("Expected a token!"); }
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
