# -*- CPERL -*-
#**********************************************************************
# Non-zero exit code on fatal
#**********************************************************************
use strict;
use warnings;

use Test::More;
use Config;
use FindBin;

use File::Temp qw(tempfile);
use File::Spec::Functions qw(catfile);
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IPC::Open3;

my $source_broken = "broken.tex";
my $destination_broken = "broken.html";

my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');

my $path_to_perl = $Config{perlpath};
my $invocation = $path_to_perl . " " . join(" ", map { ("-I", $_) } @INC) . " ";
$invocation .= $latexmlc . " --dest=$destination_broken --log=/dev/null $source_broken  2>/dev/null";

my $exit_code = system($invocation);
if ($exit_code != 0) {
  $exit_code = $exit_code >> 8;
}
cmp_ok($exit_code, "!=", 0, "latexmlc invocation has to return non-zero exit status, got: $exit_code");

ok(!(-f $destination_broken), 'broken file should not be generated due to Fatal');

if (-f $destination_broken) {
  ok(unlink($destination_broken), "clean up generated broken file");
}

done_testing();

#**********************************************************************
1;
