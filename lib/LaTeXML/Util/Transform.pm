package LaTeXML::Util::Transform;
use strict;
use LaTeXML::Global;
use LaTeXML::Number;
use LaTeXML::Util::Geometry;
use Math::Trig;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (qw(&Transform));

our $eps = 0.000001;

sub Transform { LaTeXML::Util::Transform->new(@_); }

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
		$self = _multiply($self, [$c, $s, -$s, $c, $tx*(1-$c) + $ty*$s, $ty*(1-$c)-$tx*$s]); }
	    elsif ($transform =~ s/^scale\(([^\s]+) ([^\)]+)\)//) {
		$self = _multiply($self, [$1, 0, 0, $2, 0, 0]); }
	    elsif ($transform =~ s/^scale\(([^\)\s]+)\)//) {
		$self = _multiply($self, [$1, 0, 0, $1, 0, 0]); }
	    elsif ($transform =~ s/^skewX\(([^\)]+)\)//) {
		my $angle = radians($1); my ($c, $s) = (cos($angle), sin($angle));
		$self = _multiply($self, [1, 0, $s/$c, 1, 0, 0]) if $c != 0; }
	    elsif ($transform =~ s/^skewY\(([^\)]+)\)//) {
		my $angle = radians($1); my ($c, $s) = (cos($angle), sin($angle));
		$self = _multiply($self, [1, $s/$c, 0, 1, 0, 0]) if $c != 0; }
	    elsif ($transform =~ s/^matrix\(([^\s]+) ([^\s]+) ([^\s]+) ([^\s]+) ([^\s]+) ([^\)]+)\)//) {
		$self = _multiply($self, [$1, $2, $3, $4, $5, $6]); }
	    else { Error(":misdefined:<transform> Unable to parse transform '$transform'"); last; }}}
    bless($self, $class); }

sub isIdentity {
    my ($a, $b, $c, $d, $e, $f) = @{$_[0]};  ($b, $c, $e, $f) = map(abs($_), ($b, $c, $e, $f));
    ($a < 1+$eps && $a > 1-$eps && $b < $eps && $c < $eps && $d < 1+$eps && $d > 1-$eps && $e < $eps && $f < $eps); }

sub isTranslation {
    my ($a, $b, $c, $d, $e, $f) = @{$_[0]};  ($b, $c, $e, $f) = map(abs($_), ($b, $c, $e, $f));
    ($a < 1+$eps && $a > 1-$eps && $b < $eps && $c < $eps && $d < 1+$eps && $d > 1-$eps && ($e > $eps || $f > $eps)); }

sub isRotation { 
    my ($a, $b, $c, $d, $e, $f) = @{$_[0]};  
    (abs($a-$d) < $eps && abs($b+$c) < $eps && abs($a**2+$b**2 - 1) < $eps && abs($e) < $eps && abs($f) < $eps); }

sub isScaling {
    my ($a, $b, $c, $d, $e, $f) = @{$_[0]};  ($b, $c, $e, $f) = map(abs($_), ($b, $c, $e, $f));
    (($a > 1+$eps || $a < 1-$eps) && $b < $eps && $c < $eps && ($d > 1+$eps || $d < 1-$eps) && $e < $eps && $f < $eps); }

sub inverse {
    my $self = $_[0];
    bless(_inverse($self), ref $self); }

sub differenceTo {
    my $self = $_[0];
    my $to = ($_[1] && ref $_[1] && ref $self eq ref $_[1]) ? $_[1] : (ref $self)->new($_[1]);
    bless(_multiply(_inverse($self), $to), ref $self); }

sub addPre {
    my $self = $_[0];
    my $what = ($_[1] && ref $_[1] && ref $self eq ref $_[1]) ? $_[1] : (ref $self)->new($_[1]);
    bless(_multiply($what, $self), ref $self); }

sub addPost {
    my $self = $_[0];
    my $what = ($_[1] && ref $_[1] && ref $self eq ref $_[1]) ? $_[1] : (ref $self)->new($_[1]);
    bless(_multiply($self, $what), ref $self); }

sub removePre {
    my $self = $_[0];
    my $what = ($_[1] && ref $_[1] && ref $self eq ref $_[1]) ? $_[1] : (ref $self)->new($_[1]);
    bless(_multiply($self, _inverse($what)), ref $self); }

sub removePost {
    my $self = $_[0];
    my $what = ($_[1] && ref $_[1] && ref $self eq ref $_[1]) ? $_[1] : (ref $self)->new($_[1]);
    bless(_multiply(_inverse($what), $self), ref $self); }

sub apply {
    my ($self, $x, $y) = @_; my ($a, $b, $c, $d, $e, $f) = @{$self}; my $pair = 0;
    if (!defined $y) { $y = $x->getY->valueOf; $x = $x->getX->valueOf; $pair = 1; }
    my ($ax, $ay) = ($a*$x+$c*$y+$e, $b*$x+$d*$y+$f); 
    $pair ? Pair(Dimension($ax), Dimension($ay)) : ($ax, $ay); }

sub unapply {
    my ($self, $x, $y) = @_; my ($a, $b, $c, $d, $e, $f) = @{$self}; my $pair = 0;
    if (!defined $y) { $y = $x->getY->valueOf; $x = $x->getX->valueOf; $pair = 1; }    
    my $dt = $a*$d-$b*$c; return unless $dt;
    my ($ax, $ay) = (($c*$f-$d*$e)/$dt + $d*$x/$dt - $c*$y/$dt,
		     ($b*$e-$a*$f)/$dt - $b*$x/$dt + $a*$y/$dt);
    $pair ? Pair(Dimension($ax), Dimension($ay)) : ($ax, $ay); }

sub equals {
    my ($a1, $b1, $c1, $d1, $e1, $f1) = @{$_[0]}; my ($a2, $b2, $c2, $d2, $e2, $f2) = @{$_[1]};
    my @diff = grep(abs > $eps, ($a1-$a2, $b1-$b2, $c1-$c2, $d1-$d2, $e1-$e2, $f1-$f2));
    $#diff == -1; }

sub toString {
    my ($self, $ptValue) = @_;
    return '' if $self->isIdentity();
    my ($a, $b, $c, $d, $e, $f) = @{$self};
    if ($ptValue) { $e = Dimension($e)->ptValue(); $f = Dimension($f)->ptValue(); }
    return 'rotate('.(trunc(3,_aCS($a, $b))).')' if $self->isRotation();
    ($e, $f) = trunc(3, ($e, $f));
    return "translate($e,$f)" if $self->isTranslation();
    ($a, $d) = trunc(3, ($a, $d));
    return "scale($a,$d)" if $self->isScaling();
    ($b, $c) = trunc(3, ($b, $c));
    return "matrix($a,$b,$c,$d,$e,$f)"; }

sub ptValue { $_[0]->toString(1); }

sub _aCS { my ($c, $s) = @_;  my $r = rad2deg(acos($c));
	   $r = 360 - $r if $s < 0; $r; }

sub _multiply {
    my ($a1, $b1, $c1, $d1, $e1, $f1) = @{$_[0]};
    my ($a2, $b2, $c2, $d2, $e2, $f2) = @{$_[1]};
    [$a1*$a2+$b2*$c1, $a2*$b1+$b2*$d1, $a1*$c2+$c1*$d2,
     $b1*$c2+$d1*$d2, $e1+$a1*$e2+$c1*$f2, $b1*$e2+$f1+$d1*$f2]; }

sub _inverse {
    my ($a, $b, $c, $d, $e, $f) = @{$_[0]};
    my $dt = $a*$d-$b*$c; return unless $dt;
    [$d/$dt, -$b/$dt, -$c/$dt, $a/$dt, ($c*$f-$d*$e)/$dt, ($b*$e-$a*$f)/$dt]; }

1;
