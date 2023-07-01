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
use LaTeXML::Core::Box;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use base qw(LaTeXML::Core::Definition);

# Known traits:
#    isPrefix : whether this primitive is a TeX prefix, \global, etc.
sub new {
  my ($class, $cs, $parameters, $replacement, %traits) = @_;
  Error('misdefined', $cs, $STATE->getStomach,
    "Primitive replacement for '" . ToString($cs) . "' is not a string or CODE",
    "Replacement is $replacement")
    if (ref $replacement) && (ref $replacement ne 'CODE');
  return bless { cs => $cs, parameters => $parameters, replacement => $replacement,
    locator => $STATE->getStomach->getGullet->getMouth->getLocator,
    %traits }, $class; }

sub isPrefix {
  my ($self) = @_;
  return $$self{isPrefix}; }

sub executeBeforeDigest {
  my ($self, $stomach) = @_;
  local $LaTeXML::Core::State::UNLOCKED = 1;
  my @pre = grep { defined } @{ $$self{beforeDigest} || [] };
  return (map { &$_($stomach) } @pre); }

sub executeAfterDigest {
  my ($self, $stomach, @whatever) = @_;
  local $LaTeXML::Core::State::UNLOCKED = 1;
  my @post = grep { defined } @{ $$self{afterDigest} || [] };
  return (map { &$_($stomach, @whatever) } @post); }

# Digest the primitive; this should occur in the stomach.
sub invoke {
  my ($self, $stomach) = @_;
  my $_tracing = $STATE->lookupValue('TRACING') || 0;
  my $tracing  = ($_tracing & 2);                                              # tracing commands
  my $profiled = ($_tracing & 4) && ($LaTeXML::CURRENT_TOKEN || $$self{cs});

  LaTeXML::Core::Definition::startProfiling($profiled, 'digest') if $profiled;
  Debug('{' . $self->tracingCSName . '}')                        if $tracing;
  my @result = ($self->executeBeforeDigest($stomach));
  my $parms  = $$self{parameters};
  my @args   = ($parms ? $parms->readArguments($stomach->getGullet, $self) : ());
  Debug($self->tracingArgs(@args)) if $tracing && @args;
  my $replacement = $$self{replacement};

  if (!ref $replacement) {
    my $alias = $$self{alias};
    $alias = T_CS($alias) if $alias && !ref $alias;
    push(@result, Box($replacement, undef, undef,
        Tokens($alias || $$self{cs}, ($parms ? $parms->revertArguments(@args) : ())),
        (defined $replacement ? () : (isEmpty => 1)))); }
  else {
    push(@result, &{ $$self{replacement} }($stomach, @args)); }
  push(@result, $self->executeAfterDigest($stomach));
  LaTeXML::Core::Definition::stopProfiling($profiled, 'digest') if $profiled;
  return @result; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other
      && (ref $self) eq (ref $other)) && Equals($self->getParameters, $other->getParameters)
    && Equals($$self{replacement},  $$other{replacement})
    && Equals($$self{beforeDigest}, $$other{beforeDigest})
    && Equals($$self{afterDigest},  $$other{afterDigest})
    ; }

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
