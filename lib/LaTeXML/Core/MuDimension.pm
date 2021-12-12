# /=====================================================================\ #
# |  LaTeXML::Core::MuDimension                                         | #
# | Representation of Math Dimensions                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::MuDimension;
use LaTeXML::Global;
use strict;
use warnings;
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use base qw(LaTeXML::Common::Dimension);
use base qw(Exporter);
our @EXPORT = (qw(&MuDimension));

#======================================================================
# Exported constructor.
# Note that MuDimension is almost never used in TeX (there's no \newmudimen)

# Create a MuDimension given either a float with "mu" OR a number in scaled mu (NOT scaled points!)
sub MuDimension {
  my ($spec) = @_;
  return LaTeXML::Core::MuDimension->new($spec); }

sub _unit { return 'mu'; }

sub new {
  my ($class, $spec) = @_;
  $spec = "0" unless $spec;
  $spec = ToString($spec) if ref $spec;
  if ($spec =~ /^(-?\d*\.?\d*)mu$/) {    # mu given, convert to scaled mu
    return bless [fixpoint($1, $UNITY)], $class; }    # fake "mu" in sp
  else {
    # See comment in Dimension for why kround rather than int
    return bless [kround($spec || 0)], $class; } }

#======================================================================
sub stringify {
  my ($self) = @_;
  return "MuDimension[" . $$self[0] . "]"; }

# Note that $mu->valueOf will return scaled mu, NOT scaled pts;
# But in priniple these should never be combined with regular Dimensions/Glue
# TeX gives error "Incompatible glue units"
# HOWEVER, since we'll encounter mixtures of mu & pts when computing sizes,
# we're going to have to make sure we use the right scaling!
sub spValue {
  my ($self, $prec) = @_;
  return kround($$self[0] * $STATE->lookupValue('font')->getMUWidth / $UNITY); }

# A mu is 1/18th of an em in the current math font.
# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu (for 10pt)
sub ptValue {
  my ($self, $prec) = @_;
  return roundto($$self[0] / $UNITY / 1.8, $prec); }

sub pxValue {
  my ($self, $prec) = @_;
  return roundto($$self[0] / $UNITY / 1.8 * ($STATE->lookupValue('DPI') || 100 / 72.27), $prec); }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MuDimension> - representation of math dimensions;
extends L<LaTeXML::Common::Dimension>.

=head2 Exported functions

=over 4

=item C<< $mudimension = MuDimension($spec); >>

Creates a MuDimension object, similar to Dimension.
C<$spec> can be a string with a floating point number and "mu"
or just a number standing for scaled mu (ie. fixedpoint).

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
