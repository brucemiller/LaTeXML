# /=====================================================================\ #
# |  LaTeXML::Common::Color::cmyk                                       | #
# | A representation of colors in the cmyk color model                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::cmyk;
use strict;
use warnings;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;
use List::Util qw(min max);

sub cmyk {
  my ($self) = @_;
  return $self; }

sub cmy {
  my ($self) = @_;
  my ($model, $c, $m, $y, $k) = @$self;
  return LaTeXML::Common::Color->new('cmy', min(1, $c + $k), min(1, $m + $k), min(1, $y + $k)); }

sub rgb {
  my ($self) = @_;
  return $self->cmy->rgb; }

sub hsb {
  my ($self) = @_;
  return $self->cmy->hsb; }

sub gray {
  my ($self) = @_;
  my ($model, $c, $m, $y, $k) = @$self;
  return LaTeXML::Common::Color->new('gray', 1 - min(1, 0.3 * $c + 0.59 * $m + 0.11 * $y + $k)); }

sub complement {
  my ($self) = @_;
  return $self->cmy->complement->cmyk; }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::cmyk> - represents colors in the cmyk color model:
cyan, magenta, yellow and black in [0..1];
extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
