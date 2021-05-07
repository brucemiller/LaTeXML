# -*- CPERL -*-
#**********************************************************************
# Non-zero exit code on fatal *AND* partial result
#**********************************************************************
use strict;
use warnings;
use LaTeXML::Util::Test qw(process_htmlfile is_strings);
use LaTeXML::Util::Pathname qw(pathname_copy);
use Test::More;
use Config;
use FindBin;
use IPC::Open3;

use File::Temp qw(tempfile);
use File::Spec::Functions qw(catfile);
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IPC::Open3;

my $fatals_dir = "t/daemon/fatals/";
opendir(my $dir, $fatals_dir);
my @broken_tex_files = map {s/\.tex$//; "$fatals_dir$_"} grep {/\.tex$/} readdir($dir);

my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');
my $path_to_perl = $Config{perlpath};
foreach my $broken_base (@broken_tex_files) {
  my $invocation = $path_to_perl . " " . join(" ", map { ("-I", $_) } @INC) . " ";
  $invocation .= "$latexmlc $broken_base.tex --dest=$broken_base.test.html --format=html5 --nocomments ".
  "--nodefaultresources --timestamp=0 --xsltparameter=LATEXML_VERSION:TEST --log=/dev/null ";
  if ($broken_base =~ /timeout/) {
    $invocation .= ' --timeout=5 ';
  }
  my $latexmlc_pid = open3(my $chld_in, my $chld_out, my $chld_err, $invocation);
  waitpid( $latexmlc_pid, 0 );
  my $exit_code = $? >> 8;
  cmp_ok($exit_code, "==", 1, "latexmlc invocation has to return non-zero exit status, got: $exit_code");

  ok(-f "$broken_base.test.html", 'Fatal recovery should generate a partial HTML doc');
  # DWYM - if this runs for the first time, add the .test.html as the reference file.
  if (! -f "$broken_base.html") {
    pathname_copy("$broken_base.test.html","$broken_base.html")
  }
  if (my $testhtml = process_htmlfile("$broken_base.test.html", $broken_base)) {
    if (my $html = process_htmlfile("$broken_base.html", $broken_base)) {
      is_strings($testhtml, $html, $broken_base); } }
  # cleanup the test file
  unlink("$broken_base.test.html");
}
done_testing();

#**********************************************************************
1;
