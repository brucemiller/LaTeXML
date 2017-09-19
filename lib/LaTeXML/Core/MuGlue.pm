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
use LaTeXML::Common::Float;
use base qw(LaTeXML::Common::Glue);
use base qw(Exporter);
our @EXPORT = (qw(&MuGlue));

#======================================================================
# Exported constructor.

sub MuGlue {
  my ($scaledmu, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Core::MuGlue->new($scaledmu, $plus, $pfill, $minus, $mfill); }

# NOTE: MuGlue stores scaled mu (as integer), not scaled points!
# While it would be nice to just use scaled points, the conversion leads to rounding errors
# compared to TeX.  So, we just bite the bullet & follow TeX, here.
# HOWEVER: Since muglue may show up in sizing calculations of boxes, etc,
# we'll need to adapt the API to make clear which units we get.
# Currently ->toValue just returns the internal value.
#======================================================================

# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu

my @FILL = ('', 'fil', 'fill', 'filll');    # [CONSTANT]

sub toString {
  my ($self) = @_;
  my ($smu, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Common::Dimension::formatScaled($smu) . 'mu ';
  $string .= ' plus '
    . LaTeXML::Common::Dimension::formatScaled($plus) . ($pfill ? $FILL[$pfill] : 'mu')
    if $plus != 0;
  $string .= ' minus '
    . LaTeXML::Common::Dimension::formatScaled($minus) . ($mfill ? $FILL[$mfill] : 'mu')

    if $minus != 0;
  return $string; }

# Since mu (not to mention glue) may be a bit perverse to the outside world,
# let's just conver these to simple pts.
sub toAttribute {
  my ($self) = @_;
  return LaTeXML::Common::Float::floatformat($$self[0] / 65536 / 1.8) . "pt"; }

sub stringify {
  my ($self) = @_;
  return "MuGlue[" . join(',', @$self) . "]"; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MuGlue> - representation of math glue;
extends L<LaTeXML::Common::Glue>.

=head2 Exported functions

=over 4

=item C<< $glue = MuGlue($gluespec); >>

=item C<< $glue = MuGlue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a MuGlue object, similar to Glue.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

