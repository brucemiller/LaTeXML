# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Client-Server processing
#**********************************************************************
use FindBin;
use lib "$FindBin::Bin/lib";
use TestLaTeXML;

# For each test $name there should be $name.xml and $name.log
# (the latter from a previous `good' run of 
#  latexmlc {$triggers} $name
#).

latexml_tests('t/daemon/api');

#**********************************************************************
1;
