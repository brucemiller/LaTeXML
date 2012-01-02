# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Postprocessing
#**********************************************************************
use Test;
BEGIN { plan tests => 1; }

use LaTeXML::Post;
use LaTeXML::Post::MathML;
use LaTeXML::Post::XMath;

# For each test $name there should be $name.xml and $name-post.xml
# (the latter from a previous `good' run of 
#  latexmlpost --dest=$name-post.xml --pmml --noscan --nocrossref --keepXMath $name
#).

dotest('t/post/simplemath');

#**********************************************************************
# Do the test
# Process the TeX file $texfile and compare the result to $xmlfile.

# Do I need to do some redirection, silencing, etc?
# What about turning off comments?
# A decent XML Diff utility would be nice...
sub dotest{
  my($name)=@_;

  my $xmath = LaTeXML::Post::XMath->new(verbosity=>-1);
  $xmath->setParallel(LaTeXML::Post::MathML::Presentation->new(verbosity=>-1));
  my @procs = (	$xmath );

  return ok(0,1,"Couldn't instanciate LaTeXML::Post") unless @procs;

  my($doc) = LaTeXML::Post::ProcessChain(
               LaTeXML::Post::Document->newFromFile("$name.xml",validate=>1),
	       @procs);
  my $output = $doc->toString;

  return ok(0,1,"Couldn't process $name.xml") unless $doc;

  my @lines = split('\n',$output);

#  open(IN,"<:utf8","$name-post.xml") || return ok(0,1,"Couldn't read $name-post.xml");
  open(IN,"<","$name-post.xml") || return ok(0,1,"Couldn't read $name-post.xml");
  my($n,$new,$old)=(0,undef,undef);
  do {
    $old=<IN>; chomp($old) if $old;
    $new=shift(@lines);
    $n++; } while($new && $old && ($new eq $old));
  close(IN);
  ok($new,$old,"Comparing xml at line $n for $name");
}

#**********************************************************************
1;
