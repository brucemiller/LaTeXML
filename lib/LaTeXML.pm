# -*- CPERL -*-
# /=====================================================================\ #
# |  LaTeXML                                                            | #
# | Main Module                                                         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Error;
use LaTeXML::State;
use LaTeXML::Stomach;
use LaTeXML::Document;
use LaTeXML::Model;
use LaTeXML::Object;
use LaTeXML::MathParser;
use LaTeXML::Util::Pathname;
use LaTeXML::Bib;
use LaTeXML::Package;
use LaTeXML::Version;
use Encode;
use FindBin;
use base qw(LaTeXML::Object);
use vars qw($VERSION);
use vars qw($VERSION $FULLVERSION $IDENTITY);

$VERSION = "0.7.9alpha";
# Derived, more informative version numbers
$FULLVERSION = "LaTeXML version $VERSION"
  . ($LaTeXML::Version::REVISION ? "; revision $LaTeXML::Version::REVISION" : '');
$IDENTITY = "$FindBin::Script ($FULLVERSION)";

#**********************************************************************

sub new {
  my ($class, %options) = @_;
  my $state = LaTeXML::State->new(catcodes => 'standard',
    stomach => LaTeXML::Stomach->new(),
    model => $options{model} || LaTeXML::Model->new());
  $state->assignValue(VERBOSITY => (defined $options{verbosity} ? $options{verbosity} : 0),
    'global');
  $state->assignValue(STRICT => (defined $options{strict} ? $options{strict} : 0),
    'global');
  $state->assignValue(INCLUDE_COMMENTS => (defined $options{includeComments} ? $options{includeComments} : 1),
    'global');
  $state->assignValue(DOCUMENTID => (defined $options{documentid} ? $options{documentid} : ''),
    'global');
  $state->assignValue(SEARCHPATHS => [map { pathname_absolute(pathname_canonical($_)) }
        @{ $options{searchpaths} || [] }],
    'global');
  $state->assignValue(GRAPHICSPATHS => [map { pathname_absolute(pathname_canonical($_)) }
        @{ $options{graphicspaths} || [] }], 'global');
  $state->assignValue(INCLUDE_STYLES => $options{includeStyles} || 0, 'global');
  $state->assignValue(PERL_INPUT_ENCODING => $options{inputencoding}) if $options{inputencoding};
  return bless { state => $state,
    nomathparse => $options{nomathparse} || 0,
    preload => $options{preload},
    }, $class; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# High-level API.

sub convertAndWriteFile {
  my ($self, $file) = @_;
  $file =~ s/\.tex$//;
  my $dom = $self->convertFile($file);
  $dom->toFile("$file.xml", 1) if $dom;
  return $dom; }

sub convertFile {
  my ($self, $file) = @_;
  my $digested = $self->digestFile($file);
  return unless $digested;
  return $self->convertDocument($digested); }

sub getStatusMessage {
  my ($self) = @_;
  return $$self{state}->getStatusMessage; }

sub getStatusCode {
  my ($self) = @_;
  return $$self{state}->getStatusCode; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Mid-level API.

# options are currently being evolved to accomodate the Daemon:
#    mode  : the processing mode, ie the pool to preload: TeX or BibTeX
#    noinitialize : if defined, it does not initialize State.
#    preamble = names a tex file (or standard_preamble.tex)
#    postamble = names a tex file (or standard_postamble.tex)

our %MODE_EXTENSION = (    # CONFIGURATION?
  TeX => 'tex', LaTeX => 'tex', AmSTeX => 'tex', BibTeX => 'bib');

sub digestFile {
  my ($self, $request, %options) = @_;
  my ($dir, $name, $ext);
  my $mode = $options{mode} || 'TeX';
  if (pathname_is_literaldata($request)) {
    $dir = undef; $ext = $MODE_EXTENSION{$mode};
    $name = "Anonymous String"; }
  elsif (pathname_is_url($request)) {
    $dir = undef; $ext = $MODE_EXTENSION{$mode};
    $name = $request;
  }
  else {
    $request =~ s/\.\Q$MODE_EXTENSION{$mode}\E$//;
    if (my $pathname = pathname_find($request, types => [$MODE_EXTENSION{$mode}, ''])) {
      $request = $pathname;
      ($dir, $name, $ext) = pathname_split($request); }
    else {
      $self->withState(sub {
          Fatal('missing_file', $request, undef, "Can't find $mode file $request"); }); } }
  return
    $self->withState(sub {
      my ($state) = @_;
      NoteBegin("Digesting $mode $name");
      $self->initializeState($mode . ".pool", @{ $$self{preload} || [] }) unless $options{noinitialize};
      $state->assignValue(SOURCEFILE      => $request) if (!pathname_is_literaldata($request));
      $state->assignValue(SOURCEDIRECTORY => $dir)     if defined $dir;
      $state->unshiftValue(SEARCHPATHS => $dir)
        if defined $dir && !grep { $_ eq $dir } @{ $state->lookupValue('SEARCHPATHS') };
      $state->unshiftValue(GRAPHICSPATHS => $dir)

        if defined $dir && !grep { $_ eq $dir } @{ $state->lookupValue('GRAPHICSPATHS') };

      $state->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'), undef,
          Tokens(Explode($name))));
      # Reverse order, since last opened is first read!
      $self->loadPostamble($options{postamble}) if $options{postamble};
      LaTeXML::Package::InputContent($request);
      $self->loadPreamble($options{preamble}) if $options{preamble};

      # Now for the Hacky part for BibTeX!!!
      if ($mode eq 'BibTeX') {
        my $bib = LaTeXML::Bib->newFromGullet($name, $state->getStomach->getGullet);
        LaTeXML::Package::InputContent("literal:" . $bib->toTeX); }
      my $list = $self->finishDigestion;
      NoteEnd("Digesting $mode $name");
      return $list; });
}

sub finishDigestion {
  my ($self)  = @_;
  my $state   = $$self{state};
  my $stomach = $state->getStomach;
  my @stuff   = ();
  while ($stomach->getGullet->getMouth->hasMoreInput) {
    push(@stuff, $stomach->digestNextBody); }
  if (my $env = $state->lookupValue('current_environment')) {
    Error('expected', "\\end{$env}", $stomach, "Input ended while environment $env was open"); }
  $stomach->getGullet->flush;
  return LaTeXML::List->new(@stuff); }

sub loadPreamble {
  my ($self, $preamble) = @_;
  my $gullet = $$self{state}->getStomach->getGullet;
  if ($preamble eq 'standard_preamble.tex') {
    $preamble = 'literal:\documentclass{article}\begin{document}'; }
  return LaTeXML::Package::InputContent($preamble); }

sub loadPostamble {
  my ($self, $postamble) = @_;
  my $gullet = $$self{state}->getStomach->getGullet;
  if ($postamble eq 'standard_postamble.tex') {
    $postamble = 'literal:\end{document}'; }
  return LaTeXML::Package::InputContent($postamble); }

sub convertDocument {
  my ($self, $digested) = @_;
  return
    $self->withState(sub {
      my ($state)  = @_;
      my $model    = $state->getModel;                 # The document model.
      my $document = LaTeXML::Document->new($model);
      local $LaTeXML::DOCUMENT = $document;
      NoteBegin("Building");
      $model->loadSchema();                            # If needed?
      if (my $paths = $state->lookupValue('SEARCHPATHS')) {
        if ($state->lookupValue('INCLUDE_COMMENTS')) {
          $document->insertPI('latexml', searchpaths => join(',', @$paths)); } }
      foreach my $preload (@{ $$self{preload} }) {
        next if $preload =~ /\.pool$/;
        my $options = ($preload =~ s/^\[([^\]]*)\]//) && $1;
        if ($preload =~ s/\.cls$//) {
          $document->insertPI('latexml', class => $preload, ($options ? (options => $options) : ())); }
        else {
          $preload =~ s/\.sty$//;
          $document->insertPI('latexml', package => $preload, ($options ? (options => $options) : ())); } }
      $document->absorb($digested);
      NoteEnd("Building");

      if (my $rules = $state->lookupValue('DOCUMENT_REWRITE_RULES')) {
        NoteBegin("Rewriting");
        foreach my $rule (@$rules) {
          $rule->rewrite($document, $document->getDocument->documentElement); }
        NoteEnd("Rewriting"); }

      LaTeXML::MathParser->new()->parseMath($document) unless $$self{nomathparse};
      NoteBegin("Finalizing");
      my $xmldoc = $document->finalize();
      NoteEnd("Finalizing");
      return $xmldoc; }); }

sub withState {
  my ($self, $closure) = @_;
  local $STATE = $$self{state};
  # And, set fancy error handler for ANY die!
  # Could be useful to distill the more common messages so they provide useful build statistics?
  local $SIG{__DIE__} = sub { LaTeXML::Error::perl_die_handler(@_); };
  local $SIG{INT} = sub { LaTeXML::Error::Fatal('perl', 'interrupt', undef, "LaTeXML was interrupted", @_); };
  local $SIG{__WARN__} = sub { LaTeXML::Error::perl_warn_handler(@_); };
  local $LaTeXML::DUAL_BRANCH = '';

  return &$closure($STATE); }

sub initializeState {
  my ($self, @files) = @_;
  my $state   = $$self{state};
  my $stomach = $state->getStomach;    # The current Stomach;
  my $gullet  = $stomach->getGullet;
  $stomach->initialize;
  my $paths = $state->lookupValue('SEARCHPATHS');
  foreach my $preload (@files) {
    my ($options, $type);
    $options = $1 if $preload =~ s/^\[([^\]]*)\]//;
    $type = ($preload =~ s/\.(\w+)$// ? $1 : 'sty');
    my $handleoptions = ($type eq 'sty') || ($type eq 'cls');
    if ($options) {
      if ($handleoptions) {
        $options = [split(/,/, $options)]; }
      else {
        Warn('unexpected', 'options',
          "Attempting to pass options to $preload.$type (not style or class)",
          "The options were  [$options]"); } }
    # Attach extension back if HTTP protocol:
    if (pathname_is_url($preload)) {
      $preload .= '.' . $type;
    }
    LaTeXML::Package::InputDefinitions($preload, type => $type,
      handleoptions => $handleoptions, options => $options);
  }
  return; }

sub writeDOM {
  my ($self, $dom, $name) = @_;
  $dom->toFile("$name.xml", 1);
  return 1; }

#**********************************************************************
# Should post processing be managed from here too?
# Problem: with current DOM setup, I pretty much have to write the
# file and reread it anyway...
# Also, want to inhibit loading an extreme number of classes if not needed.
#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML> - transforms TeX into XML.

=head1 SYNOPSIS

    use LaTeXML;
    my $latexml = LaTeXML->new();
    $latexml->convertAndWrite("adocument");

But also see the convenient command line script L<latexml> which suffices for most purposes.

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item C<< my $latexml = LaTeXML->new(%options); >>

Creates a new LaTeXML object for transforming TeX files into XML. 

 verbosity  : Controls verbosity; higher is more verbose,
              smaller is quieter. 0 is the default.
 strict     : If true, undefined control sequences and 
              invalid document constructs give fatal
              errors, instead of warnings.
 includeComments : If false, comments will be excluded
              from the result document.
 preload    : an array of modules to preload
 searchpath : an array of paths to be searched for Packages
              and style files.

(these generally set config variables in the L<LaTeXML::State> object)

=item C<< $latexml->convertAndWriteFile($file); >>

Reads the TeX file C<$file>.tex, digests and converts it to XML, and saves it in C<$file>.xml.

=item C<< $doc = $latexml->convertFile($file); >>

Reads the TeX file C<$file>, digests and converts it to XML and returns the
resulting L<XML::LibXML::Document>.

=item C<< $doc = $latexml->convertString($string); >>

B<OBSOLETE> Use C<$latexml->convertFile("literal:$string");> instead.

=item C<< $latexml->writeDOM($doc,$name); >>

Writes the XML document to $name.xml. 

=item C<< $box = $latexml->digestFile($file); >>

Reads the TeX file C<$file>, and digests it returning the L<LaTeXML::Box> representation.

=item C<< $box = $latexml->digestString($string); >>

B<OBSOLETE> Use C<$latexml->digestFile("literal:$string");> instead.

=item C<< $doc = $latexml->convertDocument($digested); >>

Converts C<$digested> (the L<LaTeXML::Box> reprentation) into XML,
returning the L<XML::LibXML::Document>.

=back

=head2 Customization

In the simplest case, LaTeXML will understand your source file and convert it
automatically.  With more complicated (realistic) documents, you will likely
need to make document specific declarations for it to understand local macros, 
your mathematical notations, and so forth.  Before processing a file
I<doc.tex>, LaTeXML reads the file I<doc.latexml>, if present.
Likewise, the LaTeXML implementation of a TeX style file, say
I<style.sty> is provided by a file I<style.ltxml>.

See L<LaTeXML::Package> for documentation of these customization and
implementation files.

=head1 SEE ALSO

See L<latexml> for a simple command line script.

See L<LaTeXML::Package> for documentation of these customization and
implementation files.

For cases when the high-level declarations described in L<LaTeXML::Package>
are not enough, or for understanding more of LaTeXML's internals, see

=over 2

=item  L<LaTeXML::State>

maintains the current state of processing, bindings or
variables, definitions, etc.

=item  L<LaTeXML::Token>, L<LaTeXML::Mouth> and L<LaTeXML::Gullet>

deal with tokens, tokenization of strings and files, and 
basic TeX sequences such as arguments, dimensions and so forth.

=item L<LaTeXML::Box> and  L<LaTeXML::Stomach>

deal with digestion of tokens into boxes.

=item  L<LaTeXML::Document>, L<LaTeXML::Model>, L<LaTeXML::Rewrite>

dealing with conversion of the digested boxes into XML.

=item L<LaTeXML::Definition> and L<LaTeXML::Parameters>

representation of LaTeX macros, primitives, registers and constructors.

=item L<LaTeXML::MathParser>

the math parser.

=item L<LaTeXML::Global>, L<LaTeXML::Error>, L<LaTeXML::Object>

other random modules.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
