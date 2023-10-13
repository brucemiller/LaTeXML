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
      env => 'CI', # only run in continuous integration
      texlive_min => 2016,
      packages    => 'glossaries.sty' } });
