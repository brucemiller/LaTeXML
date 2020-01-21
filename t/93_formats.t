# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Client-Server processing
#**********************************************************************
use LaTeXML::Util::Test;

# For each test $name there should be $name.xml and $name.log
# (the latter from a previous `good' run of
#  latexmlc {$triggers} $name
#).

latexml_tests('t/daemon/formats',
  requires => {
      citation => 'mode no longer supported',
      tei => 'alpha.bst',
      jats => 'alpha.bst',
      citationraw => 'alpha.bst' } );

#**********************************************************************
1;
