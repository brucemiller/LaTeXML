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
use LaTeXML::Common::Error;
use base qw(LaTeXML::Core::Definition::Register);

# A CharDef is a specialized register;
# You can't assign it; when you invoke the control sequence, it returns
# the result of evaluating the character (more like a regular primitive).

sub new {
  my ($class, $cs, $value, $internalcs, %traits) = @_;
  return bless { cs => $cs, parameters => undef,
    value => $value, internalcs => $internalcs,
    registerType => 'Number', readonly => 1,
    locator => "from " . $STATE->getStomach->getGullet->getMouth->getLocator(-1),
    %traits }, $class; }

sub valueOf {
  my ($self) = @_;
  return $$self{value}; }

sub setValue {
  my ($self, $value) = @_;
  Error('unexpected', $self, undef, "Can't assign to chardef " . $self->getCSName);
  return; }

sub invoke {
  my ($self, $stomach) = @_;
  my $cs = $$self{internalcs};
  # Tracing ?
  return (defined $cs ? $stomach->invokeToken($cs) : undef); }

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
