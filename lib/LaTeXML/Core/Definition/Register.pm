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
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use base qw(LaTeXML::Core::Definition::Primitive);

# Known Traits:
#    address : address to store in State's value table; defaults to the cs
#    getter : a sub to get the value; otherwise stores in State value table under address
#    setter : a sub to set the value; ditto
#    registerType : the type of register value (a LaTeXML class)
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    readonly : whether this register can only be read
#    default  : default value; safety for when no value assigned
sub new {
  my ($class, $cs, $parameters, %traits) = @_;
  $traits{address} = ToString($cs) unless defined $traits{address};
  return bless { cs => $cs, parameters => $parameters,
    locator => $STATE->getStomach->getGullet->getMouth->getLocator,
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
  if (my $getter = $$self{getter}) {
    return &{ $$self{getter} }(@args); }
  else {
    my $loc = (@args ? join('', $$self{address}, map { ToString($_) } @args) : $$self{address});
    return $STATE->lookupValue($loc) || $$self{default}; } }

sub setValue {
  my ($self, $value, $scope, @args) = @_;
  my $tracing = $STATE->lookupValue('TRACINGCOMMANDS') || $LaTeXML::DEBUG{tracing};
  if ($tracing) {
    my $scope  = $STATE->getPrefix('global') ? 'globally ' : '';
    my $csname = ToString($$self{cs});
    Debug("{$scope" . "changing " . $csname . "=" . ToString($self->valueOf(@args)) . "}"); }
  if (my $setter = $$self{setter}) {
    &{ $$self{setter} }($value, $scope, @args); }
  elsif ($$self{readonly}) {
    Warn('unexpected', $$self{cs}, $STATE->getStomach,
      "Can't assign readonly register " . ToString($$self{cs}) . " to " . ToString($value)); }
  else {
    my $loc = (@args ? join('', $$self{address}, map { ToString($_) } @args) : $$self{address});
    $STATE->assignValue($loc => $value, $scope); }
  Debug("{into " . ToString($$self{cs}) . "=" . ToString($self->valueOf(@args)) . "}") if $tracing;
  return; }

sub addValue {
  my ($self, $value, $scope, @args) = @_;
  my $oldvalue;
  if (my $getter = $$self{getter}) {
    $oldvalue = &{ $$self{getter} }(@args); }
  else {
    my $loc = (@args ? join('', $$self{address}, map { ToString($_) } @args) : $$self{address});
    $oldvalue = $STATE->lookupValue($loc) || $$self{default}; }
  my $newvalue = $oldvalue->add($value);
  if (my $setter = $$self{setter}) {
    &{ $$self{setter} }($newvalue, $scope, @args); }
  elsif ($$self{readonly}) {
    Warn('unexpected', $$self{cs}, $STATE->getStomach,
      "Can't assign readonly register $$self{address} to " . ToString($value)); }
  else {
    my $loc = (@args ? join('', $$self{address}, map { ToString($_) } @args) : $$self{address});
    $STATE->assignValue($loc => $newvalue, $scope); }
  return; }

# No before/after daemons ???
# (other than afterassign)
sub invoke {
  my ($self, $stomach) = @_;
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled, 'digest') if $profiled;

  my $gullet = $stomach->getGullet;
  my $parms  = $$self{parameters};
  my @args   = ($parms ? $parms->readArguments($gullet) : ());
  $gullet->readKeyword('=');    # Ignore
  my $value = $gullet->readValue($self->isRegister);
  $self->setValue($value, undef, @args);

  # Tracing ?
  if (my $after = $STATE->lookupValue('afterAssignment')) {
    $STATE->assignValue(afterAssignment => undef, 'global');
    $gullet->unread($after); }    # primitive returns boxes, so these need to be digested!
  LaTeXML::Core::Definition::stopProfiling($profiled, 'digest') if $profiled;
  return; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other
      && (ref $self) eq (ref $other)) && Equals($self->getParameters, $other->getParameters)
    && Equals($$self{address}, $$other{address}); }

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

=item C<< $register->setValue($value,$scope,@args); >>

Assign a value to the register, by invoking it's C<setter> function.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
