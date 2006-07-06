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
use LaTeXML::Global;
use LaTeXML::Error;
use LaTeXML::Gullet;
use LaTeXML::Stomach;
use LaTeXML::Model;
use LaTeXML::Object;
our @ISA = (qw(LaTeXML::Object));

#use LaTeXML::Intestine;

use vars qw($VERSION);
$VERSION = "0.2.0";

#**********************************************************************
sub new {
  my($class,%options)=@_;
  bless {stomach => LaTeXML::Stomach->new(%options),
	 model   => $options{model} || LaTeXML::Model->new(),
	 verbosity => $options{verbosity} || 0,
	 strict    => $options{strict} || 0,
	}, $class; }

sub digestFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;

  local $LaTeXML::Global::VERBOSITY  = $$self{verbosity};
  local $LaTeXML::Global::STRICT     = $$self{strict};
  local $GULLET     = LaTeXML::Gullet->new();
  local $STOMACH    = $$self{stomach}; # The current Stomach; all state is stored here.
  local $MODEL      = $$self{model};   # The document model.
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__} = sub { LaTeXML::Error::Fatal(join('',@_)); };

  $$self{stomach}->readAndDigestFile($name); }

sub convertFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  my $digested = $self->digestFile($name);
  return unless $digested;
  require LaTeXML::Intestine;
  local $LaTeXML::Global::VERBOSITY  = $$self{verbosity};
  local $LaTeXML::Global::STRICT     = $$self{strict};
  local $STOMACH    = $$self{stomach}; # The current Stomach; all state is stored here.
  local $MODEL      = $$self{model};   # The document model.
  local $INTESTINE  = LaTeXML::Intestine->new($$self{stomach});
  local $LaTeXML::DUAL_BRANCH= '';
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__} = sub { LaTeXML::Error::Fatal(join('',@_)); };

  $LaTeXML::MODEL->loadDocType([$LaTeXML::STOMACH->getSearchPaths]); # If needed?
  $LaTeXML::INTESTINE->buildDOM($digested); }

sub convertAndWriteFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  my $dom = $self->convertFile($name);
  $self->writeDOM($dom,$name) if $dom; }

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

See L<LaTeXML::Mouth>, L<LaTeXML::Gullet>,  L<LaTeXML::Stomach>
and L<LaTeXML::Intestine> for documentation on the digestive tract.
See L<LaTeXML::Token>, L<LaTeXML::Box>, and L<LaTeXML::Node>
for documentation of the data objects representing the document.
See L<LaTeXML::Package> and L<LaTeXML::Definition> for documentation
for implementing LaTeX macros and packages.

=cut

