# /=====================================================================\ #
# |  LaTeXML::Core::Definition::Primitive                               | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::Primitive;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use base qw(LaTeXML::Core::Definition);

# Known traits:
#    isPrefix : whether this primitive is a TeX prefix, \global, etc.
sub new {
  my ($class, $cs, $parameters, $replacement, %traits) = @_;
  # Could conceivably have $replacement being a List or Box?
  my $source = $STATE->getStomach->getGullet->getMouth;
  Fatal('misdefined', $cs, $source, "Primitive replacement for '" . ToString($cs) . "' is not CODE",
    "Replacement is $replacement")
    unless ref $replacement eq 'CODE';
  return bless { cs => $cs, parameters => $parameters, replacement => $replacement,
    locator => "from " . $source->getLocator(-1),
    %traits }, $class; }

sub isPrefix {
  my ($self) = @_;
  return $$self{isPrefix}; }

sub executeBeforeDigest {
  my ($self, $stomach) = @_;
  local $LaTeXML::Core::State::UNLOCKED = 1;
  my $pre = $$self{beforeDigest};
  return ($pre ? map { &$_($stomach) } @$pre : ()); }

sub executeAfterDigest {
  my ($self, $stomach, @whatever) = @_;
  local $LaTeXML::Core::State::UNLOCKED = 1;
  my $post = $$self{afterDigest};
  return ($post ? map { &$_($stomach, @whatever) } @$post : ()); }

# Digest the primitive; this should occur in the stomach.
sub invoke {
  my ($self, $stomach) = @_;
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled) if $profiled;

  if ($STATE->lookupValue('TRACINGCOMMANDS')) {
    print STDERR '{' . $self->getCSName . "}\n"; }
  my @result = (
    $self->executeBeforeDigest($stomach),
    &{ $$self{replacement} }($stomach, $self->readArguments($stomach->getGullet)),
    $self->executeAfterDigest($stomach));

  LaTeXML::Core::Definition::stopProfiling($profiled) if $profiled;
  return @result; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other
      && (ref $self) eq (ref $other)) && Equals($self->getParameters, $other->getParameters)
    && Equals($$self{replacement}, $$other{replacement}); }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::Primitive>  - Primitive Control sequence definitions.

=head1 DESCRIPTION

These represent primitive control sequences that are converted directly to
Boxes or Lists containing basic Unicode content, rather than structured XML,
or those executed for side effect during digestion in the L<LaTeXML::Core::Stomach>,
changing the L<LaTeXML::Core::State>.  The results of invoking a C<LaTeXML::Core::Definition::Primitive>,
if any, should be a list of digested items (C<LaTeXML::Core::Box>, C<LaTeXML::Core::List>
or C<LaTeXML::Core::Whatsit>).

It extends L<LaTeXML::Core::Definition>.

Primitive definitions may have lists of daemon subroutines, C<beforeDigest> and C<afterDigest>,
that are executed before (and before the arguments are read) and after digestion.
These should either end with C<return;>, C<()>, or return a list of digested 
objects (L<LaTeXML::Core::Box>, etc) that will be contributed to the current list.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
