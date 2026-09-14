# -*- CPERL -*-
#**********************************************************************
# Test cases for EPUB generation integrity
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

my ($tmp_fh, $epub_filename) = tempfile('931_testXXXX', SUFFIX => '.epub');
close $tmp_fh;

my ($source_fh, $source_filename) = tempfile('931_sourceXXXX', SUFFIX => '.tex', DIR => '.', UNLINK => 0);
print $source_fh "\\documentclass{article}\n\\begin{document}\ntest\n\\end{document}\n";
close($source_fh);

my $existing_log_content = "pre-existing external log\n";
my $log_filename = basename($source_filename);
$log_filename =~ s/\.tex$/.latexml.log/;
open(my $log_fh, '>', $log_filename);
print $log_fh $existing_log_content;
close($log_fh);

my $latexmlc = catfile($FindBin::Bin, '..', 'blib', 'script', 'latexmlc');

my $path_to_perl = $Config{perlpath};
my @invocation = $path_to_perl, map { ('-I', $_) } @INC;
push(@invocation, $latexmlc, '--css=LaTeXML-epub.css', "--dest=$epub_filename", $source_filename);

my ($writer_discard, $reader_discard, $error_discard);
my $pid = open3($writer_discard, $reader_discard, $error_discard, @invocation);
{ local $/; <$reader_discard>; } # consume all output
close($reader_discard);
ok(waitpid( $pid, 0 ), "latexmlc invocation for test 931_epub.t : $!");

ok(-f $epub_filename, 'epub file generated');
ok(!-z $epub_filename, 'epub file has content');

my $zip_file = Archive::Zip->new();
is($zip_file->read($epub_filename), AZ_OK, 'epub file successfully loads as Archive::Zip object');
my $epub_document_name = basename($epub_filename);
$epub_document_name =~ s/\.epub$/.xhtml/;
my $log_member_name = basename($log_filename);
my @expected_names = ('META-INF/', 'META-INF/container.xml', 'OPS/', "OPS/$log_member_name",
  "OPS/$epub_document_name", 'OPS/LaTeXML-epub.css', 'OPS/LaTeXML.css', 'OPS/content.opf',
  'OPS/ltx-article.css', 'mimetype');
is($zip_file->numberOfMembers, scalar(@expected_names), "correct number of files were present in final ePub");
my $names = join(", ", sort($zip_file->memberNames));
is($names, join(", ", sort(@expected_names)), "correct files were present in final ePub");

my $log_member = $zip_file->memberNamed("OPS/$log_member_name");
ok($log_member, "log file was written to epub");
my $log_content = $log_member ? $log_member->contents() : q{};
ok($log_content =~ /No obvious problems/, 'epub conversion was error-free');
unlike($log_content, qr/\Q$existing_log_content\E/, 'epub contains a fresh conversion log');

ok(-f $log_filename, 'pre-existing external log was preserved');
my $preserved_log_content;
if (open(my $preserved_log, '<', $log_filename)) {
  local $/;
  $preserved_log_content = <$preserved_log>;
  close($preserved_log);
}
is($preserved_log_content, $existing_log_content, 'pre-existing external log was not overwritten');

my @invalid_invocation = $path_to_perl, map { ('-I', $_) } @INC;
push(@invalid_invocation, $latexmlc, '--navigationtoc=bogus', "--dest=$epub_filename",
  "--log=$log_filename", 'literal:test');
my ($invalid_writer_discard, $invalid_reader_discard, $invalid_error_discard);
my $invalid_pid = open3($invalid_writer_discard, $invalid_reader_discard, $invalid_error_discard, @invalid_invocation);
{ local $/; <$invalid_reader_discard>; } # consume all output
close($invalid_reader_discard);
ok(waitpid($invalid_pid, 0), "invalid archive invocation completed: $!");
ok(-f $log_filename, 'invalid archive invocation did not delete the pre-existing external log');
my $log_content_after_invalid_invocation;
if (open(my $log_after_invalid_invocation, '<', $log_filename)) {
  local $/;
  $log_content_after_invalid_invocation = <$log_after_invalid_invocation>;
  close($log_after_invalid_invocation);
}
is($log_content_after_invalid_invocation, $existing_log_content,
  'invalid archive invocation did not overwrite the pre-existing external log');

if (-f $epub_filename) {
  ok(unlink($epub_filename), "clean up generated epub file");
}
if (-f $log_filename) {
  ok(unlink($log_filename), "clean up preserved log file");
}
if (-f $source_filename) {
  ok(unlink($source_filename), "clean up source file");
}

done_testing();

#**********************************************************************
1;
