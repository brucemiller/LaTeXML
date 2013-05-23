# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
#use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestLaTeXML;

latexml_tests("t/babel",
	      requires=>{'*'=>['babel.sty','babel.def'],
			 numprints=>'numprint.sty',
			 german=>'germanb.ldf',
			 greek=>'greek.ldf',
			 french=>['frenchb.ldf','numprint.sty']});
