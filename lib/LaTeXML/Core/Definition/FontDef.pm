# /=====================================================================\ #
# |  LaTeXML::Core::Definition::FontDef                                 | #
# | Representation of definitions of Fonts                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::FontDef;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Box;
use base qw(LaTeXML::Core::Definition::Primitive);

# A CharDef is a specialized register;
# You can't assign it; when you invoke the control sequence, it returns
# the result of evaluating the character (more like a regular primitive).
# When $mathglyph is provided, it is the unicode corresponding to the \mathchar of $value
sub new {
  my ($class, $cs, $fontid, %traits) = @_;
  return bless { cs => $cs, parameters => undef,
    fontID  => $fontid,
    locator => $STATE->getStomach->getGullet->getMouth->getLocator,
    %traits }, $class; }

# Return the "font info" associated with the (TeX) font that this command selects (See \font)
sub isFontDef {
  my ($self) = @_;
  return $STATE->lookupValue($$self{fontID}); }

sub invoke {
  my ($self, $stomach) = @_;
  my $current = $STATE->lookupValue('font');
  if (my $fontinfo = $STATE->lookupValue($$self{fontID})) {
    # Temporary hack for \the\font; remember the last font def executed
    $STATE->assignValue(current_FontDef => $$self{cs},                                     'local');
    $STATE->assignValue(font            => $STATE->lookupValue('font')->merge(%$fontinfo), 'local');
  }
  return Box(undef, undef, undef, $$self{cs}); }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::FontDef>  - Control sequence definitions for font symbols defined by \font.

=head1 DESCRIPTION

Representation for control sequences defined by \font.
It extends L<LaTeXML::Core::Definition::Primitive>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
