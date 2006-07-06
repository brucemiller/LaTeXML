# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use Test;
BEGIN { plan tests => 7; }

use LaTeXML;

# For each test $name there should be $name.tex and $name.xml
# (the latter from a previous `good' run of latexml $name).
# We transform $name.tex and compare the result to $name.xml

dotest('testchar');
dotest('testctr');
dotest('testexpand');
dotest('testif');
dotest('testover');
dotest('fonts');
dotest('xii');

#**********************************************************************
# Do the test
# Process the TeX file $texfile and compare the result to $xmlfile.

# Do I need to do some redirection, silencing, etc?
# What about turning off comments?
# A decent XML Diff utility would be nice...
sub dotest{
  my($name)=@_;

  $SIG{__DIE__} = \&LaTeXML::Error::Error;

  my $latexml= LaTeXML->new(preload=>[], searchpath=>[], includeComments=>0);
  return ok(0,1,"Couldn't instanciate LaTeXML") unless $latexml;

  my $dom = $latexml->convertFile("t/$name.tex");
  return ok(0,1,"Couldn't convert $name.tex") unless $dom;

  my @lines = split('\n',$dom->toString);

  open(IN,"<:utf8","t/$name.xml") || return ok(0,1,"Couldn't read $name.xml");
  my($n,$new,$old)=(0,undef,undef);
  do {
    $new=<IN>; chomp($new) if $new;
    $old=shift(@lines);
    $n++; } while($new && $old && ($new eq $old));
  close(IN);
  ok($new,$old,"Comparing xml at line $n for $name");
}

#**********************************************************************
1;
