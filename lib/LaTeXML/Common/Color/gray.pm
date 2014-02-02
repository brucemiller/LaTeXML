# /=====================================================================\ #
# |  LaTeXML::Common::Color::gray                                       | #
# | A representation of colors in the gray color model                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::gray;
use strict;
use warnings;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;

sub gray {
  my ($self) = @_;
  return $self; }

sub rgb {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('rgb', $$self[1], $$self[1], $$self[1]); }

sub cmy {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('cmy', 1 - $$self[1], 1 - $$self[1], 1 - $$self[1]); }

sub cmyk {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('cmy', 0, 0, 0, 1 - $$self[1]); }

sub hsb {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('hsb', 0, 0, $$self[1]); }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::gray> - represents colors in the gray color model:
gray value in [0..1];
extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
