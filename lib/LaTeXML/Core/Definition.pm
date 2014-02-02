# /=====================================================================\ #
# |  LaTeXML::Core::Definition                                          | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Core::Token;
use LaTeXML::Core::Parameters;
use Time::HiRes;
use base qw(LaTeXML::Common::Object);
# Make these present, but do not import.
require LaTeXML::Core::Definition::Expandable;
require LaTeXML::Core::Definition::Conditional;
require LaTeXML::Core::Definition::Primitive;
require LaTeXML::Core::Definition::Register;
require LaTeXML::Core::Definition::CharDef;
require LaTeXML::Core::Definition::Constructor;

#**********************************************************************

sub isaDefinition {
  return 1; }

sub getCS {
  my ($self) = @_;
  return $$self{cs}; }

sub getCSName {
  my ($self) = @_;
  return (defined $$self{alias} ? $$self{alias} : $$self{cs}->getCSName); }

sub isExpandable {
  return 0; }

sub isRegister {
  return ''; }

sub isPrefix {
  return 0; }

sub getLocator {
  my ($self) = @_;
  return $$self{locator}; }

sub readArguments {
  my ($self, $gullet) = @_;
  my $params = $self->getParameters;
  return ($params ? $params->readArguments($gullet, $self) : ()); }

sub getParameters {
  my ($self) = @_;
  # Allow defering these until the Definition is actually used.
  if ((defined $$self{parameters}) && !ref $$self{parameters}) {
    require LaTeXML::Package;
    $$self{parameters} = LaTeXML::Package::parseParameters($$self{parameters}, $$self{cs}); }
  return $$self{parameters}; }

#======================================================================
# Overriding methods
sub stringify {
  my ($self) = @_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  my $name = ($$self{alias} || $$self{cs}->getCSName);
  return $type . '[' . ($$self{parameters}
    ? $name . ' ' . Stringify($$self{parameters}) : $name) . ']'; }

sub toString {
  my ($self) = @_;
  return ($$self{parameters}
    ? ToString($$self{cs}) . ' ' . ToString($$self{parameters}) : ToString($$self{cs})); }

# Return the Tokens that would invoke the given definition with arguments.
sub invocation {
  my ($self, @args) = @_;
  my $params = $self->getParameters;
  return ($$self{cs}, ($params ? $params->revertArguments(@args) : ())); }

#======================================================================
# Profiling support
#======================================================================
# If the value PROFILING is true, we'll collect some primitive profiling info.

# Start profiling $CS (typically $LaTeXML::CURRENT_TOKEN)
# Call from within ->invoke.
sub startProfiling {
  my ($cs) = @_;
  my $name = $cs->getCSName;
  my $entry = $STATE->lookupMapping('runtime_profile', $name);
  # [#calls, total time, starts of pending calls...]
  if (!defined $entry) {
    $entry = [0, 0]; $STATE->assignMapping('runtime_profile', $name, $entry); }
  $$entry[0]++;    # One more call.
  push(@$entry, [Time::HiRes::gettimeofday]);    # started new call
  return; }

# Stop profiling $CS, if it was being profiled.
sub stopProfiling {
  my ($cs) = @_;
  $cs = $cs->getString if $cs->getCatcode == CC_MARKER;    # Special case for macros!!
  my $name = $cs->getCSName;
  if (my $entry = $STATE->lookupMapping('runtime_profile', $name)) {
    if (scalar(@$entry) > 2) {
      # Hopefully we're the pop gets the corresponding start time!?!?!
      $$entry[1] += Time::HiRes::tv_interval(pop(@$entry), [Time::HiRes::gettimeofday]); } }
  return; }

our $MAX_PROFILE_ENTRIES = 50;                             # [CONSTANT]
# Print out profiling information, if any was collected
sub showProfile {
  if (my $profile = $STATE->lookupValue('runtime_profile')) {
    my @cs         = keys %$profile;
    my @unfinished = ();
    foreach my $cs (@cs) {
      push(@unfinished, $cs) if scalar(@{ $$profile{$cs} }) > 2; }

    my @frequent = sort { $$profile{$b}[0] <=> $$profile{$a}[0] } @cs;
    @frequent = @frequent[0 .. $MAX_PROFILE_ENTRIES];
    my @expensive = sort { $$profile{$b}[1] <=> $$profile{$a}[1] } @cs;
    @expensive = @expensive[0 .. $MAX_PROFILE_ENTRIES];
    print STDERR "\nProfiling results:\n";
    print STDERR "Most frequent:\n   "
      . join(', ', map { $_ . ':' . $$profile{$_}[0] } @frequent) . "\n";
    print STDERR "Most expensive (inclusive):\n   "
      . join(', ', map { $_ . ':' . sprintf("%.2fs", $$profile{$_}[1]) } @expensive) . "\n";

    if (@unfinished) {
      print STDERR "The following were never marked as done:\n  " . join(', ', @unfinished) . "\n"; }
  }
  return; }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition>  - Control sequence definitions.

=head1 DESCRIPTION

This abstract class represents the various executables corresponding to control sequences.
See L<LaTeXML::Package> for the most convenient means to create them.

It extends L<LaTeXML::Common::Object>.

=head2 Methods

=over 4

=item C<< $token = $defn->getCS; >>

Returns the (main) token that is bound to this definition.

=item C<< $string = $defn->getCSName; >>

Returns the string form of the token bound to this definition,
taking into account any alias for this definition.

=item C<< $defn->readArguments($gullet); >>

Reads the arguments for this C<$defn> from the C<$gullet>,
returning a list of L<LaTeXML::Core::Tokens>.

=item C<< $parameters = $defn->getParameters; >>

Return the C<LaTeXML::Core::Parameters> object representing the formal parameters
of the definition.

=item C<< @tokens = $defn->invocation(@args); >>

Return the tokens that would invoke the given definition with the
provided arguments.  This is used to recreate the TeX code (or it's
equivalent).

=item C<< $defn->invoke; >>

Invoke the action of the C<$defn>.  For expandable definitions, this is done in
the Gullet, and returns a list of L<LaTeXML::Core::Token>s.  For primitives, it
is carried out in the Stomach, and returns a list of L<LaTeXML::Core::Box>es.
For a constructor, it is also carried out by the Stomach, and returns a L<LaTeXML::Core::Whatsit>.
That whatsit will be responsible for constructing the XML document fragment, when the
L<LaTeXML::Core::Document> invokes C<$whatsit->beAbsorbed($document);>.

Primitives and Constructors also support before and after daemons, lists of subroutines
that are executed before and after digestion.  These can be useful for changing modes, etc.

=back

=head1 SEE ALSO

L<LaTeXML::Core::Definition::Expandable>,
L<LaTeXML::Core::Definition::Conditional>,
L<LaTeXML::Core::Definition::Primitive>,
L<LaTeXML::Core::Definition::Register>,
L<LaTeXML::Core::Definition::CharDef> and
L<LaTeXML::Core::Definition::Constructor>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
