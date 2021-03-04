# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/complex",
  requires => {
     cleveref_minimal => 'cleveref.sty',
     si => 'siunitx.sty' });
