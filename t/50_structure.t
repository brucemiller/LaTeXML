# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/structure",
  requires => {
    amsarticle => 'amsart.cls',
    csquotes   => 'csquotes.sty',
    glossary   => {
      texlive_min => 2016,
      CI_only => 1,
      packages    => 'glossaries.sty' } });
