/*# /=====================================================================\ #
  # |  LaTeXML/src/state.c                                                | #
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
#include "boxstack.h"
#include "parameters.h"
#include "expandable.h"
#include "primitive.h"

UTF8 UNIT_NAME[] =
  {"em","ex",
   "pt","pc",
   "in","bp",
   "cm","mm",
   "dd","cc","sp",
   "truept","truepc",
   "truein","truebp",
   "truecm", "truemm",
   "truedd","truecc","truesp",
   "mu"};
#define MAX_TEXT_UNITS 20
#define MAX_UNITS 21

double UNIT_VALUE[] =           /* in scaled points. */
  {655361., 282168., /* Apparent defaults; SHOULD reference current font! */
   1.*SCALED_POINT, 12.*SCALED_POINT,
   POINTS_PER_INCH*SCALED_POINT, POINTS_PER_INCH*SCALED_POINT/72.,
   POINTS_PER_INCH*SCALED_POINT/2.54, POINTS_PER_INCH*SCALED_POINT/2.54/10.,
   1238.*SCALED_POINT/1157., 12.*1238.*SCALED_POINT/1157., 1.,
   1.*SCALED_POINT, 12.*SCALED_POINT,
   POINTS_PER_INCH*SCALED_POINT, POINTS_PER_INCH*SCALED_POINT/72.,
   POINTS_PER_INCH*SCALED_POINT/2.54, POINTS_PER_INCH*SCALED_POINT/2.54/10.,
   1238.*SCALED_POINT/1157., 12.*1238.*SCALED_POINT/1157., 1.,
   1.*SCALED_POINT};            /* NOTE! Converts to Scaled Mu!! NOT Scaled Points */

#define STACK_INIT     100
#define STACK_QUANTUM  100

#define IFSTACK_INIT     20
#define IFSTACK_QUANTUM  20

SV *
state_new(pTHX_ SV * stomach, SV * model){
  LaTeXML_State xstate;
  int i;
  Newxz(xstate,1,T_State);
  for(i = 0; i < MAX_TABLES; i++){
    xstate->tables[i] = newHV(); }
  /* Initialize Stack */
  xstate->n_stack_alloc = STACK_INIT;
  Newxz(xstate->stack,xstate->n_stack_alloc,LaTeXML_Frame);
  Newxz(xstate->stack[0],1,T_Frame);
  xstate->stack_top = 0;
  /* Inintialize IfStack */
  xstate->n_ifstack_alloc = IFSTACK_INIT;
  Newxz(xstate->ifstack,xstate->n_ifstack_alloc,LaTeXML_IfFrame);
  Newxz(xstate->ifstack[0],1,T_IfFrame);
  xstate->ifstack_top = -1;
  xstate->processing = tokenstack_new(aTHX);
  /* Add base frame to stack !!! */
  xstate->stomach = (stomach ? SvREFCNT_inc(stomach) : NULL);
  xstate->model   = (model ? SvREFCNT_inc(model) : NULL);;
  xstate->status = newHV();
  xstate->units = newHV();
  for(i = 0; i < MAX_UNITS; i++){
    hv_store(xstate->units, UNIT_NAME[i],strlen(UNIT_NAME[i]), newSVnv(UNIT_VALUE[i]),0); }
  xstate->flags = 0;
  SV * state = newSV(0);
  sv_setref_pv(state, "LaTeXML::Core::State", (void*)xstate);
  return state; }

SV *
state_global(pTHX){             /* WARNING: Can we pretend we don't need refcnt's here? */
  SV * state = get_sv("STATE",0);
  return (SvOK(state) ? state : NULL); }

SV *
state_stomach(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  return (xstate->stomach ? SvREFCNT_inc(xstate->stomach) : NULL); }

SV *
state_model(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  return (xstate->model ? SvREFCNT_inc(xstate->model) : NULL); }

/*
  Two sets of structures, a set of "table"s and a stack,
  allow us to retrieve the currently bound value of a key within a given table,
  and allow us to manage the bindings of keys within groups (\bgroup,\egroup, etc).

  * A "table" maps keys to a list of "bound_values"; the first element is the current value.
  * The "stack" is a stack of "stack_frames", one for each open group.
  * An "stack_frame" maps each table to an "undo_set"
  * Each "undo_set" maps keys, for a given table, to the number of bound values made
    within the given frame.  This is the number of values that must be popped from
    the "bound_values" when the given frame is closed.

  Although somewhat complex, it provides: constant-time lookups, non-global assignments
  and group begins.  Closing groups and global assignments require time proportional to
  the number of bound values within the frame.  
*/

SV *                            /* WARNING: No refcnt increment here!!! */
state_lookup_noinc(pTHX_ SV * state, int tableid, UTF8 string){
  HV * table;
  AV * bound_values;
  SV ** ptr;
  SV * sv;
  if(! string){
    return NULL; }
  LaTeXML_State xstate = SvState(state);
  table = xstate->tables[tableid];
  ptr  = hv_fetch(table,string,-strlen(string),0); /* $$state{$table}{$key}; neg. length=>UTF8*/
  if( ! ptr){
    return NULL; }
  bound_values = SvArray(*ptr);
  ptr  = av_fetch(bound_values,0,0);/* $$state{catcode}{$key}[0] */
  if ( ! ptr){
    return NULL; }
  sv = *ptr;
  sv = (SvOK(sv) ? sv : NULL);
  return sv; }

int
state_catcode(pTHX_ SV * state, UTF8 string){
  HV * table;
  AV * bound_values;
  SV ** ptr;
  if(! string){
    return CC_OTHER; }
  LaTeXML_State xstate = SvState(state);
  table = xstate->tables[TBL_CATCODE];
  ptr  = hv_fetch(table,string,-strlen(string),0); /* $$state{$table}{$key}; neg. length=>UTF8*/
  if( ! ptr){
    return CC_OTHER; }
  bound_values = SvArray(*ptr);
  ptr  = av_fetch(bound_values,0,0);/* $$state{catcode}{$key}[0] */
  if ( ! ptr){
    return CC_OTHER; }
  return SvIV(*ptr); }

SV *
state_lookup(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);
  return (sv ? SvREFCNT_inc(sv) : NULL); }

UTF8
state_lookupPV(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);
  return (sv ? SvPV_nolen(sv) : NULL); }

int
state_lookupIV(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);
  return (sv ? SvIV(sv) : 0); }

int
state_lookupBoole(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);
  return (sv ? SvTRUE(sv) : 0); }

AV *                            /* internal */
state_lookupAV_noinc(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);  
  if(! sv){                     /* No value? create an AV */
    AV * array = newAV();
    sv = newRV_noinc((SV*)array);
    state_assign(aTHX_ state,tableid,string, sv,"global");
    return array; }
  else if(! SvROK(sv)){
    fprintf(stderr,"Expected a reference (to an array) for key %s, got %s",
            string, sv_reftype(sv,1));
    return NULL;  }
  else if (SvTYPE(SvRV(sv)) != SVt_PVAV){
    fprintf(stderr,"Expected a reference to an array for key %s, got %s",
            string,sv_reftype(SvRV(sv),1));
    return NULL; }
  else {
    return SvArray(sv); } }

HV *                            /* internal */
state_lookupHV_noinc(pTHX_ SV * state, int tableid, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tableid, string);  
  if(! sv){                     /* No value? create an AV */
    HV * hash = newHV();
    sv = newRV_noinc((SV*)hash);
    state_assign(aTHX_ state,tableid,string, sv,"global");
    return hash; }
  else if(! SvROK(sv)){
    fprintf(stderr,"Expected a reference (to an hash) for key %s, got %s",
            string, sv_reftype(sv,1));
    return NULL;  }
  else if (SvTYPE(SvRV(sv)) != SVt_PVHV){
    fprintf(stderr,"Expected a reference to an hash for key %s, got %s",
            string,sv_reftype(SvRV(sv),1));
    return NULL; }
  else {
    return SvHash(sv); } }

void
state_assign(pTHX_ SV * state, int tableid, UTF8 key, SV * value, UTF8 scope){
  LaTeXML_State xstate = SvState(state);
  HV * table = xstate->tables[tableid];
  AV * bound_values;
  SV ** ptr;
  /* NOTE: Use NEGATIVE Length in hv_(store|fetch|..) for UTF8 keys!!!!!!!! */
  U32 keylen = strlen(key);
  /* if exists tracing....*/
  if(scope == NULL){
    scope = (xstate->flags & FLAG_GLOBAL ? "global" : "local"); }

  /* Perl has a nasty habit of reusing SV's at times (scratchpads?)
     If we store non-reference SV's the contents (int, string,...) may CHANGE behind our backs!!!
     We're storing the SV *, so we need to copy or increment refcnt, as appropriate.*/
  if(! value)          {}
  else if(SvROK(value)){ SvREFCNT_inc(value); }
  else                 { value = newSVsv(value); } /* Copy! */
  DEBUG_State("START Assign internal in table %d, %s => %p; scope=%s\n",tableid, key, value, scope);
  /* Get --- or create --- the list of bound values for key in this table */
  if( ( ptr = hv_fetch(table,key,-keylen,0) )){
    bound_values = SvArray(*ptr); }
  else {
    DEBUG_State("Assign internal: new stack for %s in table %d\n",key, tableid);
    bound_values = newAV();
    hv_store(table, key, -keylen, newRV_noinc((SV *) bound_values), 0); }

  if(strcmp(scope,"global") == 0){
    int iframe;
    LaTeXML_Frame stack_frame = NULL;
    DEBUG_State("Assign internal global: checking %d frames\n",xstate->stack_top+1);
    for(iframe = xstate->stack_top; iframe >= 0; iframe--){
      stack_frame = xstate->stack[iframe];
      DEBUG_State("Assign internal global: examining frame %d = %p\n",iframe, stack_frame);
      /* Remove bindings made in all frames down-to & including the next lower locked frame*/
      HV * undo_set = stack_frame->tables[tableid];
      if(undo_set){
        DEBUG_State("Assign internal global: found frame table %p\n",undo_set);
        if( ( ptr = hv_fetch(undo_set,key,-keylen,0)) ){
          int nbindings = SvIV(*ptr);
          DEBUG_State("Assign internal global:  %d bindings in frame\n",nbindings);
          if(nbindings > 0){ /* Undo the bindings, if $key was bound in this frame */
            DEBUG_State("Assign internal global: clearing %d bindings\n",nbindings);
            int nb;
            for(nb = 0; nb < nbindings; nb++){
              /* SV * ignore = av_shift(bound_values); PERL_UNUSED_VAR(ignore);  */
              SvREFCNT_dec(av_shift(bound_values)); 
            }
            hv_delete(undo_set,key,-keylen,G_DISCARD); }
          else {
            DEBUG_State("Assign internal global: no bindings\n"); } }
        else {
          DEBUG_State("Assign internal global: no entry for key %s found in table frame\n",key); } }
      else {
        DEBUG_State("Assign internal global: no entry for table %d found in frame\n",tableid); }
      if(stack_frame->locked){
        /* whatever is left -- if anything -- should be bindings below the locked frame. */
        DEBUG_State("Assign internal global: locked frame at %d\n",iframe);
        break; } }            /* last if $$frame{_FRAME_LOCK_}; } */
    /* Note that there will only be one value in the stack, now */
    HV * undo_set = stack_frame->tables[tableid];
    if(! undo_set){
      undo_set = newHV();
      stack_frame->tables[tableid] = undo_set; }
    hv_store(undo_set, key, -keylen, newSViv(1), 0); /* $$frame{$table}{$key} = 1 */
    av_unshift(bound_values,1);
    av_store(bound_values,0,value); } /* unshift(@{ $$self{$table}{$key} }, $value); */

  else if (strcmp(scope, "local") == 0){
    DEBUG_State("Assign internal local\n");
    LaTeXML_Frame stack_frame = xstate->stack[xstate->stack_top];
    if(!stack_frame){
      croak("stack frame %d is not initialized!",xstate->stack_top); }
    HV * undo_set = stack_frame->tables[tableid];
    if(! undo_set){
      undo_set = newHV();
      stack_frame->tables[tableid] = undo_set; }
    if( ( ptr = hv_fetch(undo_set,key,-keylen,0) )){ /* If value previously assigned in this frame */
      /* Simply replace the value  */
      DEBUG_State("Assign internal local: replacing value\n");
      av_store(bound_values,0,value); }
    else {        /* Otherwise, push new value & set 1 to be undone */
      DEBUG_State("Assign internal local: pushing new value\n");
      hv_store(undo_set,key,-keylen, newSViv(1), 0); /* $$self{undo}[0]{$table}{$key} = 1; */
      av_unshift(bound_values,1);
      av_store(bound_values,0,value); } } /* unshift(@{ $$self{$table}{$key} }, $value); */
  else {
    /* croak("Storing under random scopes (%s) NOT YET IMPLEMENTED!",scope);*/
    AV * stash;
    if(! (stash = (AV *) state_lookup_noinc(aTHX_ state, TBL_STASH, scope)) ){
      stash = newAV();
      state_assign(aTHX_ state, TBL_STASH, scope, newRV_noinc((SV *) stash), "global"); }
    AV * entry = newAV();
    av_extend(entry,3);
    av_store(entry,0,newSViv(tableid));
    av_store(entry,1,newSVpv(key,keylen));
    av_store(entry,2,value);
    av_unshift(stash,1);
    av_store(stash,0,newRV_noinc((SV *) entry)); /* push(@{ $$self{stash}{$scope}[0] }, [$table, $key, $value]); */
    if(state_lookup_noinc(aTHX_ state, TBL_STASH_ACTIVE, scope)){
      state_assign(aTHX_ state, tableid, key, value, "local"); } }
  DEBUG_State("DONE Assign internal in table %d, %s => %p; scope=%s\n",tableid, key, value, scope);
}

int
state_getFrameDepth(pTHX_ SV * state){
  int i;
  int depth = 0;
  LaTeXML_State xstate = SvState(state);
  for(i = xstate->stack_top; i >= 0; i--){
    LaTeXML_Frame stack_frame = xstate->stack[i];
    if(! stack_frame->locked){
      depth ++; } }
  return depth; }
  
int
state_isFrameLocked(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  LaTeXML_Frame stack_frame = xstate->stack[xstate->stack_top];
  return stack_frame->locked; }

void
state_setFrameLock(pTHX_ SV * state, int lock){
  LaTeXML_State xstate = SvState(state);
  LaTeXML_Frame stack_frame = xstate->stack[xstate->stack_top];
  stack_frame->locked = (lock ? 1 : 0); }

void
state_pushFrame(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  /* Allocate a new frame, extending the stack if needed */
  if(xstate->stack_top+2 > xstate->n_stack_alloc){
    Renew(xstate->stack, xstate->n_stack_alloc + STACK_QUANTUM, LaTeXML_Frame);
    Zero(xstate->stack+xstate->n_stack_alloc,STACK_QUANTUM,LaTeXML_Frame);
    xstate->n_stack_alloc += STACK_QUANTUM; }
  ++xstate->stack_top;
  if(xstate->stack[xstate->stack_top] == NULL){
    Newxz(xstate->stack[xstate->stack_top], 1, T_Frame); }
  else {
    Zero(xstate->stack[xstate->stack_top],1,T_Frame); } } /* reuse, but clear */

void
state_popFrame(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  LaTeXML_Frame stack_frame  = xstate->stack[xstate->stack_top];
  if(stack_frame->locked){
    croak("unexpected:<endgroup> Attempt to pop past locked stack frame %d", xstate->stack_top); }
  int i;
  for(i = 0; i < MAX_TABLES; i++){
    HV * undo_set = stack_frame->tables[i];
    if(undo_set){               /* if we've bound anything in this table */
      HV * table = xstate->tables[i];
      hv_iterinit(undo_set);
      /*I32 keylen;*/
      /* for each key that has been bound in this table for this frame */
      HE * entry;
      while( (entry = hv_iternext(undo_set)) ){
        /*key = hv_iterkey(entry, &keylen);*/
        STRLEN keylen;
        UTF8 key = HePV(entry, keylen);
        SV * sv = hv_iterval(undo_set, entry);
        /*int utf = HeUTF8(entry);
          fprintf(stderr,"Key %s %s utf8\n",key, (utf ? "IS":"IS NOT"));*/
        int n_undo = SvIV(sv);
        /* Some messup with unicode ??? */
        SV ** ptr;
        if( ! ((ptr = hv_fetch(table,key,-keylen,0)) && SvOK(*ptr)) ){
          /* NOTE: Mysteriously perl is retrieving the keys from the undo table
             in a different encoding than we need to look them up in the regular table.
             we need to get them back into utf8!?!?!? */
          /*fprintf(stderr,"RECHECK table entry %s for table %d\n",key,i);*/
          STRLEN altkeylen = keylen;
          UTF8 altkey = (UTF8) bytes_to_utf8((U8 *)key,&altkeylen);
          ptr  = hv_fetch(table,altkey,-altkeylen,0); }
        /*if( (ptr = hv_fetch(table,key,keylen,0) || hv_fetch(table,key,-keylen,0))
          && SvOK(*ptr) ){*/
        if(ptr && SvOK(*ptr)){
          AV * undo = SvArray(*ptr);
          int i;
          for(i = 0; i < n_undo; i++){
            SV * ignore = av_shift(undo); PERL_UNUSED_VAR(ignore); } }
        else {
          fprintf(stderr,"Missing table entry %s for table %d\n",key,i); } }
      SvREFCNT_dec(undo_set);   /* Now can free */
      stack_frame->tables[i] = NULL; } }
  /* Don't remove the stack frame; we'll probably reuse it */
  xstate->stack_top--; }

LaTeXML_IfFrame
state_pushIfFrame(pTHX_ SV * state, SV * token, UTF8 loc){
  LaTeXML_State xstate = SvState(state);
  /* Allocate a new frame, extending the stack if needed */
  xstate->if_count++;
  if(xstate->ifstack_top+2 > xstate->n_ifstack_alloc){
    Renew(xstate->ifstack, xstate->n_ifstack_alloc + IFSTACK_QUANTUM, LaTeXML_IfFrame);
    Zero(xstate->ifstack+xstate->n_ifstack_alloc,IFSTACK_QUANTUM,LaTeXML_IfFrame);
    xstate->n_ifstack_alloc += IFSTACK_QUANTUM; }
  ++xstate->ifstack_top;
  if(xstate->ifstack[xstate->ifstack_top] == NULL){
    Newxz(xstate->ifstack[xstate->ifstack_top], 1, T_IfFrame); }
  else {
    Zero(xstate->ifstack[xstate->ifstack_top],1,T_IfFrame); }  /* reuse, but clear */
  LaTeXML_IfFrame ifframe = xstate->ifstack[xstate->ifstack_top];
  ifframe->ifid    = xstate->if_count;
  ifframe->token   = (token ? SvREFCNT_inc(token) : NULL);
  ifframe->start   = (loc ? string_copy(loc) : NULL);
  ifframe->parsing = 1;
  ifframe->elses   = 0;
  return ifframe; }

LaTeXML_IfFrame
state_popIfFrame(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  xstate->ifstack_top--;
  if(xstate->ifstack_top < 0){
    return NULL; }
  else {
    return xstate->ifstack[xstate->ifstack_top]; } }

void
state_activateScope(pTHX_ SV * state, UTF8 scope){
  LaTeXML_State xstate = SvState(state);
  SV * isactive = state_lookup_noinc(aTHX_ state, TBL_STASH_ACTIVE, scope);
  if(! isactive || !SvTRUE(isactive)){ /* This stash not yet activated */
    state_assign(aTHX_ state, TBL_STASH_ACTIVE, scope, newSViv(1), "local");
    /* Get the stack stack */
    LaTeXML_Frame stack_frame = xstate->stack[xstate->stack_top];
    SV * defns_sv = state_lookup_noinc(aTHX_ state, TBL_STASH, scope);
    AV * defns = (defns_sv ? SvArray(defns_sv) : NULL);
    int ndefns = (defns ? av_len(defns)+1 : 0);
    int i;
    for(i = 0; i < ndefns; i++){
      AV * triple = array_getAV_noinc(aTHX_ defns,i);
      int tableid = array_getIV(aTHX_ triple,0);
      UTF8 key    = array_getPV(aTHX_ triple,1);
      SV * value  = array_get(aTHX_ triple,2);
      if((tableid < 0) || (tableid >= MAX_TABLES)){
        croak("internal:table No table with id %d\n",tableid); }
      HV * table  = xstate->tables[tableid];
      /* Get --- or create --- the list of bound values for key in this table */
      AV * bound_values = hash_getAV_noinc_create(aTHX_ table,key);
      HV * undo_set = stack_frame->tables[tableid];
      /* For stashed values, we ALWAYS push the new value onto the bound_values,
         and increment the undo.  This is so that we can pop the value from stash
         in deactivateScope and recover the previously bound value, EVEN if it was
         made in the same binding group.
         Compare to the local case in assign_internal */
      int nundo = hash_getIV(aTHX_ undo_set,key);
      hv_store(undo_set,key,-strlen(key), newSViv(nundo+1), 0); /* $$self{undo}[0]{$table}{$key} = 1; */
      av_unshift(bound_values,1);
      av_store(bound_values,0,value);  } /* unshift(@{ $$self{$table}{$key} }, $value); */
  } }

void
state_deactivateScope(pTHX_ SV * state, UTF8 scope){
  LaTeXML_State xstate = SvState(state);
  SV * isactive = state_lookup_noinc(aTHX_ state, TBL_STASH_ACTIVE, scope);
  if(isactive  && SvTRUE(isactive)){ /* This stash not yet activated */
    state_assign(aTHX_ state, TBL_STASH_ACTIVE, scope, newSViv(0), "local");
    /* Get the undo stack */
    LaTeXML_Frame stack_frame = xstate->stack[xstate->stack_top];
    SV * defns_sv = state_lookup_noinc(aTHX_ state, TBL_STASH, scope);
    AV * defns = (defns_sv ? SvArray(defns_sv) : NULL);
    int ndefns = (defns ? av_len(defns)+1 : 0);
    int i;
    for(i = 0; i < ndefns; i++){
      AV * triple = array_getAV_noinc(aTHX_ defns,i);
      int tableid = array_getIV(aTHX_ triple,0);
      UTF8 key    = array_getPV(aTHX_ triple,1);
      SV * value  = array_get_noinc(aTHX_ triple,2);
      if((tableid < 0) || (tableid >= MAX_TABLES)){
        croak("internal:table No table with id %d\n",tableid); }
      HV * table  = xstate->tables[tableid];
      /* Get --- or create --- the list of bound values for key in this table */
      AV * bound_values = hash_getAV_create(aTHX_ table,key);
      HV * undo_set = stack_frame->tables[tableid];
      /* For stashed values, we ALWAYS push the new value onto the bound_values,
         and increment the undo.  This is so that we can pop the value from stash
         in deactivateScope and recover the previously bound value, EVEN if it was
         made in the same binding group.
         Compare to the local case in assign_internal */
      SV * oldvalue = array_get_noinc(aTHX_ bound_values, 0);
      if(value == oldvalue){
        int nundo = hash_getIV(aTHX_ undo_set,key);
        hv_store(undo_set,key,-strlen(key), newSViv(nundo-1), 0); /* $$self{undo}[0]{$table}{$key} = 1; */
        oldvalue =av_shift(bound_values);
        SvREFCNT_dec(oldvalue); }
      else {
        fprintf(stderr,"internal:stash Unassigning wrong value for %s from table %d in deactivateScope\n",
                key,tableid); }
    } } }

int
state_isBound(pTHX_ SV * state, int tableid, UTF8 string, int frame){
  LaTeXML_State xstate = SvState(state);
  if(frame >= 0){               /* bound within a specific frame? */
    int iframe = xstate->stack_top - frame; /* frame frames down from top */
    if((iframe < 0) || (iframe > xstate->stack_top)){
      return 0; }
    LaTeXML_Frame stack_frame = xstate->stack[iframe];
    HV * undo_set = stack_frame->tables[tableid];
    SV * value      = (undo_set ? hash_get_noinc(aTHX_ undo_set, string) : NULL);
    return value && SvOK(value); }
  else {                        /* frame = -1; bound in ANY frame */
    HV * table = xstate->tables[tableid];
    AV * bound_values = hash_getAV_noinc(aTHX_ table, string);
    return (bound_values ? av_len(bound_values) >= 0 : 0); }
  return 0; }

SV *
state_lookupInFrame(pTHX_ SV * state, int tableid, UTF8 string, int frame){
  LaTeXML_State xstate = SvState(state);
  int iframe = xstate->stack_top - frame; /* frame frames down from top */
  if((iframe < 0) || (iframe > xstate->stack_top)){
    return NULL; }
  int i;
  /* Find how many bindings of string have been made down to the specified frame */
  int pos = 0;
  for(i = xstate->stack_top; i >= 0; i--){
    LaTeXML_Frame stack_frame = xstate->stack[i];
    HV * undo_set = stack_frame->tables[tableid];
    if(undo_set){
      pos += hash_getIV(aTHX_ undo_set, string); } }
  /* Now fetch that value from the bound_values */
  HV * table = xstate->tables[tableid];
  AV * bound_values = hash_getAV_noinc(aTHX_ table, string);
  return (bound_values ? array_get(aTHX_ bound_values, pos) : NULL); }

AV *                            /* WARNING: No refcnt increment here!!! */
state_bindings_noinc(pTHX_ SV * state, int tableid, UTF8 string){
  LaTeXML_State xstate = SvState(state);
  if(! string){
    return NULL; }
  HV * table = xstate->tables[tableid];
  SV ** ptr = hv_fetch(table,string,-strlen(string),0);
  if( ! ptr){
    return NULL; }
  return SvArray(*ptr); }

void
state_startProcessing(pTHX_ SV * state, SV * token){
  /* Potential hook for tracing, profiling, ... ? */
  LaTeXML_State xstate = SvState(state);
  tokenstack_pushToken(aTHX_ xstate->processing, token); }

void
state_stopProcessing(pTHX_ SV * state, SV * token){
  /* Potential hook for tracing, profiling, ... ? */
  LaTeXML_State xstate = SvState(state);
  /* Probably should compare token? */
  tokenstack_pop(aTHX_ xstate->processing); }

void
state_beginSemiverbatim(pTHX_ SV * state, int nchars, char ** chars){
  state_pushFrame(aTHX_ state);
  state_assign(aTHX_ state, TBL_VALUE,"MODE", newSVpv("text",4), "local");
  state_assign(aTHX_ state, TBL_VALUE,"IN_MATH", newSViv(0), "local");
  SV * sv;
  SV * other = newSViv(CC_OTHER);
  int i;
  if( (sv = state_lookup_noinc(aTHX_ state, TBL_VALUE,"SPECIALS")) ){
    AV * specials = SvArray(sv);
    int n = av_len(specials)+1;
    for(i = 0; i < n; i++){
      UTF8 string = array_getPV(aTHX_ specials, i);
      state_assign(aTHX_ state, TBL_CATCODE, string, other,"local"); } }
  for(i = 0; i < nchars; i++){
    state_assign(aTHX_ state, TBL_CATCODE, chars[i], other,"local"); }
  state_assign(aTHX_ state, TBL_MATHCODE, "'", newSViv(0x8000),"local");
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1);
  PUSHs(state);  PUTBACK;
  call_method("setASCIIencoding",G_DISCARD);
  SPAGAIN; PUTBACK; FREETMPS; LEAVE;
}

void
state_endSemiverbatim(pTHX_ SV * state){
  state_popFrame(aTHX_ state); }

SV *
state_meaning(pTHX_ SV * state, SV * token){
  if(token){
    LaTeXML_Token t = SvToken(token);
    if(ACTIVE_OR_CS[t->catcode]){
      return state_lookup(aTHX_ state, TBL_MEANING, t->string); }
    SvREFCNT_inc(token);
    return token; }
  return NULL; }

int
state_Equals(pTHX_ SV * thing1, SV * thing2){
  if(thing1 == thing2){     /* if same, whatever it is (including NULL), match! */
    return 1; }
  else if((!thing1) || (!thing2)){ /* if either is NULL? fail */
    return 0; }
  else if (!sv_isobject(thing1) || !sv_isobject(thing2)){
    /* perhaps shouldn't happen, but we'll not do deep comparison of raw datastructures */
    return 0; }
  else {
    UTF8 type1 = (UTF8)sv_reftype(SvRV(thing1),1);
    UTF8 type2 = (UTF8)sv_reftype(SvRV(thing2),1);
    if(strcmp(type1,type2) != 0){ /* Not same type? fail */
      return 0; }
    else if(strcmp(type1,"LaTeXML::Core::Token")==0){
      return token_equals(aTHX_ thing1, thing2); }
    else if(strcmp(type1,"LaTeXML::Core::Tokens")==0){
      return tokens_equals(aTHX_ thing1, thing2); }
    else if(strcmp(type1,"LaTeXML::Core::Definition::Expandable")==0){
      return expandable_equals(aTHX_ thing1, thing2); }
    else if(strcmp(type1,"LaTeXML::Core::Definition::Primitive")==0){
      return primitive_equals(aTHX_ thing1, thing2); }
    else if(strcmp(type1,"LaTeXML::Core::Parameters")==0){
      AV * av1 = SvArray(thing1);
      AV * av2 = SvArray(thing2);
      int n1 = av_len(av1)+1;
      int n2 = av_len(av2)+1;
      if(n1 != n2){
        return 0; }
      else {
        int i;
        for(i = 0; i < n1; i++){
          if(! state_Equals(aTHX_ 
                            array_get_noinc(aTHX_ av1, i),
                            array_get_noinc(aTHX_ av2, i))){
            return 0; } }
        return 1; } }
    else if(strcmp(type1,"LaTeXML::Core::Parameter")==0){
      return parameter_equals(aTHX_ thing1, thing2); }
    else if(strcmp(type1,"LaTeXML::Core::Opcode")==0){
      return strcmp(SvPV_nolen(SvRV(thing1)),SvPV_nolen(SvRV(thing2))) == 0; }
    /* LaTeXML::Util::Transform */
    /* LaTeXML::Common::Font */
    /* LaTeXML::Core::Box */
    /* LaTeXML::Core::List */
    /* LaTeXML::Core::Whatsit */
    else {                      /* Fallback to method call */
      dSP; ENTER; SAVETMPS; PUSHMARK(SP);
      EXTEND(SP,2); PUSHs(thing1); PUSHs(thing2); PUTBACK;
      int nvals = call_method("equals",G_SCALAR);
      SPAGAIN;
      int result = (nvals > 0 ? SvTRUEx(POPs) : 0);
      PUTBACK; FREETMPS; LEAVE;
      return result; } }
  return 0; }

int
state_XEquals(pTHX_ SV * state, SV * token1, SV * token2){
  SV * meaning1 = state_meaning(aTHX_ state, token1);
  SV * meaning2 = state_meaning(aTHX_ state, token2);
  int boolean = state_Equals(aTHX_ meaning1,meaning2);
  if(meaning1){ SvREFCNT_dec(meaning1); }
  if(meaning2){ SvREFCNT_dec(meaning2); }
  return boolean; }


SV *
state_definition(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, TBL_MEANING, name))
     && !isa_Token(defn)){ /* not a simple token! */
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

void
state_installDefinition(pTHX_ SV * state, SV * definition, UTF8 scope){
  HV * hash = SvHash(definition);
  SV ** ptr = hv_fetchs(hash,"cs",0);
  if(! ptr){
    croak("Definition doesn't have a CS!"); }
  LaTeXML_Token t = SvToken(*ptr);
  UTF8 name = PRIMITIVE_NAME[t->catcode]; /* getCSName */
  name = (name == NULL ? t->string : name);
  int nlen = strlen(name);
  char lock[nlen+8];
  strncpy(lock,name,nlen);
  strcpy(lock+nlen,":locked");
  SV * tmp;
  if ( state_lookupBoole(aTHX_ state, TBL_VALUE, lock)
       && ( ! (tmp = get_sv("LaTeXML::Core::State::UNLOCKED",0)) || !SvTRUE(tmp)) ) {
    /*fprintf(stderr,"Ignoring redefinition of %s\n",name);*/
    /*
      if (my $s = $self->getStomach->getxgullet->getSource) {
      # report if the redefinition seems to come from document source
      if ((($s eq "Anonymous String") || ($s =~ /\.(tex|bib)$/))
      && ($s !~ /\.code\.tex$/)) {
      Info('ignore', $cs, $self->getStomach, "Ignoring redefinition of $cs"); }
      return; } */
  }
  else {
    state_assign(aTHX_ state, TBL_MEANING, name, definition, scope); }
}


SV *
state_expandable(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  HV * defn_hash;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, TBL_MEANING, name))
     && SvROK(defn) && isa_Expandable(defn)
     && (defn_hash = SvHash(defn))
     && ! hash_getBoole(aTHX_ defn_hash,"isProtected")){
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

SV *                            /* Ultimately, em, ex have to scale with current font!!! */
state_convertUnit(pTHX_ SV * state, UTF8 unit){
  LaTeXML_State xstate = SvState(state);
  UTF8 p = unit;
  while(*p){ *p = tolower(*p); p++; }  /* lc(unit)!  Is this safe? in-place ? */
  SV * value = hash_get(aTHX_ xstate->units,unit);
  if(value){
    return value; }
  else {
    warn("expected:<unit> Illegal unit of measure '%s', assumning pt.",unit);
    return newSVnv(SCALED_POINT); } }

void
state_clearStatus(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  SvREFCNT_dec(xstate->status);
  xstate->status = newHV(); }

void
state_noteStatus(pTHX_ SV * state, UTF8 type){
  LaTeXML_State xstate = SvState(state);
  HV * status = xstate->status;
  int n = hash_getIV(aTHX_ status,type);
  hash_put(aTHX_ status, type, newSViv(n+1)); }

void
state_noteSymbolStatus(pTHX_ SV * state, UTF8 type, UTF8 symbol){
  LaTeXML_State xstate = SvState(state);
  HV * substatus = hash_getHV_noinc_create(aTHX_ xstate->status,type);
  int n = hash_getIV(aTHX_ substatus,symbol);
  hash_put(aTHX_ substatus, type, newSViv(n+1)); }

SV *
state_getStatus(pTHX_ SV * state, UTF8 type){
  LaTeXML_State xstate = SvState(state);
  return hash_get(aTHX_ xstate->status,type); }

extern void
state_setProfiling(pTHX_ SV * state, int profiling){
  LaTeXML_State xstate = SvState(state);
  if(profiling){
    xstate->config |= CONFIG_PROFILING; }
  else {
    xstate->config &= ~CONFIG_PROFILING; } }

extern int
state_getProfiling(pTHX_ SV * state){
  LaTeXML_State xstate = SvState(state);
  return xstate->config & CONFIG_PROFILING; }

/* Not exactly the correct place for this ? */
/* These 2 deal with the tuples for registers: the definition + the arguments (if any) */
SV *
register_valueOf(pTHX_ SV * reg, SV * state, int nargs, SV ** args){
  SV * getter = hash_get(aTHX_ SvHash(reg), "getter");
  SV * value = hash_get(aTHX_ SvHash(reg), "value");
  int i;
  /* For chardef's .... Yuck!*/
  /*  if(value){
    return value; }
    else */
 if(! getter || !SvOK(getter)){
    LaTeXML_Token t = SvToken(hash_get(aTHX_ SvHash(reg), "cs"));
    croak("This thing is not a Register %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string); }
  else if(SvROK(getter) && SvTYPE(SvRV(getter)) == SVt_PVCV){ /* 'CODE' */
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,nargs);
    for(i=0; i<nargs; i++){
      SV * arg = (args[i] ? args[i] : &PL_sv_undef);
      PUSHs(arg); }
    PUTBACK;
    int nvals = call_sv(getter,G_SCALAR);
    SPAGAIN;
    /* Could return one of a variety of register types,
       how to check against what was expected? */
    if(nvals){ value = POPs; SvREFCNT_inc(value); }
    PUTBACK; FREETMPS; LEAVE; }
  else if (nargs > 0){
    croak("This Register %s cannot take %d args",SvPV_nolen(getter),nargs); }
  else if(SvPOK(getter)){
    value = state_lookup(aTHX_ state_global(aTHX), TBL_VALUE, SvPV_nolen(getter)); }
  else {
    LaTeXML_Token t = SvToken(hash_get(aTHX_ SvHash(reg), "cs"));
    /* Probably should just be a warn, return NULL */
    croak("This thing is not a Register %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string); }
  return value; }

void
register_setValue(pTHX_ SV * reg, SV * state, int nargs, SV ** args, SV * value){
  SV * setter = hash_get(aTHX_ SvHash(reg), "setter");
  int i;
  if(! setter || !SvOK(setter)){
    LaTeXML_Token t = SvToken(hash_get(aTHX_ SvHash(reg), "cs"));
    croak("This thing is not a Register %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string); }
  else if(SvROK(setter) && SvTYPE(SvRV(setter)) == SVt_PVCV){ /* 'CODE' */
    dSP; ENTER; SAVETMPS; PUSHMARK(SP);
    EXTEND(SP,nargs+1); PUSHs((value ? value : &PL_sv_undef));
    for(i=0; i<nargs; i++){
      SV * arg = (args[i] ? args[i] : &PL_sv_undef);
      PUSHs(arg); }
    PUTBACK;
    call_sv(setter,G_DISCARD);
    SPAGAIN; PUTBACK; FREETMPS; LEAVE; }
  else if (nargs > 0){
    croak("This Register %s cannot take %d args",SvPV_nolen(setter), nargs); }
  else if(SvPOK(setter)){
    state_assign(aTHX_ state_global(aTHX), TBL_VALUE, SvPV_nolen(setter), value, NULL); }
  else {
    LaTeXML_Token t = SvToken(hash_get(aTHX_ SvHash(reg), "cs"));
    /* Probably should just be a warn? */
    croak("This thing is not a Register %s[%s]\n",CC_SHORT_NAME[t->catcode],t->string); } }
