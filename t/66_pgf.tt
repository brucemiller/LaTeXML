# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/pgf",
	requires=>{
		stress_pgfmath=>{
			env => 'CI', packages=>'tikz.sty'},
		stress_pgfplots=>{
			env => 'CI', packages=>'pgfplots.sty'} });
