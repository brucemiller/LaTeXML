# /=====================================================================\ #
# |  LaTeXML::Common::Number                                            | #
# | Representation of numbers                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Number;
use LaTeXML::Global;
use strict;
use warnings;
use LaTeXML::Common::Object;
use LaTeXML::Core::Token;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (qw(&Number &roundto &kround));

#======================================================================
# Exported constructor.

sub Number {
  my ($number) = @_;
  return LaTeXML::Common::Number->new($number); }

#======================================================================

sub new {
  my ($class, $number) = @_;
  $number = ToString($number) if ref $number;
  return bless [int($number) || "0"], $class; }    # truncate, not round

sub valueOf {
  my ($self) = @_;
  return $$self[0]; }

sub toString {
  my ($self) = @_;
  return $$self[0]; }

my @SCALES = (1, 10, 100, 1000, 10000, 100000);

# smallest number that makes a difference added to 1 in Perl's float format.
our $EPSILON = 1.0;
while (1.0 + $EPSILON / 2 != 1) {
  $EPSILON /= 2.0; }
our $ROUNDING_HALF = 0.5 * (1 - $EPSILON);

# Round $number to $prec decimals (0...6)
# attempting to do so portably.
sub roundto {
  my ($number, $prec) = @_;
  $prec = 2 unless defined $prec;
  $prec = 0 if $prec < 0;
  $prec = 5 if $prec > 5;
  my $scale = $SCALES[$prec];
  # scale to integer, w/some slop in case arbitrarily close to an integer...
  my $n = $number * $scale * (1 + 100 * $EPSILON);
  return int($n < -$EPSILON ? $n - 0.5 : ($n > $EPSILON ? $n + 0.5 : 0.0)) / $scale; }

# An attempt at rounding floats to integers (like scaled points),
# in a (hopefully) Knuthian manner (like round_decimals \S102 in Tex The Program)
sub kround {
  my ($number) = @_;
  return int($number < 0 ? $number - $ROUNDING_HALF : $number + $ROUNDING_HALF); }

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

# Truncating division
sub divide {
  my ($self, $other) = @_;
  return (ref $self)->new(int($self->valueOf / ((ref $other ? $other->valueOf : $other) || $EPSILON))); }

# Rounding division
sub divideround {
  my ($self, $other) = @_;
  return (ref $self)->new(int(0.5 + $self->valueOf / ((ref $other ? $other->valueOf : $other) || $EPSILON))); }

sub stringify {
  my ($self) = @_;
  return "Number[" . $$self[0] . "]"; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Number> - representation of numbers;
extends L<LaTeXML::Common::Object>.

=head2 Exported functions

=over 4

=item C<< $number = Number($num); >>

Creates a Number object representing C<$num>.

=back

=head2 Methods

=over 4

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this C<$object>.

=item C<< $string = $object->toString; >>

Return a string representing C<$object>.

=item C<< $string = $object->ptValue; >>

Return a value representing C<$object> without the measurement unit (pt) 
with limited decimal places.

=item C<< $string = $object->pxValue; >>

Return an integer value representing C<$object> in pixels.
Uses the state variable C<DPI> (dots per inch).

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

=item C<< $n = $object->divide($n); >>

Return an object representing the (truncating) division of C<$object> by C<$n> (a regular number).

=item C<< $n = $object->divideround($n); >>

Return an object representing the (rounding) division of C<$object> by C<$n> (a regular number).

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
