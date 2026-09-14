# -*- CPERL -*-
#**********************************************************************
# Test cases for ZIP generation integrity
#**********************************************************************
use strict;
use warnings;

use Test::More;
use Config;
use FindBin;

use File::Basename qw(basename);
use File::Temp qw(tempfile);
use File::Spec::Functions qw(catfile);
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IPC::Open3;

my ($zip_fh, $zip_filename) = tempfile('932_testXXXX', SUFFIX => '.zip');
close($zip_fh);

my $existing_log_content = "pre-existing external log\n";
my ($log_fh, $log_filename) = tempfile('932_testXXXX', SUFFIX => '.log', DIR => '.', UNLINK => 0);
print $log_fh $existing_log_content;
close($log_fh);

my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');
my $path_to_perl = $Config{perlpath};
my @invocation = $path_to_perl, map { ('-I', $_) } @INC;
push(@invocation, $latexmlc, '--format=xml', "--dest=$zip_filename", "--log=$log_filename", 'literal:test');

my ($writer_discard, $reader_discard, $error_discard);
my $pid = open3($writer_discard, $reader_discard, $error_discard, @invocation);
{ local $/; <$reader_discard>; } # consume all output
close($reader_discard);
ok(waitpid($pid, 0), "latexmlc invocation for explicit-format ZIP output: $!");

my $zip_file = Archive::Zip->new();
is($zip_file->read($zip_filename), AZ_OK, 'explicit-format ZIP successfully loads as Archive::Zip object');
my $log_member = $zip_file->memberNamed(basename($log_filename));
ok($log_member, 'log file was written to explicit-format ZIP');
my $log_content = $log_member ? $log_member->contents() : q{};
ok($log_content =~ /No obvious problems/, 'explicit-format ZIP conversion was error-free');
ok(-f $log_filename, 'pre-existing external log was preserved for explicit-format ZIP');
my $preserved_log_content;
if (open(my $preserved_log, '<', $log_filename)) {
  local $/;
  $preserved_log_content = <$preserved_log>;
  close($preserved_log);
}
is($preserved_log_content, $existing_log_content,
  'pre-existing external log was not overwritten for explicit-format ZIP');

if (-f $zip_filename) {
  ok(unlink($zip_filename), "clean up generated ZIP file");
}
if (-f $log_filename) {
  ok(unlink($log_filename), "clean up preserved ZIP log file");
}

done_testing();

#**********************************************************************
1;
