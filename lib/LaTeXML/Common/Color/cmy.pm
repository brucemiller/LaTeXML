# /=====================================================================\ #
# |  LaTeXML::Common::Color::cmy                                        | #
# | A representation of colors in the cmy color model                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::cmy;
use strict;
use warnings;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;
use List::Util qw(min max);

sub cmy {
  my ($self) = @_;
  return $self; }

sub rgb {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('rgb', 1 - $$self[1], 1 - $$self[2], 1 - $$self[3]); }

sub hsb {
  my ($self) = @_;
  return $self->rgb->hsb; }

sub gray {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('gray', 1 - (0.3 * $$self[1] + 0.59 * $$self[2] + 0.11 * $$self[3])); }

sub cmyk {
  my ($self) = @_;
  my ($model, $c, $m, $y) = @$self;
  # These beta parameters are linear coefficients for "undercolor-removal", and "black-generation"
  # In xcolor, they could come from \adjustUCRBG
  my ($bc, $bm, $by, $bk) = (1, 1, 1, 1);
  my $k = min($c, min($m, $y));
  return LaTeXML::Common::Color->new('cmyk', min(1, max(0, $c - $bc * $k)),
    min(1, max(0, $m - $bm * $k)),
    min(1, max(0, $y - $by * $k)),
    $bk * $k); }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::cmy> - represents colors in the cmy color model:
cyan, magenta and yellow [0..1];
extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
