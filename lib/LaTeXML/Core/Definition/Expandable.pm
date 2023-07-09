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
use base             qw(LaTeXML::Core::Definition);

sub new {
  my ($class, $cs, $parameters, $expansion, %traits) = @_;
  my $source = $STATE->getStomach->getGullet->getMouth;
  my $type   = ref $expansion;
  # expansion must end up Tokens or CODE
  if (!$type) {
    $expansion = TokenizeInternal($expansion)->packParameters; }
  elsif ($type eq 'LaTeXML::Core::Token') {
    $expansion = TokensI($expansion); }
  elsif ($type eq 'LaTeXML::Core::Tokens') {
    Fatal('misdefined', $cs, $source, "Expansion of '" . ToString($cs) . "' has unbalanced {}",
      "Expansion is " . ToString($expansion)) unless $expansion->isBalanced;
    $expansion = $expansion->packParameters unless $traits{nopackParameters}; }
  elsif ($type ne 'CODE') {
    Error('misdefined', $cs, $source,
      "Expansion of '" . ToString($cs) . "' cannot be of type '$type'");
    $expansion = TokensI(); }
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    locator     => $source->getLocator,
    isProtected => $traits{protected} || $STATE->getPrefix('protected'),
    isOuter     => $traits{outer}     || $STATE->getPrefix('outer'),
    isLong      => $traits{long}      || $STATE->getPrefix('long'),
    hasCCARG    => (($type ne 'CODE') && (grep { $$_[1] == CC_ARG; } $expansion->unlist) ? 1 : 0),
    %traits }, $class; }

sub isExpandable {
  return 1; }

sub getExpansion {
  my ($self) = @_;
  return $$self{expansion}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
# This MUST return Tokens() or undef. (NOT a Token)
sub invoke {
  no warnings 'recursion';
  my ($self, $gullet, $onceonly) = @_;
  # shortcut for "trivial" macros; but only if not tracing & profiling!!!!
  my $_tracing  = $STATE->lookupValue('TRACING') || 0;
  my $tracing   = ($_tracing & TRACE_MACROS);
  my $profiled  = ($_tracing & TRACE_PROFILE) && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  my $expansion = $$self{expansion};
  my $etype     = ref $expansion;
  my $result;
  my $parms = $$self{parameters};

  LaTeXML::Core::Definition::startProfiling($profiled, 'expand') if $profiled;
  if ($etype eq 'CODE') {
    # Harder to emulate \tracingmacros here.
    my @args = ($parms ? $parms->readArguments($gullet, $self) : ());
    $result = Tokens(&$expansion($gullet, @args));
    if ($tracing) {
      Debug($self->tracingCSName . ' ==> ' . tracetoString($result));
      Debug($self->tracingArgs(@args)) if @args; } }
  elsif (!$parms) {    # Trivial macro
    Debug($self->tracingCSName . ' ->' . tracetoString($expansion)) if $tracing;
    # For trivial expansion, make sure we don't get \cs or \relax\cs direct recursion!
    if (!$onceonly && $$self{cs}) {
      my ($t0, $t1) = ($etype eq 'LaTeXML::Core::Tokens'
        ? ($$expansion[0], $$expansion[1]) : ($expansion, undef));
      if ($t0 && ($t0->equals($$self{cs})
          || ($t1 && $t1->equals($$self{cs}) && $t0->equals(T_CS('\protect'))))) {
        Error('recursion', $$self{cs}, $gullet,
          "Token " . Stringify($$self{cs}) . " expands into itself!",
          "defining as empty");
        $expansion = TokensI(); } }
    $result = $expansion; }
  else {
    my @args = $parms->readArguments($gullet, $self);
    if ($$self{hasCCARG}) {    # Do we actually need to substitute the args in?
      my $r;                   # Make sure they are actually Tokens!
      @args = map { ($_ && ($r = ref $_)
            && (($r eq 'LaTeXML::Core::Token') || ($r eq 'LaTeXML::Core::Tokens'))
          ? $_ : Tokens(Revert($_))); } @args;
      $result = $expansion->substituteParameters(@args); }
    else {
      $result = $expansion; }
    if ($tracing) {    # More involved...
      Debug($self->tracingCSName . ' ->' . tracetoString($expansion));
      Debug($self->tracingArgs(@args)) if @args; } }
  # Getting exclusive profiling requires dubious Gullet support!
  $result = Tokens($result, T_MARKER($profiled)) if $profiled;
  return $result; }

# print a string of tokens like TeX would when tracing.
sub tracetoString {
  my ($tokens) = @_;
  return join('', map { ($_->getCatcode == CC_CS ? $_->toString . ' ' : $_->toString) }
      $tokens->unlist); }

sub equals {
  my ($self, $other) = @_;
  return (defined $other && (ref $self) eq (ref $other))
    && Equals($self->getParameters, $other->getParameters)
    && Equals($$self{expansion},    $$other{expansion}); }

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
