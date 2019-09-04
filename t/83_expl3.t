# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/expl3",
  requires => { tilde_tricks => 'expl3.sty', xparse => ['expl3.sty','xparse.sty'] });
