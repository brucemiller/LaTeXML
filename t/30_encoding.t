# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
#use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestLaTeXML;

# Note that this is a singlet; the same Builder is shared.
my $Test=Test::Builder->new();

# NOTE: We assume the name of each test is the same as the encoding,
# and that there is an appropriate encoding file somewhere in the texmf tree
# Either an input encoding, then there must be <test>.def
# Or a font encoding, then there must be a <test>enc.def
# If we find NEITHER, we'll skip the test!

my $directory='t/encoding';
my $kpsewhich = $ENV{LATEXML_KPSEWHICH} || 'kpsewhich';

# The following is the equivalent of:
# latexml_tests("t/encoding");
# but we skip any tests for which we can't find an encoding definition
if(!opendir(DIR,$directory)){
  # Can't read directory? Fail (assumed single) test.
  $Test->expected_tests(1+$Test->expected_tests);
  do_fail($directory,"Couldn't read directory $directory:$!"); }
else {
  local $Test::Builder::Level =  $Test::Builder::Level+1;
  my @tests = grep(s/\.tex$//, sort readdir(DIR));
  closedir(DIR);
  $Test->expected_tests(1+scalar(@tests)+$Test->expected_tests);
  eval { use_ok("LaTeXML"); }; # || skip_all("Couldn't load LaTeXML"); }

  foreach my $test (@tests){
    my $fontenc = $test.'enc.def';
    my $inputenc = $test.'.def';
    my $hasenc = `$kpsewhich $fontenc $inputenc`;
    chomp($hasenc);
    if(! -f "$directory/$test.xml"){
      $Test->skip("No file $directory/$test.xml"); }
    elsif(! $hasenc){
      $Test->skip("No encoding definition for $test"); }
    else {
      latexml_ok("$directory/$test.tex","$directory/$test.xml","$directory/$test"); }
  }}
