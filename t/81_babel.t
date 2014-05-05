# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/babel",
	      requires=>{'*'=>['babel.sty','babel.def'],
			 numprints=>'numprint.sty',
			 german=>'germanb.ldf',
			 greek=>'greek.ldf',
			 french=>['frenchb.ldf','numprint.sty'],
                         page545=>['germanb.ldf','french.ldf']});
