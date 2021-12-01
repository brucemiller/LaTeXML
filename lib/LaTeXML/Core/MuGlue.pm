# /=====================================================================\ #
# |  LaTeXML::Core::MuGlue                                              | #
# | Representation of Stretchy Math Dimensions                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::MuGlue;
use LaTeXML::Global;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::Common::Float;
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use LaTeXML::Common::Glue;
use base qw(LaTeXML::Common::Glue);
use base qw(Exporter);
our @EXPORT = (qw(&MuGlue));

#======================================================================
# Exported constructor.

# Create a new MuGlue, given EITHER a string with muunits, fills,etc,
# OR separate args, wiith $spec, $plus, $minus being fixed point,
# and $pfill, $mfill being 0 (sp) or a fillcode
# Note: this stores mu (NOT pts) as fixed point number
# [Glue is parameterized on the effective unit]
sub MuGlue {
  my ($spec, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Core::MuGlue->new($spec, $plus, $pfill, $minus, $mfill); }

#======================================================================
sub _unit { return 'mu'; }

sub stringify {
  my ($self) = @_;
  return "MuGlue[" . join(',', @$self) . "]"; }

sub spValue {
  my ($self, $prec) = @_;
  return fixpoint($$self[0] / $UNITY, $STATE->lookupValue('font')->getMUWidth); }

sub ptValue {
  my ($self, $prec) = @_;
  return roundto($self->spValue / $UNITY, $prec); }

sub pxValue {
  my ($self, $prec) = @_;
  return roundto($self->spValue / $UNITY / 1.8 * ($STATE->lookupValue('DPI') || 100 / 72.27), $prec); }
#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MuGlue> - representation of math glue;
extends L<LaTeXML::Common::Glue>.

=head2 Exported functions

=over 4

=item C<< $glue = MuGlue($spec); >>

=item C<< $glue = MuGlue($spec,$plus,$pfill,$minus,$mfill); >>

Creates a MuGlue object (similar to Glue).  C<$spec> can be a string in the
form that TeX recognizes (number "mu" optional plus and minus parts).
Alternatively, the dimension, plus and minus parts can be given separately
as scaled mu (fixpoint),
while C<$pfill> and C<$mfill> are 0 (when the C<$plus> or C<$minus> part is in scaledmu)
or 1,2,3 for fil, fill or filll, respectively.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

