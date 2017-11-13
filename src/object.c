/*# /=====================================================================\ #
  # |  LaTeXML/src/object.c                                               | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ #  */

/*==================================3====================================
  Low-level support for various objects, hashs, arrays, strings */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "../ppport.h"
#include "object.h"

/* Simplified hash accessors; would be nice to macroize */
SV *
hash_get_noinc(pTHX_ HV * hash, UTF8 key){ /* No refcnt inc! */
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return *ptr; }
  else {
    return NULL; } }

SV *
hash_get(pTHX_ HV * hash, UTF8 key){
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    SvREFCNT_inc(*ptr);
    return *ptr; }
  else {
    return NULL; } }

UTF8
hash_getPV(pTHX_ HV * hash, UTF8 key){
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvPV_nolen(*ptr); }
  else {
    return NULL; } }

int
hash_getIV(pTHX_ HV * hash, UTF8 key){
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvIV(*ptr); }
  else {
    return 0; } }

int
hash_getBoole(pTHX_ HV * hash, UTF8 key){
  SV ** ptr;
  if( (ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr) ){
    return SvTRUE(*ptr); }
  else {
    return 0; } }

/* These probably need an option to create, return NULL or signal error
  (but too many versions, along with noinc!) */
AV *
hash_getAV_internal(pTHX_ HV * hash, UTF8 key, int refcnt, int create){
  SV ** ptr;
  if(! ((ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr))){
    if(create){
      AV * av = newAV();
      hv_store(hash,key,-strlen(key),newRV_noinc((SV*)av),0);
      return av; }
    return NULL; }
  else if(! SvROK(*ptr)){
    fprintf(stderr,"Expected a reference (to an array) for %s key %s, got %s",
            sv_reftype((SV*)hash,1), key, sv_reftype(*ptr,1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL;  }
  else if (SvTYPE(SvRV(*ptr)) != SVt_PVAV){
    fprintf(stderr,"Expected a reference to an array for %s key %s, got %s",
            sv_reftype((SV*)hash,1), key, sv_reftype(SvRV(*ptr),1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL; }
  else {
    AV * av = SvArray(*ptr);
    if(refcnt){ SvREFCNT_inc(av); }
    return av; } }

HV *
hash_getHV_internal(pTHX_ HV * hash, UTF8 key, int refcnt, int create){
  SV ** ptr;
  if(! ((ptr  = hv_fetch(hash,key,-strlen(key),0)) && *ptr && SvOK(*ptr))){
    if(create){
      HV * hv = newHV();
      hv_store(hash,key,-strlen(key),newRV_noinc((SV*)hv),0);
      return hv; }
    return NULL; }
  else if(! SvROK(*ptr)){
    fprintf(stderr,"Expected a reference (to a hash) for %s key %s, got %s",
            sv_reftype((SV*)hash,1), key, sv_reftype(*ptr,1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL;  }
  else if (SvTYPE(SvRV(*ptr)) != SVt_PVHV){
    fprintf(stderr,"Expected a reference to a hash for %s key %s, got %s",
            sv_reftype((SV*)hash,1), key, sv_reftype(SvRV(*ptr),1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL; }
  else {
    HV * hv = SvHash(*ptr);
    if(refcnt){ SvREFCNT_inc(hv); }
    return hv; } }

void
hash_put_noinc(pTHX_ HV * hash, UTF8 key, SV * value){
  if(value){
    hv_store(hash,key,-strlen(key),value, 0); }
  else {
    hv_delete(hash,key,-strlen(key),0); } }

void
hash_put(pTHX_ HV * hash, UTF8 key, SV * value){
  if(value){
    SvREFCNT_inc(value);
    hv_store(hash,key,-strlen(key),value, 0); }
  else {
    hv_delete(hash,key,-strlen(key),0); } }

/* Simplified array accessors */
SV *
array_get_noinc(pTHX_ AV * array, int i){ /* No refcnt inc! */
  SV ** ptr;
  if(i < 0){
    i = av_len(array)+1-i; }
  if( (ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr) ){
    return *ptr; }
  else {
    return NULL; } }

SV *
array_get(pTHX_ AV * array, int i){
  SV ** ptr;
  if( (ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr) ){
    SvREFCNT_inc(*ptr);
    return *ptr; }
  else {
    return NULL; } }

UTF8
array_getPV(pTHX_ AV * array, int i){
  SV ** ptr;
  if( (ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr) ){
    return SvPV_nolen(*ptr); }
  else {
    return NULL; } }

int
array_getIV(pTHX_ AV * array, int i){
  SV ** ptr;
  if( (ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr) ){
    return SvIV(*ptr); }
  else {
    return 0; } }

int
array_getBoole(pTHX_ AV * array, int i){
  SV ** ptr;
  if( (ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr) ){
    return SvTRUE(*ptr); }
  else {
    return 0; } }

AV *
array_getAV_internal(pTHX_ AV * array, int i, int refcnt, int create){
  SV ** ptr;
  if(! ((ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr))){
    if(create){
      AV * av = newAV();
      av_store(array,i,newRV_noinc((SV*)av)); /* make room? */
      return av; }
    return NULL; }
  else if(! SvROK(*ptr)){
    fprintf(stderr,"Expected a reference (to an array) in array %s at %d, got %s",
            sv_reftype((SV*)array,1), i, sv_reftype(*ptr,1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL;  }
  else if (SvTYPE(SvRV(*ptr)) != SVt_PVAV){
    fprintf(stderr,"Expected a reference to an array in array %s at %d, got %s",
            sv_reftype((SV*)array,1), i, sv_reftype(SvRV(*ptr),1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL; }
  else {
    AV * av = SvArray(*ptr);
    if(refcnt){ SvREFCNT_inc(av); }
    return av; } }

HV *
array_getHV_internal(pTHX_ AV * array, int i, int refcnt, int create){
  SV ** ptr;
  if(! ((ptr  = av_fetch(array,i,0)) && *ptr && SvOK(*ptr))){
    if(create){
      HV * hv = newHV();
      av_store(array,i,newRV_noinc((SV*)hv)); /* make room? */
      return hv; }
    return NULL; }
  else if(! SvROK(*ptr)){
    fprintf(stderr,"Expected a reference (to a hash) in array %s at %d, got %s",
            sv_reftype((SV*)array,1), i, sv_reftype(*ptr,1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL;  }
  else if (SvTYPE(SvRV(*ptr)) != SVt_PVHV){
    fprintf(stderr,"Expected a reference to a hash in array %s at %d, got %s",
            sv_reftype((SV*)array,1), i, sv_reftype(SvRV(*ptr),1));
    /*Perl_sv_dump(aTHX_ *ptr);*/
    return NULL; }
  else {
    HV * hv = SvHash(*ptr);
    if(refcnt){ SvREFCNT_inc(hv); }
    return hv; } }

void
array_put_noinc(pTHX_ AV * array, int i, SV * value){
  av_store(array,i,value); }

void
array_put(pTHX_ AV * array, int i, SV * value){
  if(value){
    SvREFCNT_inc(value);
    av_store(array,i,value); }
  else {
    av_store(array,i,newSV(0)); } } /* special case for undef? */

  /*======================================================================
    Some string utilities */
UTF8
string_copy(UTF8 string){
  int n = strlen(string);
  UTF8 newstring;
  Newx(newstring,(n + 1),char);
  CopyChar(string,newstring,n);
  return newstring; }

void
showstr(UTF8 op, UTF8 name, UTF8 string){
  fprintf(stderr,"%s %s: '%s'= ",op, name,string);
  int i=0;
  while(*(string+i)){
    fprintf(stderr,"%hhx",*(string+i)); i++; }
  fprintf(stderr,"\n"); }
