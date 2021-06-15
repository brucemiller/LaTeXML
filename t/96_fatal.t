# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Fatal error recovery
#**********************************************************************
use strict;
use warnings;
use LaTeXML::Util::Test;
# For each test $name there should be $name.xml and $name.log
# (the latter from a previous `good' run of 
#  latexmlc {$triggers} $name
#).
latexml_tests('t/daemon/fatals');
#**********************************************************************
1;
