# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use Test;
our @tests;
BEGIN { 
  @tests = ( qw( testchar testctr testexpand testif testover
		 fonts xii verb comment simplemath
		 scopemacro keyval ns));
plan tests => scalar(@tests); }

use LaTeXML;

# For each test $name there should be $name.tex and $name.xml
# (the latter from a previous `good' run of latexml $name).
# We transform $name.tex and compare the result to $name.xml

foreach my $test (@tests){
  dotest($test); }

#**********************************************************************
# Do the test
# Process the TeX file $texfile and compare the result to $xmlfile.

# Do I need to do some redirection, silencing, etc?
# What about turning off comments?
# A decent XML Diff utility would be nice...
sub dotest{
  my($name)=@_;

  my $latexml= LaTeXML->new(preload=>[], searchpath=>[], includeComments=>0,
			   verbosity=>-2);
  return ok(0,1,"Couldn't instanciate LaTeXML") unless $latexml;

  my $dom = $latexml->convertFile("t/$name.tex");
  return ok(0,1,"Couldn't convert $name.tex") unless $dom;

  my @lines = split('\n',$dom->toString(1));

  open(IN,"<:utf8","t/$name.xml") || return ok(0,1,"Couldn't read $name.xml");
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
