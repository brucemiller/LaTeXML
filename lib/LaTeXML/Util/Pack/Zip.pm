# /=====================================================================\ #
# |  LaTeXML::Util::Pack::Zip                                           | #
# | Processor for handling Zip inputs                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::Pack::Zip;
use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use File::Path            qw(rmtree);
use Archive::Zip          qw(:CONSTANTS :ERROR_CODES);
use LaTeXML::Util::Pathname;

use base qw(LaTeXML::Util::Pack);

# LaTeXML::Util::Pack methods, ZIP implementation

sub unpack_source {
  my ($self)     = @_;
  my $zip_handle = $$self{zip_handle} = Archive::Zip->new();
  my $source     = $$self{source};
  if (pathname_is_literaldata($source)) {
    # If literal, just use the data
    $source =~ s/^literal\://;
    my $content_handle = IO::String->new($source);
    unless ($zip_handle->readFromFileHandle($content_handle) == AZ_OK) {
      print STDERR "Fatal:I/O:Archive Can't read in literal archive:\n $source\n"; } }
  else {    # Otherwise, read in from file
    unless ($zip_handle->read($source) == AZ_OK) {
      print STDERR "Fatal:I/O:Archive Can't read in source archive: $source\n"; } }
  # Extract the Perl zip datastructure to the temporary directory
  my $sandbox_directory = $$self{sandbox_directory};
  foreach my $member ($zip_handle->memberNames()) {
    $zip_handle->extractMember($member, catfile($sandbox_directory, $member)); }
  return $self->detect_source();
}

sub find_file {
  my ($self, $name) = @_;
  my $member = $$self{zip_handle}->memberNamed($name);
  return $member && catfile($$self{sandbox_directory}, $member->fileName()); }

sub full_filename {
  my ($self, $name) = @_;
  return catfile($$self{sandbox_directory}, $name);
}

sub find_tex_files {
  my ($self)           = @_;
  my $zip_handle       = $$self{zip_handle};
  my $tex_ext          = $LaTeXML::Util::Pack::TEX_EXT;
  my @TeX_file_members = map { $_->fileName() } $zip_handle->membersMatching($tex_ext);
  if (!@TeX_file_members) {    # No .tex file? Try files with no, or unusually long, extensions
    @TeX_file_members = grep { !/\./ || /\.[^.]{4,}$/ } map { $_->fileName() } $zip_handle->members();
  }
  return @TeX_file_members; }

sub cleanup {
  my ($self) = @_;
  if (my $sandbox_directory = $$self{sandbox_directory}) {
    rmtree($sandbox_directory);
    return; } }

### Helpers for pack_collection, currently ZIP-only:

sub get_archive {
  my ($directory, $whatsout) = @_;
  # Zip and send back
  my $archive = Archive::Zip->new();
  opendir(my $dirhandle, $directory)
    # TODO: Switch to Error API
    # or Fatal('expected', 'directory', undef,
    # "Expected a directory to archive '$directory':", $@);
    or (print STDERR 'Fatal:expected:directory Failed to compress directory \'$directory\': $@');
  my @entries = grep { /^[^.]/ } readdir($dirhandle);
  closedir $dirhandle;
  my $ext_exclude = $LaTeXML::Util::Pack::ARCHIVE_EXT_EXCLUDE;
  my @files       = grep { !/$ext_exclude/ && pathname_test_f(pathname_concat($directory, $_)) } @entries;
  my @subdirs     = grep { -d File::Spec->catdir($directory, $_) } @entries;
 # We want to first add the files instead of simply invoking ->addTree on the top level
 # without ANY file attributes at all,
 # since EPUB is VERY picky about the first entry in the archive starting at byte 38 (file 'mimetype')
  @files = sort @files;
  my @nomime_files = grep { !/^mimetype$/ } @files;
  if (scalar(@nomime_files) != scalar(@files)) {
    @files = ('mimetype', @nomime_files); }
  foreach my $file (@files) {
    local $/ = undef;
    my $FH;
    my $pathname = pathname_concat($directory, $file);
    open $FH, "<", $pathname
      # TODO: Switch to Error API
      #or Fatal('I/O', $pathname, undef, "File $pathname is not readable.");
      or (print STDERR "Fatal:I/O:$pathname File $pathname is not readable.");
    my $file_contents = <$FH>;
    close($FH);
    # Compress all files except mimetype
    my $compression = ($file eq 'mimetype' ? COMPRESSION_STORED : COMPRESSION_DEFLATED);
    $archive->addString($file_contents, $file,)->desiredCompressionMethod($compression); }

  foreach my $subdir (sort @subdirs) {
    my $current_dir = File::Spec->catdir($directory, $subdir);
    $archive->addTree($current_dir, $subdir, sub { !/$ext_exclude/ }, COMPRESSION_DEFLATED); }

  if (defined $ENV{SOURCE_DATE_EPOCH}) {
    for my $member ($archive->members()) {
      $member->setLastModFileDateTimeFromUnix($ENV{SOURCE_DATE_EPOCH}); } }

  my $payload;
  if ($whatsout =~ /^archive(::zip)?$/) {
    my $content_handle = IO::String->new($payload);
    undef $payload unless ($archive->writeToFileHandle($content_handle) == AZ_OK); }
  elsif ($whatsout eq 'archive::zip::perl') {
    $payload = $archive; }
  return $payload; }

1;

=head1 NAME

C<LaTeXML::Util::Pack::Zip> - smart packing and unpacking of ZIP bundles

=head1 DESCRIPTION

This module provides the concrete methods for handling ZIP files, following the
interfaced defined by C<LaTeXML::Util::Pack>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>,
Deyan Ginev <deyan.ginev@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
