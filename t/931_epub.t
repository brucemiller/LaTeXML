# -*- CPERL -*-
#**********************************************************************
# Test cases for EPUB generation integrity
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

my ($tmp_fh, $epub_filename) = tempfile('931_testXXXX', SUFFIX => '.epub');
close $tmp_fh;

my $log_filename = "931_test.log";
my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');

my $path_to_perl = $Config{perlpath};
my $invocation = $path_to_perl . " " . join(" ", map { ("-I", $_) } @INC) . " ";
$invocation .= $latexmlc . " --dest=$epub_filename --log=$log_filename literal:test ";

my ($writer_discard, $reader_discard, $error_discard);
my $pid = open3($writer_discard, $reader_discard, $error_discard, $invocation);
ok(waitpid( $pid, 0 ), "latexmlc invocation for test 931_epub.t : $!");

ok(-f $epub_filename, 'epub file generated');
ok(!-z $epub_filename, 'epub file has content');

my $zip_file = Archive::Zip->new();
is($zip_file->read($epub_filename), AZ_OK, 'epub file successfully loads as Archive::Zip object');
is($zip_file->numberOfMembers, 9, "correct number of files were present in final ePub");
my $names = join(", ",sort($zip_file->memberNames));
ok($names =~ /^META-INF\/, META-INF\/container\.xml, OPS\/, OPS\/931_test\.log, OPS\/931_test....\.xhtml, OPS\/LaTeXML\.css, OPS\/content\.opf, OPS\/nav\.xhtml, mimetype$/, "correct files were present in final ePub: $names");

my $log_member = $zip_file->memberNamed("OPS/$log_filename");
ok($log_member, "log file was written to epub");
my $log_content = $log_member->contents();
ok($log_content =~ /No obvious problems/, 'epub conversion was error-free');

if (-f $epub_filename) {
  ok(unlink($epub_filename), "clean up generated epub file");
}

done_testing();

#**********************************************************************
1;
