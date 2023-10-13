# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/complex",
  requires => {
    cleveref_minimal => 'cleveref.sty',
    si               => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2015 } });
