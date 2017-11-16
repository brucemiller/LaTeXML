# /=====================================================================\ #
# |  LaTeXML::Util::Pack                                                | #
# | Packs the requested output (document, fragment, math, archive)      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::Pack;
use strict;
use warnings;

use LaTeXML::Util::Pathname;
use File::Spec::Functions qw(catfile);
use File::Path qw(rmtree);
use IO::String;
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);

use base qw(Exporter);
our @EXPORT = qw(&unpack_source &pack_collection);
our $archive_file_exclusion_regex = qr/(?:^\.)|(?:\.(?:zip|gz|epub|tex|bib|mobi|cache)$)|(?:~$)/;

sub unpack_source {
  my ($source, $sandbox_directory) = @_;
  my $main_source;
  my $zip_handle = Archive::Zip->new();
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
  foreach my $member ($zip_handle->memberNames()) {
    $zip_handle->extractMember($member, catfile($sandbox_directory, $member)); }
  # Set $source to point to the main TeX file in that directory
  my @TeX_file_members = map { $_->fileName() } $zip_handle->membersMatching('\.tex$');
  if (!@TeX_file_members) { # No .tex file? Try files with no, or unusually long, extensions
    @TeX_file_members = grep {!/\./ || /\.[^.]{4,}$/} map { $_->fileName() } $zip_handle->members();
  }

  # Heuristically determine the input (borrowed from arXiv::FileGuess)
  my %Main_TeX_likelihood;
  my @vetoed = ();
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
        $maybe_tex = 1; }
      if (/\\(?:input|include)(?:\s+|\{)([^ \}]+)/) {
        $maybe_tex = 1;
        # the argument of \input can't be the main file
        # (it could in very elaborate multi-target setups, but we DON'T support those)
        # so veto it.
        my $vetoed_file = $1;
        if ($vetoed_file eq 'amstex') { # TeX Priority
          $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; }
        if ($vetoed_file !~ /\./) {
          $vetoed_file .= '.tex';
        }
        my $base = $tex_file;
        $base =~ s/\/[^\/]+$//;
        $vetoed_file = "$base/$vetoed_file";
        push @vetoed, $vetoed_file; }
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
  # Veto files that were e.g. arguments of \input macros
  for my $filename(@vetoed) {
    delete $Main_TeX_likelihood{$filename};
  }
  # The highest likelihood (>0) file gets to be the main source.
  my @files_by_likelihood = sort { $Main_TeX_likelihood{$b} <=> $Main_TeX_likelihood{$a} } grep { $Main_TeX_likelihood{$_} > 0 } keys %Main_TeX_likelihood;
  if (@files_by_likelihood) {
   # If we have a tie for max score, grab the alphanumerically first file (to ensure deterministic runs)
    my $max_likelihood = $Main_TeX_likelihood{ $files_by_likelihood[0] };
    @files_by_likelihood = sort { $a cmp $b } grep { $Main_TeX_likelihood{$_} == $max_likelihood } @files_by_likelihood;
    $main_source = shift @files_by_likelihood; }

  # If failed, clean up sandbox directory.
  rmtree($sandbox_directory) unless $main_source;
  # Return the main source from the unpacked files in the sandbox directory (or undef if failed)
  return $main_source;
}

# Options:
#   whatsout: determine what shape and size we want to pack into
#             admissible: document (default), fragment, math, archive
#   siteDirectory: the directory to compress into a ZIP archive
#   collection: the collection of documents to be packed
sub pack_collection {
  my (%options) = @_;
  my @packed_docs;
  my $whatsout = $options{whatsout};
  my @docs     = @{ $options{collection} };
  # Archive once if requested
  if ($whatsout =~ /^archive/) {
    my $archive = get_archive($options{siteDirectory}, $whatsout);
  # TODO: Error API should be integrated once generalized to Util::
  #Fatal("I/O", $self, $docs[0], "Writing archive to IO::String handle failed") unless defined $archive;
    print STDERR "Fatal:I/O:Archive Writing archive to IO::String handle failed" unless defined $archive;
    return ($archive); }
  # Otherwise pack each document passed
  foreach my $doc (@docs) {
    next unless defined $doc;
    if ((!$whatsout) || ($whatsout eq 'document')) {
      push @packed_docs, $doc; }    # Document is no-op
    elsif ($whatsout eq 'fragment') {
      # If we want an embedable snippet, unwrap to body's "main" div
      push @packed_docs, get_embeddable($doc); }
    elsif ($whatsout eq 'math') {
      # Math output - least common ancestor of all math in the document
      print STDERR "REQUESTING MATH\n";
      push @packed_docs, get_math($doc); }
    else { push @packed_docs, $doc; } }
  return @packed_docs; }

## Helpers for pack_collection:
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
  my @files = grep { !/$archive_file_exclusion_regex/ && -f pathname_concat($directory, $_) } @entries;
  my @subdirs = grep { -d File::Spec->catdir($directory, $_) } @entries;
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
    # Only compress the textual files
    my $compression_level = ($file =~ /css|js|xml|html$/) ?
      COMPRESSION_DEFLATED
      : COMPRESSION_STORED;
    $archive->addString($file_contents, $file,)->desiredCompressionMethod($compression_level); }

  foreach my $subdir (sort @subdirs) {
    my $current_dir = File::Spec->catdir($directory, $subdir);
    $archive->addTree($current_dir, $subdir, sub { !/$archive_file_exclusion_regex/ }, COMPRESSION_STORED); }

  my $payload;
  if ($whatsout =~ /^archive(::zip)?$/) {
    my $content_handle = IO::String->new($payload);
    undef $payload unless ($archive->writeToFileHandle($content_handle) == AZ_OK); }
  elsif ($whatsout eq 'archive::zip::perl') {
    $payload = $archive; }
  return $payload; }

sub get_math {
  my ($doc) = @_;
  my $math_xpath = '//*[local-name()="math" or local-name()="Math"]';
  return unless defined $doc;
  my @mnodes     = $doc->findnodes($math_xpath);
  my $math_count = scalar(@mnodes);
  if (!$math_count) {
    return get_embeddable($doc); }
  my $math = $mnodes[0];
  if ($math_count > 1) {
    my $math_found = 0;
    while ($math_found != $math_count) {
      $math_found = $math->findnodes('.' . $math_xpath)->size;
      $math_found++ if ($math->localname =~ /^math$/i);
      $math = $math->parentNode if ($math_found != $math_count);
    }
    $math = $math->parentNode while ($math->nodeName =~ '^t[rd]$'); }
  if ($math) {
    my $imagesrc = $math->getAttribute('imagesrc');
    if ($imagesrc && $imagesrc =~ /[.]svg$/) {
      # Return the SVG directly
      $math = LaTeXML::Common::XML::Parser->new()->parseFile($imagesrc);
      $math = $math && $math->getDocumentElement;
    }
    # Copy over document namespace declarations:
    # NOTE: This copies ALL the namespaces, not just the needed ones!
    foreach ($doc->getDocumentElement->getNamespaces) {
      $math->setNamespace($_->getData, $_->getLocalName, 0); } }
  return $math; }

sub get_embeddable {
  my ($doc) = @_;
  return unless defined $doc;
  my ($embeddable) = $doc->findnodes('//*[contains(@class,"ltx_document")]');
  if ($embeddable) {
    # Only one child? Then get it, must be a inline-compatible one!
    while (($embeddable->nodeName eq 'div') && (scalar(@{ $embeddable->childNodes }) == 1) &&
      ($embeddable->getAttribute('class') =~ /^ltx_(page_(main|content)|document|para|header)$/) &&
      (!defined $embeddable->getAttribute('style'))) {
      if (defined $embeddable->firstChild) {
        $embeddable = $embeddable->firstChild; }
      else {
        last; }
    }
# Is the root a <p>? Make it a span then, if it has only math/text/spans - it should be inline
# For MathJax-like inline conversion mode
# TODO: Make sure we are schema-complete wrt nestable inline elements, and maybe find a smarter way to do this?
    if (($embeddable->nodeName eq 'p') && ((@{ $embeddable->childNodes }) == (grep { $_->nodeName =~ /math|text|span/ } $embeddable->childNodes))) {
      $embeddable->setNodeName('span');
      $embeddable->setAttribute('class', 'text');
    }

    # Copy over document namespace declarations:
    foreach ($doc->getDocumentElement->getNamespaces) {
      $embeddable->setNamespace($_->getData, $_->getLocalName, 0);
    }
    # Also, copy RDFa attributes:
    foreach my $rdfa_attr (qw(prefix property content resource about typeof rel rev datatype)) {
      if (my $rdfa_value = $doc->getDocumentElement->getAttribute($rdfa_attr)) {
        $embeddable->setAttribute($rdfa_attr, $rdfa_value); } }
  }
  return $embeddable || $doc; }

1;

__END__

=pod

=head1 NAME

C<LaTeXML::Util::Pack> - smart packing and unpacking of TeX archives

=head1 DESCRIPTION

This module provides an API and convenience methods for:
    1. Unpacking Zip archives which contain a TeX manuscript.
    2. Packing the files of a LaTeXML manuscript into a single archive
    3. Extracting embeddable fragments, as well as single formulas from LaTeXML documents

All user-level methods are unconditionally exported by default.

=head2 METHODS

=over 4

=item C<< $main_tex_source = unpack_source($archive,$extraction_directory); >>

Unpacks a given $archive into the $extraction_directory. Next, perform a
    heuristic analysis to determine, and return, the main file of the TeX manuscript.
    If the main file cannot be determined, the $extraction_directory is removed and undef is returned.

In this regard, we implement a simplified form of the logic in
    TeX::AutoTeX and particularly arXiv::FileGuess

=item C<< @packed_documents = pack_collection(collection=>\@documents, whatsout=>'math|fragment|archive', siteDirectory=>$path); >>

Packs a collection of documents using the packing method specified via the 'whatsout' option.
    If 'fragment' or 'math' are chosen, each input document is transformed into
    an embeddable fragment or a single formula, respectively.
    If 'archive' is chose, all input documents are written into an archive in the specified 'siteDirectory'.
    The name of the archive is provided by the 'destination' property of the first provided $document object.
    Each document is expected to be a LaTeXML::Post::Document object.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>,
Deyan Ginev <deyan.ginev@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
