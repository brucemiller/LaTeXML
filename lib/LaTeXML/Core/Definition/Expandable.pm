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

package LaTeXML::Core::Definition::Expandable;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Parameters;
use LaTeXML::Package qw(TokenizeInternal);
use base qw(LaTeXML::Core::Definition);

sub new {
  my ($class, $cs, $parameters, $expansion, %traits) = @_;
  $expansion = Tokens($expansion) if ref $expansion eq 'LaTeXML::Core::Token';
  my $source = $STATE->getStomach->getGullet->getMouth;
  my $trivexpansion;
  if (ref $expansion eq 'LaTeXML::Core::Tokens') {
    Fatal('misdefined', $cs, $source, "Expansion of '" . ToString($cs) . "' has unbalanced {}",
      "Expansion is " . ToString($expansion)) unless $expansion->isBalanced;
    # rescan for match tokens and unwrap dont_expand...
    $expansion = Tokens(PrepArgTokens(@$expansion));
    # If expansion is Tokens, and no arguments, we're a "trivial macro"
    if (!$parameters) {
      $trivexpansion = $expansion; }
  }
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    trivial_expansion => $trivexpansion,
    locator           => $source->getLocator,
    isProtected       => $traits{protected} || $STATE->getPrefix('protected'),
    isOuter           => $traits{outer} || $STATE->getPrefix('outer'),
    isLong            => $traits{long} || $STATE->getPrefix('long'),
    isExpandable      => 1,
    %traits }, $class; }

sub isExpandable {
  return 1; }

sub getExpansion {
  my ($self) = @_;
  my $expansion = $$self{expansion};
  if (!ref $expansion) {    # Tokenization DEFERRED till actually used (shaves > 5%)
    $expansion = TokenizeInternal($expansion);
    # rescan for match tokens and unwrap dont_expand...
    $expansion = Tokens(PrepArgTokens(@$expansion));
    $$self{expansion} = $expansion; }
  return $expansion; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my ($self, $gullet, $onceonly) = @_;
  # shortcut for "trivial" macros; but only if not tracing & profiling!!!!
  if (my $triv = (!$STATE->lookupValue('TRACINGMACROS')) && $$self{trivial_expansion}) {
    if (!$onceonly && recursion_check($$self{cs}, $triv->unlist)) {
      Error('recursion', $$self{cs}, $gullet,
        "Token " . Stringify($$self{cs}) . " expands into itself!",
        "defining as empty");
      $triv = Tokens(); }
    return $triv; }
  else {
    return $self->doInvocation($gullet, $self->readArguments($gullet)); } }

sub doInvocation {
  my ($self, $gullet, @args) = @_;
  my $expansion = $self->getExpansion;
  my $r;
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled, 'expand') if $profiled;
  my @result;
  if ($STATE->lookupValue('TRACINGMACROS')) {    # More involved...
    if (ref $expansion eq 'CODE') {
      # Harder to emulate \tracingmacros here.
      @result = &$expansion($gullet, @args);
      # CHECK @result HERE TOO!!!!
      print STDERR "\n" . $self->tracingCSName . ' ==> ' . tracetoString(Tokens(@result)) . "\n";
      print STDERR $self->tracingArgs(@args) . "\n" if @args; }
    else {
      # for "real" macros, make sure all args are Tokens
      my @targs = map { $_ && (($r = ref $_) && ($r eq 'LaTeXML::Core::Tokens')
          ? $_
          : ($r && ($r eq 'LaTeXML::Core::Token')
            ? Tokens($_)
            : Tokens(Revert($_)))) }
        @args;
      print STDERR "\n" . $self->tracingCSName
        . ' -> ' . tracetoString($expansion) . "\n";
      print STDERR $self->tracingArgs(@targs) . "\n" if @args;
      @result = $expansion->substituteParameters(@targs)->unlist; } }
  else {
    if (ref $expansion eq 'CODE') {
      my $t;
      # Check the result from code calls.
      @result = map { (($t = ref $_) eq 'LaTeXML::Core::Token' ? $_
          : ($t eq 'LaTeXML::Core::Tokens' ? @$_
            : (Error('misdefined', $self, undef,
                "Expected a Token in expansion of " . ToString($self),
                "got " . Stringify($_)), ()))) }
        &$expansion($gullet, @args); }
    else {
      # but for tokens, make sure args are proper Tokens (lists)
      @result = $expansion->substituteParameters(
        map { $_ && (($r = ref $_) && ($r eq 'LaTeXML::Core::Tokens')
            ? $_
            : ($r && ($r eq 'LaTeXML::Core::Token')
              ? Tokens($_)
              : Tokens(Revert($_)))) }
          @args)->unlist; } }
  # Avoid simplest case of infinite-loop expansion.
  if ((ref $expansion ne 'CODE') && !scalar(@args) && recursion_check($$self{cs}, @result)) {
    Error('recursion', $$self{cs}, $gullet,
      "Token " . Stringify($$self{cs}) . " expands into itself!",
      "defining as empty");
    @result = (); }
  # Getting exclusive requires dubious Gullet support!
  push(@result, T_MARKER($profiled)) if $profiled;
  return [@result]; }

sub recursion_check {
  my ($cs, @tokens) = @_;
  # expect $expansion as Token, Tokens or [Token...] ! Argh !
  return $cs &&
    (($tokens[0] && $tokens[0]->equals($cs))
    || ($tokens[1] && $tokens[1]->equals($cs) && $tokens[0]->equals(T_CS('\protect')))); }

# print a string of tokens like TeX would when tracing.
sub tracetoString {
  my ($tokens) = @_;
  return join('', map { ($_->getCatcode == CC_CS ? $_->toString . ' ' : $_->toString) }
      $tokens->unlist); }

sub equals {
  my ($self, $other) = @_;
  return (defined $other && (ref $self) eq (ref $other))
    && Equals($self->getParameters, $other->getParameters)
    && Equals($self->getExpansion,  $other->getExpansion); }

# Groups PARAM+OTHER token pair into match tokens.
# Collapses PARAM+PARAM token pair into a single PARAM
# B book suggests running this
sub PrepArgTokens {
  my (@toks) = @_;
  my @masks;
  if (ref $toks[-1] eq 'ARRAY') {
    # we have masks!
    my $masks = pop(@toks);
    @masks = @$masks; }
  my @rescanned = ();
  my $index     = -1;
  while (my $t = shift @toks) {
    $index++;
    $t = $$t[2] || $t;    # remove noexpand flag
    if (@masks && $masks[$index]) {
      push(@rescanned, $t); }
    elsif ($$t[1] == CC_PARAM && @toks) {
      my $next_t = shift @toks;
      $index++;
      $next_t = $$next_t[2] || $next_t;
      my $next_cc = $next_t && $$next_t[1];
      if ($next_cc == CC_OTHER) {
        # only group clear match token cases
        push(@rescanned, T_ARG($next_t)); }
      elsif ($next_cc == CC_PARAM) {
        push(@rescanned, $t); }
      else {    # any other case, preserve as-is, let the higher level call resolve any errors
                # e.g. \detokenize{#,} is legal, while \textbf{#,} is not
        Error('misdefined', 'expansion', undef, "Parameter has a malformed arg, should be #1-#9 or ##. ",
          "In expansion " . ToString(Tokens(@toks))); } }
    else {
      push(@rescanned, $t); } }
  return @rescanned; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Definition::Expandable>  - Expandable Control sequence definitions.

=head1 DESCRIPTION

These represent macros and other expandable control sequences
that are carried out in the Gullet during expansion. The results of invoking an
C<LaTeXML::Core::Definition::Expandable> should be a list of C<LaTeXML::Core::Token>s.
See L<LaTeXML::Package> for the most convenient means to create Expandables.

It extends L<LaTeXML::Core::Definition>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
