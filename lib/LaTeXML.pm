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
use Encode;
our @ISA = (qw(LaTeXML::Object));

#use LaTeXML::Document;

use vars qw($VERSION);
$VERSION = "0.7.9alpha";

#**********************************************************************

sub new {
  my($class,%options)=@_;
  my $state     = LaTeXML::State->new(catcodes=>'standard',
				      stomach=>LaTeXML::Stomach->new(),
				      model  => $options{model} || LaTeXML::Model->new());
  $state->assignValue(VERBOSITY=>(defined $options{verbosity} ? $options{verbosity} : 0),
		      'global');
  $state->assignValue(STRICT   =>(defined $options{strict}   ? $options{strict}     : 0),
		      'global');
  $state->assignValue(INCLUDE_COMMENTS=>(defined $options{includeComments} ? $options{includeComments} : 1),
		      'global');
  $state->assignValue(DOCUMENTID=>(defined $options{documentid} ? $options{documentid} : ''),
		      'global');
  $state->assignValue(SEARCHPATHS=> [ map(pathname_absolute(pathname_canonical($_)),
					  @{$options{searchpaths} || []})], 'global');
  $state->assignValue(GRAPHICSPATHS=> [ map(pathname_absolute(pathname_canonical($_)),
					    @{$options{graphicspaths} || []}) ],'global');
  $state->assignValue(INCLUDE_STYLES=>$options{includeStyles}|| 0,'global');
  $state->assignValue(PERL_INPUT_ENCODING=>$options{inputencoding}) if $options{inputencoding};
  bless {state   => $state, 
	 nomathparse=>$options{nomathparse}||0,
	 preload=>$options{preload},
	}, $class; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# High-level API.

sub convertAndWriteFile {
  my($self,$file)=@_;
  $file =~ s/\.tex$//;
  my $dom = $self->convertFile($file);
  $dom->toFile("$file.xml",1) if $dom; }

sub convertFile {
  my($self,$file)=@_;
  my $digested = $self->digestFile($file);
  return unless $digested;
  $self->convertDocument($digested); }

sub convertString {
  my($self,$string)=@_;
  my $digested = $self->digestString($string);
  return unless $digested;
  $self->convertDocument($digested); }


sub getStatusMessage {
  my($self)=@_;
  $$self{state}->getStatusMessage; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Mid-level API.

# options are currently being evolved to accomodate the Daemon:
#    noinitialize : if defined, it does not initialize State.
#    preamble = names a tex file (or standard_preamble.tex)
#    postamble = names a tex file (or standard_postamble.tex)
sub digestFile {
  my($self,$file,%options)=@_;
  $file =~ s/\.tex$//;
  $self->withState(sub {
     my($state)=@_;
     NoteBegin("Digesting $file");
     $self->initializeState('TeX.pool', @{$$self{preload} || []}) unless $options{noinitialize};

     my $pathname = pathname_find($file,types=>['tex','']);
     Fatal(":missing_file:$file Cannot find TeX file $file") unless $pathname;
     my($dir,$name,$ext)=pathname_split($pathname);
     $state->assignValue(SOURCEFILE=>$pathname);
     $state->assignValue(SOURCEDIRECTORY=>$dir);
     $state->unshiftValue(SEARCHPATHS=>$dir) unless grep($_ eq $dir, @{$state->lookupValue('SEARCHPATHS')});
     $state->unshiftValue(GRAPHICSPATHS=>$dir) unless grep($_ eq $dir, @{$state->lookupValue('GRAPHICSPATHS')});

     $state->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,
							Tokens(Explode($name))));
     my $stomach=$state->getStomach;
     my @stuff=();
     push(@stuff,$self->loadPreamble($options{preamble})) if $options{preamble};

     $stomach->getGullet->input($pathname);
     while($stomach->getGullet->getMouth->hasMoreInput){
       push(@stuff,$stomach->digestNextBody); }

     push(@stuff,$self->loadPostamble($options{postamble})) if $options{postamble};
#     my $list = $self->finishDigestion;
     my $list = LaTeXML::List->new(@stuff);
     NoteEnd("Digesting $file");
     $list; });
}
sub digestString {
  my($self,$string, %options)=@_;
  $self->withState(sub {
     my($state)=@_;
     NoteBegin("Digesting string");
     $self->initializeState('TeX.pool', @{$$self{preload} || []})  unless $options{noinitialize};

     my $stomach=$state->getStomach;
     my @stuff=();

     push(@stuff,$self->loadPreamble($options{preamble})) if $options{preamble};

     $stomach->getGullet->openMouth(LaTeXML::Mouth->new($string),0);
     while($stomach->getGullet->getMouth->hasMoreInput){
       push(@stuff,$stomach->digestNextBody); }

     push(@stuff,$self->loadPostamble($options{postamble})) if $options{postamble};

     # my $list = $self->finishDigestion;
     my $list = LaTeXML::List->new(@stuff);
     NoteEnd("Digesting string");
     $list; });
}

# pre/postamble ????

sub digestBibTeXFile {
  my($self,$file, %options)=@_;
  $file =~ s/\.bib$//;
  $self->withState(sub {
     my($state)=@_;
     NoteBegin("Digesting bibliography $file");
     # NOTE: This is set up to do BibTeX for LaTeX (not other flavors, if any)
     $self->initializeState('TeX.pool','LaTeX.pool', 'BibTeX.pool', @{$$self{preload} || []})
       unless $options{noinitialize};
     my $pathname = pathname_find($file,types=>['bib','']);
     Fatal(":missing_file:$file Cannot find TeX file $file") unless $pathname;
     my $bib = LaTeXML::Bib->newFromFile($file);
     my($dir,$name,$ext)=pathname_split($pathname);
     $state->unshiftValue(SEARCHPATHS=>$dir) unless grep($_ eq $dir, @{$state->lookupValue('SEARCHPATHS')});
     $state->unshiftValue(GRAPHICSPATHS=>$dir) unless grep($_ eq $dir, @{$state->lookupValue('GRAPHICSPATHS')});

     $state->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,
							Tokens(Explode($name))));
     # This is handled by the gullet for TeX files, but we're doing a batch of string processing first.
     # Nevertheless, we'd like access to state & variables during that string processing.
     $state->getStomach->getGullet->inputConfigfile($name); #  Load configuration for this source, if any.

     my $tex = $bib->toTeX;
     $state->getStomach->getGullet->openMouth(LaTeXML::Mouth->new($tex),0);
     my $line = $self->finishDigestion;
     NoteEnd("Digesting bibliography $file");
     $line; });
}

sub finishDigestion {
  my($self)=@_;
  my $state = $$self{state};
  my $stomach  = $state->getStomach; # The current Stomach;
  my $list = LaTeXML::List->new($stomach->digestNextBody);
  if(my $env = $state->lookupValue('current_environment')){
    Error(":expected:\\end{$env} Input ended while environment $env was open"); } 
  $stomach->getGullet->flush;
  $list; }

sub loadPreamble {
  my($self,$preamble)=@_;
  my $state = $$self{state};
  my $stomach  = $state->getStomach; # The current Stomach;
  my @stuff = ();
  if($preamble eq 'standard_preamble.tex'){
     $stomach->getGullet->openMouth(LaTeXML::Mouth->new('\documentclass{article}\begin{document}'),0); }
  else {
     $stomach->getGullet->input($preamble); }
  while($stomach->getGullet->getMouth->hasMoreInput){
    push(@stuff,$stomach->digestNextBody); }
  LaTeXML::List->new(@stuff); }

sub loadPostamble {
  my($self,$postamble)=@_;
  my $state = $$self{state};
  my $stomach  = $state->getStomach; # The current Stomach;
  my @stuff = ();
  if($postamble eq 'standard_postamble.tex'){
     $stomach->getGullet->openMouth(LaTeXML::Mouth->new('\end{document}'),0); }
  else {
     $stomach->getGullet->input($postamble); }
  while($stomach->getGullet->getMouth->hasMoreInput){
    push(@stuff,$stomach->digestNextBody); }
  LaTeXML::List->new(@stuff); }

sub convertDocument {
  my($self,$digested)=@_;
  $self->withState(sub {
     my($state)=@_;
     my $model    = $state->getModel;   # The document model.
     my $document  = LaTeXML::Document->new($model);
     NoteBegin("Building");
     $model->loadSchema(); # If needed?
     if(my $paths = $state->lookupValue('SEARCHPATHS')){
       if($state->lookupValue('INCLUDE_COMMENTS')){
	 $document->insertPI('latexml',searchpaths=>join(',',@$paths)); }}
     foreach my $preload (@{$$self{preload}}){
       next if $preload=~/\.pool$/;
       $preload =~ s/^\[([^\]]*)\]//;
       my $options = $1;
       $preload =~ s/\.sty$//;
       $document->insertPI('latexml',package=>$preload,options=>$options); }
     $document->absorb($digested);
     NoteEnd("Building");

     NoteBegin("Rewriting");
     $model->applyRewrites($document,$document->getDocument->documentElement);
     NoteEnd("Rewriting");

     LaTeXML::MathParser->new()->parseMath($document) unless $$self{nomathparse};
     NoteBegin("Finalizing");
     my $xmldoc = $document->finalize(); 
     NoteEnd("Finalizing");
     $xmldoc; }); }

sub withState {
  my($self,$closure)=@_;
  local $STATE    = $$self{state};
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__}  = sub { LaTeXML::Error::Fatal(join('',":perl:die ",@_)); };
  local $SIG{INT}      = sub { LaTeXML::Error::Fatal(join('',":perl:interrupt ",@_)); }; # ??
  local $SIG{__WARN__} = sub { LaTeXML::Error::Warn(join('',":perl:warn ",@_)); };
  local $LaTeXML::DUAL_BRANCH= '';

  &$closure($STATE); }

sub initializeState {
  my($self,@files)=@_;
  my $stomach  = $STATE->getStomach; # The current Stomach;
  my $gullet = $stomach->getGullet;
  $stomach->initialize;
  my $paths = $STATE->lookupValue('SEARCHPATHS');
  foreach my $preload (@files){
    $preload =~ s/^\[([^\]]*)\]//;
    my $options = $1;
    $preload =~ s/\.(\w+)$//;
    my $type = $1 || 'sty';
    my $handleoptions = ($type eq 'sty')||($type eq 'cls');
    if($options){
      if($handleoptions){
	$options = [split(/,/,$options)]; }
      else {
	Warn(":unexpected:options Attempting to pass options [$options] to $preload.$type"
	   ."which is not a style or class file"); }}
    LaTeXML::Package::InputDefinitions($preload,type=>$type,
				       handleoptions=>$handleoptions, options=>$options)
      || Fatal(":missing_file:$preload.$type Couldn't find $preload.$type to preload"); }

  # NOTE: This is seemingly a result of a not-quite-right
  # processing model.  Opening a new mouth to tokenize & digest
  # the bibtex material lets the macros do the right-thing as far as
  # catcodes, etc.
  # HOWEVER, it goes in at the FRONT of the line; pending preloads
  # may not get finished.
  # Probably the right solution is to immediately process included, interpreted, style files?
  my @pending = ();
  while($gullet->getMouth->hasMoreInput){
    push(@pending,$stomach->digestNextBody); }
  @pending = map($_->unlist,@pending);
  if(@pending){
    Warn(":unexpected:<boxes> Got boxes from preloaded modules: ".join(Stringify($_),@pending));}
}

sub writeDOM {
  my($self,$dom,$name)=@_;
  $dom->toFile("$name.xml",1);
  1; }

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

Digests C<$string>, presumably containing TeX markup, converts it to XML
and returns the L<XML::LibXML::Document>.

=item C<< $latexml->writeDOM($doc,$name); >>

Writes the XML document to $name.xml. 

=item C<< $box = $latexml->digestFile($file); >>

Reads the TeX file C<$file>, and digests it returning the L<LaTeXML::Box> representation.

=item C<< $box = $latexml->digestString($string); >>

Digests C<$string>, which presumably contains TeX markup,
returning the L<LaTeXML::Box> representation.

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
