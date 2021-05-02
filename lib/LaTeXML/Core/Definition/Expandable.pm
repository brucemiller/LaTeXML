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
  if (ref $expansion eq 'LaTeXML::Core::Tokens') {
    Fatal('misdefined', $cs, $source, "Expansion of '" . ToString($cs) . "' has unbalanced {}",
      "Expansion is " . ToString($expansion)) unless $expansion->isBalanced;
    # rescan for match tokens and unwrap dont_expand...
    $expansion = $expansion->packParameters unless $traits{nopackParameters};
  }
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    locator      => $source->getLocator,
    isProtected  => $traits{protected} || $STATE->getPrefix('protected'),
    isOuter      => $traits{outer}     || $STATE->getPrefix('outer'),
    isLong       => $traits{long}      || $STATE->getPrefix('long'),
    isExpandable => 1,
    %traits }, $class; }

sub isExpandable {
  return 1; }

sub getExpansion {
  my ($self) = @_;
  my $expansion = $$self{expansion};
  if (!ref $expansion) {    # Tokenization DEFERRED till actually used (shaves > 5%)
    $expansion = TokenizeInternal($expansion);
    # rescan for match tokens and unwrap dont_expand...
    $expansion = $expansion->packParameters;
    $$self{expansion} = $expansion; }
  return $expansion; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my ($self, $gullet, $onceonly) = @_;
  # shortcut for "trivial" macros; but only if not tracing & profiling!!!!
  my $tracing   = $STATE->lookupValue('TRACINGMACROS');
  my $profiled  = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  my $expansion = $self->getExpansion;
  my $etype     = ref $expansion;
  my $iscode    = $etype eq 'CODE';
  my $result;
  if ($iscode) {
    # Harder to emulate \tracingmacros here.
    my @args = $self->readArguments($gullet);
    LaTeXML::Core::Definition::startProfiling($profiled, 'expand') if $profiled;
    $result = Tokens(&$expansion($gullet, @args));
    if ($tracing) {    # More involved...
      print STDERR "\n" . $self->tracingCSName . ' ==> ' . tracetoString($result) . "\n";
      print STDERR $self->tracingArgs(@args) . "\n" if @args; } }
  elsif (!$$self{parameters}) {    # Trivial macro
    LaTeXML::Core::Definition::startProfiling($profiled, 'expand') if $profiled;
    if ($tracing) {                # More involved...
      print STDERR "\n" . $self->tracingCSName . ' -> ' . tracetoString($expansion) . "\n"; }
    # For trivial expansion, make sure we don't get \cs or \relax\cs direct recursion!
    if (!$onceonly && $$self{cs}) {
      my ($t0, $t1) = ($etype eq 'LaTeXML::Core::Tokens'
        ? ($$expansion[0], $$expansion[1]) : ($expansion, undef));
      if ($t0 && ($t0->equals($$self{cs})
          || ($t1 && $t1->equals($$self{cs}) && $t0->equals(T_CS('\protect'))))) {
        Error('recursion', $$self{cs}, $gullet,
          "Token " . Stringify($$self{cs}) . " expands into itself!",
          "defining as empty");
        $expansion = Tokens(); } }
    $result = $expansion; }
  else {
    my @args = $self->readArguments($gullet);
    # for "real" macros, make sure all args are Tokens
    my $r;
    my @targs = map { ($_ && ($r = ref $_)
          && (($r eq 'LaTeXML::Core::Token') || ($r eq 'LaTeXML::Core::Tokens'))
        ? $_ : Tokens(Revert($_))); } @args;
    if ($tracing) {    # More involved...
      print STDERR "\n" . $self->tracingCSName . ' -> ' . tracetoString($expansion) . "\n";
      print STDERR $self->tracingArgs(@targs) . "\n" if @args; }
    LaTeXML::Core::Definition::startProfiling($profiled, 'expand') if $profiled;
    $result = $expansion->substituteParameters(@targs); }
  # Getting exclusive requires dubious Gullet support!
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
    && Equals($self->getExpansion,  $other->getExpansion); }

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
