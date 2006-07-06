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
use LaTeXML::Stomach;
use LaTeXML::Intestine;

use vars qw($VERSION);
$VERSION = "0.1.1";

#**********************************************************************
sub new {
  my($class,%options)=@_;
  bless {stomach => LaTeXML::Stomach->new(%options)}, $class;
}

sub digestFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  $$self{stomach}->readAndDigestFile("$name.tex"); }

sub convertFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  my $digested = $self->digestFile($name);
  return unless $digested;
  LaTeXML::Intestine->new($$self{stomach})->buildDOM($digested); }

sub convertAndWriteFile {
  my($self,$name)=@_;
  $name =~ s/\.tex$//;
  my $dom = $self->convertFile($name);
  $self->writeDOM($dom,$name) if $dom; }

sub writeDOM {
  my($self,$dom,$name)=@_;
  my $domstring = $dom->toString;
  open(OUT,">:utf8","$name.xml") || die "Failed to open $name.xml for writing: $!";
  $dom->serialize(\*OUT);
  close(OUT); 
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

=item C<< $latexml->digestFile($name); >>

Reads the TeX file $name, and digests it returning the L<LaTeXML::List> representation.

=item C<< $latexml->convertFile($name); >>

Reads the TeX file $name, digests and converts it to XML, returning the L<LaTeXML::DOM> representation.

=item C<< $latexml->convertAndWriteFile($name); >>

Reads the TeX file $name, digests and converts it to XML, and saves it in $name.xml.

=item C<< $latexml->writeDOM($dom,$name); >>

Given the L<LaTeXML::DOM> reprsentation of a converted TeX file, this saves it in $name.xml.

=back

=head2 SEE ALSO

See L<LaTeXML::Mouth>, L<LaTeXML::Gullet>  L<LaTeXML::Stomach>
and L<LaTeXML::Intestine> for documentation on the digestive tract.
See L<LaTeXML::Token>, L<LaTeXML::Box>, and L<LaTeXML::DOM>
for documentation of the objects representing the document.
See L<LaTeXML::Package> and L<LaTeXML::Definition> for documentation
for implementing LaTeX macros and packages.

=cut

