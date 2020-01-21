# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/keyval", 
  requires=>{xkeyvalview=>'xkvview.sty'});