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

extern int
number_formatScaled(pTHX_ char * buffer, int sp);

extern SV *
dimension_new(pTHX_ int sp);

extern SV *
glue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill);

extern SV *
glue_negate(pTHX_ SV * glue);

extern SV *
muglue_new(pTHX_ int sp, int plus, int plusfill, int minus, int minusfill);

extern SV *
muglue_negate(pTHX_ SV * muglue);

extern SV *
float_new(pTHX_ double num);     /* num presumbed to be SViv/SVnv scaled points */

#endif
