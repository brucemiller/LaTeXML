# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/babel",
	      requires=>{'*'=>['babel.sty','babel.def'],
		     csquotes=>['skipbecauseofoldtexliveintravis', 'csquotes.sty', 'frenchb.ldf', 'germanb.ldf'],
			 numprints=>'numprint.sty',
			 german=>'germanb.ldf',
			 greek=>['greek.ldf','lgrenc.def'],
			 french=>['frenchb.ldf','numprint.sty'],
                         page545=>['germanb.ldf','frenchb.ldf']});
