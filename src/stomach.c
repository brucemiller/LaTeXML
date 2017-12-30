/*# /=====================================================================\ #
  # |  LaTeXML/src/stomach.c                                                | #
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

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "errors.h"
#include "object.h"
#include "tokens.h"
#include "tokenstack.h"
#include "state.h"
#include "mouth.h"
#include "gullet.h"
#include "boxstack.h"
#include "primitive.h"
#include "stomach.h"

SV *
stomach_new(pTHX){
  LaTeXML_Stomach xstomach;
  Newxz(xstomach, 1, T_Stomach);
  xstomach->gullet = gullet_new(aTHX);
  xstomach->boxing = newAV();
  xstomach->token_stack = newAV();
  SV * stomach = newSV(0);
  sv_setref_pv(stomach, "LaTeXML::Core::Stomach", (void*) xstomach);
  return stomach; }

SV *
stomach_textDefault(pTHX){
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(newSVpv("LaTeXML::Common::Font",21)); PUTBACK;
  int nvals = call_method("textDefault", G_SCALAR);
  SPAGAIN;
  SV * font = NULL;
  /* if(nvals){
     font = POPs; SvREFCNT_inc(font); }*/
  if((nvals > 0) && (font = POPs) && isa_Font(font)) {
    SvREFCNT_inc(font); }
  else {
    typecheck_fatal(font,"textDefault","",Font); }
  PUTBACK; FREETMPS; LEAVE;
  return font; }

SV *
stomach_mathDefault(pTHX){
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(newSVpv("LaTeXML::Common::Font",21)); PUTBACK;
  int nvals = call_method("mathDefault", G_SCALAR);
  SPAGAIN;
  SV * font = NULL;
  /*  if(nvals){
      font = POPs; SvREFCNT_inc(font); }*/
  if((nvals > 0) && (font = POPs) && isa_Font(font)) {
    SvREFCNT_inc(font); }
  else {
    typecheck_fatal(font,"mathDefault","",Font); }
  PUTBACK; FREETMPS; LEAVE;
  return font; }
  
void
stomach_initialize(pTHX_ SV * stomach, SV * state){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  av_clear(xstomach->boxing);
  av_clear(xstomach->token_stack);
  state_assign(aTHX_ state, TBL_VALUE, "MODE",              newSVpv("text",4),           "global");
  state_assign(aTHX_ state, TBL_VALUE, "IN_MATH",           newSViv(0),                  "global");
  state_assign(aTHX_ state, TBL_VALUE, "PRESERVE_NEWLINES", newSViv(1),                  "global");
  state_assign(aTHX_ state, TBL_VALUE, "afterGroup",        newRV_noinc((SV*)newAV()),   "global");
  state_assign(aTHX_ state, TBL_VALUE, "afterAssignment",   NULL,                        "global");
  state_assign(aTHX_ state, TBL_VALUE, "groupInitiator",    newSVpv("Initialization",14),"global");
  state_assign(aTHX_ state, TBL_VALUE, "font",              stomach_textDefault(aTHX),   "global");
  state_assign(aTHX_ state, TBL_VALUE, "mathfont",          stomach_mathDefault(aTHX),   "global");
}

/*
void
stomach_DESTROY(pTHX_ stomach){
}
*/

SV *
stomach_gullet(pTHX_ SV * stomach){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  SV * gullet = xstomach->gullet;
  if(! gullet){
    croak("internal:stomach Stomach has no Gullet!"); }
  SvREFCNT_inc(gullet);
  return gullet; }

AV *
stomach_getBoxingAV_noinc(pTHX_ SV * stomach){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  SvREFCNT_inc(xstomach->boxing);
  return xstomach->boxing; }

void
stomach_pushStackFrame(pTHX_ SV * stomach, SV * state, int nobox){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  SV * token = array_get(aTHX_ xstomach->token_stack, -1);
  state_pushFrame(aTHX_ state);
  state_assign(aTHX_ state, TBL_VALUE, "beforeAfterGroup", newRV_noinc((SV*)newAV()), "local");
  state_assign(aTHX_ state, TBL_VALUE, "afterGroup",       newRV_noinc((SV*)newAV()), "local");
  state_assign(aTHX_ state, TBL_VALUE, "afterAssignment",  NULL,                      "local");
  state_assign(aTHX_ state, TBL_VALUE, "groupNonBoxing",   (nobox ? newSViv(1):NULL), "local");
  state_assign(aTHX_ state, TBL_VALUE, "groupInitiator",   token,                     "local");
  state_assign(aTHX_ state, TBL_VALUE, "groupInitiatorLocator",
               stomach_getLocator(aTHX_ stomach),                                     "local");
  if(! nobox){
    SvREFCNT_inc(token);
    av_push(xstomach->boxing,token); }
}

void
stomach_popStackFrame(pTHX_ SV * stomach, SV * state, int nobox){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  AV * ba = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, "beforeAfterGroup");
  if(ba){    /* digest the tokens in ba, put into @LaTeXML::LIST */
    GV * list_gv = *(GV**)hv_fetch(gv_stashpv("LaTeXML",0),"LIST",4,1);
    AV * list = GvAV(list_gv);
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    int n = av_len(ba)+1;
    int i;
    for(i=0; i < n; i++){
      stomach_invokeToken(aTHX_ stomach, state, array_get(aTHX_ ba, i), stack); }
    for(i = 0; i < stack->nboxes; i++){
      SvREFCNT_inc(stack->boxes[i]); /* ? */
      av_push(list,stack->boxes[i]); }
    boxstack_DESTROY(aTHX_ stack); /* Should make this more reusable */
  }
  AV * after = state_lookupAV_noinc(aTHX_ state, TBL_VALUE, "afterGroup");
  state_popFrame(aTHX_ state);
  if(! nobox){
    av_pop(xstomach->boxing); }
  if(after){
    int n = av_len(after)+1;
    int i;
    for(i=n-1; i >= 0; i--){
      gullet_unread(aTHX_ xstomach->gullet, array_get(aTHX_ after,i)); } }
}  

void
stomach_egroup(pTHX_ SV * stomach, SV * state){
  if(state_isBound(aTHX_ state, TBL_VALUE, "MODE", 0)
     || state_lookupBoole(aTHX_ state, TBL_VALUE,"groupNonBoxing")){
    croak("unexpected:\\egroup attempt to close boxing group"); }
  stomach_popStackFrame(aTHX_ stomach, state, 0); }

void
stomach_endgroup(pTHX_ SV * stomach, SV * state){
  if(state_isBound(aTHX_ state, TBL_VALUE, "MODE", 0)
     || ! state_lookupBoole(aTHX_ state, TBL_VALUE,"groupNonBoxing")){
    croak("unexpected:\\endgroup attempt to close non-boxing group"); }
  stomach_popStackFrame(aTHX_ stomach, state, 1); }

SV *
stomach_getMergedMathFont(pTHX_ SV * stomach, SV * state, SV * curfont, UTF8 mode){
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,3); PUSHs(stomach); PUSHs(curfont); PUSHs(newSVpv(mode,strlen(mode))); PUTBACK;
  int nvals = call_method("getMergedMathFont",G_SCALAR);
  SPAGAIN;
  SV * font = NULL;
  /*  if(nvals){
      font = POPs; SvREFCNT_inc(font); } */
  if((nvals > 0) && (font = POPs) && isa_Font(font)) {
    SvREFCNT_inc(font); }
  else {
    typecheck_fatal(font,"getMergedMathFont","",Font); }
  PUTBACK; FREETMPS; LEAVE;
  return font; }

SV *
stomach_getMergedTextFont(pTHX_ SV * stomach, SV * state, SV * curfont){
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,2); PUSHs(stomach); PUSHs(curfont); PUTBACK;
  int nvals = call_method("getMergedTextFont",G_SCALAR);
  SPAGAIN;
  SV * font = NULL;
  /* if(nvals){
     font = POPs; SvREFCNT_inc(font); }*/
  if((nvals > 0) && (font = POPs) && isa_Font(font)) {
    SvREFCNT_inc(font); }
  else {
    typecheck_fatal(font,"getMergedTextFont","",Font); }
  PUTBACK; FREETMPS; LEAVE;
  return font; }

void
stomach_beginMode(pTHX_ SV * stomach, SV * state, UTF8 mode){
  stomach_pushStackFrame(aTHX_ stomach, state, 0);
  UTF8 oldmode = state_lookupPV(aTHX_ state, TBL_VALUE, "MODE");
  int ismath = strncmp(mode + strlen(mode)-4,"math",4) == 0;
  state_assign(aTHX_ state, TBL_VALUE, "MODE", newSVpv(mode,strlen(mode)), "local");
  state_assign(aTHX_ state, TBL_VALUE, "IN_MATH", newSViv(ismath),"local");
  SV * curfont = state_lookup(aTHX_ state,TBL_VALUE, "font");
  if(strcmp(mode,oldmode) == 0){
  }
  else if(ismath){
    state_assign(aTHX_ state, TBL_VALUE, "savedfont", curfont, "local");
    state_assign(aTHX_ state, TBL_VALUE, "font",
                 stomach_getMergedMathFont(aTHX_ stomach, state, curfont, mode), "local"); }
  else {
    state_assign(aTHX_ state, TBL_VALUE, "font",
                 stomach_getMergedTextFont(aTHX_ stomach, state, curfont), "local"); }
}

void
stomach_endMode(pTHX_ SV * stomach, SV * state, UTF8 mode){
  UTF8 oldmode = NULL;
  if(! state_isBound(aTHX_ state, TBL_VALUE, "MODE",0)
     || ((oldmode = state_lookupPV(aTHX_ state, TBL_VALUE, "MODE"))
         && (strcmp(mode,oldmode) != 0)) ){
    croak("unexpected: attempt to end mode %s but we're in %s",mode,oldmode); }
  stomach_popStackFrame(aTHX_ stomach, state, 0); }

void
stomach_defineUndefined(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack){
  /* $stomach->invokeToken_undefined($token) */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, token, state, stomach, "invokeToken_undefined", nargs, args); }

void
stomach_insertComment(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, token, state, stomach, "invokeToken_comment", nargs, args); }

void
stomach_insertBox(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack){
  /* part of $stomach->invokeToken_simple($token,$meahing); */
  SV * args[] = {token};
  int nargs = 1;
  boxstack_callmethod(aTHX_ stack, token, state, stomach, "invokeToken_insert", nargs, args); }

void                            /* NOTE: Really only for constructors */
stomach_invokeDefinition(pTHX_ SV * stomach, SV * state, SV * token, SV * defn, LaTeXML_Boxstack stack){
  SV * args[] = {token, defn};
  int nargs = 2;
  boxstack_callmethod(aTHX_ stack, token, state, stomach, "invokeToken_definition", nargs, args); }

int absorbable_cc[] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0};

int letter_or_other[] = {
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 1,
  1, 0, 0, 0,
  0, 0};

void
stomach_invokeToken(pTHX_ SV * stomach, SV * state, SV * token, LaTeXML_Boxstack stack){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  LaTeXML_State xstate = SvState(state);
  SvREFCNT_inc(token);
  av_push(xstomach->token_stack, token);
  /* if maxstack, fatal */
  
 REINVOKE:
  if(! token){
    return; }
  LaTeXML_Token t = SvToken(token);
  int cc = t->catcode;
  DEBUG_Stomach("Invoke token %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string);
  char * name =
    (ACTIVE_OR_CS [cc]
     || (letter_or_other[cc] && state_lookupBoole(aTHX_ state,TBL_VALUE, "IN_MATH")
         && (state_lookupIV(aTHX_ state, TBL_MATHCODE, t->string) == 0x8000))
     ? t->string
     : EXECUTABLE_NAME[cc]);
  SV * defn = NULL;
  SV * insert_token = NULL;    /* Common case, default */
  if(name && (defn = state_lookup_noinc(aTHX_ state,TBL_MEANING, name)) ){
    /* If \let to an executable token (typically $, {,}, etc), lookup IT's defn! */
    if(isa_Token(defn)){
      LaTeXML_Token let = SvToken(defn);
      char * letname;
      SV * letdefn;
      if( (letname = EXECUTABLE_NAME[let->catcode])
          && (letdefn = state_lookup_noinc(aTHX_ state, TBL_MEANING, letname)) ){
        if(isa_Token(letdefn)){ /* And if that's a token? */
          insert_token = letdefn; /*SvREFCNT_dec(defn);*/ defn = NULL; }
        else {
          defn = letdefn; } }
      else {
        insert_token = defn; defn = NULL; } } }
  else {
    insert_token = token; }
  if(insert_token){
    DEBUG_Stomach("Invoke token self-insert %s[%s]\n",
                  CC_SHORT_NAME[SvToken(insert_token)->catcode],SvToken(insert_token)->string); }
  else {
    DEBUG_Stomach("Invoke defn %p [%s]\n", defn, sv_reftype(SvRV(defn),1));
    /*Perl_sv_dump(aTHX_ defn);*/
  }
  HV * defn_hash = (defn ? SvHash(defn) : NULL);
  if (insert_token) {    /* Common case*/
    LaTeXML_Token it = SvToken(insert_token);
    int icc = it->catcode;
    if (icc == CC_CS) {
      DEBUG_Stomach("Invoking undefined\n");
      stomach_defineUndefined(aTHX_ stomach, state, insert_token, stack); }
    else if (icc == CC_COMMENT) {
      DEBUG_Stomach("Inserting comment\n");
      stomach_insertComment(aTHX_ stomach, state, insert_token, stack); }
    else if (absorbable_cc[icc]) {
      DEBUG_Stomach("Inserting box\n");
      stomach_insertBox(aTHX_ stomach, state, insert_token, stack); }
    else {
      croak("misdefined: The token %s[%s] => %s[%s] should never reach Stomach!",
            CC_SHORT_NAME[t->catcode],t->string,
            CC_SHORT_NAME[it->catcode],it->string); } }
  /* A math-active character will (typically) be a macro,
     but it isn't expanded in the gullet, but later when digesting, in math mode (? I think) */
  /*  else if (hash_getBoole(aTHX_ defn_hash,"isExpandable")){*/
  else if (isa_Expandable(defn)){
    SvREFCNT_inc(defn);
    SV * exp = expandable_invoke(aTHX_ defn, token, xstomach->gullet, state);
    DEBUG_Stomach("Invoking expandable\n");
    gullet_unread(aTHX_ xstomach->gullet, exp);
    token = gullet_readXToken(aTHX_ xstomach->gullet, state, 0, 0); /* replace token by it's expansion!!!*/
    av_pop(xstomach->token_stack);
    SvREFCNT_dec(defn);
    goto REINVOKE; }
  /*  elsif ($meaning->isaDefinition) { */   /* Otherwise, a normal primitive or constructor*/
  else if(isa_Primitive(defn)) {
    SvREFCNT_inc(defn);
    primitive_invoke(aTHX_ defn, token, stomach, state, stack);
    if(! hash_getBoole(aTHX_ defn_hash, "isPrefix")){
      xstate->flags = 0; }
    SvREFCNT_dec(defn);
  }
  else if(isa_Definition(defn)) {
    SvREFCNT_inc(defn);
    DEBUG_Stomach("Invoking Constructor\n");
    stomach_invokeDefinition(aTHX_ stomach, state, token, defn, stack);
    xstate->flags = 0;
    SvREFCNT_dec(defn); }
  else {
    croak("misdefined: The token %s[%s] => %p [%s] should never reach Stomach!",
          CC_SHORT_NAME[t->catcode],t->string, defn, sv_reftype(SvRV(defn),1)); }
  /*
  if ((scalar(@result) == 1) && (!defined $result[0])) {
  @result = (); }  */                                     /*Just paper over the obvious thing.*/
  /*
  Fatal('misdefined', $token, $self,
    "Execution yielded non boxes",
    "Returned " . join(',', map { "'" . Stringify($_) . "'" }
        grep { (!ref $_) || (!$_->isaBox) } @result))
        if grep { (!ref $_) || (!$_->isaBox) } @result; */
  /*pop(@{ $$self{token_stack} });*/
  /*return @result; */
  av_pop(xstomach->token_stack);
}

SV *
stomach_digest(pTHX_ SV * stomach, SV * state, SV * tokens){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  /* no warnings 'recursion' ... How ??? */
  LaTeXML_State xstate = SvState(state);
  if(! SvOK(tokens)){
    return NULL; }
  SvREFCNT_inc(tokens);
  SV * mouth = gullet_openMouth(aTHX_ xstomach->gullet, tokens, 1);
  xstate->flags = 0;
  int ismath = state_lookupBoole(aTHX_ state, TBL_VALUE,"IN_MATH");
  int init_depth = av_len(xstomach->boxing); /* Actually is -1, but we're just comparing */
  ENTER;                           /* local @LaTeXML::LIST = (); */
  GV * list_gv = *(GV**)hv_fetch(gv_stashpv("LaTeXML",0),"LIST",4,1);
  save_ary(list_gv);
  AV * list = GvAV(list_gv);
  av_clear(list);

  /* Should maybe evolve LaTeXML::LIST to BE the boxstack ? */
  SV * token;
  while( (token = gullet_readXToken(aTHX_ xstomach->gullet, state, 1,1)) ){
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    stomach_invokeToken(aTHX_ stomach, state, token, stack);
    int i;
    for(i = 0; i < stack->nboxes; i++){
      SvREFCNT_inc(stack->boxes[i]); /* ? */
      /*      typecheck_value(stack->boxes[i],TokenName(token),"digested",Box,List,Whatsit,KeyVals,Comment);*/
      typecheck_value(stack->boxes[i],TokenName(token),"digested",BoxLike);
      av_push(list,stack->boxes[i]); }
    boxstack_DESTROY(aTHX_ stack); /* Should make this more reusable */
    if( init_depth > av_len(xstomach->boxing)){ /* if we've closed the initial mode */
      break; } }
  /* Is this really supposed to be in effect? */
  if(0 && (init_depth < av_len(xstomach->boxing))){
    croak("internal:<EOF> we've fallen off the end somehow ?"); }
  gullet_closeThisMouth(aTHX_ xstomach->gullet, mouth);
  SvREFCNT_dec(mouth);
  
  /*boxes = make_list(@LaTeXML::LIST, mode = (ismath? "math" : "text"));*/
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,2); PUSHs(stomach); PUSHs(newSViv(ismath)); PUTBACK;
  int nvals = call_method("makeDigestedList",G_SCALAR);
  SPAGAIN;
  SV * boxes = NULL;
  if(nvals){
    boxes = POPs;
    SvREFCNT_inc(boxes); }
  PUTBACK; FREETMPS; LEAVE;
  LEAVE;
  return boxes; }

LaTeXML_Boxstack
stomach_digestNextBody(pTHX_ SV * stomach, SV * state, SV * terminal){
  LaTeXML_Stomach xstomach = SvStomach(stomach);
  /* no warnings 'recursion' ... How ??? */
  /*LaTeXML_State xstate = SvState(state);*/
  /*SV * startloc = gullet_getLocator(aTHX_ xstomach->gullet);*/
  int init_depth = av_len(xstomach->boxing); /* Actually is -1, but we're just comparing */
  ENTER;                           /* local @LaTeXML::LIST = (); */
  GV * list_gv = *(GV**)hv_fetch(gv_stashpv("LaTeXML",0),"LIST",4,1);
  save_ary(list_gv);
  AV * list = GvAV(list_gv);
  av_clear(list);

  /* Should maybe evolve LaTeXML::LIST to BE the boxstack ? */
  int i;
  SV * token;
  while( (token = gullet_readXToken(aTHX_ xstomach->gullet, state, 1,1)) ){
    LaTeXML_Boxstack stack = boxstack_new(aTHX);
    stomach_invokeToken(aTHX_ stomach, state, token, stack);
    for(i = 0; i < stack->nboxes; i++){
      SvREFCNT_inc(stack->boxes[i]); /* ? */
      av_push(list,stack->boxes[i]); }
    boxstack_DESTROY(aTHX_ stack); /* Should make this more reusable */
    if(terminal && (token_equals(aTHX_ token, terminal))){ /* Found end token? */
      break; }
    if( init_depth > av_len(xstomach->boxing)){ /* if we've closed the initial mode */
      break; } }
  if(terminal && !(token_equals(aTHX_ token, terminal))){
    /* Does this actuallly warrant a warning? */
    /* fprintf(stderr,"expected:terminal %s",SvToken(terminal)->string); */
  }

  /* push(@LaTeXML::LIST, Box()) unless $token;                      # Dummy `trailer' if none explicit
   */
  /* Returning @LaTeXML::LIST; use boxstack for now... */
  LaTeXML_Boxstack stack = boxstack_new(aTHX);
  int n = av_len(list)+1;
  for(i = 0; i < n; i++){
    boxstack_push(aTHX_ stack, *av_fetch(list,i,0)); }
  LEAVE;
  return stack; }

void                            /* Manually avoid method dispatch on beDigested */
stomach_digestThing(pTHX_ SV * stomach, SV * state, SV * thing, LaTeXML_Boxstack stack){
  if(!SvOK(thing)){}
  else if(isa_Token(thing) || isa_Tokens(thing)){
    SV * box = stomach_digest(aTHX_ stomach, state, thing);
    boxstack_push(aTHX_ stack, box);
    SvREFCNT_dec(box); }
  else if(sv_derived_from(thing,"LaTeXML::Common::Number")){ /* Do nothing */
    boxstack_push(aTHX_ stack, SvREFCNT_inc(thing)); }
  else {
    SV * args[] = {stomach};
    /* Passing token as NULL !?!?! Need to figure out what our context is! */
    boxstack_callmethod(aTHX_ stack, NULL, state, thing, "beDigested", 1, args); }
}

    
