# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/pgf",
	requires=>{
		env => 'CI',
		stress_pgfmath=>'tikz.sty',
		stress_pgfplots=>'pgfplots.sty',
});
