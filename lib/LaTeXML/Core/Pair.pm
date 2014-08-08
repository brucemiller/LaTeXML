# /=====================================================================\ #
# |  LaTeXML::Core::Pair                                                | #
# | Representation of pairs of numbers or dimensions                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Pair;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Core::Token;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (qw(&Pair));

#======================================================================
# Exported constructor.

sub Pair {
  my ($x, $y) = @_;
  return LaTeXML::Core::Pair->new($x, $y); }

#======================================================================

# NOTE: This is candiate to be absorbed into Array (perhaps)

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
  my ($self, $prec) = @_;
  return $$self[0]->ptValue($prec) . ',' . $$self[1]->ptValue($prec); }

sub pxValue {
  my ($self, $prec) = @_;
  return $$self[0]->pxValue($prec) . ',' . $$self[1]->pxValue($prec); }

sub toString {
  my ($self) = @_;
  return $$self[0]->toString() . ',' . $$self[1]->toString(); }

sub toAttribute {
  my ($self) = @_;
  return $$self[0]->toAttribute() . ',' . $$self[1]->toAttribute(); }

sub stringify {
  my ($self) = @_;
  return "Pair[" . join(',', map { $_->stringify } @$self) . "]"; }

sub revert {
  my ($self) = @_;
  return (T_OTHER('('), Revert($$self[0]), T_OTHER(','), Revert($$self[1]), T_OTHER(')')); }

sub negate {
  my ($self) = @_;
  return $self->multiply(-1); }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Pair> - representation of pairs of numerical things

=head1 DESCRIPTION

represents pairs of numerical things, coordinates or such.
Candidate for removal!

=head2 Exported functions

=over 4

=item C<< $pair = Pair($num1,$num2); >>

Creates an object representing a pair of numbers;
Not a part of TeX, but useful for graphical objects.
The two components can be any numerical object.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

