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
#include "src/tokenstack.h"
#include "src/boxstack.h"
#include "src/parameters.h"
#include "src/state.h"
#include "src/mouth.h"
#include "src/gullet.h"
#include "src/expandable.h"
#include "src/primitive.h"
#include "src/stomach.h"

/*======================================================================
 Towards consistent, predictable API's for both C & Perl,
 in consideration of the fact that there will be a lot of storing/fetching
 pointers to objects in both C structures and Perl Hashes & Arrays,
 as well as creating new objects when required.

 * C-API should return NULL for failures, non-things, etc
 * Perl-API should watch for NULL's and return &PL_sv_undef
   (otherwise mysterious memory errors)

 * C-API functions should give the rights to the caller any object(s) returned,
   typically through SvREFCNT_inc (or equivalent).
   The caller either returns the object to it's caller, or uses SvREFCNT_dec
   (or equivalent) when done with the object.
   Exception: functions named with _noinc suffix; use when you know you'll be done
   with the object before anyone will dec its refcnt or Perl will get a chance to do any cleanup.
   Functions are NOT responsible for managing the REFCNT of arguments!
 
   [ALWAYS? Or is there a naming convention for exceptions?
   eg. the gullet_getMouth, various state methods etc where you are
   seldom likely to return the object to Perl ???]

 * Functions that store an object should assure that REFCNT is incremented.

 * Perl-API functions should always set mortal (eg. sv_2mortal),
   but note that RETVAL will automatically have sv_2mortal applied!

 * BE CAREFUL about putting things like POPs inside something like SvTRUE
   Some of the latter are macros that duplicate it's arguments!!!!!!

NOTE: Neither hv_store/hv_fetch (& av) change the reference count on the stored
   SV *, and fetch returns the same SV that was stored.

Question: Should some of the C API avoid passing pTHX as argument ?
It's not always actually needed or passed through.
But, if we omit it, we need to be predictable.

Major ToDo:
(1) separate into modules
(2) reimplement tracing
(3) develop error & logging API
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

void
assign_internal(state, table, key, value, ...)
    SV * state;
    UTF8 table;
    UTF8 key;
    SV * value;
  CODE:   
    UTF8 scope = ((items > 4) && SvTRUE(ST(4)) ? SvPV_nolen(ST(4)) : NULL);
    state_assign_internal(aTHX_ state, table, key, value, scope);

SV *
getStomach(state)
    SV * state;
  CODE:
    RETVAL = state_stomach(aTHX_ state);
  OUTPUT:
    RETVAL

SV *
getStomach_noerror(state)
    SV * state;
  CODE:
    RETVAL = state_stomach_noerror(aTHX_ state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

SV *
getModel(state)
    SV * state;
  CODE:
    RETVAL = state_model(aTHX_ state);
  OUTPUT:
    RETVAL

void
getValueKeys(state)
    SV * state;
  INIT:
    HV * hash = state_valueTable_noinc(aTHX_ state);
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
    HV * hash = state_stashTable_noinc(aTHX_ state);
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
    HV * hash = state_activeStashTable_noinc(aTHX_ state);
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

int
lookupCatcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_catcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignCatcode(state,string,catcode,...)
    SV * state;
    UTF8 string;
    int catcode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_catcode(aTHX_ state,string,catcode,scope);

int
lookupMathcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_mathcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignMathcode(state,string,mathcode,...)
    SV * state;
    UTF8 string;
    int mathcode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_mathcode(aTHX_ state,string,mathcode,scope);

int
lookupSFcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_SFcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignSFcode(state,string,sfcode,...)
    SV * state;
    UTF8 string;
    int sfcode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_SFcode(aTHX_ state,string,sfcode,scope);

int
lookupLCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_LCcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignLCcode(state,string,lccode,...)
    SV * state;
    UTF8 string;
    int lccode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_LCcode(aTHX_ state,string,lccode,scope);

int
lookupUCcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_UCcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignUCcode(state,string,uccode,...)
    SV * state;
    UTF8 string;
    int uccode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_UCcode(aTHX_ state,string,uccode,scope);

int
lookupDelcode(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_Delcode(aTHX_ state, string);
  OUTPUT:
    RETVAL

void
assignDelcode(state,string,delcode,...)
    SV * state;
    UTF8 string;
    int delcode;
  PPCODE:
    UTF8 scope = ((items > 3) && SvTRUE(ST(3)) ? SvPV_nolen(ST(3)) : NULL);
    state_assign_Delcode(aTHX_ state,string,delcode,scope);

SV *
lookupValue(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_value(aTHX_ state, string);
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
    state_assign_value(aTHX_ state, string, value, scope);

int
isValueBound(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    int frame = ((items > 2) && SvOK(ST(2)) ? SvIV(ST(2)) : -1);
  CODE:
    RETVAL = state_isValueBound(aTHX_ state, string, frame);
  OUTPUT:
    RETVAL

SV *
valueInFrame(state,string,...)
    SV * state;
    UTF8 string;
  INIT:
    int frame = ((items > 2) && SvOK(ST(2)) ? SvIV(ST(2)) : 0);
  CODE:
    RETVAL = state_valueInFrame(aTHX_ state, string, frame);
  OUTPUT:
    RETVAL

void
lookupStackedValues(state,string)
    SV * state;
    UTF8 string;
  INIT:
    AV * av = state_boundValues_noinc(aTHX_ state, string);
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
    AV * av = state_valueAV_noinc(aTHX_ state, string);
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
    AV * av = state_valueAV_noinc(aTHX_ state, string);
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
    AV * av = state_valueAV_noinc(aTHX_ state, string);
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
    AV * av = state_valueAV_noinc(aTHX_ state, string);
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
    HV * hash = state_valueHV_noinc(aTHX_ state, string);
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
    HV * hash = state_valueHV_noinc(aTHX_ state, string);
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
    HV * hash = state_valueHV_noinc(aTHX_ state, string);
  PPCODE:
    hv_store(hash,key,-strlen(key),value,0);
    SvREFCNT_inc(value);

SV *
lookupStash(state,string)
    SV * state;
    UTF8 string;
  CODE:
    RETVAL = state_stash(aTHX_ state, string);
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
    state_assign_stash(aTHX_ state, string, value, scope);

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
globalFlag(state)
    SV * state;
  CODE:
   RETVAL = state_globalFlag(aTHX_ state); 
  OUTPUT:
    RETVAL

void
setGlobalFlag(state)
    SV * state;
  CODE:
   state_setGlobalFlag(aTHX_ state); 

int
longFlag(state)
    SV * state;
  CODE:
   RETVAL = state_longFlag(aTHX_ state); 
  OUTPUT:
    RETVAL

void
setLongFlag(state)
    SV * state;
  CODE:
   state_setLongFlag(aTHX_ state); 

int
outerFlag(state)
    SV * state;
  CODE:
   RETVAL = state_outerFlag(aTHX_ state); 
  OUTPUT:
    RETVAL

void
setOuterFlag(state)
    SV * state;
  CODE:
   state_setOuterFlag(aTHX_ state); 

int
protectedFlag(state)
    SV * state;
  CODE:
   RETVAL = state_protectedFlag(aTHX_ state); 
  OUTPUT:
    RETVAL

void
setProtectedFlag(state)
    SV * state;
  CODE:
   state_setProtectedFlag(aTHX_ state); 

void
clearFlags(state)
    SV * state;
  CODE:
   state_clearFlags(aTHX_ state); 

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
      LaTeXML_Core_Token t = SvToken(token);
      UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
      name = (name == NULL ? t->string : name);
      state_assign_meaning(aTHX_ state, name, meaning, scope); }

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
      LaTeXML_Core_Token t1 = SvToken(token1);
      UTF8 name1 = PRIMITIVE_NAME[t1->catcode]; /* getCSName */
      name1 = (name1 == NULL ? t1->string : name1);
      state_assign_meaning(aTHX_ state, name1, meaning, scope); }
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
    HV * hash = SvHash(definition);
    SV ** ptr = hv_fetchs(hash,"cs",0);
    if(! ptr){
      croak("Definition doesn't have a CS!"); }
    LaTeXML_Core_Token t = SvToken(*ptr);
    UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
    name = (name == NULL ? t->string : name);
    int nlen = strlen(name);
    char lock[nlen+8];
    strncpy(lock,name,nlen);
    strcpy(lock+nlen,":locked");
    SV * tmp;
    if ( state_booleval(aTHX_ state, lock)
         && ( ! (tmp = get_sv("LaTeXML::Core::State::UNLOCKED",0)) || !SvTRUE(tmp)) ) {
      /*fprintf(stderr,"Ignoring redefinition of %s\n",name);*/
      /*
       if (my $s = $self->getStomach->getGullet->getSource) {
         # report if the redefinition seems to come from document source
         if ((($s eq "Anonymous String") || ($s =~ /\.(tex|bib)$/))
           && ($s !~ /\.code\.tex$/)) {
           Info('ignore', $cs, $self->getStomach, "Ignoring redefinition of $cs"); }
           return; } */
    }
    else {
      state_assign_meaning(aTHX_ state, name, definition, scope); }

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
convertUnit(state,unit)
    SV * state;
    UTF8 unit;
  CODE:
    RETVAL = state_convertUnit(aTHX_ state, unit);
  OUTPUT:
    RETVAL

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
getCatcode(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->catcode;
  OUTPUT:
    RETVAL

UTF8
getString(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->string;
  OUTPUT:
    RETVAL

UTF8
toString(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = self->string;
  OUTPUT:
    RETVAL

int
getCharcode(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = (self->catcode == CC_CS ? 256 : (int) self->string [0]);
  OUTPUT:
    RETVAL

UTF8
getCSName(self)
    LaTeXML_Core_Token self
  INIT:
    UTF8 s = PRIMITIVE_NAME[self->catcode];
  CODE:
    RETVAL = (s == NULL ? self->string : s);
  OUTPUT:
    RETVAL 

int
isExecutable(self)
    LaTeXML_Core_Token self
  CODE:
    RETVAL = EXECUTABLE_CATCODE [self->catcode];
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
DESTROY(self)
    LaTeXML_Core_Token self
  CODE:
    token_DESTROY(aTHX_ self);

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
    LaTeXML_Core_Tokens tokens;
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
     DEBUG_Tokens( "done %d.\n", tokens->ntokens);
     RETVAL = newSV(0);
     sv_setref_pv(RETVAL, "LaTeXML::Core::Tokens", (void*)tokens);
    }
  OUTPUT:
    RETVAL

int
equals(a, b)
    SV * a
    SV * b
  CODE:
   if (SvOK(a) && sv_isa(a, "LaTeXML::Core::Tokens")
       && SvOK(b) && sv_isa(b, "LaTeXML::Core::Tokens")) {
     RETVAL = tokens_equals(aTHX_ SvTokens(a),SvTokens(b)); }
   else {
     RETVAL = 0; }
  OUTPUT:
    RETVAL

UTF8
toString(tokens)
    LaTeXML_Core_Tokens tokens;
  CODE:
    RETVAL = tokens_toString(aTHX_ tokens);
  OUTPUT: 
    RETVAL

void
unlist(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i;
  PPCODE:
    EXTEND(SP, self->ntokens);
    for(i = 0; i < self->ntokens; i++) {
      PUSHs(sv_2mortal(SvREFCNT_inc(self->tokens[i]))); }

void
revert(self)
    LaTeXML_Core_Tokens self
  INIT:                    /* same as unlist */
    int i;
  PPCODE:
    EXTEND(SP, self->ntokens);
    for(i = 0; i < self->ntokens; i++) {
      PUSHs(sv_2mortal(SvREFCNT_inc(self->tokens[i]))); }

int
isBalanced(self)
    LaTeXML_Core_Tokens self
  INIT:
    int i, level;
  CODE:
    level = 0;
    DEBUG_Tokens("\nChecking balance of %d tokens",self->ntokens);
    for (i = 0 ; i < self->ntokens ; i++) {
      LaTeXML_Core_Token t = SvToken(self->tokens[i]);
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

LaTeXML_Core_Tokens
substituteParameters(self,...)
    LaTeXML_Core_Tokens self
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
    RETVAL = tokens_substituteParameters(aTHX_ self, nargs, args);
    if(RETVAL == NULL){ croak("NULL from substituteParameters"); }
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
trim(self)
    LaTeXML_Core_Tokens self
  CODE:
    RETVAL = tokens_trim(aTHX_ self); 
  OUTPUT:
    RETVAL
  
void
DESTROY(self)
    LaTeXML_Core_Tokens self
  CODE:
    tokens_DESTROY(aTHX_ self);

 #/*======================================================================
 #   LaTeXML::Core::Tokenstack
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Tokenstack

SV *
new()
  INIT:
    LaTeXML_Core_Tokenstack stack;
  CODE:
    stack = tokenstack_new(aTHX);
    RETVAL = newSV(0);
    sv_setref_pv(RETVAL, "LaTeXML::Core::Tokenstack", (void*)stack);
  OUTPUT:
    RETVAL

void
push(stack,token)
    LaTeXML_Core_Tokenstack stack;
    SV * token;
  CODE:
    SV * sv = newSVsv(token);
    tokenstack_push(aTHX_ stack,sv); 
    SvREFCNT_dec(sv);

SV *
pop(stack)
    LaTeXML_Core_Tokenstack stack;
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
new_internal(class,source,short_source,content,saved_state,note_message)
      UTF8 class;
      UTF8 source;
      UTF8 short_source;
      UTF8 content;
      SV * saved_state;
      UTF8 note_message;
  INIT:
    LaTeXML_Core_Mouth mouth
      = mouth_new(aTHX_ source,short_source,content,saved_state,note_message); 
  CODE:
    RETVAL = newSV(0);
    sv_setref_pv(RETVAL, class, (void*)mouth);
  OUTPUT:
    RETVAL

void
DESTROY(self)
    LaTeXML_Core_Mouth self
  CODE:
    mouth_DESTROY(aTHX_ self);

void
finish_internal(mouth)
    LaTeXML_Core_Mouth mouth;
  INIT:
    LaTeXML_Core_Tokenstack pb = mouth->pushback;
  CODE:
    DEBUG_Mouth("Finished with Mouth for %s\n",mouth->source);
    mouth->lineno = 1;
    mouth->colno  = 0;
    mouth->nbytes = 0;
    mouth->ptr    = 0;
    while(pb->ntokens > 0){
      pb->ntokens--;
      SvREFCNT_dec(pb->tokens[pb->ntokens]); }

int
hasMoreInput(mouth)
    LaTeXML_Core_Mouth mouth
  CODE:
    DEBUG_Mouth("Mouth has %lu bytes\n", mouth->nbytes-mouth->ptr);
    RETVAL = (mouth->pushback->ntokens > 0) || (mouth->ptr < mouth->nbytes);
  OUTPUT:
    RETVAL

void
getPosition(mouth)
    LaTeXML_Core_Mouth mouth;
  PPCODE:
    EXTEND(SP, 2);
    mPUSHi((IV) mouth->lineno);
    mPUSHi((IV) mouth->colno);

SV *
getLocator(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:  
    RETVAL = mouth_getLocator(aTHX_ mouth);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

UTF8
getSource(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth->source;
    if(RETVAL == NULL){ croak("NULL from getSource"); }
  OUTPUT:
    RETVAL

UTF8
getShortSource(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->short_source;
    if(RETVAL == NULL){ croak("NULL from getShortSource"); }
  OUTPUT:
    RETVAL

UTF8
getNoteMessage(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    RETVAL = mouth->note_message;
    if(RETVAL == NULL){ croak("NULL from getNoteMessage"); }
 OUTPUT:
    RETVAL

SV *
getSavedState(mouth)
    LaTeXML_Core_Mouth mouth;    
  CODE:
    if(mouth->saved_state){
      RETVAL = SvREFCNT_inc(mouth->saved_state);
      RETVAL = mouth->saved_state; }
    else {
      RETVAL = &PL_sv_undef; }
     /*mouth->saved_state = NULL; */             /* use only ONCE! */
  OUTPUT:
    RETVAL

void
setInput(mouth,input)
    LaTeXML_Core_Mouth mouth;
    UTF8 input;
  CODE:
    mouth_setInput(aTHX_ mouth,input);

SV *
readToken(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth_readToken(aTHX_ mouth, state_global(aTHX));
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL


LaTeXML_Core_Tokens
readTokens(mouth,...)
    LaTeXML_Core_Mouth mouth;
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
    LaTeXML_Core_Mouth mouth;
  INIT:
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i));
      mouth_unreadToken(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

void
getPushback(mouth)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int i,n;
    LaTeXML_Core_Tokenstack pb;
  PPCODE:
    pb = mouth->pushback;
    n = pb->ntokens;
    EXTEND(SP, n);
    for(i = n-1; i >= 0; i--) {
      PUSHs(sv_2mortal(tokenstack_pop(aTHX_ pb))); }

int
atEOF(mouth)
    LaTeXML_Core_Mouth mouth;
  CODE:
    RETVAL = mouth->at_eof;
  OUTPUT:
    RETVAL

SV *
readRawLine(mouth,...)
    LaTeXML_Core_Mouth mouth;
  INIT:
    int noread = 0;
  CODE:
    if(items > 1){
      noread = SvIV(ST(1)); }
    /* Peculiar logic: 'noread' really means return the rest of current line,
       if we've alread read something from it */
    if(noread){
      if(mouth->colno > 0){
        STRLEN pstart = mouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        /*
        if(n==0){ fprintf(stderr,"KEEP RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(mouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"KEEP RAW: '%s'\n",buffer); }
              */
        RETVAL = newSVpvn_flags(mouth->chars+pstart,n, SVf_UTF8); }
      else {
        RETVAL = &PL_sv_undef; } }
    else {
      if(mouth->ptr >= mouth->nbytes){       /* out of input */
        /* mouth_fetchInput(aTHX_ mouth); }  */
        mouth->at_eof = 1; }
      if(mouth->ptr < mouth->nbytes) { /* If we have input now */
        STRLEN pstart = mouth->ptr;
        STRLEN n = mouth_readLine(aTHX_ mouth);
        /*
        if(n==0){ fprintf(stderr,"READ RAW: Empty line\n"); }
        else {
          char buffer[n+1];
          Copy(mouth->chars+pstart,buffer,n,char);
          buffer[n] = 0;
          fprintf(stderr,"READ RAW: '%s'\n",buffer); }
               */
        RETVAL = newSVpvn_flags(mouth->chars+pstart,n, SVf_UTF8); }
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
readToken(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readToken(aTHX_ gullet, state);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
unread(gullet,...)
    SV * gullet;
  INIT:
    LaTeXML_Core_Mouth mouth = gullet_getMouth(aTHX_ gullet);
    int i;
  CODE:
    for(i = items-1; i >= 1; i--){
      SV * sv = newSVsv(ST(i));
      mouth_unreadToken(aTHX_ mouth, sv);
      SvREFCNT_dec(sv); }

SV *
getLocator(gullet)
    SV * gullet;
  CODE:  
    RETVAL = gullet_getLocator(aTHX_ gullet);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
   /*else { sv_2mortal(RETVAL); }  WHY NOT????????*/
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

void
expandafter(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    gullet_expandafter(aTHX_ gullet, state);

LaTeXML_Core_Tokens
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

LaTeXML_Core_Tokens
readBalanced(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  CODE:
    gullet_readBalanced(aTHX_ gullet, state, tokens, 0);
    RETVAL = tokens;
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readXBalanced(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
  CODE:
    gullet_readBalanced(aTHX_ gullet, state, tokens, 1);
    RETVAL = tokens;
  OUTPUT:
    RETVAL
    
LaTeXML_Core_Tokens
readArg(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
readXArg(gullet)
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
  CODE:
    RETVAL = gullet_readXArg(aTHX_ gullet, state);
    if(RETVAL == NULL){ croak("NULL from readArg"); }
  OUTPUT:
    RETVAL

LaTeXML_Core_Tokens
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

    LaTeXML_Core_Tokens tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 0, nchoices, maxlength, type, choices, &match);
    U8 gimme = GIMME_V;
    if(gimme == G_VOID){}
    else if (gimme == G_SCALAR){
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv); }
    else {
      EXTEND(SP, 2);
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv);
      if(match < 0){
        PUSHs(&PL_sv_undef); }
      else {
        sv = sv_2mortal(SvREFCNT_inc(choices[match]));
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

    LaTeXML_Core_Tokens tokens =
      gullet_readUntilMatch(aTHX_ gullet, state, 1, nchoices, maxlength, type, choices, &match);
    U8 gimme = GIMME_V;
    if(gimme == G_VOID){}
    else if (gimme == G_SCALAR){
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv); }
    else {
      EXTEND(SP, 2);
      SV * sv = newSV(0);
      sv_setref_pv(sv, "LaTeXML::Core::Tokens", (void*)tokens);
      PUSHs(sv);
      if(match < 0){
        PUSHs(&PL_sv_undef); }
      else {
        sv = sv_2mortal(SvREFCNT_inc(choices[match]));
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
      int nargs = gullet_readArguments(aTHX_ gullet, npara, params, fordefn, values);
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
    HV * hash = newHV();
    int i;
  CODE:
    if((items-4) % 2){
      croak("Odd number of hash elements in Expandable->new"); }
    /* tokenize expansion ? */
    /* expansion = Tokens(expansion) if ref expansion Token ? */
    if(!SvOK(cs) || !sv_isa(cs, "LaTeXML::Core::Token")) {
      croak("Undefined cs!\n");}
    if(!SvOK(expansion)){
      expansion = NULL; }
    else if(sv_isa(expansion, "LaTeXML::Core::Token")) {
      LaTeXML_Core_Tokens tokens = tokens_new(aTHX_ 1);
      tokens_add_to(aTHX_ tokens,expansion,0);
      expansion = newSV(0);
      sv_setref_pv(expansion, "LaTeXML::Core::Tokens", (void*) tokens); }
      
    /* check expansion balanced */
    if(!SvOK(parameters)){ /* or empty? */
      parameters = NULL; }
    hv_store(hash, "cs",2, SvREFCNT_inc(cs),0);
    if(parameters){
      hv_store(hash,"parameters",10,SvREFCNT_inc(parameters),0); }
    if(expansion){
      hv_store(hash,"expansion",    9,SvREFCNT_inc(expansion),0); }
    SV * stomach = state_stomach(aTHX_ state);
    SV * gullet =  stomach_gullet(aTHX_ stomach);
    SV * locator = gullet_getLocator(aTHX_ gullet);
    SvREFCNT_dec(stomach); SvREFCNT_dec(gullet);
    hv_store(hash,"locator",      7,locator, 0);
    if(state_protectedFlag(aTHX_ state)){
      hv_store(hash,"isProtected", 11,newSViv(1),0); }
    hv_store(hash,"isExpandable",12,newSViv(1),0);
    for(i = 4; i < items; i+=2){
      SV * keysv = ST(i);
      SV * value = ST(i+1);
      if(SvOK(keysv) && SvOK(value)){
        STRLEN keylen;
        UTF8 key = SvPV(ST(i),keylen);
        hv_store(hash,key,keylen,SvREFCNT_inc(value),0); }}
    RETVAL = newRV_noinc((SV*)hash);
    sv_bless(RETVAL, gv_stashpv(class,0));
  OUTPUT:    
    RETVAL
    
void
invoke(self, token, gullet)
    SV * self;
    SV * token;
    SV * gullet;
  INIT:
    SV * state = state_global(aTHX);
    SV * result;
  PPCODE:
    PUTBACK;
    result = expandable_invoke(aTHX_ self, token, gullet, state);
    SPAGAIN;
    if(result){ 
      EXTEND(SP,1);
      PUSHs(sv_2mortal(result)); }

 #/*======================================================================
 #   LaTeXML::Core::Definition::Primitive
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Definition::Primitive

void
invoke(self, token, stomach)
    SV * self;
    SV * token;
    SV * stomach;
  INIT:
    SV * state = state_global(aTHX);
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
    int i;
  PPCODE:
    /* NOTE: Apparently if you're calling back to Perl, and Perl REallocates the stack
    you can get into trouble with invalid access, etc. The (Extra?!?) wrap of
    PUTBACK/SPAGAIN seems to handle that (even though the called functions use them already).
    See cryptic comments at https://github.com/Perl-XS/notes/issues/7 */
    PUTBACK;
    primitive_invoke(aTHX_ self, token, stomach, state, stack);
    SPAGAIN;
    if(stack->nboxes){
      EXTEND(SP,stack->nboxes);
      for(i = 0; i < stack->nboxes; i++){
        SvREFCNT_inc(stack->boxes[i]);
        PUSHs(sv_2mortal(stack->boxes[i])); } }
    boxstack_DESTROY(aTHX_ stack);

 #/*======================================================================
 #   LaTeXML::Core::Stomach
 #  ======================================================================*/
MODULE = LaTeXML  PACKAGE = LaTeXML::Core::Stomach

SV *
getLocator(stomach)
    SV * stomach;
  CODE:  
    RETVAL = stomach_getLocator(aTHX_ stomach);
    if(RETVAL == NULL){ RETVAL = &PL_sv_undef; }
  OUTPUT:
    RETVAL

void
invokeToken(stomach, token)
    SV * stomach;
    SV * token;
  INIT:
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
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
    LaTeXML_Core_Boxstack stack = boxstack_new(aTHX);
    SV * token;
  PPCODE:  
    PUTBACK;                    /* Apparently needed here, as well... (but why?) */
    stack->discard = 1;         /* NO need to accumulate! */
    while( (token = gullet_readXToken(aTHX_ gullet, state, 0,0)) ){
      LaTeXML_Core_Token t = SvToken(token);
      if(t->catcode != CC_SPACE){
        stomach_invokeToken(aTHX_ stomach, state_global(aTHX), token, stack);
      }
      SvREFCNT_dec(token); }
    SvREFCNT_dec(gullet);
    boxstack_DESTROY(aTHX_ stack);  /* DISCARD boxes! */
    SPAGAIN;
