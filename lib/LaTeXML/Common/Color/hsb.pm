# /=====================================================================\ #
# |  LaTeXML::Common::Color::hsb                                        | #
# | A representation of colors in the hsb color model                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::hsb;
use strict;
use warnings;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;

sub hsb { my ($self) = @_; return $self; }

sub rgb {
  my ($self) = @_;
  my ($model, $h, $s, $b) = @$self;
  my $i = int(6 * $h);
  my $f = 6 * $h - $i;
  my $u = $b * (1 - $s * (1 - $f));
  my $v = $b * (1 - $s * $f);
  my $w = $b * (1 - $s);
  if    ($i == 0) { return LaTeXML::Common::Color->new('rgb', $b, $u, $w); }
  elsif ($i == 1) { return LaTeXML::Common::Color->new('rgb', $v, $b, $w); }
  elsif ($i == 2) { return LaTeXML::Common::Color->new('rgb', $w, $b, $u); }
  elsif ($i == 3) { return LaTeXML::Common::Color->new('rgb', $w, $v, $b); }
  elsif ($i == 4) { return LaTeXML::Common::Color->new('rgb', $u, $w, $b); }
  elsif ($i == 5) { return LaTeXML::Common::Color->new('rgb', $b, $w, $v); }
  elsif ($i == 6) { return LaTeXML::Common::Color->new('rgb', $b, $w, $w); } }

sub cmy  { my ($self) = @_; return $self->rgb->cmy; }
sub cmyk { my ($self) = @_; return $self->rgb->cmyk; }
sub gray { my ($self) = @_; return $self->rgb->gray; }

sub complement {
  my ($self) = @_;
  my ($h, $s, $b) = $self->components;
  my $hp = ($h < 0.5 ? $h + 0.5 : $h - 0.5);
  my $bp = 1 - $b * (1 - $s);
  my $sp = ($bp == 0 ? 0 : $b * $s / $bp);
  return $self->new($hp, $sp, $bp); }

sub mix {
  my ($self, $color, $fraction) = @_;
  # I don't quite follow what Kern's saying, on a quick read,
  # so we'll punt by doing the conversion in rgb space, then converting back.
  return $self->rgb->mix($color, $fraction)->hsb; }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::hsb> - represents colors in the hsb color model:
hue, saturation, brightness in [0..1];
extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
