# /=====================================================================\ #
# |  LaTeXML::Common::Dimension                                         | #
# | Representation of Dimensions                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Dimension;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Number;
use base qw(LaTeXML::Common::Number);
use base qw(Exporter);
our @EXPORT = (qw(&Dimension &fixedformat  &fixpoint $UNITY));

#======================================================================
# Exported constructor.

# Create a Dimension given either a float with unit OR a number in scaled points
sub Dimension {
  my ($spec) = @_;
  return LaTeXML::Common::Dimension->new($spec); }

#======================================================================
sub _unit { return 'pt'; }

sub new {
  my ($class, $spec) = @_;
  $spec = "0" unless $spec;
  $spec = ToString($spec) if ref $spec;
  if ($spec =~ /^(-?\d*\.?\d*)([a-zA-Z][a-zA-Z])$/) {    # Dimensions given.
    return bless [fixpoint($1, $STATE->convertUnit($2))], $class; }
  else {
    # When scaled points passed in (typically the result of Perl calculations on other Dimensions),
    # you might think truncation (int) is more TeX-like.
    # Recall that TeX arithmatic truncates, whereas reading by Gullet tends to round.
    # The Perl arithmetic is replacing an unknown combination of those truncates & rounds.
    # As it turns out, using int() here results in non-terminating loops in pgf/tikz.
    # So, we use round (Knuth style)
    # Note that divide and such explicitly use int(), however!
    return bless [kround($spec || 0)], $class; } }

sub toString {
  my ($self) = @_;
  return fixedformat($$self[0], $self->_unit); }

sub toAttribute {
  my ($self) = @_;
  return attributeformat($$self[0], $self->_unit); }

sub stringify {
  my ($self) = @_;
  return "Dimension[" . $$self[0] . "]"; }

# One in fixpoint.
our $UNITY = 65536;
# Convert $float to a fixed-point number
# If $unit is given, it is number of units PER SCALED-POINT! (hence, extra division)
# AND, note that the float is rounded and THEN truncated after multiplying by units!
# to mimic TeX's behavior.
sub fixpoint {
  my ($float, $unit) = @_;
  my $fix = kround($float * $UNITY);
  return (defined $unit ? int($fix * $unit / $UNITY) : $fix); }

# This is Knuth's print_scaled (See TeX the Program, \S 103)
# It (should) round-trip with kround.
sub fixedformat {
  my ($s, $unit) = @_;
  $s = int($s);
  my $string = '';
  if ($s < 0) {
    $string .= '-'; $s = -$s; }
  $string .= int($s / $UNITY);
  $string .= '.';
  $s = 10 * ($s % $UNITY) + 5;
  my $delta = 10;
  do {
    $s += 0x8000 - 50000 if $delta > $UNITY;
    $string .= "0" + int($s / $UNITY);
    $s = 10 * ($s % $UNITY);
    $delta *= 10;
  } until $s <= $delta;
  return $string . ($unit || ''); }

sub attributeformat {
  my ($sp, $unit) = @_;
  return sprintf('%.1f', LaTeXML::Common::Number::roundto($sp / $UNITY, 1)) . ($unit || 'pt'); }

sub ptValue {
  my ($self, $prec) = @_;
  return roundto($$self[0] / $UNITY, $prec); }

sub pxValue {
  my ($self, $prec) = @_;
  return roundto($$self[0] / $UNITY * ($STATE->lookupValue('DPI') || 100) / 72.27, $prec); }

sub spValue {
  my ($self, $prec) = @_;
  return kround($$self[0]); }

sub emValue {
    my($self, $prec, $font)=@_;
    $font = $STATE->lookupValue('font') unless $font;
    return roundto($$self[0] / $font->getEMWidth, $prec); }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Dimension> - representation of dimensions;
extends L<LaTeXML::Common::Number>.

=head2 Exported functions

=over 4

=item C<< $dimension = Dimension($spec); >>

Creates a Dimension object.
C<$spec> can be a string with a floating point number and units
(with any of the usual TeX recognized units, except mu),
or just a number standing for scaled points (sp).

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

