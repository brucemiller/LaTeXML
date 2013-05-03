package TestDaemon;
use strict;
use base qw(Test::Builder Exporter);
use Test::More;
use FindBin;
use File::Copy;

our @EXPORT = (qw(daemon_tests daemon_ok),
	       @Test::More::EXPORT);

# Note that this is a singlet; the same Builder is shared.
our $Test=Test::Builder->new();

# Test the invocations of all *.spec files in the given directory (typically t/something)
# Skip any that have no corresponding *.xml and *.status files.

# When daemon_tests is run with 'make' as a second argument, it will generate tests, instead of
# testing against existing ones.

sub daemon_tests {
  my($directory,$mode)=@_;
  my $generate;
  $generate = 1 if ((defined $mode) && ($mode eq 'make'));

  if(!opendir(DIR,$directory)){
    # Can't read directory? Fail (assumed single) test.
    $Test->expected_tests(1+$Test->expected_tests);
    do_fail($directory,"Couldn't read directory $directory:$!"); }
  else {
    local $Test::Builder::Level =  $Test::Builder::Level+1;
    my @tests = map("$directory/$_", grep(s/\.spec$//, sort readdir(DIR)));
    closedir(DIR);
    $Test->expected_tests(3*scalar(@tests)+$Test->expected_tests) unless $generate;

    foreach my $test (@tests){
      if((-f "$test.xml" && -f "$test.status") || ($generate)) {
	daemon_ok($test,$directory,$generate); }
      else {
	$Test->skip("Missing $test.xml and/or $test.status"); }
    }
  }
}

sub daemon_ok {
  my($base,$dir,$generate)=@_;
  my $localname = $base;
  $localname =~ s/$dir\///;
  my $opts = read_options("$base.spec");
  push @$opts, ( ['destination', "$localname.test.xml"],
		['log', "/dev/null"],
		['timeout',5],
		['autoflush',1],
		['timestamp','0'],
		['nodefaultresources',''],
		['xsltparameter','LATEXML_VERSION:TEST'],
		['nocomments', ''] );

  my $invocation = "cd $dir; $FindBin::Bin/../blib/script/latexmlc ";
  my $timed = undef;
  foreach my $opt(@$opts) {
    if ($$opt[0] eq 'timeout') { # Ensure .opt timeout takes precedence
      if ($timed) { next; } else {$timed=1;}
    }
    $invocation.= "--".$$opt[0].(length($$opt[1]) ? ("='".$$opt[1]."' ") : (' '));
  }
  $invocation .= " 2>$localname.test.status; cd -";
  if (!$generate) {
    is(system($invocation),0,"Progress: processed $localname...\n");
    { local $Test::Builder::Level =  $Test::Builder::Level+1;
      is_filecontent("$base.test.xml","$base.xml",$base);
      is_filecontent("$base.test.status","$base.status",$base);
    }
    unlink "$base.test.xml" if -e "$base.test.xml";
    unlink "$base.test.status" if -e "$base.test.status";
  }
  else {
    print STDERR "$invocation\n";
    system($invocation);
    move("$base.test.xml","$base.xml") if -e "$base.test.xml";
    move("$base.test.status","$base.status") if -e "$base.test.status";
  }
}

sub read_options {
  my $opts = [];
  open (OPT,"<",shift);
  while (<OPT>) {
    next if /^#/;
    chomp;
    /(\S+)\s*=\s*(.*)/;
    my ($key,$value) = ($1,$2||'');
    $value =~ s/\s+$//;
    push @$opts, [$key, $value];
  }
  close OPT;
  $opts;
}

sub get_filecontent {
  my ($path,$name) = @_;
  my @lines;
  if (-e $path) {
    if(!open(IN,"<",$path)){
      do_fail($name,"Could not open $path"); }
    else {
      { local $\=undef; 
	@lines = <IN>; }
      close(IN);
    }
  } else {
    push @lines,'';
  }
  \@lines;
}

sub is_filecontent {
  my($path1,$path2,$name)=@_;
  my $content1 = get_filecontent($path1,$name);
  my $content2 = get_filecontent($path2,$name);
  { local $Test::Builder::Level =  $Test::Builder::Level+1;
    is_strings($content1,$content2,$name); }}


sub is_strings {
  my($strings1,$strings2,$name)=@_;
  my $max = $#$strings1 > $#$strings2 ? $#$strings1 : $#$strings2;
  my $ok = 1;
  for(my $i = 0; $i <= $max; $i++){
    my $string1 = $$strings1[$i];
    my $string2 = $$strings2[$i];
    if(defined $string1){
      chomp($string1); }
    else{
      $ok = 0; $string1 = ""; }
    if(defined $string2){
      chomp($string2); }
    else{
      $ok = 0; $string2 = ""; }
    if(!$ok || ($string1 ne $string2)){
      return do_fail($name,
		     "Difference at line ".($i+1)." for $name\n"
		     ."      got : '$string1'\n"
		     ." expected : '$string2'\n"); }}
  $Test->ok(1, $name); }


sub do_fail {
  my($name,$diag)=@_;
  { local $Test::Builder::Level =  $Test::Builder::Level+1;
    my $ok = $Test->ok(0,$name);
    $Test->diag($diag);
    return $ok; }}


# TODO: Reconsider what else we need to test, ideas below:

# Tier 1.3: Math setups with embedding variations

# Tier 1.5: 

# Tier 2: Preloads and preambles

# Tier 3: Autoflush and Timeouts

# Tier 4: Ports and local conversion

# Tier 5: Defaults and multi-job daemon processing


# 1. We need to test daemon in fragment mode with fragment tests, math mode with math tests and standard mode with standard tests. Essentially, this is all about having the right preambles.

# 2. We need to benchmark consecutive runs, to make sure the first run is slowest and the rest (3?5?) are not initializing.

# 2.1. Set a --autoflush to 2 , send 3 conversions and make sure the process pid's differ.

# 2.2. Make sure an infinite macro times out (set --timeout=3 for fast test)
# 2.3. Check if the server can be set up on all default ports.

# 3. Exhaustively test all possible option combinations - we need triples of option vector with a test case and XML result, or some sane setup of this nature.

# 4. Moreover, we should test the option logic by comparing input-output option hashes (again, exhaustively!)

# 5. We need to compare the final document, log and summary produced.

1;
