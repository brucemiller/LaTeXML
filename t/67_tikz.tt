# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

# With gratitude to TeXample - https://texample.net/
# for their large open gallery of Tikz diagrams,
# from which we have also adapted some suitable test snippets.

latexml_tests("t/tikz",
	requires=>{
		'*' => {
      env => 'CI',
		  packages => 'tikz.sty'}});
