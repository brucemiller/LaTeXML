package LaTeXML::Util::Test;
use strict;
use warnings;

use Test::More;
use LaTeXML::Util::Pathname;
use JSON::XS;
use FindBin;
use File::Copy;
use File::Which;
use File::Spec::Functions;
use LaTeXML::Post;
use LaTeXML::Post::MathML::Presentation;
use LaTeXML::Post::XMath;
use Config;

use base qw(Exporter);
#  @Test::More::EXPORT);
our @EXPORT = (qw(&latexml_ok &latexml_tests),
  qw(&process_domstring &process_xmlfile &process_htmlfile &is_strings
    &convert_texfile_as_test &serialize_dom_as_test get_filecontent),
  @Test::More::EXPORT);
# Note that this is a singlet; the same Builder is shared.

# Test the conversion of all *.tex files in the given directory (typically t/something)
# Skip any that have no corresponding *.xml file.
sub latexml_tests {
  my ($directory, %options) = @_;
  my $DIR;
  if ($options{texlive_min} && (texlive_version() < $options{texlive_min})) {
    plan skip_all => "Requirement minimal texlive $options{texlive_min} not met.";
    return done_testing(); }
  if (!opendir($DIR, $directory)) {
    # Can't read directory? Fail (assumed single) test.
    return do_fail($directory, "Couldn't read directory $directory:$!"); }
  else {
    my @dir_contents = sort readdir($DIR);
    my $t;
    my @core_tests   = map { (($t = $_) =~ s/\.tex$//      ? ($t) : ()); } @dir_contents;
    my @post_tests   = map { (($t = $_) =~ s/-post\.xml$// ? ($t) : ()); } @dir_contents;
    my @daemon_tests = map { (($t = $_) =~ s/\.spec$//     ? ($t) : ()); } @dir_contents;
    closedir($DIR);
    # (try to) predict how many subtests there will be.
    # (this helps the report when the latexml crashes completely)
    plan tests => (1
        + scalar(@core_tests)
        + scalar(@post_tests)
        + 2 * scalar(@daemon_tests) - ($directory =~ /runtimes/ ? 1 : 0));    # !!
    if (eval { use_ok("LaTeXML::Core"); }) {
    SKIP: {
        my $requires = $options{requires} || {};    # normally a hash: test=>[files...]
        $requires = { '*' => $requires } unless ref $requires;    # scalar== filename required by ALL
        ## Carry out any TeX conversion tests
        foreach my $name (@core_tests) {
          my $test = "$directory/$name";
        SKIP: {
            skip("No file $test.xml", 1) unless (-f "$test.xml");
            next unless check_requirements($test, 1, $$requires{'*'}, $$requires{$name});
            latexml_ok("$test.tex", "$test.xml", $test, $options{compare}, $options{core_options}); } }
        # Carry out any post-processing tests
        foreach my $name (@post_tests) {
          my $test = "$directory/$name";
        SKIP: {
            skip("No file $test.xml and/or $test-post.xml", 1)
              unless ((-f "$test.xml") && (-f "$test-post.xml"));
            next unless check_requirements($test, 1, $$requires{'*'}, $$requires{$name});
            latexmlpost_ok("$test.tex", "$test-post.xml", $test); } }
        # Carry out any daemon tests.
        foreach my $name (@daemon_tests) {
          my $test = "$directory/$name";
        SKIP: {
            skip("No file $test.xml", 1)
              unless (-f "$test.xml");
            my $ntests = ($directory =~ /runtimes/ ? 1 : 2);
            next unless check_requirements($test, $ntests, $$requires{'*'}, $$requires{$name});
            daemon_ok($test, $directory, $options{generate});
          } } } }
    else {
      skip_all("Couldn't load LaTeXML"); } }
  return done_testing(); }

sub check_requirements {
  my ($test, $ntests, @reqmts) = @_;
  foreach my $reqmts (@reqmts) {
    next unless $reqmts;
    my @required_packages = ();
    my $texlive_min       = 0;
    if (!(ref $reqmts)) {
      @required_packages = ($reqmts); }
    elsif (ref $reqmts eq 'ARRAY') {
      @required_packages = @$reqmts; }
    elsif (ref $reqmts eq 'HASH') {
      @required_packages = (ref $$reqmts{packages} eq 'ARRAY' ? @{ $$reqmts{packages} } : $$reqmts{packages});
      $texlive_min       = $$reqmts{texlive_min} || 0; }
    foreach my $reqmt (@required_packages) {
      if (pathname_kpsewhich($reqmt) || pathname_find($reqmt)) { }
      else {
        my $message = "Missing requirement $reqmt for $test";
        diag("Skip: $message");
        skip($message, $ntests);
        return 0; } }
    # Check if specific texlive versions are required for this test
    if ($texlive_min && (texlive_version() < $texlive_min)) {
      my $message = "Minimal texlive $texlive_min requirement not met for $test";
      diag("Skip: $message");
      skip($message, $ntests);
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
  my ($texpath, $xmlpath, $name, $compare_kind, $core_options) = @_;
  if (my $texstrings = process_texfile(texpath => $texpath, name => $name, core_options => $core_options, compare_kind => $compare_kind)) {
    if (my $xmlstrings = process_xmlfile($xmlpath, $name, $compare_kind)) {
      return is_strings($texstrings, $xmlstrings, $name); } } }

sub latexmlpost_ok {
  my ($xmlpath, $postxmlpath, $name) = @_;
  if (my $texstrings = postprocess_xmlfile($xmlpath, $name)) {
    if (my $xmlstrings = process_xmlfile($postxmlpath, $name)) {
      return is_strings($texstrings, $xmlstrings, $name); } } }

our %CORE_OPTIONS_FOR_TESTS = (
  preload => [], searchpaths => [], includecomments => 0, includepathpis => 0, verbosity => -2);

sub convert_texfile_as_test {
  my (%options)    = @_;
  my $texpath      = $options{texpath};
  my $name         = $options{name};
  my $compare_kind = $options{compare_kind};
  my %core_options = $options{core_options} ? %{ $options{core_options} } : %CORE_OPTIONS_FOR_TESTS;
  my $latexml      = eval { LaTeXML::Core->new(%core_options) };
  if (!$latexml) {
    do_fail($name, "Couldn't instanciate LaTeXML: " . @!); return; }
  else {
    my $dom = eval { $latexml->convertFile($texpath); };
    if (!$dom) {
      do_fail($name, "Couldn't convert $texpath: " . @!); return; }
    else {
      return $dom; } } }

# These return the list-of-strings form of whatever was requested, if successful,
# otherwise undef; and they will have reported the failure
sub process_texfile {
  my (%options) = @_;
  if (my $dom = convert_texfile_as_test(%options)) {
    my $name         = $options{name};
    my $compare_kind = $options{compare_kind};
    return process_dom($dom, $name, $compare_kind); }
  else { return; } }

sub postprocess_xmlfile {
  my ($xmlpath, $name) = @_;
  my $xmath = LaTeXML::Post::XMath->new();
  return do_fail($name, "Couldn't instanciate LaTeXML::Post::XMath") unless $xmath;
  $xmath->setParallel(LaTeXML::Post::MathML::Presentation->new());
  my @procs       = ($xmath);
  my $latexmlpost = LaTeXML::Post->new(verbosity => -1);
  return do_fail($name, "Couldn't instanciate LaTeXML::Post:") unless $latexmlpost;

  my ($doc) = $latexmlpost->ProcessChain(
    LaTeXML::Post::Document->newFromFile("$name.xml", validate => 1),
    @procs);
  return do_fail($name, "Couldn't process $name.xml") unless $doc;
  return process_dom($doc, $name); }

sub serialize_dom_as_test {
  my ($xmldom) = @_;
  my $domstring = eval { my $string = $xmldom->toString(1);
    my $parser = XML::LibXML->new(load_ext_dtd => 0, validation => 0, keep_blanks => 1);
    $parser->parse_string($string)->toStringC14N(0); };
  return $domstring; }

sub process_dom {
  my ($xmldom, $name, $compare_kind) = @_;
  # We want the DOM to be BOTH indented AND canonical!!
  if (my $domstring = serialize_dom_as_test($xmldom)) {
    return process_domstring($domstring, $name, $compare_kind); }
  else {
    do_fail($name, "Couldn't convert dom to string: " . $@); return; } }

sub process_xmlfile {
  my ($xmlpath, $name, $compare_kind) = @_;
  my $domstring =
    eval { my $parser = XML::LibXML->new(load_ext_dtd => 0, validation => 0, keep_blanks => 1);
    $parser->parse_file($xmlpath)->toStringC14N(0); };
  if (!$domstring) {
    do_fail($name, "Could not convert file $xmlpath to string: " . $@); return; }
  else {
    return process_domstring($domstring, $name, $compare_kind); } }

sub process_htmlfile {
  my ($htmlpath, $name, $compare_kind) = @_;
  my $domstring = eval {
    XML::LibXML->load_html(
      location => $htmlpath,
      # tags such as <article> or <math> are invalid?? ignore.
      suppress_errors => 1,
      recover         => 1,
  )->toStringHTML(); };
  if (!$domstring) {
    do_fail($name, "Could not convert file $htmlpath to string: " . $@); return; }
  else {
    return process_domstring($domstring, $name, $compare_kind); } }

sub process_domstring {
  my ($domstring, $name, $compare_kind) = @_;
  if ($compare_kind && $compare_kind eq 'words') {    # words
    return [split(/\s+/, $domstring)]; }
  else {                                              # lines
    return [split('\n', $domstring)]; } }

# $strings1 is the currently generated material
# $strings2 is the stored expected result.
sub is_strings {
  my ($strings1, $strings2, $name) = @_;
  my $max = $#$strings1 > $#$strings2 ? $#$strings1 : $#$strings2;
  my $ok  = 1;
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
  return ok(1, $name); }

sub daemon_ok {
  my ($base, $dir, $generate) = @_;
  my $current_dir = pathname_cwd();
  my $localname   = $base;
  $localname =~ s/$dir\///;
  my $opts = read_options("$base.spec", $base);
  push @$opts, (['destination', "$localname.test.xml"],
    ['log',                "/dev/null"],
    ['quiet',              ''],
    ['quiet',              ''],
    ['quiet',              ''],
    ['quiet',              ''],
    ['timeout',            10],
    ['autoflush',          1],
    ['timestamp',          '0'],
    ['nodefaultresources', ''],
    ['xsltparameter',      'LATEXML_VERSION:TEST'],
    ['nocomments',         '']);

  my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');
  $latexmlc =~ s/^\.\///;
  my $path_to_perl = $Config{perlpath};

  my $invocation = $path_to_perl . " " . join(" ", map { ("-I", $_) } @INC) . " " . $latexmlc . ' ';
  my $timed      = undef;
  foreach my $opt (@$opts) {
    if ($$opt[0] eq 'timeout') {    # Ensure .opt timeout takes precedence
      if ($timed) { next; } else { $timed = 1; }
    }
    $invocation .= "--" . $$opt[0] . (length($$opt[1]) ? ('="' . $$opt[1] . '" ') : (' '));
  }
  if (!$generate) {
    pathname_chdir($dir);
    my $exit_code = system($invocation);
    if ($exit_code != 0) {
      $exit_code = $exit_code >> 8;
    }
    is($exit_code, 0, "latexmlc invocation for test $localname: $invocation yielded $!");
    pathname_chdir($current_dir);
    # Compare the just generated $base.test.xml to the previous $base.xml
    if (my $teststrings = process_xmlfile("$base.test.xml", $base)) {
      if (my $xmlstrings = process_xmlfile("$base.xml", $base)) {
        is_strings($teststrings, $xmlstrings, $base); } }
    unlink "$base.test.xml" if -e "$base.test.xml";
  }
  else {
    #TODO: Skip 3 tests
    print STDERR "$invocation\n";
    pathname_chdir($dir);
    system($invocation);
    pathname_chdir($current_dir);
    move("$base.test.xml", "$base.xml") if -e "$base.test.xml";
  }
  return; }

sub read_options {
  my ($optionfile, $testname) = @_;
  my $opts = [];
  my $OPT;
  if (open($OPT, "<", $optionfile)) {
    while (my $line = <$OPT>) {
      next if $line =~ /^#/;
      chomp($line);
      if ($line =~ /(\S+)\s*=\s*(.*)/) {
        my ($key, $value) = ($1, $2 || '');
        $value =~ s/\s+$//;
        push @$opts, [$key, $value]; } }
    close $OPT; }
  else {
    do_fail($testname, "Could not open $optionfile"); }
  return $opts; }

sub get_filecontent {
  my ($path, $testname) = @_;
  my $IN;
  my @lines;
  if (-e $path) {
    if (!open($IN, "<", $path)) {
      do_fail($testname, "Could not open $path"); }
    else {
      { local $\ = undef;
        @lines = <$IN>; }
      close($IN);
    }
  }
  if (scalar(@lines)) {
    $lines[-1] =~ s/\s+$//;
  } else {
    push @lines, '';
  }
  return \@lines; }

our $texlive_version;

sub texlive_version {
  if (defined $texlive_version) {
    return $texlive_version; }
  my $extra_flag = '';
  if ($ENV{"APPVEYOR"}) {
    # disabled under windows for now
    return 0; }
  my $tex;
  # If kpsewhich specified, look for tex next to it
  if (my $path = $ENV{LATEXML_KPSEWHICH}) {
    if (($path =~ s/kpsewhich/tex/i) && (-X $path)) {
      $tex = $path; } }
  if (!$tex) {    # Else look for executable
    $tex = which("tex"); }
  if ($tex) {     # If we found one, hope it has TeX Live version in it's --version
    my $version_string = `$tex --version`;
    if ($version_string =~ /TeX Live (\d+)/) {
      $texlive_version = int($1); }
    else {
      $texlive_version = 0; } }
  else {
    $texlive_version = 0; }
  return $texlive_version; }

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
