# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use strict;
use warnings;
use LaTeXML::Util::Test;

latexml_tests("t/expl3",
  requires => {
    tilde_tricks => {
      env => 'CI',
      texlive_min => 2018,
      packages    => 'expl3.sty' },
    xparse => {
      env => 'CI',
      texlive_min => 2019,
      packages    => ['expl3.sty', 'xparse.sty']
    } });
