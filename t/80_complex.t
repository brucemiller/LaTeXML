# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/complex",
  requires => {
    cleveref_minimal => 'cleveref.sty',
    si => {
      packages => 'siunitx.sty',
      CI_only=>1,
      texlive_min => 2015
    } });
