/*# /=====================================================================\ #
  # |  LaTeXML/src/numbers.h                                              | #
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
  C-Level Numbers, Dimensions ... support
  Strictly speaking, Number should contain int (SViv); others contain SVnv (double) */

#ifndef NUMBERS_H
#define NUMBERS_H

extern SV *
number_new(pTHX_ int num);

extern int
number_value(pTHX_ SV * sv);

extern SV *
number_scale(pTHX_ SV * number, int scale);

extern SV *
number_divide(pTHX_ SV * number, int scale);

extern SV *
number_add(pTHX_ SV * number, SV * other);

extern int
number_formatScaled(pTHX_ char * buffer, int sp);

extern SV *
dimension_new(pTHX_ int sp);

extern SV *
dimension_scale(pTHX_ SV * dimension, int scale);

extern SV *
dimension_divide(pTHX_ SV * dimension, int scale);

extern SV *
dimension_add(pTHX_ SV * dimension, SV * other);

extern SV *
glue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill);

extern SV *
glue_scale(pTHX_ SV * glue, int scale);

extern SV *
glue_divide(pTHX_ SV * glue, int scale);

extern SV *
glue_add(pTHX_ SV * glue, SV * other);

extern SV *
muglue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill);

extern SV *
muglue_scale(pTHX_ SV * muglue, int scale);

extern SV *
muglue_divide(pTHX_ SV * muglue, int scale);

extern SV *
muglue_add(pTHX_ SV * muglue, SV * other);

extern SV *
float_new(pTHX_ double num);     /* num presumbed to be SViv/SVnv scaled points */

#endif
