package LaTeXML::Util::Test;
use strict;
use warnings;

use Test::More;
use LaTeXML::Util::Pathname;
use JSON::XS;
use FindBin;
use File::Copy;
use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = (qw(latexml_ok is_xmlcontent is_filecontent is_strings skip_all
    latexml_tests),
  @Test::More::EXPORT);
our $kpsewhich = $ENV{LATEXML_KPSEWHICH} || 'kpsewhich';

# Note that this is a singlet; the same Builder is shared.

# Test the conversion of all *.tex files in the given directory (typically t/something)
# Skip any that have no corresponding *.xml file.
sub latexml_tests {
  my ($directory, %options) = @_;

  if (!opendir(DIR, $directory)) {
    # Can't read directory? Fail (assumed single) test.
    do_fail($directory, "Couldn't read directory $directory:$!"); }
  else {
    my @dir_contents = sort readdir(DIR);
    my @core_tests   = grep(s/\.tex$//, @dir_contents);
    my @daemon_tests = grep(s/\.spec$//, @dir_contents);
    closedir(DIR);
    eval { use_ok("LaTeXML"); };    # || skip_all("Couldn't load LaTeXML"); }

  SKIP: {
      my $requires = $options{requires} || {};    # normally a hash: test=>[files...]
      if (!ref $requires) {                       # scalar== filename required by ALL
        check_requirements("$directory/", $requires);    # may SKIP:
        $requires = {}; }                                # but turn to normal, empty set
      elsif ($$requires{'*'}) {
        check_requirements("$directory/", $$requires{'*'}); }

      foreach my $name (@core_tests) {
        my $test = "$directory/$name";
      SKIP: {
          skip("No file $test.xml", 1) unless (-f "$test.xml");
          next unless check_requirements($test, $$requires{$name});
          latexml_ok("$test.tex", "$test.xml", $test); } }
      foreach my $name (@daemon_tests) {
        my $test = "$directory/$name";
      SKIP: {
          skip("No file $test.xml and/or $$test.status", 1)
            unless ((-f "$test.xml") && (-f "$test.status"));
          next unless check_requirements($test, $$requires{$name});
          daemon_ok($test, $directory, $options{generate});
        } } } }
  done_testing(); }

sub check_requirements {
  my ($test, $reqmts) = @_;
  foreach my $reqmt (!$reqmts ? () : (ref $reqmts ? @$reqmts : $reqmts)) {
    if (`$kpsewhich $reqmt`) { }
    else {
      skip("Missing requirement $reqmt for $test", 1);
      return 0; } }
  return 1; }

sub do_fail {
  my ($name, $diag) = @_;
  my $ok = ok(0, $name);
  diag($diag);
  return $ok; }

# Would like to evolve a sensible XML comparison.
# This is a start...

# NOTE: This assumes you will have successfully loaded LaTeXML.
sub latexml_ok {
  my ($texpath, $xmlpath, $name) = @_;
  my ($latexml, $dom, $domstring);
  my @paths = ($texpath =~ m|^(.+)/\w+\.tex$| ? ($1) : ());
  eval { $latexml = LaTeXML->new(preload => [], searchpaths => [], includeComments => 0,
      verbosity => -2); };
  return do_fail($name, "Couldn't instanciate LaTeXML: " . @!) unless $latexml;

  eval { $dom = $latexml->convertFile($texpath); };
  return do_fail($name, "Couldn't convert $texpath: " . @!) unless $dom;
  is_xmlcontent($latexml, $dom, $xmlpath, $name); }

sub is_xmlcontent {
  my ($latexml, $xmldom, $path, $name) = @_;
  my ($domstring);
  if (!defined $xmldom) {
    do_fail($name, "The XML DOM was undefined for $name"); }
  else {
###    eval { $domstring = $xmldom->toString(1); };
####    eval { $domstring = $xmldom->toStringC14N(0); };
    # We want the DOM to be BOTH indented AND canonical!!
    eval { my $string = $xmldom->toString(1);
      my $parser = XML::LibXML->new();
      $parser->validation(0);
      $parser->keep_blanks(1);
      $domstring = $parser->parse_string($string)->toStringC14N(0); };
    return do_fail($name, "Couldn't convert dom to string: " . @!) unless $domstring;
    is_xmlfilecontent([split('\n', $domstring)], $path, $name); } }

sub is_filecontent {
  my ($strings, $path, $name) = @_;
  #  if(!open(IN,"<:utf8",$path)){
  if (!open(IN, "<", $path)) {
    do_fail($name, "Could not open $path"); }
  else {
    my @lines;
    { local $\ = undef;
      @lines = <IN>; }
    close(IN);
    is_strings($strings, [@lines], $name); } }

sub is_xmlfilecontent {
  my ($strings, $path, $name) = @_;
  my ($domstring);
  eval { my $parser = XML::LibXML->new();
    $parser->validation(0);
    $parser->keep_blanks(1);
    $domstring = $parser->parse_file($path)->toStringC14N(0); };
  return do_fail($name, "Could not open $path") unless $domstring;
  is_strings($strings, [split('\n', $domstring)], $name); }

sub is_strings {
  my ($strings1, $strings2, $name) = @_;
  my $max = $#$strings1 > $#$strings2 ? $#$strings1 : $#$strings2;
  my $ok = 1;
  for (my $i = 0 ; $i <= $max ; $i++) {
    my $string1 = $$strings1[$i];
    my $string2 = $$strings2[$i];
    if (defined $string1) {
      chomp($string1); }
    else {
      $ok = 0; $string1 = ""; }
    if (defined $string2) {
      chomp($string2); }
    else {
      $ok = 0; $string2 = ""; }
    if (!$ok || ($string1 ne $string2)) {
      return do_fail($name,
        "Difference at line " . ($i + 1) . " for $name\n"
          . "      got : '$string1'\n"
          . " expected : '$string2'\n"); } }
  ok(1, $name); }

sub daemon_ok {
  my ($base, $dir, $generate) = @_;
  my $localname = $base;
  $localname =~ s/$dir\///;
  my $opts = read_options("$base.spec");
  push @$opts, (['destination', "$localname.test.xml"],
    ['log',                "/dev/null"],
    ['timeout',            5],
    ['autoflush',          1],
    ['timestamp',          '0'],
    ['nodefaultresources', ''],
    ['xsltparameter',      'LATEXML_VERSION:TEST'],
    ['nocomments',         '']);

  my $invocation = "cd $dir; $FindBin::Bin/../blib/script/latexmlc ";
  my $timed      = undef;
  foreach my $opt (@$opts) {
    if ($$opt[0] eq 'timeout') {    # Ensure .opt timeout takes precedence
      if ($timed) { next; } else { $timed = 1; }
    }
    $invocation .= "--" . $$opt[0] . (length($$opt[1]) ? ("='" . $$opt[1] . "' ") : (' '));
  }
  $invocation .= " 2>$localname.test.status; cd -";
  if (!$generate) {
    is(system($invocation), 0, "Progress: processed $localname...\n");
    is_filecontent(get_filecontent("$base.test.xml"),    "$base.xml",    $base);
    is_filecontent(get_filecontent("$base.test.status"), "$base.status", $base);
    unlink "$base.test.xml"    if -e "$base.test.xml";
    unlink "$base.test.status" if -e "$base.test.status";
  }
  else {
    #TODO: Skip 3 tests
    print STDERR "$invocation\n";
    system($invocation);
    move("$base.test.xml",    "$base.xml")    if -e "$base.test.xml";
    move("$base.test.status", "$base.status") if -e "$base.test.status";
  }
}

sub read_options {
  my $opts = [];
  open(OPT, "<", shift);
  while (<OPT>) {
    next if /^#/;
    chomp;
    /(\S+)\s*=\s*(.*)/;
    my ($key, $value) = ($1, $2 || '');
    $value =~ s/\s+$//;
    push @$opts, [$key, $value];
  }
  close OPT;
  $opts;
}

sub get_filecontent {
  my ($path, $name) = @_;
  my @lines;
  if (-e $path) {
    if (!open(IN, "<", $path)) {
      do_fail($name, "Could not open $path"); }
    else {
      { local $\ = undef;
        @lines = <IN>; }
      close(IN);
    }
  }
  if (scalar(@lines)) {
    $lines[-1] =~ s/\s+$//;
  } else {
    push @lines, '';
  }
  \@lines;
}

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
