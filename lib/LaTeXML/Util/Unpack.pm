# /=====================================================================\ #
# |  LaTeXML::Util::Unpack                                              | #
# | Unpacks an archive provided on input                                | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::Unpack;
use strict;
use warnings;
use IO::String;
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use File::Spec::Functions qw(catfile);
use LaTeXML::Util::Pathname;

use base qw(Exporter);
our @EXPORT = qw(&unpack_source);

sub unpack_source {
  my ($source, $sandbox_directory) = @_;
  my $main_source;
  my $zip_handle = Archive::Zip->new();
  if (pathname_is_literaldata($source)) {
    # If literal, just use the data
    my $content_handle = IO::String->new($source);
    unless ($zip_handle->readFromFileHandle($content_handle) == AZ_OK) {
      print STDERR "Fatal:IO:Archive Can't read in literal archive:\n $source\n"; } }
  else {    # Otherwise, read in from file
    unless ($zip_handle->read($source) == AZ_OK) {
      print STDERR "Fatal:IO:Archive Can't read in source archive: $source\n"; } }
  # Extract the Perl zip datastructure to the temporary directory
  foreach my $member ($zip_handle->memberNames()) {
    $zip_handle->extractMember($member, catfile($sandbox_directory, $member)); }
  # Set $source to point to the main TeX file in that directory
  my @TeX_file_members = map { $_->fileName() } $zip_handle->membersMatching('\.tex$');
  if (scalar(@TeX_file_members) == 1) {
    # One file, that's the input!
    $main_source = catfile($sandbox_directory, $TeX_file_members[0]); }
  else {
    # Heuristically determine the input (borrowed from arXiv::FileGuess)
    my %Main_TeX_likelihood;
    foreach my $tex_file (@TeX_file_members) {
      # Read in the content
      $tex_file = catfile($sandbox_directory, $tex_file);
      # Open file and read first few bytes to do magic sequence identification
      # note that file will be auto-closed when $FILE_TO_GUESS goes out of scope
      open(my $FILE_TO_GUESS, '<', $tex_file) ||
        (print STDERR "failed to open '$tex_file' to guess its format: $!. Continuing.\n");
      local $/ = "\n";
      my ($maybe_tex, $maybe_tex_priority, $maybe_tex_priority2);
    TEX_FILE_TRAVERSAL:
      while (<$FILE_TO_GUESS>) {
        if ((/\%auto-ignore/ && $. <= 10) ||    # Ignore
          ($. <= 10 && /\\input texinfo/) ||    # TeXInfo
          ($. <= 10 && /\%auto-include/))       # Auto-include
        { $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }    # Not primary
        if ($. <= 12 && /^\r?%\&([^\s\n]+)/) {
          if ($1 eq 'latex209' || $1 eq 'biglatex' || $1 eq 'latex' || $1 eq 'LaTeX') {
            $Main_TeX_likelihood{$tex_file} = 3; last TEX_FILE_TRAVERSAL; }    # LaTeX
          else {
            $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; } }    # Mac TeX
            # All subsequent checks have lines with '%' in them chopped.
            #  if we need to look for a % then do it earlier!
        s/\%[^\r]*//;
        if (/(?:^|\r)\s*\\document(?:style|class)/) {
          $Main_TeX_likelihood{$tex_file} = 3; last TEX_FILE_TRAVERSAL; }    # LaTeX
        if (/(?:^|\r)\s*(?:\\font|\\magnification|\\input|\\def|\\special|\\baselineskip|\\begin)/) {
          $maybe_tex = 1;
          if (/\\input\s+amstex/) {
            $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; } }    # TeX Priority
        if (/(?:^|\r)\s*\\(?:end|bye)(?:\s|$)/) {
          $maybe_tex_priority = 1; }
        if (/\\(?:end|bye)(?:\s|$)/) {
          $maybe_tex_priority2 = 1; }
        if (/\\input *(?:harv|lanl)mac/ || /\\input\s+phyzzx/) {
          $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }        # Mac TeX
        if (/beginchar\(/) {
          $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # MetaFont
        if (/(?:^|\r)\@(?:book|article|inbook|unpublished)\{/i) {
          $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # BibTeX
        if (/^begin \d{1,4}\s+[^\s]+\r?$/) {
          if ($maybe_tex_priority) {
            $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; }      # TeX Priority
          if ($maybe_tex) {
            $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }      # TeX
          $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }        # UUEncoded or PC
        if (m/paper deliberately replaced by what little/) {
          $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }
      }
      close $FILE_TO_GUESS || warn "couldn't close file: $!";
      if (!defined $Main_TeX_likelihood{$tex_file}) {
        if ($maybe_tex_priority) {
          $Main_TeX_likelihood{$tex_file} = 2; }
        elsif ($maybe_tex_priority2) {
          $Main_TeX_likelihood{$tex_file} = 1.5; }
        elsif ($maybe_tex) {
          $Main_TeX_likelihood{$tex_file} = 1; }
        else {
          $Main_TeX_likelihood{$tex_file} = 0; }
      }
    }
    # The highest likelihood (>0) file gets to be the main source.
    my @files_by_likelihood = sort { $Main_TeX_likelihood{$b} <=> $Main_TeX_likelihood{$a} } grep { $Main_TeX_likelihood{$_} > 0 } keys %Main_TeX_likelihood;
    if (@files_by_likelihood) {
     # If we have a tie for max score, grab the alphanumerically first file (to ensure deterministic runs)
      my $max_likelihood = $Main_TeX_likelihood{ $files_by_likelihood[0] };
      @files_by_likelihood = sort { $a cmp $b } grep { $Main_TeX_likelihood{$_} == $max_likelihood } @files_by_likelihood;
      $main_source = shift @files_by_likelihood; }
  }

  # If failed, clean up sandbox directory.
  remove_tree($sandbox_directory) unless $main_source;
  # Return the main source from the unpacked files in the sandbox directory (or undef if failed)
  return $main_source;
}

1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Util::Unpack> - smart unpacking of TeX archives

=head1 DESCRIPTION

This module provides an API and convenience methods for unpacking
    Zip archives which contain a TeX manuscript.

In this regard, we implement a simplified form of the logic in
    TeX::AutoTeX and particularly arXiv::FileGuess

All methods are unconditionally exported by default.

=head2 METHODS

=over 4

=item C<< my $main_tex_source = unpack_source($archive,$extraction_directory); >>

Unpacks a given $archive into the $extraction_directory. Next, perform a
    heuristic analysis to determine, and return, the main file of the TeX manuscript.
    If the main file cannot be determined, the $extraction_directory is removed and undef is returned.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Deyan Ginev <deyan.ginev@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
