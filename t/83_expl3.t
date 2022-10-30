# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use strict;
use warnings;
use LaTeXML::Util::Test;

if (!$ENV{"CI"}) {
  plan skip_all => "Only checked in continuous integration. (set environment var CI=true and rerun tests)";
  done_testing();
  exit;
}

latexml_tests("t/expl3",
  requires => {
    tilde_tricks => {
      texlive_min => 2018,
      packages    => 'expl3.sty' },
    xparse => {
      texlive_min => 2019,
      packages    => ['expl3.sty', 'xparse.sty']
    } });
