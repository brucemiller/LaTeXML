# /=====================================================================\ #
# |  LaTeXML:MathBox                                                    | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::MathBox;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Core::Box);

sub new {
  my ($class, $string, $font, $locator, $tokens, $attributes) = @_;
  return bless [$string, $font, $locator, $tokens, { attributes => $attributes }], $class; }

sub isMath {
  return 1; }    # MathBoxes are math mode.

sub beAbsorbed {
  my ($self, $document) = @_;
  my $string = $$self[0];
  my $attr   = $$self[4]{attributes};
  return ((defined $string) && ($string ne '')
    ? $document->insertMathToken($$self[0], font => $$self[1], ($attr ? %$attr : ()))
    : undef); }

1;

#======================================================================

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MathBox> - A digested Math object.

=head1 DESCRIPTION

represents a math token in a particular font;

=cut

