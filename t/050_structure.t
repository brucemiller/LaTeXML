# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/structure",
  requires => {
    csquotes => 'csquotes.sty',
    glossary => 'glossaries.sty' });
