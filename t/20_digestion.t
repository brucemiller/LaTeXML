# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/digestion",
  requires => { colorbox_sizes => { packages => 'tcolorbox.sty', texlive_min => 2024 } });

