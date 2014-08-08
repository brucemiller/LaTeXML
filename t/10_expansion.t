# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/expansion",
	      requires=>{meaning=>'t1enc.def',
                         ifthen=>'ifthen.sty'});

