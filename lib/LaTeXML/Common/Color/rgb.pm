# /=====================================================================\ #
# |  LaTeXML::Common::Color::rgb                                        | #
# | A representation of colors in the rgb color model                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::rgb;
use strict;
use warnings;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;

sub rgb {
  my ($self) = @_;
  return $self; }

# Convert to cmy, cmyk,
sub cmy {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('cmy', 1 - $$self[1], 1 - $$self[2], 1 - $$self[3]); }

sub cmyk {
  my ($self) = @_;
  return $self->cmy->cmyk; }

sub gray {
  my ($self) = @_;
  return LaTeXML::Common::Color->new('gray', 0.3 * $$self[1] + 0.59 * $$self[2] + 0.11 * $$self[3]); }

# See Section 6.3.1 in xcolor documentation Dr.Uwe Kern; xcolor.pdf
sub Phi {
  my ($x, $y, $z, $u, $v) = @_;
  return LaTeXML::Common::Color->new('hsb', ($u * ($x - $z) + $v * ($x - $y)) / (6 * ($x - $z)),
    ($x - $z) / $x,
    $x); }

sub hsb {
  my ($self) = @_;
  my ($m, $r, $g, $b) = @$self;
  my $i = 4 * ($r >= $g) + 2 * ($g >= $b) + ($b >= $r);
  if    ($i == 1) { return Phi($b, $g, $r, 3, 1); }
  elsif ($i == 2) { return Phi($g, $r, $b, 1, 1); }
  elsif ($i == 3) { return Phi($g, $b, $r, 3, -1); }
  elsif ($i == 4) { return Phi($r, $b, $g, 5, 1); }
  elsif ($i == 5) { return Phi($b, $r, $g, 5, -1); }
  elsif ($i == 6) { return Phi($r, $g, $b, 1, -1); }
  elsif ($i == 7) { return LaTeXML::Common::Color->new('hsb', 0, 0, $b); } }

my @hex = qw(0 1 2 3 4 5 6 7 8 9 A B C D E F);    # [CONSTANT]

sub hex2 {
  my ($n) = @_;
  return $hex[int($n / 16)] . $hex[$n % 16]; }

sub toHex {
  my ($self) = @_;
  my ($model, $r, $g, $b) = @$self;
  return '#' . hex2(int($r * 255 + 0.5)) . hex2(int($g * 255 + 0.5)) . hex2(int($b * 255 + 0.5)); }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::rgb> - represents colors in the rgb color model:
red, green and blue in [0..1];
extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
