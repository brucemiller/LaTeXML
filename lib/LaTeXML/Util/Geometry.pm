package LaTeXML::Util::Geometry;
use strict;
use LaTeXML::Global;
use LaTeXML::Number;
use Math::Trig;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (qw(&coordList &explodeCoord &radians &trunc &round &lineParams &pointPointDist
		  &linePointDist &lineIntersect &lineAngle));

our $eps = 0.000001;

sub coordList {
    my @points = @_; my ($l, $spc) = ('', '');
    foreach (@points) {
	$l.=$spc.$_; 
	if ($spc eq ' ' || $spc eq '') {$spc = ',';}
	elsif ($spc eq ',') {$spc = ' ';}}
    $l; }

sub explodeCoord {
    my ($pts) = @_; return () unless $pts;
    $pts =~ s/,/ /g; $pts =~ s/\s+/ /g; $pts =~ s/^\s+//; $pts =~ s/\s+$//;
    split(/ /, $pts); }

sub radians { $#_>0 ? map(deg2rad($_), @_) : deg2rad($_[0]); }

sub trunc {
    my ($d, @ns) = @_; $d = 10**$d;
    for (my $i=0; $i<=$#ns; $i++) { $ns[$i] = round($ns[$i]*$d)/$d; }
    $#ns>0 ? @ns : $ns[0]; }

sub round { int($_[0]+0.5*($_[0] <=> 0)); }

sub lineParams {
  my ($P, $angle, $perpendicular) = @_;
  $angle = radians($angle); my ($c, $s) = (cos($angle), sin($angle));
  my ($la, $lb) = $perpendicular ? (abs($c)>$eps ? (1, $s/$c) : (0, 1)) : (abs($c)>$eps ? (-$s/$c, 1) : (1, 0));
  my $lc = - $la * $P->getX->valueOf - $lb * $P->getY->valueOf;
  ($la, $lb, $lc); }

sub pointPointDist {
  my ($P1, $P2) = @_;
  sqrt($P1->getX->subtract($P2->getX)->valueOf()**2 + $P1->getY->subtract($P2->getY)->valueOf()**2); }

sub linePointDist {
  my ($P, @l) = @_;
  abs($l[0]*$P->getX->valueOf + $l[1]*$P->getY->valueOf + $l[2])/sqrt($l[0]**2+$l[1]**2); }

sub lineIntersect {
  my ($l1, $l2) = @_; my ($la, $lb, $lc) = @{$l1}; my ($La, $Lb, $Lc) = @{$l2};
  Pair(Dimension(($lb*$Lc-$Lb*$lc)/($la*$Lb-$La*$lb)), Dimension(($la*$Lc-$La*$lc)/($La*$lb-$la*$Lb))); }

sub lineAngle {
    my ($A, $B) = @_;
    rad2deg(atan2($B->getY->subtract($A->getY)->valueOf, $B->getX->subtract($A->getX)->valueOf)); }

1;
