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
#include "object.h"
#include "tokens.h"
#include "boxstack.h"
#include "state.h"

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

SV *
state_global(pTHX){             /* WARNING: Can we pretend we don't need refcnt's here? */
  return get_sv("STATE",0); }

SV *
state_stomach(pTHX_ SV * state){
  SV * stomach = hash_get(aTHX_ SvHash(state), "stomach");
  if(! stomach){
    croak("internal:stomach State has no stomach!"); }
  return stomach; }

SV *
state_stomach_noerror(pTHX_ SV * state){
  SV * stomach = hash_get(aTHX_ SvHash(state), "stomach");
  return stomach; }

SV *
state_model(pTHX_ SV * state){
  SV * model = hash_get(aTHX_ SvHash(state), "model");
  return model; }

/*
  Two sets of structures, a set of "table"s and an undo stack,
  allow us to retrieve the currently bound value of a key within a given table,
  and allow us to manage the bindings of keys within groups (\bgroup,\egroup, etc).

  * A "table" maps keys to a list of "bound_values"; the first element is the current value.
  * The "undo_stack" is a stack of "undo_frames", one for each open group.
  * An "undo_frame" maps each table to an "undo_set"
  * Each "undo_set" maps keys, for a given table, to the number of bound values made
    within the given frame.  This is the number of values that must be popped from
    the "bound_values" when the given frame is closed.

  Although somewhat complex, it provides: constant-time lookups, non-global assignments
  and group begins.  Closing groups and global assignments require time proportional to
  the number of bound values within the frame.  
*/

SV *                            /* WARNING: No refcnt increment here!!! */
state_lookup_noinc(pTHX_ SV * state, UTF8 tablename, UTF8 string){
  HV * state_hash = SvHash(state);
  HV * table;
  AV * bound_values;
  SV ** ptr;
  SV * sv;
  if(! string){
    return NULL; }
  ptr  = hv_fetch(state_hash,tablename,strlen(tablename),0); /* $$state{$table} */
  if(! ptr){
    croak("State doesn't have a %s table!",tablename); }
  table = SvHash(*ptr);
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

/* AWKWARD! */
HV * state_valueTable_noinc(pTHX_ SV * state){
  return SvHash(hash_get_noinc(aTHX_ SvHash(state),"value")); }

HV * state_stashTable_noinc(pTHX_ SV * state){
  return SvHash(hash_get_noinc(aTHX_ SvHash(state),"stash")); }

HV * state_activeStashTable_noinc(pTHX_ SV * state){
  return SvHash(hash_get_noinc(aTHX_ SvHash(state),"stash_active")); }

SV *
state_lookup(pTHX_ SV * state, UTF8 tablename, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, tablename, string);
  return (sv ? SvREFCNT_inc(sv) : NULL); }

void
state_assign_internal(pTHX_ SV * state, UTF8 tablename, UTF8 key, SV * value, UTF8 scope){
  HV * state_hash;
  HV * table;
  AV * bound_values;
  AV * undo_stack;
  SV ** ptr;
  U32 tablenamelen = strlen(tablename);
  /* NOTE: Use NEGATIVE Length in hv_(store|fetch|..) for UTF8 keys!!!!!!!! */
  U32 keylen = strlen(key);
  /* if exists tracing....*/
  state_hash = SvHash(state);
  if(scope == NULL){
    scope = (state_globalFlag(aTHX_ state) ? "global" : "local"); }

  SvREFCNT_inc(value);          /* Eventually we'll store it... */
  DEBUG_State("START Assign internal in table %s, %s => %p; scope=%s\n",tablename, key, value, scope);

  if(! (ptr = hv_fetch(state_hash,tablename,tablenamelen,0)) ){
    croak("State doesn't have a %s table!",tablename); }
  /* Get the hash for the requested table */
  table = SvHash(*ptr);
  /* Get --- or create --- the list of bound values for key in this table */
  if( ( ptr = hv_fetch(table,key,-keylen,0) )){
    bound_values = SvArray(*ptr); }
  else {
    DEBUG_State("Assign internal: new stack for %s in table %s\n",key, tablename);
    bound_values = newAV();
    hv_store(table, key, -keylen, newRV_noinc((SV *) bound_values), 0); }
  /* Get the undo stack */
  if(! (ptr = hv_fetch(state_hash,"undo",4,0) )){
    croak("State doesn't have an undo stack!"); }
  undo_stack = SvArray(*ptr); /* $$state{undo}  */

  if(strcmp(scope,"global") == 0){
    SSize_t nframes = av_len(undo_stack) + 1;
    int iframe;
    HV * undo_frame = NULL;
    DEBUG_State("Assign internal global: checking %lu frames\n",nframes);
    for(iframe = 0; iframe < nframes; iframe++){
      if(! (ptr = av_fetch(undo_stack, iframe,0) )){
        croak("State's undo stack doesn't have a valid frame %d!", iframe); }
      undo_frame = SvHash(*ptr); /* $$state{undo}[$iframe]{$table} */
      DEBUG_State("Assign internal global: examining frame %d = %p\n",iframe, undo_frame);
      /* Remove bindings made in all frames down-to & including the next lower locked frame*/
      if( ( ptr = hv_fetch(undo_frame,tablename,tablenamelen,0) ) ){
        HV * undo_set = SvHash(*ptr);
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
        DEBUG_State("Assign internal global: no entry for table %s found in frame\n",tablename); }
      if((ptr = hv_fetch(undo_frame,"_FRAME_LOCK_",12,0)) && SvTRUE(*ptr)){
        /* whatever is left -- if anything -- should be bindings below the locked frame. */
        DEBUG_State("Assign internal global: locked frame at %d\n",iframe);
        break; } }            /* last if $$frame{_FRAME_LOCK_}; } */
    /* Note that there will only be one value in the stack, now */
    HV * undo_set;
    if( ( ptr = hv_fetch(undo_frame,tablename,tablenamelen,0)) ){
      undo_set = SvHash(*ptr); }
    else {
      undo_set = newHV();
      hv_store(undo_frame,tablename,tablenamelen, newRV_noinc( (SV *) undo_set), 0); }
    hv_store(undo_set, key, -keylen, newSViv(1), 0); /* $$frame{$table}{$key} = 1 */
    av_unshift(bound_values,1);
    av_store(bound_values,0,value); } /* unshift(@{ $$self{$table}{$key} }, $value); */

  else if (strcmp(scope, "local") == 0){
    HV * undo_frame;                 /* top undo frame */
    HV * undo_set;           /* $$state{undo}[0]{$table} */
    DEBUG_State("Assign internal local\n");
    if(! (ptr = av_fetch(undo_stack, 0 ,0) )){
      croak("State's undo stack doesn't have a valid frame for 0!"); }
    undo_frame = SvHash(*ptr);  /* $$state{undo}[0] */
    if( ( ptr = hv_fetch(undo_frame,tablename,tablenamelen,0)) ){
      undo_set = SvHash(*ptr); }
    else {
      undo_set = newHV();
      hv_store(undo_frame,tablename,tablenamelen, newRV_noinc((SV *) undo_set),0); }
    
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
    if(! (stash = (AV *) state_lookup_noinc(aTHX_ state, "stash", scope)) ){
      stash = newAV();
      state_assign_internal(aTHX_ state, "stash", scope, newRV_noinc((SV *) stash), "global"); }
    AV * entry = newAV();
    av_extend(entry,3);
    av_store(entry,0,newSVpv(tablename,tablenamelen));
    av_store(entry,1,newSVpv(key,keylen));
    av_store(entry,2,value);
    av_unshift(stash,1);
    av_store(stash,0,newRV_noinc((SV *) entry)); /* push(@{ $$self{stash}{$scope}[0] }, [$table, $key, $value]); */
    if(state_lookup_noinc(aTHX_ state, "stash_active", scope)){
      state_assign_internal(aTHX_ state, tablename, key, value, "local"); } }
  DEBUG_State("DONE Assign internal in table %s, %s => %p; scope=%s\n",tablename, key, value, scope);
}

int
state_getFrameDepth(pTHX_ SV * state){
  AV * undo_stack = hash_getAV_noinc(aTHX_ SvHash(state), "undo");
  int i;
  int nframes = av_len(undo_stack)+1;
  int depth = 0;
  for(i = 0; i < nframes; i++){
    HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack, i);
    if(! hash_getBoole(aTHX_ undo_frame,"_FRAME_LOCK_")){
      depth ++; } }
  return depth; }
  
int
state_isFrameLocked(pTHX_ SV * state){
  AV * undo_stack = hash_getAV_noinc(aTHX_ SvHash(state), "undo");
  HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack, 0);
  return hash_getBoole(aTHX_ undo_frame,"_FRAME_LOCK_"); }

void
state_setFrameLock(pTHX_ SV * state, int lock){
  AV * undo_stack = hash_getAV_noinc(aTHX_ SvHash(state), "undo");
  HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack, 0);
  hash_put_noinc(aTHX_ undo_frame, "_FRAME_LOCK_", (lock ? newSViv(1) : NULL)); }

void
state_pushFrame(pTHX_ SV * state){
  AV * undo_stack = hash_getAV_noinc(aTHX_ SvHash(state), "undo");
  HV * undo_frame = newHV();
  av_unshift(undo_stack, 1);
  av_store(undo_stack, 0, newRV_noinc((SV *)undo_frame)); }

void
state_popFrame(pTHX_ SV * state){
  SV * sv;
  HV * state_hash = SvHash(state);
  AV * undo_stack = hash_getAV_noinc(aTHX_ state_hash, "undo");
  /* remove the first undo frame */
  SV * undo_frame_sv = av_shift(undo_stack);
  HV * undo_frame = SvHash(undo_frame_sv);
  if(hash_getBoole(aTHX_ undo_frame, "_FRAME_LOCK_")){
    croak("unexpected:<endgroup> Attempt to pop past locked stack frame"); }
  hv_iterinit(undo_frame);
  I32 tablenamelen;
  UTF8 tablename;
  /* for each table(value,meaning,...) */
  while( (sv = hv_iternextsv(undo_frame, &tablename,&tablenamelen)) ){
    HV * undo_set = SvHash(sv);
    HV * table =  hash_getHV_noinc(aTHX_ state_hash, tablename);
    hv_iterinit(undo_set);
    /*I32 keylen;*/
    STRLEN keylen;
    UTF8 key;
    /* for each key that has been bound in this table for this frame */
    /*while( (sv = hv_iternextsv(undo_set, &key,&keylen)) ){*/
    HE * entry;
    while( (entry = hv_iternext(undo_set)) ){
      /*key = hv_iterkey(entry, &keylen);*/
      key = HePV(entry, keylen);
      sv = hv_iterval(undo_set, entry);
      /*int utf = HeUTF8(entry);
        fprintf(stderr,"Key %s %s utf8\n",key, (utf ? "IS":"IS NOT"));*/
      
      int n_undo = SvIV(sv);
      /* Some messup with unicode ??? */
      SV ** ptr;
      if( ! ((ptr = hv_fetch(table,key,-keylen,0)) && SvOK(*ptr)) ){
        /* NOTE: Mysteriously perl is retrieving the keys from the undo table
           in a different encoding than we need to look them up in the regular table.
           we need to get them back into utf8!?!?!? */
        /*fprintf(stderr,"RECHECK table entry %s{%s}\n",tablename,key);*/
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
        fprintf(stderr,"Missing table entry %s{%s}\n",tablename,key); } }
  } }

void
state_activateScope(pTHX_ SV * state, UTF8 scope){
  HV * state_hash = SvHash(state);
  SV * isactive = state_lookup_noinc(aTHX_ state, "stash_active", scope);
  if(! isactive || !SvTRUE(isactive)){ /* This stash not yet activated */
    state_assign_internal(aTHX_ state, "stash_active", scope, newSViv(1), "local");
    /* Get the undo stack */
    AV * undo_stack = hash_getAV_noinc(aTHX_ state_hash, "undo");
    HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack,0);                 /* top undo frame */
    /*AV * defns = state_valueAV_noinc(aTHX_ state, "stash", scope);*/
    /*AV * defns = SvArray(state_lookup_noinc(aTHX_ state, "stash", scope));*/
    SV * defns_sv = state_lookup_noinc(aTHX_ state, "stash", scope);
    AV * defns = (defns_sv ? SvArray(defns_sv) : NULL);
    int ndefns = (defns ? av_len(defns)+1 : 0);
    int i;
    for(i = 0; i < ndefns; i++){
      AV * triple = array_getAV_noinc(aTHX_ defns,i);
      UTF8 tablename = array_getPV(aTHX_ triple,0);
      UTF8 key       = array_getPV(aTHX_ triple,1);
      SV * value     = array_get(aTHX_ triple,2);
      HV * table = hash_getHV(aTHX_ state_hash,tablename);
      /* Get --- or create --- the list of bound values for key in this table */
      AV * bound_values = hash_getAV_noinc_create(aTHX_ table,key);
      HV * undo_set = hash_getHV_noinc_create(aTHX_ undo_frame,tablename);
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
  HV * state_hash = SvHash(state);
  SV * isactive = state_lookup_noinc(aTHX_ state, "stash_active", scope);
  if(isactive  && SvTRUE(isactive)){ /* This stash not yet activated */
    state_assign_internal(aTHX_ state, "stash_active", scope, newSViv(0), "local");
    /* Get the undo stack */
    AV * undo_stack = hash_getAV_noinc(aTHX_ state_hash, "undo");
    HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack,0);                 /* top undo frame */
    /*AV * defns = state_valueAV_noinc(aTHX_ state, "stash", scope);*/
    /*AV * defns = SvArray(state_lookup_noinc(aTHX_ state, "stash", scope));*/
    SV * defns_sv = state_lookup_noinc(aTHX_ state, "stash", scope);
    AV * defns = (defns_sv ? SvArray(defns_sv) : NULL);
    int ndefns = (defns ? av_len(defns)+1 : 0);
    int i;
    for(i = 0; i < ndefns; i++){
      AV * triple = array_getAV_noinc(aTHX_ defns,i);
      UTF8 tablename = array_getPV(aTHX_ triple,0);
      UTF8 key       = array_getPV(aTHX_ triple,1);
      SV * value     = array_get_noinc(aTHX_ triple,2);
      HV * table = hash_getHV_noinc(aTHX_ state_hash,tablename);
      /* Get --- or create --- the list of bound values for key in this table */
      AV * bound_values = hash_getAV_create(aTHX_ table,key);
      HV * undo_set = hash_getHV_noinc_create(aTHX_ undo_frame,tablename);
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
        fprintf(stderr,"internal:stash Unassigning wrong value for %s from table %s in deactivateScope\n",
                key,tablename); }
    } } }

SV *
state_value(pTHX_ SV * state, UTF8 string){
  return state_lookup(aTHX_ state, "value", string); }

void
state_assign_value(pTHX_ SV * state, UTF8 string, SV * value, UTF8 scope){
  state_assign_internal(aTHX_ state, "value", string, value, scope); }

SV *
state_stash(pTHX_ SV * state, UTF8 string){
  return state_lookup(aTHX_ state, "stash", string); }

void
state_assign_stash(pTHX_ SV * state, UTF8 string, SV * value, UTF8 scope){
  state_assign_internal(aTHX_ state, "stash", string, value, scope); }

SV *
state_value_noinc(pTHX_ SV * state, UTF8 string){
  return state_lookup_noinc(aTHX_ state, "value", string); }

int
state_isValueBound(pTHX_ SV * state, UTF8 string, int frame){
  HV * state_hash = SvHash(state);
  if(frame >= 0){               /* bound within a specific frame? */
    AV * undo_stack = hash_getAV_noinc(aTHX_ state_hash,"undo");
    HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack, frame);
    HV * undo_set   = hash_getHV_noinc(aTHX_ undo_frame, "value");
    SV * value      = (undo_set ? hash_get_noinc(aTHX_ undo_set, string) : NULL);
    return value && SvOK(value); }
  else {                        /* frame = -1; bound in ANY frame */
    HV * table = hash_getHV_noinc(aTHX_ state_hash,"value");
    AV * bound_values = hash_getAV_noinc(aTHX_ table, string);
    return (bound_values ? av_len(bound_values) >= 0 : 0); }
  return 0; }

SV *
state_valueInFrame(pTHX_ SV * state, UTF8 string, int frame){
  HV * state_hash = SvHash (state);
  AV * undo_stack = hash_getAV_noinc(aTHX_ state_hash,"undo");
  int nframes = av_len(undo_stack)+1;
  if((frame < 0) || (frame >= nframes)){
    return NULL; }
  int i;
  /* Find how many bindings of string have been made down to the specified frame */
  int pos = 0;
  for(i = 0; i < frame; i++){
    HV * undo_frame = array_getHV_noinc(aTHX_ undo_stack,i);
    HV * undo_set   = hash_getHV_noinc(aTHX_ undo_frame,"value");
    if(undo_set){
      pos += hash_getIV(aTHX_ undo_set, string); } }
  /* Now fetch that value from the bound_values */
  HV * table = hash_getHV_noinc(aTHX_ state_hash,"value");
  AV * bound_values = hash_getAV_noinc(aTHX_ table, string);
  return (bound_values ? array_get(aTHX_ bound_values, pos) : NULL); }

AV *                            /* WARNING: No refcnt increment here!!! */
state_boundValues_noinc(pTHX_ SV * state, UTF8 string){
  HV * state_hash = SvHash(state);
  SV ** ptr;
  if(! string){
    return NULL; }
  HV * table = hash_getHV_noinc(aTHX_ state_hash, "value");
  ptr  = hv_fetch(table,string,-strlen(string),0); /* $$state{$table}{$key}; neg. length=>UTF8*/
  if( ! ptr){
    return NULL; }
  return SvArray(*ptr); }

int
state_intval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);
  return (sv ? SvIV(sv) : 0); }

int
state_booleval(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);
  return (sv ? SvTRUE(sv) : 0); }

AV *                            /* internal */
state_valueAV_noinc(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);  
  if(! sv){                     /* No value? create an AV */
    AV * array = newAV();
    sv = newRV_noinc((SV*)array);
    state_assign_internal(aTHX_ state,"value",string, sv,"global");
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
state_valueHV_noinc(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "value", string);  
  if(! sv){                     /* No value? create an AV */
    HV * hash = newHV();
    sv = newRV_noinc((SV*)hash);
    state_assign_internal(aTHX_ state,"value",string, sv,"global");
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

int
state_catcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "catcode", string);
  return (sv ? SvIV(sv) : CC_OTHER); }

void
state_assign_catcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "catcode", string, newSViv(value), scope); }

int
state_mathcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "mathcode", string);
  return (sv ? SvIV(sv) : 0); }

void
state_assign_mathcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "mathcode", string, newSViv(value), scope); }

int
state_SFcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "sfcode", string);
  return (sv ? SvIV(sv) : 0); }

void
state_assign_SFcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "sfcode", string, newSViv(value), scope); }

int
state_LCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "lccode", string);
  return (sv ? SvIV(sv) : 0); }

void
state_assign_LCcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "lccode", string, newSViv(value), scope); }

int
state_UCcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "uccode", string);
  return (sv ? SvIV(sv) : 0); }

void
state_assign_UCcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "uccode", string, newSViv(value), scope); }

int
state_Delcode(pTHX_ SV * state, UTF8 string){
  SV * sv = state_lookup_noinc(aTHX_ state, "delcode", string);
  return (sv ? SvIV(sv) : 0); }

void
state_assign_Delcode(pTHX_ SV * state, UTF8 string, int value, UTF8 scope){
  state_assign_internal(aTHX_ state, "delcode", string, newSViv(value), scope); }

void
state_beginSemiverbatim(pTHX_ SV * state, int nchars, char ** chars){
  state_pushFrame(aTHX_ state);
  state_assign_internal(aTHX_ state, "value","MODE", newSVpv("text",4), "local");
  state_assign_internal(aTHX_ state, "value","IN_MATH", newSViv(0), "local");
  SV * sv;
  SV * other = newSViv(CC_OTHER);
  int i;
  if( (sv = state_lookup_noinc(aTHX_ state, "value","SPECIALS")) ){
    AV * specials = SvArray(sv);
    int n = av_len(specials)+1;
    for(i = 0; i < n; i++){
      UTF8 string = array_getPV(aTHX_ specials, i);
      state_assign_internal(aTHX_ state, "catcode", string, other,"local"); } }
  for(i = 0; i < nchars; i++){
    state_assign_internal(aTHX_ state, "catcode", chars[i], other,"local"); }
  state_assign_internal(aTHX_ state, "mathcode", "'", newSViv(0x8000),"local");
  dSP; ENTER; SAVETMPS; PUSHMARK(SP);
  EXTEND(SP,1); PUSHs(state);  PUTBACK;
  call_method("setASCIIencoding",G_DISCARD);
  SPAGAIN; PUTBACK; FREETMPS; LEAVE;
}

void
state_endSemiverbatim(pTHX_ SV * state){
  state_popFrame(aTHX_ state); }

SV *
state_meaning_internal(pTHX_ SV * state, UTF8 name){
  return state_lookup_noinc(aTHX_ state, "meaning", name); }

SV *
state_meaning(pTHX_ SV * state, SV * token){
  if(token){
    LaTeXML_Core_Token t = SvToken(token);
    if(ACTIVE_OR_CS[t->catcode]){
      return state_lookup(aTHX_ state, "meaning", t->string); }
    SvREFCNT_inc(token);
    return token; }
  return NULL; }

extern void
state_assign_meaning(pTHX_ SV * state, UTF8 name, SV * meaning, UTF8 scope){
  state_assign_internal(aTHX_ state, "meaning", name, meaning, scope); }

int
state_globalFlag(pTHX_ SV * state){
  return hash_getBoole(aTHX_ SvHash(state), "global_flag"); }

void
state_setGlobalFlag(pTHX_ SV * state){
  hash_put(aTHX_ SvHash(state), "global_flag",newSViv(1)); }

int
state_longFlag(pTHX_ SV * state){
  return hash_getBoole(aTHX_ SvHash(state), "long_flag"); }

void
state_setLongFlag(pTHX_ SV * state){
  hash_put(aTHX_ SvHash(state), "long_flag",newSViv(1)); }

int
state_outerFlag(pTHX_ SV * state){
  return hash_getBoole(aTHX_ SvHash(state), "outer_flag"); }

void
state_setOuterFlag(pTHX_ SV * state){
  hash_put(aTHX_ SvHash(state), "outer_flag",newSViv(1)); }

int
state_protectedFlag(pTHX_ SV * state){
  return hash_getBoole(aTHX_ SvHash(state), "protected_flag"); }

void
state_setProtectedFlag(pTHX_ SV * state){
  hash_put(aTHX_ SvHash(state), "protected_flag",newSViv(1)); }

void
state_clearFlags(pTHX_ SV * state){
  HV * state_hash = SvHash(state);
  hash_put(aTHX_ state_hash, "global_flag",NULL);
  hash_put(aTHX_ state_hash, "long_flag",NULL);
  hash_put(aTHX_ state_hash, "outer_flag",NULL);
  hash_put(aTHX_ state_hash, "protected_flag",NULL); }

SV *
state_definition(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, "meaning", name))
     && !sv_isa(defn, "LaTeXML::Core::Token")){ /* not a simple token! */
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

SV *
state_expandable(pTHX_ SV * state, SV * token){
  if(! token){
    return NULL; }
  LaTeXML_Core_Token t = SvToken(token);
  int cc = t->catcode;
  char * name = (ACTIVE_OR_CS [cc] ? t->string : EXECUTABLE_NAME[cc]);
  SV * defn;
  HV * defn_hash;
  if(name
     && (defn = state_lookup_noinc(aTHX_ state, "meaning", name))
     && SvROK(defn) && sv_derived_from(defn, "LaTeXML::Core::Definition")
     && (defn_hash = SvHash(defn))
     && hash_getBoole(aTHX_ defn_hash,"isExpandable")
     && ! hash_getBoole(aTHX_ defn_hash,"isProtected")){
    SvREFCNT_inc(defn);
    return defn; }
  else {
    return NULL; } }

SV *                            /* Ultimately, em, ex have to scale with current font!!! */
state_convertUnit(pTHX_ SV * state, UTF8 unit){
  HV * state_hash = SvHash(state);
  UTF8 p = unit;
  while(*p){ *p = tolower(*p); p++; }  /* lc(unit)!  Is this safe? in-place ? */
  SV * units_sv = hash_get_noinc(aTHX_ state_hash,"units");
  HV * units;
  if(units_sv){
    units = SvHash(units_sv); }
  else {                  /* Initialize units table */
    units = newHV();
    int i;
    for(i = 0; i < MAX_UNITS; i++){
      hv_store(units, UNIT_NAME[i],strlen(UNIT_NAME[i]), newSVnv(UNIT_VALUE[i]),0); }
    units_sv = newRV_noinc((SV*)units);
    hv_store(state_hash,"units",5,units_sv,0); }
  SV * value = hash_get(aTHX_ units,unit);
  if(value){
    return value; }
  else {
    warn("expected:<unit> Illegal unit of measure '%s', assumning pt.",unit);
    return newSVnv(SCALED_POINT); } }

void
state_noteStatus(pTHX_ SV * state, UTF8 type){
  HV * state_hash = SvHash(state);
  HV * status = hash_getHV_noinc_create(aTHX_ state_hash,"status");
  int n = hash_getIV(aTHX_ status,type);
  hash_put(aTHX_ status, type, newSViv(n+1)); }

void
state_noteSymbolStatus(pTHX_ SV * state, UTF8 type, UTF8 symbol){
  HV * state_hash = SvHash(state);
  HV * status = hash_getHV_noinc_create(aTHX_ state_hash,"status");
  HV * substatus = hash_getHV_noinc_create(aTHX_ status,type);
  int n = hash_getIV(aTHX_ substatus,symbol);
  hash_put(aTHX_ substatus, type, newSViv(n+1)); }

SV *
state_getStatus(pTHX_ SV * state, UTF8 type){
  HV * state_hash = SvHash(state);
  HV * status = hash_getHV_noinc_create(aTHX_ state_hash,"status");
  return hash_get(aTHX_ status,type); }
