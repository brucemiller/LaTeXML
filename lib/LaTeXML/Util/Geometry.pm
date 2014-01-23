package LaTeXML::Util::Geometry;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use LaTeXML::Core::Pair;
use Math::Trig;
use base qw(Exporter);
our @EXPORT = (qw(&coordList &explodeCoord &radians &trunc &round &lineParams &pointPointDist
    &linePointDist &lineIntersect &lineAngle));

my $eps = 0.000001;    # [CONSTANT]

sub coordList {
  my @points = @_; my ($l, $spc) = ('', '');
  foreach (@points) {
    $l .= $spc . $_;
    if ($spc eq ' ' || $spc eq '') { $spc = ','; }
    elsif ($spc eq ',') { $spc = ' '; } }
  return $l; }

sub explodeCoord {
  my ($pts) = @_; return () unless $pts;
  $pts =~ s/,/ /g; $pts =~ s/\s+/ /g; $pts =~ s/^\s+//; $pts =~ s/\s+$//;
  return split(/ /, $pts); }

sub radians {
  my (@angles) = @_;
  return scalar(@angles) == 1 ? deg2rad($angles[0]) : map { deg2rad($_) } @angles; }

sub trunc {
  my ($d, @ns) = @_;
  $d = 10**$d;
  return (scalar(@ns) == 1 ? round($ns[0] * $d) / $d : map { round($_ * $d) / $d } @ns); }

sub round {
  my ($n) = @_;
  return int($n + 0.5 * ($n <=> 0)); }

sub lineParams {
  my ($P, $angle, $perpendicular) = @_;
  $angle = radians($angle); my ($c, $s) = (cos($angle), sin($angle));
  my ($la, $lb) = $perpendicular ? (abs($c) > $eps ? (1, $s / $c) : (0, 1)) : (abs($c) > $eps ? (-$s / $c, 1) : (1, 0));
  my $lc = -$la * $P->getX->valueOf - $lb * $P->getY->valueOf;
  return ($la, $lb, $lc); }

sub pointPointDist {
  my ($P1, $P2) = @_;
  return sqrt($P1->getX->subtract($P2->getX)->valueOf()**2
      + $P1->getY->subtract($P2->getY)->valueOf()**2); }

sub linePointDist {
  my ($P, @l) = @_;
  return abs($l[0] * $P->getX->valueOf + $l[1] * $P->getY->valueOf + $l[2])
    / sqrt($l[0]**2 + $l[1]**2); }

sub lineIntersect {
  my ($l1, $l2) = @_; my ($la, $lb, $lc) = @{$l1}; my ($La, $Lb, $Lc) = @{$l2};
  return Pair(Dimension(($lb * $Lc - $Lb * $lc) / ($la * $Lb - $La * $lb)),
    Dimension(($la * $Lc - $La * $lc) / ($La * $lb - $la * $Lb))); }

sub lineAngle {
  my ($A, $B) = @_;
  return rad2deg(atan2($B->getY->subtract($A->getY)->valueOf, $B->getX->subtract($A->getX)->valueOf)); }

1;
