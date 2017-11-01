/*# /=====================================================================\ #
  # |  LaTeXML/src/object.h                                               | #
  # |                                                                     | #
  # |=====================================================================| #
  # | Part of LaTeXML:                                                    | #
  # |  Public domain software, produced as part of work done by the       | #
  # |  United States Government & not subject to copyright in the US.     | #
  # |---------------------------------------------------------------------| #
  # | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
  # | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
  # \=========================================================ooo==U==ooo=/ # */

/*==================================3====================================
  Low-level support for various objects, hashs, arrays, strings */

#ifndef OBJECT_H
#define OBJECT_H

/* Performance penalty for all this cruft when the hash is used several times??? */

typedef char * UTF8;

#define SvHash(arg)       MUTABLE_HV(SvRV(arg))
#define SvArray(arg)      MUTABLE_AV(SvRV(arg))

#define CopyChar(src,dest,n) if(n==1){ *(dest)=*(src); } else { Copy(src,dest,n,char); } *((dest)+n)=0

extern SV *
hash_get_noinc(pTHX_ HV * hash, UTF8 key);

extern SV *
hash_get(pTHX_ HV * hash, UTF8 key);

extern UTF8
hash_getPV(pTHX_ HV * hash, UTF8 key);

extern int
hash_getIV(pTHX_ HV * hash, UTF8 key);

extern int
hash_getBoole(pTHX_ HV * hash, UTF8 key);

extern AV *
hash_getAV_internal(pTHX_ HV * hash, UTF8 key, int refcnt, int create);

#define hash_getAV(hash,key) hash_getAV_internal(hash,key,1,0)
#define hash_getAV_noinc(hash,key) hash_getAV_internal(hash,key,0,0)
#define hash_getAV_create(hash,key) hash_getAV_internal(hash,key,1,1)
#define hash_getAV_noinc_create(hash,key) hash_getAV_internal(hash,key,0,1)

extern HV *
hash_getHV_internal(pTHX_ HV * hash, UTF8 key, int refcnt, int create);

#define hash_getHV(hash,key) hash_getHV_internal(hash,key,1,0)
#define hash_getHV_noinc(hash,key) hash_getHV_internal(hash,key,0,0)
#define hash_getHV_create(hash,key) hash_getHV_internal(hash,key,1,1)
#define hash_getHV_noinc_create(hash,key) hash_getHV_internal(hash,key,0,1)

extern void
hash_put_noinc(pTHX_ HV * hash, UTF8 key, SV * value);

extern void
hash_put(pTHX_ HV * hash, UTF8 key, SV * value);

extern SV *
array_get_noinc(pTHX_ AV * array, int i);

extern SV *
array_get(pTHX_ AV * array, int i);

extern UTF8
array_getPV(pTHX_ AV * array, int i);

extern int
array_getIV(pTHX_ AV * array, int i);

extern AV *
array_getAV_internal(pTHX_ AV * array, int i, int refcnt, int create);

#define array_getAV(array,i) array_getAV_internal(array,i,1,0)
#define array_getAV_noinc(array,i) array_getAV_internal(array,i,0,0)
#define array_getAV_create(array,i) array_getAV_internal(array,i,1,1)
#define array_getAV_noinc_create(array,i) array_getAV_internal(array,i,0,1)

extern HV *
array_getHV_internal(pTHX_ AV * array, int i, int refcnt, int create);

#define array_getHV(array,i) array_getHV_internal(array,i,1,0)
#define array_getHV_noinc(array,i) array_getHV_internal(array,i,0,0)
#define array_getHV_create(array,i) array_getHV_internal(array,i,1,1)
#define array_getHV_noinc_create(array,i) array_getHV_internal(array,i,0,1)

extern int
array_getBoole(pTHX_ AV * array, int i);

extern void
array_put_noinc(pTHX_ AV * array, int i, SV * value);

extern void
array_put(pTHX_ AV * array, int i, SV * value);

  /*======================================================================
    Some string utilities */
extern UTF8
string_copy(UTF8 string);

extern void
showstr(UTF8 op, UTF8 name, UTF8 string);
#endif
