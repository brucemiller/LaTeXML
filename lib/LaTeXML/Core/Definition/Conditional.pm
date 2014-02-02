# /=====================================================================\ #
# |  LaTeXML::Core::Definition::Conditional                             | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::Conditional;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use base qw(LaTeXML::Core::Definition::Expandable);

# Conditional control sequences; Expandable
#   Expand enough to determine true/false, then maybe skip
#   record a flag somewhere so that \else or \fi is recognized
#   (otherwise, they should signal an error)

sub new {
  my ($class, $cs, $parameters, $test, %traits) = @_;
  my $source = $STATE->getStomach->getGullet->getMouth;
  return bless { cs => $cs, parameters => $parameters, test => $test,
    locator => "from " . $source->getLocator(-1),
    %traits }, $class; }

sub getTest {
  my ($self) = @_;
  return $$self{test}; }

# Note that although conditionals are Expandable,
# they do NOT defined as macros, so they don't need to handle doInvocation,
sub invoke {
  my ($self, $gullet) = @_;
  # A real conditional must have is_conditional set
  if ($$self{is_conditional}) {
    return $self->invoke_conditional($gullet); }
  elsif ($$self{is_else}) {
    return $self->invoke_else($gullet); }
  elsif ($$self{is_or}) {
    return $self->invoke_else($gullet); }
  elsif ($$self{is_fi}) {
    return $self->invoke_fi($gullet); }
  else {
    Error('unexpected', $$self{cs}, $gullet,
      "Unknown conditional control sequence " . Stringify($LaTeXML::CURRENT_TOKEN));
    return; } }

#sub invoke {
sub invoke_conditional {
  my ($self, $gullet) = @_;
  # Keep a stack of the conditionals we are processing.
  my $ifid = $STATE->lookupValue('if_count') || 0;
  $STATE->assignValue(if_count => ++$ifid, 'global');
  local $LaTeXML::IFFRAME = { token => $LaTeXML::CURRENT_TOKEN, start => $gullet->getLocator,
    parsing => 1, elses => 0, ifid => $ifid };
  $STATE->unshiftValue(if_stack => $LaTeXML::IFFRAME);

  my @args = $self->readArguments($gullet);
  $$LaTeXML::IFFRAME{parsing} = 0;    # Now, we're done parsing the Test clause.
  my $tracing = $STATE->lookupValue('TRACINGCOMMANDS');
  print STDERR '{' . ToString($LaTeXML::CURRENT_TOKEN) . "} [#$ifid]\n" if $tracing;
  if (my $test = $self->getTest) {
    my $result = &$test($gullet, @args);
    if ($result) {
      print STDERR "{true}\n" if $tracing; }
    else {
      my $to = skipConditionalBody($gullet, -1);
      print STDERR "{false} [skipped to " . ToString($to) . "]\n" if $tracing; } }
  # If there's no test, it must be the Special Case, \ifcase
  else {
    my $num = $args[0]->valueOf;
    if ($num > 0) {
      my $to = skipConditionalBody($gullet, $num);
      print STDERR "{$num} [skipped to " . ToString($to) . "]\n" if $tracing; } }
  return; }

#======================================================================
# Support for conditionals:

# Skipping for conditionals
#   0 : skip to \fi
#  -1 : skip to \else, if any, or \fi
#   n : skip to n-th \or, if any, or \else, if any, or \fi.

# NOTE that there are 2 kinds of "nested" ifs.
#  \if's inside the body of either the true or false branch
# are easily skipped by tracking a level of if nesting and skipping over the
# same number of \fi as you find \if.
#  \if's that get expanded while evaluating the test clause itself
# are considerably trickier. There's a frame on the if-stack for this \if
# that's above the one we're currently processing; typically the \else & \fi
# may still remain, but we need to either evaluate them a normal
# if we're continuing to follow the true branch, or skip oever them if
# we're trying to find the \else for the false branch.
# The danger is mistaking the \else that's associated with the test clause's \if
# and taking it for the \else that we're skipping to!
# Canonical example:
#   \if\ifx AA XY junk \else blah \fi True \else False \fi
# The inner \ifx should expand to "XY junk", since A==A
# Return the token we've skipped to, and the frame that this applies to.
sub skipConditionalBody {
  my ($gullet, $nskips) = @_;
  my $level = 1;
  my $n_ors = 0;
  my $start = $gullet->getLocator;
  while (my $t = $gullet->readToken) {
    # The only Interesting tokens are bound to defns (defined OR \let!!!)
    if (defined(my $defn = $STATE->lookupDefinition($t))) {
      if ($$defn{is_conditional}) {    #  Found a \ifxx of some sort
        $level++; }
      elsif ($$defn{is_fi}) {          #  Found a \fi
                                       # But is it for a condition nested in the test clause?
        if ($STATE->lookupValue('if_stack')->[0] ne $LaTeXML::IFFRAME) {
          $STATE->shiftValue('if_stack'); }    # then DO pop that conditional's frame; it's DONE!
        elsif (!--$level) {                    # If no more nesting, we're done.
          $STATE->shiftValue('if_stack');      # Done with this frame
          return $t; } }                       # AND Return the finishing token.
      elsif ($level > 1) {                     # Ignore \else,\or nested in the body.
      }
      elsif ($$defn{is_or} && (++$n_ors == $nskips)) {
        return $t; }
      elsif ($$defn{is_else} && $nskips
        # Found \else and we're looking for one?
        # Make sure this \else is NOT for a nested \if that is part of the test clause!
        && ($STATE->lookupValue('if_stack')->[0] eq $LaTeXML::IFFRAME)) {
        # No need to actually call elseHandler, but note that we've seen an \else!
        $STATE->lookupValue('if_stack')->[0]->{elses} = 1;
        return $t; } } }
  Error('expected', '\fi', $gullet, "Missing \\fi or \\else, conditional fell off end",
    "Conditional started at $start");
  return; }

sub invoke_else {
  my ($self, $gullet) = @_;
  my $stack = $STATE->lookupValue('if_stack');
  if (!($stack && $$stack[0])) {    # No if stack entry ?
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $gullet,
      "Didn't expect a " . Stringify($LaTeXML::CURRENT_TOKEN)
        . " since we seem not to be in a conditional");
    return; }
  elsif ($$stack[0]{parsing}) {     # Defer expanding the \else if we're still parsing the test
    return (T_CS('\relax'), $LaTeXML::CURRENT_TOKEN); }
  elsif ($$stack[0]{elses}) {       # Already seen an \else's at this level?
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $gullet,
      "Extra " . Stringify($LaTeXML::CURRENT_TOKEN),
"already saw \\else for " . Stringify($$stack[0]{token}) . " [" . $$stack[0]{ifid} . "] at " . $$stack[0]{start});
    return; }
  else {
    local $LaTeXML::IFFRAME = $$stack[0];
    my $t = skipConditionalBody($gullet, 0);
    print STDERR '{' . ToString($LaTeXML::CURRENT_TOKEN) . '}'
      . " [for " . ToString($$LaTeXML::IFFRAME{token}) . " #" . $$LaTeXML::IFFRAME{ifid}
      . " skipping to " . ToString($t) . "]\n"
      if $STATE->lookupValue('TRACINGCOMMANDS');
    return; } }

sub invoke_fi {
  my ($self, $gullet) = @_;
  my $stack = $STATE->lookupValue('if_stack');
  if (!($stack && $$stack[0])) {    # No if stack entry ?
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $gullet,
      "Didn't expect a " . Stringify($LaTeXML::CURRENT_TOKEN)
        . " since we seem not to be in a conditional");
    return; }
  elsif ($$stack[0]{parsing}) {     # Defer expanding the \else if we're still parsing the test
    return (T_CS('\relax'), $LaTeXML::CURRENT_TOKEN); }
  else {                            # "expand" by removing the stack entry for this level
    local $LaTeXML::IFFRAME = $$stack[0];
    $STATE->shiftValue('if_stack');    # Done with this frame
    print STDERR '{' . ToString($LaTeXML::CURRENT_TOKEN) . '}'
      . " [for " . Stringify($$LaTeXML::IFFRAME{token}) . " #" . $$LaTeXML::IFFRAME{ifid} . "]\n"
      if $STATE->lookupValue('TRACINGCOMMANDS');
    return; } }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::Conditional>  - Conditionals Control sequence definitions.

=head1 DESCRIPTION

These represent the control sequences for conditionals, as well as
C<\else>, C<\or> and C<\fi>.
See L<LaTeXML::Package> for the most convenient means to create them.

It extends L<LaTeXML::Core::Definition::Expandable>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
