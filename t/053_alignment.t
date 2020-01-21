# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/alignment",
  requires => {
    listing => 'listings.cfg',
    algx    => ['algorithm.sty', 'algpseudocode.sty'],
    cells   => 'makecell.sty' });
