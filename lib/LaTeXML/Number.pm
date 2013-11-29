# /=====================================================================\ #
# |  LaTeXML::Number, LaTeXML::Dimension etc                            | #
# | Representation of Token(s)                                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
package LaTeXML::Number;
use LaTeXML::Global;
use base qw(LaTeXML::Object);
use strict;
use warnings;

sub new {
  my ($class, $number) = @_;
  return bless [$number || "0"], $class; }

sub valueOf {
  my ($self) = @_;
  return $$self[0]; }

sub toString {
  my ($self) = @_;
  return $$self[0]; }

sub ptValue {
  my ($self) = @_;
  my $h = $$self[0] / 655.36;
  return int($h < 0 ? $h - 0.5 : $h + 0.5) / 100; }

sub unlist {
  my ($self) = @_;
  return $self; }

sub revert {
  my ($self) = @_;
  return ExplodeText($self->toString); }

sub smaller {
  my ($self, $other) = @_;
  return ($self->valueOf < $other->valueOf) ? $self : $other; }

sub larger {
  my ($self, $other) = @_;
  return ($self->valueOf > $other->valueOf) ? $self : $other; }

sub absolute {
  my ($self, $other) = @_;
  return (ref $self)->new(abs($self->valueOf)); }

sub sign {
  my ($self) = @_;
  return ($self->valueOf < 0) ? -1 : (($self->valueOf > 0) ? 1 : 0); }

sub negate {
  my ($self) = @_;
  return (ref $self)->new(-$self->valueOf); }

sub add {
  my ($self, $other) = @_;
  return (ref $self)->new($self->valueOf + $other->valueOf); }

sub subtract {
  my ($self, $other) = @_;
  return (ref $self)->new($self->valueOf - $other->valueOf); }

# arg 2 is a number
sub multiply {
  my ($self, $other) = @_;
  return (ref $self)->new(int($self->valueOf * (ref $other ? $other->valueOf : $other))); }

sub stringify {
  my ($self) = @_;
  return "Number[" . $$self[0] . "]"; }

#**********************************************************************
# Strictly speaking, Float isn't part of TeX, but it's handy.
package LaTeXML::Float;
use LaTeXML::Global;
use base qw(LaTeXML::Number);
use strict;

sub toString {
  my ($self) = @_;
  return LaTeXML::Float::floatformat($$self[0]); }

sub multiply {
  my ($self, $other) = @_;
  return (ref $self)->new($self->valueOf * (ref $other ? $other->valueOf : $other)); }

sub stringify {
  my ($self) = @_;
  return "Float[" . $$self[0] . "]"; }

# Utility for formatting sane numbers.
sub floatformat {
  my ($n) = @_;
  my $s = sprintf("%5f", $n);
  $s =~ s/0+$// if $s =~ /\./;
  #  $s =~ s/\.$//;
  $s =~ s/\.$/.0/;    # Seems TeX prints .0 which in odd corner cases, people use?
  return $s; }

#**********************************************************************
package LaTeXML::Dimension;
use LaTeXML::Global;
use base qw(LaTeXML::Number);
use strict;

sub new {
  my ($class, $sp) = @_;
  $sp = "0" unless $sp;
  if ($sp =~ /^(-?\d*\.?\d*)([a-zA-Z][a-zA-Z])$/) {    # Dimensions given.
    $sp = $1 * $STATE->convertUnit($2); }
  return bless [$sp || "0"], $class; }

sub toString {
  my ($self) = @_;
  return pointformat($$self[0]); }

sub stringify {
  my ($self) = @_;
  return "Dimension[" . $$self[0] . "]"; }

# Utility for formatting scaled points sanely.
sub pointformat {
  my ($sp) = @_;
  my $s = sprintf("%2f", int($sp * 100 / 65536 + ($sp > 0 ? 0.5 : -0.5)) / 100);
  $s =~ s/0+$// if $s =~ /\./;
  #  $s =~ s/\.$//;
  $s =~ s/\.$/.0/;    # Seems TeX prints .0 which in odd corner cases, people use?
  return $s . 'pt'; }

#**********************************************************************
package LaTeXML::MuDimension;
use LaTeXML::Global;
use base qw(LaTeXML::Dimension);

# A mu is 1/18th of an em in the current math font.
# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu
sub toString {
  my ($self) = @_;
  return LaTeXML::Float::floatformat($$self[0] / 65536 * 1.8) . 'mu'; }

sub stringify {
  my ($self) = @_;
  return "MuDimension[" . $$self[0] . "]"; }

#**********************************************************************
package LaTeXML::Glue;
use LaTeXML::Global;
use base qw(LaTeXML::Dimension);
use strict;

my %fillcode = (fil => 1, fill => 2, filll => 3);    # [CONSTANT]
my @FILL = ('', 'fil', 'fill', 'filll');             # [CONSTANT]

my $num_re   = qr/\d*\.?\d*/;                        # [CONSTANT]
my $unit_re  = qr/\w\w/;                             # [CONSTANT]
my $fill_re  = qr/fil|fill|filll|[a-zA-Z][a-zA-Z]/;  # [CONSTANT]
my $plus_re  = qr/\s+plus\s*($num_re)($fill_re)/;    # [CONSTANT]
my $minus_re = qr/\s+minus\s*($num_re)($fill_re)/;   # [CONSTANT]
our $GLUE_re = qr/(\+?\-?$num_re)($unit_re)($plus_re)?($minus_re)?/;    # [CONSTANT]

sub new {
  my ($class, $sp, $plus, $pfill, $minus, $mfill) = @_;
  if ((!defined $plus) && (!defined $pfill) && (!defined $minus) && (!defined $mfill)) {
    if ($sp =~ /^(\d*\.?\d*)$/) { }
    elsif ($sp =~ /^$GLUE_re$/) {
      my ($f, $u, $p, $pu, $m, $mu) = ($1, $2, $4, $5, $7, $8);
      $sp = $f * $STATE->convertUnit($u);
      if (!$pu) { }
      elsif ($fillcode{$pu}) { $plus = $p;                            $pfill = $pu; }
      else                   { $plus = $p * $STATE->convertUnit($pu); $pfill = 0; }
      if (!$mu) { }
      elsif ($fillcode{$mu}) { $minus = $m;                            $mfill = $mu; }
      else                   { $minus = $m * $STATE->convertUnit($mu); $mfill = 0; }
    } }
  return bless [$sp || "0", $plus || "0", $pfill || 0, $minus || "0", $mfill || 0], $class; }

#sub getStretch { $_[0]->[1]; }
#sub getShrink  { $_[0]->[2]; }

sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Dimension::pointformat($sp);
  $string .= ' plus ' . ($pfill ? $plus . $FILL[$pfill] : LaTeXML::Dimension::pointformat($plus))
    if $plus != 0;
  $string .= ' minus ' . ($mfill ? $minus . $FILL[$mfill] : LaTeXML::Dimension::pointformat($minus))
    if $minus != 0;
  return $string; }

sub negate {
  my ($self) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  return (ref $self)->new(-$pts, -$p, $pf, -$m, $mf); }

sub add {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  if (ref $other eq 'LaTeXML::Glue') {
    my ($pts2, $p2, $pf2, $m2, $mf2) = @$other;
    $pts += $pts2;
    if ($pf == $pf2) { $p += $p2; }
    elsif ($pf < $pf2) { $p = $p2; $pf = $pf2; }
    if ($mf == $mf2) { $m += $m2; }
    elsif ($mf < $mf2) { $m = $m2; $mf = $mf2; }
    return (ref $self)->new($pts, $p, $pf, $m, $mf); }
  else {
    return (ref $self)->new($pts + $other->valueOf, $p, $pf, $m, $mf); } }

sub multiply {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  return (ref $self)->new($pts * $other, $p * $other, $pf, $m * $other, $mf); }

sub stringify {
  my ($self) = @_;
  return "Glue[" . join(',', @$self) . "]"; }

#**********************************************************************
package LaTeXML::MuGlue;
use LaTeXML::Global;
use base qw(LaTeXML::Glue);

# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu
sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Float::format($sp / 65536 * 1.8) . "mu";
  $string .= ' plus ' . ($pfill ? $plus . $FILL[$pfill] : LaTeXML::Float::format($plus / 65536 * 1.8) . 'mu') if $plus != 0;
  $string .= ' minus ' . ($mfill ? $minus . $FILL[$mfill] : LaTeXML::Float::format($minus / 65536 * 1.8) . 'mu') if $minus != 0;
  return $string; }

sub stringify {
  my ($self) = @_;
  return "MuGlue[" . join(',', @$self) . "]"; }

#**********************************************************************
package LaTeXML::BoxDimensions;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, %specs) = @_;
  return bless {%specs}, $class; }

sub toString {
  my ($self) = @_;
  return join(' ', map { ToString($_) . ' ' . ToString($$self{$_}) } keys %{$self}); }

sub revert {
  my ($self) = @_;
  return map { (ExplodeText($_), T_SPACE, Revert($$self{$_})) } keys %{$self}; }

#**********************************************************************

package LaTeXML::Pair;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, $x, $y) = @_;
  return bless [$x, $y], $class; }

sub getX {
  my ($self) = @_;
  return $$self[0]; }

sub getY {
  my ($self) = @_;
  return $$self[1]; }

# multiply by anything; this keeps the same type of elements in the pair
sub multiplyN {
  my ($self, $other, $other2) = @_;
  return (ref $self)->new($$self[0]->multiply($other), $$self[1]->multiply($other2 || $other)); }

# multiply by a dimension or such; this upgrades the elements in the pair to
# the type used in multiplication
sub multiply {
  my ($self, $other, $other2) = @_;
  return $self->multiplyN($other, $other2) if !(ref $other) || ($other2 && !ref $other2);
  return (ref $self)->new($other->multiply($$self[0]), ($other2 || $other)->multiply($$self[1])); }

sub swap {
  my ($self) = @_;
  return (ref $self)->new($$self[1], $$self[0]); }

sub ptValue {
  my ($self) = @_;
  return $$self[0]->ptValue() . ',' . $$self[1]->ptValue(); }

sub toString {
  my ($self) = @_;
  return $$self[0]->toString() . ',' . $$self[1]->toString(); }

sub stringify {
  my ($self) = @_;
  return "Pair[" . join(',', map { $_->stringify } @$self) . "]"; }

sub revert {
  my ($self) = @_;
  return (T_OTHER('('), Revert($$self[0]), T_OTHER(','), Revert($$self[1]), T_OTHER(')')); }

sub negate {
  my ($self) = @_;
  return $self->multiply(-1); }

#**********************************************************************
package LaTeXML::PairList;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, @pairs) = @_;
  return bless [@pairs], $class; }

sub getCount {
  my ($self) = @_;
  return $#{$self} + 1; }

sub getPair {
  my ($self, $n) = @_;
  return $$self[$n]; }

sub getPairs {
  my ($self) = @_;
  return @$self; }

sub ptValue {
  my ($self) = @_;
  return join(' ', map { $_->ptValue } @$self); }

sub toString {
  my ($self) = @_;
  return join(' ', map { $_->toString } @$self); }

sub stringify {
  my ($self) = @_;
  return "PairList[" . join(',', map { $_->stringify } @$self) . "]"; }

sub revert {
  my ($self) = @_;
  my @rev = ();
  map { push(@rev, Revert($_)) } @$self;
  return @rev; }

1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Number> - representation of numbers, dimensions, skips and glue.

=head1 DESCRIPTION

This module defines various dimension and number-like data objects

=over 4

=item C<LaTeXML::Number>

represents numbers,

=item C<LaTeXML::Float>

=begin latex

\label{LaTeXML::Float}

=end latex

represents floating-point numbers,

=item C<LaTeXML::Dimension>

=begin latex

\label{LaTeXML::Dimension}

=end latex

represents dimensions,

=item C<LaTeXML::MuDimension>

=begin latex

\label{LaTeXML::MuDimension}

=end latex

represents math dimensions,

=item C<LaTeXML::Glue>

=begin latex

\label{LaTeXML::Glue}

=end latex

represents glue (skips),

=item C<LaTeXML::MuGlue>

=begin latex

\label{LaTeXML::MuGlue}

=end latex

represents math glue,

=item C<LaTeXML::Pair>

=begin latex

\label{LaTeXML::Pair}

=end latex

represents pairs of numbers

=item C<LaTeXML::Pairlist>

=begin latex

\label{LaTeXML::PairList}

=end latex

represents list of pairs.

=back

=head2 Common methods

The following methods apply to all objects.

=over 4

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this C<$object>.

=item C<< $string = $object->toString; >>

Return a string representing C<$object>.

=item C<< $string = $object->ptValue; >>

Return a value representing C<$object> without the measurement unit (pt) 
with limited decimal places.

=back

=head2 Numerics methods

These methods apply to the various numeric objects

=over 4

=item C<< $n = $object->valueOf; >>

Return the value in scaled points (ignoring shrink and stretch, if any).

=item C<< $n = $object->smaller($other); >>

Return C<$object> or C<$other>, whichever is smaller

=item C<< $n = $object->larger($other); >>

Return C<$object> or C<$other>, whichever is larger

=item C<< $n = $object->absolute; >>

Return an object representing the absolute value of the C<$object>.

=item C<< $n = $object->sign; >>

Return an integer: -1 for negatives, 0 for 0 and 1 for positives

=item C<< $n = $object->negate; >>

Return an object representing the negative of the C<$object>.

=item C<< $n = $object->add($other); >>

Return an object representing the sum of C<$object> and C<$other>

=item C<< $n = $object->subtract($other); >>

Return an object representing the difference between C<$object> and C<$other>

=item C<< $n = $object->multiply($n); >>

Return an object representing the product of C<$object> and C<$n> (a regular number).

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

