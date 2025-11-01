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

use IO::String;
use JSON::XS qw(decode_json);
use File::Find;
use LaTeXML::Util::Pathname;

use base qw(Exporter);
our @EXPORT = qw(&pack_collection);
require LaTeXML::Util::Pack::Zip;

our $ARCHIVE_EXT_EXCLUDE = qr/(?:^\.)|(?:\.(?:zip|gz|epub|tex|bib|mobi|cache)$)|(?:~$)/;
our $TEX_EXT             = qr/\.(?:[tT](:?[eE][xX]|[xX][tT])|ltx|LTX)$/;

sub new {
  my ($class, %opts) = @_;
  my $type = (delete $opts{type}) || 'zip';
  if ($type eq 'zip') {
    return bless \%opts, 'LaTeXML::Util::Pack::Zip'; }
  elsif ($type eq 'directory') {
    return bless \%opts, 'LaTeXML::Util::Pack::Dir'; }
  else {
    print STDERR "Fatal:Pack:new unsupported archive type $type.\n";
    return; } }

# Abstract interface methods, to be implemented by each concrete processor:
sub find_file {
  print STDERR "Fatal:Pack:find_file abstract class should never be called (arg: $_)\n";
  return; }

sub find_tex_files {
  print STDERR "Fatal:Pack:find_tex_files abstract class should never be called\n";
  return; }

sub full_filename {
  print STDERR "Fatal:Pack:find_tex_files abstract class should never be called\n";
  return; }

sub unpack_source {
  print STDERR "Fatal:Pack:unpack_source abstract class should never be called\n";
  return; }

sub cleanup {
  print STDERR "Fatal:Pack:cleanup abstract class should never be called\n";
  return; }

# Assume a self with the abstrat methods above implemented.
# Each processor is able to unpack to a directory, in which we can identically
# try to detect the top-level TeX file(s).
sub detect_source {
  my ($self) = @_;
  # I. Detect and return the main TeX file in that directory (or .txt, for old arXiv bundles)
  # I.1. arXiv has a special metadata file identifying the primary source, and ignoring assets
  # I.1.1. 2025 arXiv refresh of 00README
  my $readme_file;
  if ($readme_file = $self->find_file('00README.json')) {
    my $json_str = do {
      local $/ = undef;
      open(my $README_FH, '<', $readme_file) or
        (print STDERR "failed to open '$readme_file' for use as input directives: $!. Continuing.\n");
      <$README_FH>;
    } || '';
    my $json_data = eval { decode_json($json_str); } || {};
    my ($name) = map { $$_{filename} } grep { $$_{usage} eq 'toplevel' } @{ $$json_data{sources} || [] };
    if ($name) {
      my $toplevelfile = $self->full_filename($name);
      return $toplevelfile;
  } }
  # I.1.2. Legacy arXiv 00README.XXX
  elsif ($readme_file = $self->find_file('00README.XXX')) {
    open(my $README_FH, '<', $readme_file) or
      (print STDERR "failed to open '$readme_file' for use as input directives: $!. Continuing.\n");
    local $/ = "\n";
    my $toplevelfile;
    while (<$README_FH>) {
      chomp($_);
      my ($name, $directive) = split(/\s+/, $_);
      if ($directive) {
        if ($directive eq 'toplevelfile') {
          # shortcut guessing the top file, the user has provided it explicitly.
          $toplevelfile = $self->full_filename($name);
        } elsif ($directive eq 'ignore') {
          my $ignored_filepath = $self->full_filename($name);
          pathname_unlink($ignored_filepath) if pathname_test_e($ignored_filepath); } } }
    return $toplevelfile if $toplevelfile; }

  # I.2. Without an explicit directive,
  #      heuristically determine the input (borrowed from arXiv::FileGuess)
  my @TeX_file_members = $self->find_tex_files();
  my $main_source;
  my (%Main_TeX_likelihood, %Main_TeX_level);
  my @vetoed = ();
  foreach my $tex_file (@TeX_file_members) {
    # Read in the content
    $tex_file = $self->full_filename($tex_file);
    # Open file and read first few bytes to do magic sequence identification
    # note that file will be auto-closed when $FILE_TO_GUESS goes out of scope
    next unless pathname_test_e($tex_file);    # skip deleted "ignored" files.
    open(my $FILE_TO_GUESS, '<', $tex_file) or
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
        if ($vetoed_file eq 'amstex') {    # TeX Priority
          $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; }
        if ($vetoed_file !~ /\./) {
          $vetoed_file =~ s/\s+$//;        # drop trailing spaces if any;
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
        $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }    # Mac TeX
      if (/beginchar\(/) {
        $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }    # MetaFont
      if (/(?:^|\r)\@(?:book|article|inbook|unpublished)\{/i) {
        $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }    # BibTeX
      if (/^begin \d{1,4}\s+[^\s]+\r?$/) {
        if ($maybe_tex_priority) {
          $Main_TeX_likelihood{$tex_file} = 2; last TEX_FILE_TRAVERSAL; }    # TeX Priority
        if ($maybe_tex) {
          $Main_TeX_likelihood{$tex_file} = 1; last TEX_FILE_TRAVERSAL; }    # TeX
        $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }      # UUEncoded or PC
      if (m/paper deliberately replaced by what little/) {
        $Main_TeX_likelihood{$tex_file} = 0; last TEX_FILE_TRAVERSAL; }
    }
    close $FILE_TO_GUESS or (print STDERR "couldn't close file: $!");
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
  for my $filename (@vetoed) {
    delete $Main_TeX_likelihood{$filename}; }
  # Examine only the max-scoring candidates (if any)
  my @files_by_likelihood = sort { $Main_TeX_likelihood{$b} <=> $Main_TeX_likelihood{$a} }
    grep { $Main_TeX_likelihood{$_} > 0 } keys %Main_TeX_likelihood;
  if (@files_by_likelihood) {
    my $max_likelihood = $Main_TeX_likelihood{ $files_by_likelihood[0] };
    @files_by_likelihood = grep { $Main_TeX_likelihood{$_} == $max_likelihood } @files_by_likelihood;
# Special heuristic 1: If we have multiple "best" candidates, prefer those closer to the archive root '/'
    if (scalar(@files_by_likelihood) > 1) {
      my $min_count = 100;
      foreach my $file (@files_by_likelihood) {
        my $count = $file =~ tr/\///;
        $Main_TeX_level{$file} = $count;
        $min_count = $count if $min_count > $count; }
      @files_by_likelihood = grep { $Main_TeX_level{$_} == $min_count } @files_by_likelihood; }
    # Special heuristic 2: prefer candidates with PDF-like \includegraphics
    if (scalar(@files_by_likelihood) > 1) {
      my @pdf_includes = heuristic_check_for_pdftex(@files_by_likelihood);
      @files_by_likelihood = @pdf_includes if @pdf_includes; }
    # Special heuristic 3: prefer "best" candidates with a .bbl file
    if (scalar(@files_by_likelihood) > 1) {
      my @with_bbl = grep { my $base = $_; $base =~ s/\.tex$//; pathname_test_e("$base.bbl"); } @files_by_likelihood;
      @files_by_likelihood = @with_bbl if @with_bbl; }
# Special heuristic 4 ?!: Sometimes in arXiv the decision is made in an unclear manner
# (example: see 2112.08935 v1, which has equally good main.tex and bare_adv.tex)
# so, for now, err on the side of preferring one of the extremely common names, when they are available at highest score.
    if (scalar(@files_by_likelihood) > 1) {
      my @common_name = grep { /(^|\W)(?:main|ms|paper)\.tex$/ } @files_by_likelihood;
      @files_by_likelihood = @common_name if @common_name; }
    # Final heuristic: tie-breaker is lexicographical order
    if (scalar(@files_by_likelihood) > 1) {
      @files_by_likelihood = sort { $a cmp $b } @files_by_likelihood; }
    # set the winner for main source
    $main_source = shift @files_by_likelihood; }

  # If failed, clean up sandbox directory.
  $self->cleanup() unless $main_source;
  # Return the main source from the unpacked files in the sandbox directory (or undef if failed)
  return $main_source; }

sub heuristic_check_for_pdftex {
  my @filenames    = @_;
  my @pdf_includes = ();
  for my $tex_file (@filenames) {
    my $is_open = open(my $TEX_FH, '<', $tex_file);
    if (!$is_open) {
      print STDERR "failed to open '$tex_file' to guess its format: $!. Continuing.\n";
      next; }
    local $/ = "\n";
    my $pdfoutput_checks = 5;
    while (<$TEX_FH>) {
      # Check from arXiv::FileGuess, line 317
      # https://metacpan.org/release/SIMEON/arXiv-1.01/source/lib/arXiv/FileGuess.pm#L317
      if (/^[^%]*\\includegraphics[^%]*\.(?:pdf|png|gif|jpg)\s?\}/i ||
        ($pdfoutput_checks >= 0 && /^[^%]*\\pdfoutput(?:\s+)?=(?:\s+)?1/)) {
        push(@pdf_includes, $tex_file);
        last; }
      $pdfoutput_checks-- if $pdfoutput_checks; }
    close $TEX_FH or (print STDERR "couldn't close file: $!"); }
  return @pdf_includes; }

# Output utilitities

### Utility methods for --whatsout variants

sub get_math {
  my ($doc) = @_;
  my $math_xpath = '//*[local-name()="math" or local-name()="Math"]';
  return unless defined $doc;
  my @mnodes     = $doc->findnodes($math_xpath);
  my $math_count = scalar(@mnodes);
  if (!$math_count) {    # If no real math nodes, look for math image nodes
    my $math_img_xpath = '//*[local-name()="img" and contains(@class,"ltx_Math")]';
    @mnodes     = $doc->findnodes($math_img_xpath);
    $math_count = scalar(@mnodes);
  }
  if (!$math_count) {
    return get_embeddable($doc); }
  my $math = $mnodes[0];
  if ($math_count > 1) {
    my $math_found = 0;
    while ($math_found != $math_count) {
      $math_found = $math->findnodes('.' . $math_xpath)->size;
      $math_found++             if ($math->localname =~ /^math$/i);
      $math = $math->parentNode if ($math_found != $math_count);
    }
    $math = $math->parentNode while ($math->nodeName =~ '^t[rd]$'); }
  if ($math) {
    my $imagesrc = $math->getAttribute('imagesrc') || $math->getAttribute('src');
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
    my $archive = LaTeXML::Util::Pack::Zip::get_archive($options{siteDirectory}, $whatsout);
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
      push @packed_docs, get_math($doc);
      pathname_unlink('LaTeXML.cache'); }
    else { push @packed_docs, $doc; } }
  return @packed_docs; }

1;

__END__

=pod

=head1 NAME

C<LaTeXML::Util::Pack> - smart packing and unpacking of TeX input bundles

=head1 DESCRIPTION

This module provides an API and convenience methods for:
    1. Unpacking Zip archives which contain a TeX manuscript.
    2. Packing the files of a LaTeXML manuscript into a single archive
    3. Extracting embeddable fragments, as well as single formulas from LaTeXML documents

All user-level methods are unconditionally exported by default.

=head2 METHODS

=over 4

=item C<< my $self = LaTeXML::Util::Pack->new(source => $source, type => $type, %opts); >>

Creates a new Pack processor, for the appropriate archive type. Currently defaults to 'zip',
with 'directory' (i.e. already unpacked) as the only alternative option.

To specify where to unpack, set the C<sandbox_directory> option.

=item C<< $main_tex_source = $self->unpack_source(); >>

Unpacks a given archive into the C<$sandbox_directory>, when needed. Next, perform a
    heuristic analysis to determine, and return, the main file of the TeX manuscript.
    If the main file cannot be determined, the C<$sandbox_directory> is removed and undef is returned.

In this regard, we implement a simplified form of the logic in
    C<TeX::AutoTeX> and particularly C<arXiv::FileGuess>

=item C<< @packed_documents = pack_collection(collection=>\@documents, whatsout=>'math|fragment|archive', siteDirectory=>$path); >>

Packs a collection of documents using the packing method specified via the 'whatsout' option.
    If 'fragment' or 'math' are chosen, each input document is transformed into
    an embeddable fragment or a single formula, respectively.
    If 'archive' is chose, all input documents are written into an archive in the specified 'siteDirectory'.
    The name of the archive is provided by the 'destination' property of the first provided document object.
    Each document is expected to be a C<LaTeXML::Post::Document> object.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>,
Deyan Ginev <deyan.ginev@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
