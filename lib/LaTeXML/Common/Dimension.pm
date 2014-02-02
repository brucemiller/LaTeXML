# /=====================================================================\ #
# |  LaTeXML::Common::Dimension                                         | #
# | Representation of Dimensions                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Dimension;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use base qw(LaTeXML::Common::Number);
use base qw(Exporter);
our @EXPORT = (qw(&Dimension));

#======================================================================
# Exported constructor.

sub Dimension {
  my ($scaledpoints) = @_;
  return LaTeXML::Common::Dimension->new($scaledpoints); }

#======================================================================

sub new {
  my ($class, $sp) = @_;
  $sp = "0" unless $sp;
  if ($sp =~ /^(-?\d*\.?\d*)([a-zA-Z][a-zA-Z])$/) {    # Dimensions given.
    $sp = $1 * $STATE->convertUnit($2); }
  return bless [$sp || "0"], $class; }

sub toString {
  my ($self) = @_;
  return pointformat($$self[0]); }

sub toAttribute {
  my ($self) = @_;
  return attributeformat($$self[0]); }

sub stringify {
  my ($self) = @_;
  return "Dimension[" . $$self[0] . "]"; }

# Utility for formatting scaled points sanely.
sub pointformat {
  my ($sp) = @_;
  # As much as I'd like to make this more friendly & readable
  # there's TeX code that depends on getting enough precision
  # If you use %.5f, tikz (for example) will sometimes hang trying to do arithmetic!
  # But see toAttribute for friendlier forms....
  my $s = sprintf("%.6f", ($sp / 65536));
  $s =~ s/0+$// if $s =~ /\./;
  #  $s =~ s/\.$//;
  $s =~ s/\.$/.0/;    # Seems TeX prints .0 which in odd corner cases, people use?
  return $s . 'pt'; }

sub attributeformat {
  my ($sp) = @_;
  # As much as I'd like to make this more friendly & readable
  # there's TeX code that depends on getting enough precision
  # But see toAttribute for friendlier forms....
  my $s = sprintf("%.2f", ($sp / 65536));
  $s =~ s/0+$// if $s =~ /\./;
  #  $s =~ s/\.$//;
  $s =~ s/\.$/.0/;    # Seems TeX prints .0 which in odd corner cases, people use?
  return $s . 'pt'; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Dimension> - representation of dimensions;
extends L<LaTeXML::Common::Number>.

=head2 Exported functions

=over 4

=item C<< $dimension = Dimension($dim); >>

Creates a Dimension object.  C<$num> can be a string with the number and units
(with any of the usual TeX recognized units), or just a number standing for
scaled points (sp).

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

