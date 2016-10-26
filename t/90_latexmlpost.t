# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Postprocessing
#**********************************************************************
use LaTeXML::Util::Test;

# For each test $name there should be $name.xml and $name-post.xml
# (the latter from a previous `good' run of 
#  latexmlpost --dest=$name-post.xml --keepXMath --pmml --noscan --nocrossref $name
#).

latexml_tests("t/post");
