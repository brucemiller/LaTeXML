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

sub new {
  my ($class, $number) = @_;
  bless [$number || "0"], $class; }

sub valueOf  { $_[0]->[0]; }
sub toString { $_[0]->[0]; }

sub ptValue { int($_[0]->[0] / 655.36) / 100; }

sub unlist { $_[0]; }
sub revert { ExplodeText($_[0]->toString); }

sub smaller { ($_[0]->valueOf < $_[1]->valueOf) ? $_[0] : $_[1]; }
sub larger  { ($_[0]->valueOf > $_[1]->valueOf) ? $_[0] : $_[1]; }
sub absolute { (ref $_[0])->new(abs($_[0]->valueOf)); }
sub sign     { ($_[0]->valueOf < 0) ? -1 : (($_[0]->valueOf > 0) ? 1 : 0); }
sub negate   { (ref $_[0])->new(-$_[0]->valueOf); }
sub add      { (ref $_[0])->new($_[0]->valueOf + $_[1]->valueOf); }
sub subtract { (ref $_[0])->new($_[0]->valueOf - $_[1]->valueOf); }
# arg 2 is a number
sub multiply { (ref $_[0])->new(int($_[0]->valueOf * (ref $_[1] ? $_[1]->valueOf : $_[1]))); }

sub stringify { "Number[" . $_[0]->[0] . "]"; }

#**********************************************************************
# Strictly speaking, Float isn't part of TeX, but it's handy.
package LaTeXML::Float;
use LaTeXML::Global;
use base qw(LaTeXML::Number);
use strict;

sub toString  { LaTeXML::Float::format($_[0]->[0]); }
sub multiply  { (ref $_[0])->new($_[0]->valueOf * (ref $_[1] ? $_[1]->valueOf : $_[1])); }
sub stringify { "Float[" . $_[0]->[0] . "]"; }

# Utility for formatting sane numbers.
sub format {
  my $s = sprintf("%5f", $_[0]);
  $s =~ s/0+$// if $s =~ /\./;
  #  $s =~ s/\.$//;
  $s =~ s/\.$/.0/;    # Seems TeX prints .0 which in odd corner cases, people use?
  $s; }

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
  bless [$sp || "0"], $class; }

sub toString { LaTeXML::Float::format($_[0]->[0] / 65536) . 'pt'; }

sub stringify { "Dimension[" . $_[0]->[0] . "]"; }
#**********************************************************************
package LaTeXML::MuDimension;
use LaTeXML::Global;
use base qw(LaTeXML::Dimension);

# A mu is 1/18th of an em in the current math font.
# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu
sub toString { LaTeXML::Float::format($_[0]->[0] / 65536 * 1.8) . 'mu'; }

sub stringify { "MuDimension[" . $_[0]->[0] . "]"; }
#**********************************************************************
package LaTeXML::Glue;
use LaTeXML::Global;
use base qw(LaTeXML::Dimension);
use strict;

our %fillcode = (fil => 1, fill => 2, filll => 3);
our @FILL = ('', 'fil', 'fill', 'filll');

sub new {
  my ($class, $sp, $plus, $pfill, $minus, $mfill) = @_;
  if ((!defined $plus) && (!defined $pfill) && (!defined $minus) && (!defined $mfill)) {
    if ($sp =~ /^(\d*\.?\d*)$/) { }
    elsif ($sp =~ /^(\d*\.?\d*)(\w\w)(\s+plus\s*(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z]))?(\s+minus\s*(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z]))?$/) {
      my ($f, $u, $p, $pu, $m, $mu) = ($1, $2, $4, $5, $7, $8);
      $sp = $f * $STATE->convertUnit($u);
      if (!$pu) { }
      elsif ($fillcode{$pu}) { $plus = $p;                            $pfill = $pu; }
      else                   { $plus = $p * $STATE->convertUnit($pu); $pfill = 0; }
      if (!$mu) { }
      elsif ($fillcode{$mu}) { $minus = $m;                            $mfill = $mu; }
      else                   { $minus = $m * $STATE->convertUnit($mu); $mfill = 0; }
    } }
  bless [$sp || "0", $plus || "0", $pfill || 0, $minus || "0", $mfill || 0], $class; }

#sub getStretch { $_[0]->[1]; }
#sub getShrink  { $_[0]->[2]; }

sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Float::format($sp / 65536) . 'pt';
  $string .= ' plus ' . ($pfill ? $plus . $FILL[$pfill] : LaTeXML::Float::format($plus / 65536) . 'pt') if $plus != 0;
  $string .= ' minus ' . ($mfill ? $minus . $FILL[$mfill] : LaTeXML::Float::format($minus / 65536) . 'pt') if $minus != 0;
  $string; }

sub negate {
  my ($pts, $p, $pf, $m, $mf) = @{ $_[0] };
  (ref $_[0])->new(-$pts, -$p, $pf, -$m, $mf); }

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
    (ref $_[0])->new($pts, $p, $pf, $m, $mf); }
  else {
    (ref $_[0])->new($pts + $other->valueOf, $p, $pf, $m, $mf); } }

sub multiply {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  (ref $_[0])->new($pts * $other, $p * $other, $pf, $m * $other, $mf); }

sub stringify { "Glue[" . join(',', @{ $_[0] }) . "]"; }
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
  $string; }

sub stringify { "MuGlue[" . join(',', @{ $_[0] }) . "]"; }

#**********************************************************************
package LaTeXML::BoxDimensions;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, %specs) = @_;
  bless {%specs}, $class; }

sub toString {
  my ($self) = @_;
  join(' ', map(ToString($_) . ' ' . ToString($$self{$_}), keys %{$self})); }

sub revert {
  my ($self) = @_;
  map((ExplodeText($_), T_SPACE, Revert($$self{$_})), keys %{$self}); }

#**********************************************************************

package LaTeXML::Pair;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, $x, $y) = @_;
  bless [$x, $y], $class; }

sub getX { $_[0][0]; }
sub getY { $_[0][1]; }

# multiply by anything; this keeps the same type of elements in the pair
sub multiplyN { (ref $_[0])->new($_[0][0]->multiply($_[1]), $_[0][1]->multiply($_[2] || $_[1])); }
# multiply by a dimension or such; this upgrades the elements in the pair to
# the type used in multiplication
sub multiply { return $_[0]->multiplyN($_[1], $_[2]) unless (ref $_[1] && (!$_[2] || ref $_[2]));
  (ref $_[0])->new($_[1]->multiply($_[0][0]), ($_[2] || $_[1])->multiply($_[0][1])); }

sub swap { (ref $_[0])->new($_[0][1], $_[0][0]); }

sub ptValue   { $_[0][0]->ptValue() . ',' . $_[0][1]->ptValue(); }
sub toString  { $_[0][0]->toString() . ',' . $_[0][1]->toString(); }
sub stringify { "Pair[" . join(',', map($_->stringify, @{ $_[0] })) . "]"; }

sub revert {
  my ($self) = @_;
  (T_OTHER('('), Revert($$self[0]), T_OTHER(','), Revert($$self[1]), T_OTHER(')')); }

sub negate { $_[0]->multiply(-1); }

#**********************************************************************
package LaTeXML::PairList;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my ($class, @pairs) = @_;
  bless [@pairs], $class; }

sub getCount { $#{ $_[0] } + 1; }
sub getPair  { $_[0][$_[1]]; }
sub getPairs { @{ $_[0] }; }

sub ptValue { join(' ', map($_->ptValue, @{ $_[0] })); }

sub toString { join(' ', map($_->toString, @{ $_[0] })); }
sub stringify { "PairList[" . join(',', map($_->stringify, @{ $_[0] })) . "]"; }

sub revert { my @rev = (); map(push(@rev, Revert($_)), @{ $_[0] }); @rev; }

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

