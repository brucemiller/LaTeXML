# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/digestion",
  requires => { colorbox_sizes => { packages => 'tcolorbox.sty' } });

