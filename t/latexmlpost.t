# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML Postprocessing
#**********************************************************************
use Test;
BEGIN { plan tests => 1; }

use LaTeXML::Post;
use LaTeXML::Post::MathML;

# For each test $name there should be $name.tex and $name.xml
# (the latter from a previous `good' run of latexml $name).
# We transform $name.tex and compare the result to $name.xml

dotest('simplemath');

#**********************************************************************
# Do the test
# Process the TeX file $texfile and compare the result to $xmlfile.

# Do I need to do some redirection, silencing, etc?
# What about turning off comments?
# A decent XML Diff utility would be nice...
sub dotest{
  my($name)=@_;

  my $POST = LaTeXML::Post->new();
  my $procs = [LaTeXML::Post::MathML::Presentation->new()];

  return ok(0,1,"Couldn't instanciate LaTeXML::Post") unless $POST;

  my $source = $POST->readDocument("t/$name.xml");
  my $doc = $POST->process($source,
			   format    => 'xml',
			   verbosity => -1,
			   processors=>$procs);
  $POST->adjust_latexml_doctype($doc,'MathML');
  my $output = $POST->toString($doc);

  return ok(0,1,"Couldn't process $name.xml") unless $doc;

  my @lines = split('\n',$output);

  open(IN,"<:utf8","t/$name-post.xml") || return ok(0,1,"Couldn't read $name-post.xml");
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
