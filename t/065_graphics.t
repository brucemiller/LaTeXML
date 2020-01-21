# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/graphics",
	      requires=>{colors=>'dvipsnam.def',
			 xcolors=>'dvipsnam.def'});
