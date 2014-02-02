# /=====================================================================\ #
# |  LaTeXML::Core::MuDimension                                         | #
# | Representation of Math Dimensions                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::MuDimension;
use LaTeXML::Global;
use strict;
use warnings;
use base qw(LaTeXML::Common::Dimension);
use base qw(Exporter);
our @EXPORT = (qw(&MuDimension));

#======================================================================
# Exported constructor.

sub MuDimension {
  my ($scaledpoints) = @_;
  return LaTeXML::Core::MuDimension->new($scaledpoints); }

#======================================================================

# A mu is 1/18th of an em in the current math font.
# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu
sub toString {
  my ($self) = @_;
  return LaTeXML::Common::Float::floatformat($$self[0] / 65536 * 1.8) . 'mu'; }

sub stringify {
  my ($self) = @_;
  return "MuDimension[" . $$self[0] . "]"; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MuDimension> - representation of math dimensions;
extends L<LaTeXML::Common::Dimension>.

=head2 Exported functions

=over 4

=item C<< $mudimension = MuDimension($dim); >>

Creates a MuDimension object; similar to Dimension.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

