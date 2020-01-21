# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/theorem",
	      requires=>{ntheorem=>'ntheorem.std'});

