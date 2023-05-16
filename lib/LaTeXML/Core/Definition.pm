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
use LaTeXML::Common::Error;
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

# NOTE: Need to clean up alias; really should already be Token (or Tokens?)
# and is not always a CS!
sub getCSorAlias {
  my ($self) = @_;
  return (defined $$self{alias} ? T_CS($$self{alias}) : $$self{cs}); }

sub isExpandable {
  return 0; }

sub isRegister {
  return ''; }

sub isPrefix {
  return 0; }

# The following come from flags, but probably(?) only make sense for Expandable (macros)
# and furthermore, only isProtected is used for anything significant.
sub isProtected {
  my ($self) = @_;
  return $$self{isProtected}; }

sub setIsProtected {
  my ($self) = @_;
  $$self{isProtected} = 1;
  return; }

sub isOuter {
  my ($self) = @_;
  return $$self{isOuter}; }

sub setIsOuter {
  my ($self) = @_;
  $$self{isOuter} = 1;
  return; }

sub isLong {
  my ($self) = @_;
  return $$self{isLong}; }

sub setIsLong {
  my ($self) = @_;
  $$self{isLong} = 1;
  return; }

sub getLocator {
  my ($self) = @_;
  return $$self{locator}; }

sub readArguments {
  my ($self, $gullet) = @_;
  return ($$self{parameters} ? $$self{parameters}->readArguments($gullet, $self) : ()); }

sub getParameters {
  my ($self) = @_;
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

#======================================================================
# Tracing support
sub tracingCSName {
  my ($self) = @_;
  my $parameters = $$self{parameters};
  return ToString($self->getCSName)
    # Show parameter string too
    . ($parameters ? ' ' . ToString($parameters) : '')
    # And if this was \let to something show the name it was called by
    . ($LaTeXML::CURRENT_TOKEN && !$$self{cs}->equals($LaTeXML::CURRENT_TOKEN)
    ? ' [for ' . ToString($LaTeXML::CURRENT_TOKEN) . ']' : ''); }

sub tracingArgs {
  my ($self, @args) = @_;
  my $i = 1;
  return join("\n", map { '#' . $i++ . '<-' . tracingArgToString($_) } @args); }

# Annoying special handing of registers
sub tracingArgToString {
  my ($arg) = @_;
  return (ref $arg eq 'ARRAY' ? '[' . join(',', map { ToString($_) } @$arg) . ']' : ToString($arg)); }

#======================================================================
# Profiling support
#======================================================================
# If the value PROFILING is true, we'll collect some primitive profiling info.

# Start profiling $CS (typically $LaTeXML::CURRENT_TOKEN)
# Call from within ->invoke.
# $mode = expand | digest | absorb
sub startProfiling {
  my ($cs, $mode) = @_;
  my $name  = $cs->getCSName;
  my $entry = $STATE->lookupMapping('runtime_profile', $name);
  # [#calls, max_depth, inclusive_time, exclusive_time, #pending
  #   starts of pending calls...]
  if (!defined $entry) {
    $entry = [0, 0, 0, 0, 0]; $STATE->assignMapping('runtime_profile', $name, $entry); }
  $$entry[0]++ unless $mode eq 'absorb';    # One more call.
  $$entry[4]++;                             # One more pending...
                                            #Debug("START PROFILE $mode of ".ToString($cs));
  $STATE->pushValue('runtime_stack', [$name, $mode, [Time::HiRes::gettimeofday], $entry]);
  return; }

# Stop profiling $CS.
# Complication w/Macros: If the expansion of a macro contains CS's that read tokens,
# the end MARKER of macros may get read before the macro's effects have really been processed.
# So we need to ignore a stop on a macro that isn't at the top of the stack,
# and conversely, automatically stop a macro that is at the top above a CS that is being stopped.
sub stopProfiling {
  my ($cs, $mode) = @_;
  $cs = $cs->getString if $cs->getCatcode == CC_MARKER;    # Special case for macros!!
  return unless ref $cs;
  my $name      = $cs->getCSName;
  my $stack     = $STATE->lookupValue('runtime_stack');
  my $currdepth = scalar(@$stack);
  my $prevdepth = $STATE->lookupValue('runtime_maxdepth') || '0';
  $STATE->assignValue('runtime_maxdepth' => $currdepth, 'global') if $currdepth > $prevdepth;

  while (@{$stack}) {
    my ($top, $topmode, $t0, $entry) = @{ $$stack[-1] };
    if ((($top ne $name) || ($topmode ne $mode)) && ($topmode ne 'expand')) {
      return if $mode eq 'expand';    # No error (yet) if this is a macro end marker.
      Debug("PROFILE Error: ending $mode of $name but stack holds "
          . join(',', map { $$_[0] . '(' . $$_[1] . ')' } @$stack) . ", $top ($topmode)");
      return; }
    pop(@$stack);
    my $duration = Time::HiRes::tv_interval($t0, [Time::HiRes::gettimeofday]);
    my $depth    = $$entry[4];
    if ($depth > $$entry[1]) {
      $$entry[1] = $depth; }
    $$entry[2] += $duration if $depth == 1;    # add to inclusive time only in uppermost call
    $$entry[3] += $duration;                   # add to exclusive time (see below)
    $$entry[4]--;
    if (my $caller = $$stack[-1]) {
      my ($callername, $callermode, $callerstart, $callerentry) = @$caller;
      $$callerentry[3] -= $duration; }         # Remove our cost from caller's exclusive time.
    return if $top eq $name; }
  Debug("PROFILE Error: ending $mode of $name but stack is empty")
    unless $mode eq 'expand';
  return; }

our $MAX_PROFILE_ENTRIES = 30;    # [CONSTANT]

# Print out profiling information, if any was collected
sub showProfile {
  if (my $profile = $STATE->lookupValue('runtime_profile')) {
    my @cs    = keys %$profile;
    my $calls = 0;
    map { $calls += $$profile{$_}[0] } @cs;
    my $depth    = $STATE->lookupValue('runtime_maxdepth');
    my @frequent = sort { $$profile{$b}[0] <=> $$profile{$a}[0] } @cs;
    @frequent = @frequent[0 .. $MAX_PROFILE_ENTRIES];
    my @deepest = sort { $$profile{$b}[1] <=> $$profile{$a}[1] } @cs;
    @deepest = @deepest[0 .. $MAX_PROFILE_ENTRIES];
    my @inclusive = sort { $$profile{$b}[2] <=> $$profile{$a}[2] } @cs;
    @inclusive = @inclusive[0 .. $MAX_PROFILE_ENTRIES];
    my @exclusive = sort { $$profile{$b}[3] <=> $$profile{$a}[3] } @cs;
    @exclusive = @exclusive[0 .. $MAX_PROFILE_ENTRIES];
    Debug("Profiling results:");
    Debug("Total calls: $calls; Maximum depth: $depth");
    Debug("Most frequent:\n   "
        . join(', ', map { $_ . ':' . $$profile{$_}[0] } @frequent));
    Debug("Deepest :\n   "
        . join(', ', map { $_ . ':' . $$profile{$_}[1] } @deepest));
    Debug("Most expensive inclusive:\n   "
        . join(', ', map { $_ . ':' . sprintf("%.2fs/%d", $$profile{$_}[2], $$profile{$_}[0]) } @inclusive));
    Debug("Most expensive exclusive:\n   "
        . join(', ', map { $_ . ':' . sprintf("%.2fs/%d", $$profile{$_}[3], $$profile{$_}[0]) } @exclusive));
    my $stack = $STATE->lookupValue('runtime_stack');
    if (@$stack) {
      Debug("The following were never marked as done:\n  "
          . join(', ', map { $$_[0] . '(' . $$_[1] . ')' } @$stack)); } }
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
