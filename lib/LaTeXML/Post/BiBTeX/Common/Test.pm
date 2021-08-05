# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Common::Test                                | #
# | Utility Functions for test cases                                    | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef InputOutput::RequireCheckedOpen Subroutines::RequireArgUnpacking);

package LaTeXML::Post::BiBTeX::Common::Test;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile);
use LaTeXML::Post::BiBTeX::Common::StreamReader;
use LaTeXML::Post::BiBTeX::Runner;
use LaTeXML::Post::BiBTeX::Common::Utils qw(slurp puts);
use LaTeXML::Post::BiBTeX::Runtime::Utils qw(fmtLogMessage);

use LaTeXML::Util::Pathname qw(pathname_kpsewhich);

use Digest::SHA qw(sha256_hex);

use Encode;
use Time::HiRes qw(time);

use File::Basename qw(dirname);
use File::Spec;

use base qw(Exporter);
our @EXPORT = qw(
  &fixture &isResult
  &makeStringReader &makeFixtureReader
  &measureBegin &measureEnd
  &integrationTest &integrationTestPaths
  &findFileVersion
);

# resolves the path to a fixture, if more than one argument is provided
# else returns the sole first argument.
sub fixture {
  return shift(@_) if (scalar(@_) == 1);
  return File::Spec->join(dirname(shift(@_)), 'fixtures', @_); }

# makes a LaTeXML::Post::BiBTeX::Common::StreamReader to a fixed string
sub makeStringReader {
  my ($content, $eat, $delimiter) = @_;
  my $reader = LaTeXML::Post::BiBTeX::Common::StreamReader->new();
  $reader->openString(($eat ? ' ' : '')
    . $content
      . (defined($delimiter) ? $delimiter : ' '));
  $reader->eatChar if $eat;
  return $reader; }

# makes a LaTeXML::Post::BiBTeX::Common::StreamReader to a fixture
sub makeFixtureReader {
  my $reader = LaTeXML::Post::BiBTeX::Common::StreamReader->new();
  my $path   = fixture(@_);
  $reader->openFile($path, "utf-8");
  return ($reader, $path); }

# joins a list of objects by stringifying them
sub joinStrs {
  my @strs = map { $_->stringify; } @_;
  return join("\n\n", @strs); }

# starts a measurement
sub measureBegin {
  return time; }

# ends a measurement
sub measureEnd {
  my ($begin, $name) = @_;
  my $duration = time - $begin;
  return Test::More::diag("evaluated $name in $duration seconds"); }

sub isResult {
  my ($results, $path, $message) = @_;
  return Test::More::is(joinStrs(@{$results}), slurp("$path.txt"), $message); }

sub integrationTestPaths {
  my ($path) = @_;
  # resolve the path to the test case
  $path = File::Spec->catfile('t', '900_bibtex', 'fixtures', 'integration', $path);
  # read the citation specification file
  my $citesIn = [
    grep { /\S/ } split(
      /\n/, slurp(File::Spec->catfile($path, 'input_citations.spec'))
    )];

  # read the macro specification file
  my $macroIn = slurp(File::Spec->catfile($path, 'input_macro.spec'));
  $macroIn =~ s/^\s+|\s+$//g;
  $macroIn = undef if $macroIn eq '';
  # hard-code input and output files
  my $bstIn     = File::Spec->catfile($path, 'input.bst');
  my $bibIn     = File::Spec->catfile($path, 'input.bib');
  my $resultOut = File::Spec->catfile($path, 'output.bbl');
  return $bstIn, $bibIn, $citesIn, $macroIn, $resultOut; }

# represents a full test of the BiBTeXML steps
sub integrationTest {
  my ($name, $path) = @_;
  # resolve paths to input and output
  my ($bstIn, $bibIn, $citesIn, $macroIn, $resultOut) =
    integrationTestPaths($path);
  return subtest "$name" => sub {
    plan tests => 4;
    # create a reader for the bst file
    my $bst = LaTeXML::Post::BiBTeX::Common::StreamReader->newFromFile($bstIn);
    my $bib = LaTeXML::Post::BiBTeX::Common::StreamReader->newFromFile($bibIn);
    # compile it
    my ($code, $compiled) = createCompile($bst, \&note, $bstIn);
    # check that the code compiled without problems
    is($code, 0, 'compilation went without problems');
    return if $code != 0;
    # execute the compiled code
    $compiled = eval $compiled;
    is(ref $compiled, 'CODE', 'compilation produced CODE');
    # create a temporary file for the output
    my ($output) = File::Temp->new(UNLINK => 1, SUFFIX => '.tex');
    open(my $handle, ">", $output);
    # and create the run
    my $runcode = createRun($compiled, [$bib], $citesIn, $macroIn, sub {
        note(fmtLogMessage(@_) . "\n");
    }, $handle, 1);
    # run the run
    my ($status) = &{$runcode}();
    is($status, 0, 'running went ok');
    # check that we compiled the expected output
    is(slurp($output), slurp($resultOut),
      'compilation returned expected result'); } }

# finds (using kpsewhich) a file of the given name and compares it's sha256 checksum.
# returns a pair $path, $error with $path being undef if either the sha256 mismatches or it doesn't exist.
sub findFileVersion {
  my ($file, $expectSHA256) = @_;
  # find the candidate path
  my $candidate = pathname_kpsewhich($file);
  return undef, "Required file $file not found. " unless (defined($candidate) && (-e $candidate));
  # compute it's sha256
  my $gotHash256 = sha256_hex(slurp($candidate));
  return undef, "Found required file $file at $candidate, but unable to compute SHA256. " unless defined($gotHash256);
  # sha256 differs!
  return undef, "Found required file $file at $candidate, but SHA256 $gotHash256 differs from expected $expectSHA256" unless $expectSHA256 eq $gotHash256;
  # and we're done
  return $candidate, undef; }

1;
