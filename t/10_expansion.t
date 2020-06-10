# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/expansion",
	      requires=>{meaning=>'t1enc.def',
                   ifthen=>'ifthen.sty',
                   textcase=>'textcase.sty',
                   etoolbox=>'etoolbox.sty',
                   texbook_ex_20_7=>'support for non-brace begin delimiters in \def'});
