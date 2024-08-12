# /=====================================================================\ #
# |  LaTeXML::Core::Definition::CharDef                                 | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::CharDef;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Box;
use base qw(LaTeXML::Core::Definition::Register);

# A CharDef is a specialized register;
# You can't assign it; when you invoke the control sequence, it returns
# the result of evaluating the character (more like a regular primitive).
# When $mathglyph is provided, it is the unicode corresponding to the \mathchar of $value
sub new {
  my ($class, $cs, $value, $mathglyph, %traits) = @_;
  return bless { cs => $cs, parameters => undef,
    value        => $value,   mathglyph => $mathglyph,
    registerType => 'Number', readonly  => 1,
    locator      => $STATE->getStomach->getGullet->getMouth->getLocator,
    %traits }, $class; }

sub valueOf {
  my ($self) = @_;
  return $$self{value}; }

sub setValue {
  my ($self, $value, $scope) = @_;
  Error('unexpected', $self, undef, "Can't assign to chardef " . $self->getCSName);
  return; }

sub invoke {
  my ($self, $stomach) = @_;
  my $value     = $$self{value};
  my $mathglyph = $$self{mathglyph};
  # A dilemma: If the \chardef were in a style file, you're prefer to revert to the $cs
  # but if defined in the document source, better to use \char ###\relax, so it still "works"
  my $src   = $$self{locator} && $$self{locator}->toString;
  my $local = $src && $src !~ /\.(?:sty|ltxml|ltxmlc)/;    # Dumps currently have undefined src!
  if (defined $mathglyph) {                                # Must be a math char
    return Box($mathglyph, undef, undef,
      ($local ? Tokens(T_CS('\mathchar'), $value->revert, T_CS('\relax')) : $$self{cs}),
      role => $$self{role}); }
  else {    # else text; but note defered font/encoding till digestion!
    my ($char, %props) = LaTeXML::Package::FontDecode($value->valueOf);
    return Box($char, undef, undef,
      ($local ? Tokens(T_CS('\char'), $value->revert, T_CS('\relax')) : $$self{cs}),
      %props); } }

sub equals {
  my ($self, $other) = @_;
  return (defined $other)
    && ((ref $self) eq (ref $other))
    && ($$self{value}->valueOf == $$other{value}->valueOf); }
#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::CharDef>  - Control sequence definitions for chardefs.

=head1 DESCRIPTION

Representation as a further specialized Register for chardef.
See L<LaTeXML::Package> for the most convenient means to create them.
It extends L<LaTeXML::Core::Definition::Register>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
