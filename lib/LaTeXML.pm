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
use LaTeXML::Gullet;
use LaTeXML::Stomach;
use LaTeXML::Document;
use LaTeXML::Model;
use LaTeXML::Object;
use LaTeXML::MathParser;
our @ISA = (qw(LaTeXML::Object));

#use LaTeXML::Document;

use vars qw($VERSION);
$VERSION = "0.2.99";

#**********************************************************************
# What a Mess of Globals!
#**********************************************************************

sub new {
  my($class,%options)=@_;
  my $state     = LaTeXML::State->new(catcodes=>'standard'),
  my $stomach   = LaTeXML::Stomach->new(%options);
  bless {state   => $state, stomach => $stomach, 
	 model   => $options{model} || LaTeXML::Model->new(),
	 verbosity => $options{verbosity} || 0,
	 strict    => $options{strict} || 0,
	 nomathparse=>$options{nomathparse}||0,
	}, $class; }


sub convertAndWriteFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  my $dom = $self->convertFile($name);
  $self->writeDOM($dom,$name) if $dom; }

sub convertFile {
  my($self,$name)=@_;
  my $digested = $self->digestFile($name);
  return unless $digested;
  my $doc = $self->convertDocument($digested);
  $doc; }

sub convertString {
  my($self,$string)=@_;
  my $digested = $self->digestString($string);
  return unless $digested;
  my $doc = $self->convertDocument($digested);
  $doc; }


sub digestFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;

  local $LaTeXML::Global::VERBOSITY  = $$self{verbosity};
  local $LaTeXML::Global::STRICT     = $$self{strict};
  local $STATE      = $$self{state};
  local $GULLET     = LaTeXML::Gullet->new();
  local $STOMACH    = $$self{stomach}; # The current Stomach; all state is stored here.
  local $MODEL      = $$self{model};   # The document model.
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__} = sub { LaTeXML::Error::Fatal(join('',@_)); };

  $$self{stomach}->readAndDigestFile($name); }

sub digestString {
  my($self,$string)=@_;

  local $LaTeXML::Global::VERBOSITY  = $$self{verbosity};
  local $LaTeXML::Global::STRICT     = $$self{strict};
  local $STATE      = $$self{state};
  local $GULLET     = LaTeXML::Gullet->new();
  local $STOMACH    = $$self{stomach}; # The current Stomach; all state is stored here.
  local $MODEL      = $$self{model};   # The document model.
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__} = sub { LaTeXML::Error::Fatal(join('',@_)); };

  $$self{stomach}->readAndDigestString($string); }

sub convertDocument {
  my($self,$digested)=@_;
  local $LaTeXML::Global::VERBOSITY  = $$self{verbosity};
  local $LaTeXML::Global::STRICT     = $$self{strict};
  local $STATE      = $$self{state};
  local $GULLET     = LaTeXML::Gullet->new();
  local $STOMACH    = $$self{stomach}; # The current Stomach; all state is stored here.
  local $MODEL      = $$self{model};   # The document model.

  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__} = sub { LaTeXML::Error::Fatal(join('',@_)); };
  $LaTeXML::MODEL->loadDocType([$LaTeXML::STOMACH->getSearchPaths]); # If needed?

  local $LaTeXML::DUAL_BRANCH= '';
  my $document  = LaTeXML::Document->new();

  NoteProgress("\n(Building");
  $document->absorb($digested);
  NoteProgress(")");

  NoteProgress("\n(Rewriting");
  $MODEL->applyRewrites($document,$document->getDocument->documentElement);
  NoteProgress(")");

  LaTeXML::MathParser->new()->parseMath($document) unless $$self{nomathparse};
  my $xml = $document->finalize();
  $xml; }

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

=head1 LaTeXML

=head2 DESCRIPTION

LaTeXML transforms TeX into XML.

=head2 SYNOPSIS

    use LaTeXML;
    my $latexml = LaTeXML->new();
    $latexml->convertAndWrite("adocument");

=head2 METHODS

=over 4

=item C<< my $latexml = LaTeXML->new(%options); >>

Creates a new LaTeXML object for transforming TeX files into XML. Options are:

   verbosity : 0 is the default, more positive makes it more verbose,
               more negative, quieter.
   strict    : If true, undefined control sequences and invalid document
               constructs give fatal errors, instead of warnings.

The following options are passed on to the created L<LaTeXML::Stomach>:

   preload         : an array of modules to preload
   searchpath      : an array of paths to be searched for Packages and style files.
   includeComments : If false, comments will be excluded from the result document.

=item C<< $latexml->convertAndWriteFile($name); >>

Reads the TeX file C<$name>, digests and converts it to XML, and saves it in C<$name>.xml.

=item C<< $latexml->convertFile($name); >>

Reads the TeX file C<$name>, digests and converts it to XML and returns the L<XML::LibXML::Document>.

=item C<< $latexml->digestFile($name); >>

Reads the TeX file C<$name>, and digests it returning the L<LaTeXML::List> representation.

=item C<< $latexml->writeDOM($dom,$name); >>

Deprecated: Given the L<XML::LibXML::Document> reprsentation of a converted TeX file, 
this saves it in $name.xml.

=back

=head2 SEE ALSO

See L<LaTeXML::Mouth>, L<LaTeXML::Gullet> and  L<LaTeXML::Stomach>
for documentation on the digestive tract.
See L<LaTeXML::Token>, L<LaTeXML::Box>, and L<LaTeXML::Document>
for documentation of the data objects representing the document.
See L<LaTeXML::Package> and L<LaTeXML::Definition> for documentation
for implementing LaTeX macros and packages.

=cut

