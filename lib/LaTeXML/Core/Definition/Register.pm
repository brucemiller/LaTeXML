# /=====================================================================\ #
# |  LaTeXML::Core::Definition::Register                                | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::Register;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Core::Definition::Primitive);

# Known Traits:
#    registerType : the type of register (a LaTeXML class)
#    getter : a sub to get the value (essentially required)
#    setter : a sub to set the value (estentially required)
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    readonly : whether this register can only be read
sub new {
  my ($class, $cs, $parameters, %traits) = @_;
  return bless { cs => $cs, parameters => $parameters,
    locator => "from " . $STATE->getStomach->getGullet->getMouth->getLocator(-1),
    %traits }, $class; }

sub isPrefix {
  return 0; }

sub isRegister {
  my ($self) = @_;
  return $$self{registerType}; }

sub isReadonly {
  my ($self) = @_;
  return $$self{readonly}; }

sub valueOf {
  my ($self, @args) = @_;
  return &{ $$self{getter} }(@args); }

sub setValue {
  my ($self, $value, @args) = @_;
  &{ $$self{setter} }($value, @args);
  return; }

# No before/after daemons ???
# (other than afterassign)
sub invoke {
  my ($self, $stomach) = @_;
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled) if $profiled;

  my $gullet = $stomach->getGullet;
  my @args   = $self->readArguments($gullet);
  $gullet->readKeyword('=');    # Ignore
  my $value = $gullet->readValue($self->isRegister);
  $self->setValue($value, @args);

  # Tracing ?
  if (my $after = $STATE->lookupValue('afterAssignment')) {
    $STATE->assignValue(afterAssignment => undef, 'global');
    $gullet->unread($after); }    # primitive returns boxes, so these need to be digested!
  LaTeXML::Core::Definition::stopProfiling($profiled) if $profiled;
  return; }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::Register>  - Control sequence definitions for Registers.

=head1 DESCRIPTION

These are set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.
See L<LaTeXML::Package> for the most convenient means to create them.

It extends L<LaTeXML::Core::Definition::Primitive>.

Registers generally store some value in the current C<LaTeXML::Core::State>, but are not
required to. Like TeX's registers, when they are digested, they expect an optional
C<=>, and then a value of the appropriate type. Register definitions support these
additional methods:

=head1 Methods

=over 4

=item C<< $value = $register->valueOf(@args); >>

Return the value associated with the register, by invoking it's C<getter> function.
The additional args are used by some registers
to index into a set, such as the index to C<\count>.

=item C<< $register->setValue($value,@args); >>

Assign a value to the register, by invoking it's C<setter> function.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
