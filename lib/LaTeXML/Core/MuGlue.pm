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
  my ($scaledpoints, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Core::MuGlue->new($scaledpoints, $plus, $pfill, $minus, $mfill); }

#======================================================================

# 1 mu = 1em/18 = 10pt/18 = 5/9 pt; 1pt = 9/5mu = 1.8mu
sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Common::Float::floatformat($sp / 65536 * 1.8) . "mu";
  $string .= ' plus ' . ($pfill
    ? $plus . $LaTeXML::Common::Glue::FILL[$pfill]
    : LaTeXML::Common::Float::floatformat($plus / 65536 * 1.8) . 'mu') if $plus != 0;
  $string .= ' minus ' . ($mfill
    ? $minus . $LaTeXML::Common::Glue::FILL[$mfill]
    : LaTeXML::Common::Float::floatformat($minus / 65536 * 1.8) . 'mu') if $minus != 0;
  return $string; }

sub toAttribute {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Common::Float::floatformat($sp / 65536 * 1.8) . "mu";
  $string .= ' plus ' . ($pfill
    ? $plus . $LaTeXML::Common::Glue::FILL[$pfill]
    : LaTeXML::Common::Float::floatformat($plus / 65536 * 1.8) . 'mu') if $plus != 0;
  $string .= ' minus ' . ($mfill
    ? $minus . $LaTeXML::Common::Glue::FILL[$mfill]
    : LaTeXML::Common::Float::floatformat($minus / 65536 * 1.8) . 'mu') if $minus != 0;
  return $string; }

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

