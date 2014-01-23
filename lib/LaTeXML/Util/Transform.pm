package LaTeXML::Util::Transform;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use LaTeXML::Core::Pair;
use LaTeXML::Util::Geometry;
use Math::Trig;
use base qw(Exporter);
our @EXPORT = (qw(&Transform));

my $eps = 0.000001;    # [CONSTANT]

sub Transform {
  my (@args) = @_;
  return LaTeXML::Util::Transform->new(@args); }

sub new {
  my ($class, $transform) = @_; $transform = '' unless $transform;
  if (ref $transform eq 'ARRAY') { $transform = join(' ', @{$transform}); }
  if (ref $transform) { $transform = $transform->toString; }
  my $self = [1, 0, 0, 1, 0, 0];
  if ($transform) {
    $transform =~ s/,/ /g; $transform =~ s/\s+$//; $transform =~ s/\s+/ /g;
    while ($transform) {
      $transform =~ s/^\s//;
      if ($transform =~ s/^translate\(([^\s]+) ([^\)]+)\)//) {
        $self = _multiply($self, [1, 0, 0, 1, $1, $2]); }
      elsif ($transform =~ s/^translate\(([^\)\s]+)\)//) {
        $self = _multiply($self, [1, 0, 0, 1, $1, 0]); }
      elsif ($transform =~ s/^rotate\(([^\)\s]+)\)//) {
        my $angle = radians($1); my ($c, $s) = (cos($angle), sin($angle));
        $self = _multiply($self, [$c, $s, -$s, $c, 0, 0]); }
      elsif ($transform =~ s/^rotate\(([^\s]+) ([^\s]+) ([^\)]+)\)//) {
        my ($angle, $tx, $ty) = (radians($1), $2, $3); my ($c, $s) = (cos($angle), sin($angle));
        $self = _multiply($self, [$c, $s, -$s, $c, $tx * (1 - $c) + $ty * $s, $ty * (1 - $c) - $tx * $s]); }
      elsif ($transform =~ s/^scale\(([^\s]+) ([^\)]+)\)//) {
        $self = _multiply($self, [$1, 0, 0, $2, 0, 0]); }
      elsif ($transform =~ s/^scale\(([^\)\s]+)\)//) {
        $self = _multiply($self, [$1, 0, 0, $1, 0, 0]); }
      elsif ($transform =~ s/^skewX\(([^\)]+)\)//) {
        my $angle = radians($1); my ($c, $s) = (cos($angle), sin($angle));
        $self = _multiply($self, [1, 0, $s / $c, 1, 0, 0]) if $c != 0; }
      elsif ($transform =~ s/^skewY\(([^\)]+)\)//) {
        my $angle = radians($1); my ($c, $s) = (cos($angle), sin($angle));
        $self = _multiply($self, [1, $s / $c, 0, 1, 0, 0]) if $c != 0; }
      elsif ($transform =~ s/^matrix\(([^\s]+) ([^\s]+) ([^\s]+) ([^\s]+) ([^\s]+) ([^\)]+)\)//) {
        $self = _multiply($self, [$1, $2, $3, $4, $5, $6]); }
      else {
        Error('misdefined', '<transform>', undef, "Unable to parse transform '$transform'");
        last; } } }
  return bless($self, $class); }

sub isIdentity {
  my ($self) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  ($Tb, $Tc, $Te, $Tf) = map { abs($_) } $Tb, $Tc, $Te, $Tf;
  return ($Ta < 1 + $eps
      && $Ta > 1 - $eps
      && $Tb < $eps
      && $Tc < $eps
      && $Td < 1 + $eps
      && $Td > 1 - $eps
      && $Te < $eps
      && $Tf < $eps); }

sub isTranslation {
  my ($self) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  ($Tb, $Tc, $Te, $Tf) = map { abs($_) } $Tb, $Tc, $Te, $Tf;
  return ($Ta < 1 + $eps
      && $Ta > 1 - $eps
      && $Tb < $eps
      && $Tc < $eps
      && $Td < 1 + $eps
      && $Td > 1 - $eps
      && ($Te > $eps || $Tf > $eps)); }

sub isRotation {
  my ($self) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  return (abs($Ta - $Td) < $eps
      && abs($Tb + $Tc) < $eps
      && abs($Ta**2 + $Tb**2 - 1) < $eps
      && abs($Te) < $eps
      && abs($Tf) < $eps); }

sub isScaling {
  my ($self) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  ($Tb, $Tc, $Te, $Tf) = map { abs($_) } $Tb, $Tc, $Te, $Tf;
  return (($Ta > 1 + $eps || $Ta < 1 - $eps)
      && $Tb < $eps
      && $Tc < $eps
      && ($Td > 1 + $eps || $Td < 1 - $eps)
      && $Te < $eps
      && $Tf < $eps); }

sub inverse {
  my ($self) = @_;
  return bless(_inverse($self), ref $self); }

sub differenceTo {
  my ($self, $q) = @_;
  my $to = ($q && ref $q && (ref $self eq ref $q)) ? $q : (ref $self)->new($q);
  return bless(_multiply(_inverse($self), $to), ref $self); }

sub addPre {
  my ($self, $q) = @_;
  my $what = ($q && ref $q && (ref $self eq ref $q)) ? $q : (ref $self)->new($q);
  return bless(_multiply($what, $self), ref $self); }

sub addPost {
  my ($self, $q) = @_;
  my $what = ($q && ref $q && (ref $self eq ref $q)) ? $q : (ref $self)->new($q);
  return bless(_multiply($self, $what), ref $self); }

sub removePre {
  my ($self, $q) = @_;
  my $what = ($q && ref $q && (ref $self eq ref $q)) ? $q : (ref $self)->new($q);
  return bless(_multiply($self, _inverse($what)), ref $self); }

sub removePost {
  my ($self, $q) = @_;
  my $what = ($q && ref $q && (ref $self eq ref $q)) ? $q : (ref $self)->new($q);
  return bless(_multiply(_inverse($what), $self), ref $self); }

sub apply {
  my ($self, $x, $y) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  my $pair = 0;
  if (!defined $y) { $y = $x->getY->valueOf; $x = $x->getX->valueOf; $pair = 1; }
  my ($ax, $ay) = ($Ta * $x + $Tc * $y + $Te, $Tb * $x + $Td * $y + $Tf);
  return $pair ? Pair(Dimension($ax), Dimension($ay)) : ($ax, $ay); }

sub unapply {
  my ($self, $x, $y) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  my $pair = 0;
  if (!defined $y) { $y = $x->getY->valueOf; $x = $x->getX->valueOf; $pair = 1; }
  my $dt = $Ta * $Td - $Tb * $Tc; return unless $dt;
  my ($ax, $ay) = (($Tc * $Tf - $Td * $Te) / $dt + $Td * $x / $dt - $Tc * $y / $dt,
    ($Tb * $Te - $Ta * $Tf) / $dt - $Tb * $x / $dt + $Ta * $y / $dt);
  return $pair ? Pair(Dimension($ax), Dimension($ay)) : ($ax, $ay); }

sub equals {
  my ($self, $other) = @_;
  my ($Ta1, $Tb1, $Tc1, $Td1, $Te1, $Tf1) = @$self;
  my ($Ta2, $Tb2, $Tc2, $Td2, $Te2, $Tf2) = @$other;
  my @diff = grep { abs($_) > $eps } $Ta1 - $Ta2, $Tb1 - $Tb2, $Tc1 - $Tc2, $Td1 - $Td2, $Te1 - $Te2, $Tf1 - $Tf2;
  return $#diff == -1; }

sub toString {
  my ($self, $ptValue) = @_;
  return '' if $self->isIdentity();
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @{$self};
  if ($ptValue) {
    $Te = Dimension($Te)->ptValue();
    $Tf = Dimension($Tf)->ptValue(); }
  return 'rotate(' . (trunc(3, _aCS($Ta, $Tb))) . ')' if $self->isRotation();
  ($Te, $Tf) = trunc(3, ($Te, $Tf));
  return "translate($Te,$Tf)" if $self->isTranslation();
  ($Ta, $Td) = trunc(3, ($Ta, $Td));
  return "scale($Ta,$Td)" if $self->isScaling();
  ($Tb, $Tc) = trunc(3, ($Tb, $Tc));
  return "matrix($Ta,$Tb,$Tc,$Td,$Te,$Tf)"; }

sub ptValue {
  my ($self) = @_;
  return $self->toString(1); }

sub _aCS {
  my ($Tc, $s) = @_;
  my $r = rad2deg(acos($Tc));
  $r = 360 - $r if $s < 0;
  return $r; }

sub _multiply {
  my ($self, $other) = @_;
  my ($Ta1, $Tb1, $Tc1, $Td1, $Te1, $Tf1) = @$self;
  my ($Ta2, $Tb2, $Tc2, $Td2, $Te2, $Tf2) = @$other;
  return [
    $Ta1 * $Ta2 + $Tb2 * $Tc1, $Ta2 * $Tb1 + $Tb2 * $Td1, $Ta1 * $Tc2 + $Tc1 * $Td2,
    $Tb1 * $Tc2 + $Td1 * $Td2, $Te1 + $Ta1 * $Te2 + $Tc1 * $Tf2, $Tb1 * $Te2 + $Tf1 + $Td1 * $Tf2]; }

sub _inverse {
  my ($self) = @_;
  my ($Ta, $Tb, $Tc, $Td, $Te, $Tf) = @$self;
  my $dt = $Ta * $Td - $Tb * $Tc; return unless $dt;
  return [$Td / $dt, -$Tb / $dt, -$Tc / $dt,
    $Ta / $dt, ($Tc * $Tf - $Td * $Te) / $dt, ($Tb * $Te - $Ta * $Tf) / $dt]; }

1;
