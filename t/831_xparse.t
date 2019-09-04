# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;
use LaTeXML::Util::Pathname;

latexml_tests("t/xparse",
   texlive_min => 2018,
   requires => {xparse => ['expl3.sty','xparse.sty'] });
