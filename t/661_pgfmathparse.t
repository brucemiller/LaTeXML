# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/pgfmathparse",
	requires=>{
		pgfmathparse=>{
			packages=>'pgf.sty'} });
