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
use base qw(LaTeXML::Core::Definition);

sub new {
  my ($class, $cs, $parameters, $expansion, %traits) = @_;
  $expansion = Tokens($expansion) if ref $expansion eq 'LaTeXML::Core::Token';
  my $source = $STATE->getStomach->getGullet->getMouth;
  if (ref $expansion eq 'LaTeXML::Core::Tokens') {
    my $level = 0;
    foreach my $t ($expansion->unlist) {
      $level++ if $t->equals(T_BEGIN);
      $level-- if $t->equals(T_END); }
    Fatal('misdefined', $cs, $source, "Expansion of '" . ToString($cs) . "' has unbalanced {}",
      "Expansion is " . ToString($expansion)) if $level; }
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    locator     => "from " . $source->getLocator(-1),
    isProtected => $STATE->getPrefix('protected'),
    %traits }, $class; }

sub isExpandable {
  return 1; }

sub isProtected {
  my ($self) = @_;
  return $$self{isProtected}; }

sub getExpansion {
  my ($self) = @_;
  if (!ref $$self{expansion}) {    # Tokenization DEFERRED till actually used (shaves > 5%)
    require LaTeXML::Package;      # make sure present, but no imports
    $$self{expansion} = LaTeXML::Package::TokenizeInternal($$self{expansion}); }
  return $$self{expansion}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my ($self, $gullet) = @_;
  return $self->doInvocation($gullet, $self->readArguments($gullet)); }

sub doInvocation {
  my ($self, $gullet, @args) = @_;
  my $expansion = $self->getExpansion;
  my $r;
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled) if $profiled;
  my @result;
  if ($STATE->lookupValue('TRACINGMACROS')) {    # More involved...
    if (ref $expansion eq 'CODE') {
      # Harder to emulate \tracingmacros here.
      @result = &$expansion($gullet, @args);
      print STDERR "\n" . ToString($self->getCSName) . ' ==> ' . tracetoString(Tokens(@result)) . "\n";
      my $i = 1;
      foreach my $arg (@args) {
        print STDERR '#' . $i++ . '<-' . ToString($arg) . "\n"; } }
    else {
      # for "real" macros, make sure all args are Tokens
      my @targs = map { $_ && (($r = ref $_) && ($r eq 'LaTeXML::Core::Tokens')
          ? $_
          : ($r && ($r eq 'LaTeXML::Core::Token')
            ? Tokens($_)
            : Tokens(Revert($_)))) }
        @args;
      print STDERR "\n" . ToString($self->getCSName) . ' -> ' . tracetoString($expansion) . "\n";
      my $i = 1;
      foreach my $arg (@targs) {
        print STDERR '#' . $i++ . '<-' . ToString($arg) . "\n"; }
      @result = substituteTokens($expansion, @targs); } }
  else {
    @result = (ref $expansion eq 'CODE'
      ? &$expansion($gullet, @args)
      : substituteTokens($expansion,
        map { $_ && (($r = ref $_) && ($r eq 'LaTeXML::Core::Tokens')
            ? $_
            : ($r && ($r eq 'LaTeXML::Core::Token')
              ? Tokens($_)
              : Tokens(Revert($_)))) }
          @args)); }
  # This would give (something like) "inclusive time"
  #  LaTeXML::Core::Definition::stopProfiling($profiled) if $profiled;
  # This gives (something like) "exclusive time"
  # but requires dubious Gullet support!
  push(@result, T_MARKER($profiled)) if $profiled;
  return @result; }

# print a string of tokens like TeX would when tracing.
sub tracetoString {
  my ($tokens) = @_;
  return join('', map { ($_->getCatcode == CC_CS ? $_->getString . ' ' : $_->getString) }
      $tokens->unlist); }

# NOTE: Assumes $tokens is a Tokens list of Token's and each arg either undef or also Tokens
# Using inline accessors on those assumptions
sub substituteTokens {
  my ($tokens, @args) = @_;
  my @in     = @{$tokens};    # ->unlist
  my @result = ();
  while (@in) {
    my $token;
    if (($token = shift(@in))->[1] != CC_PARAM) {    # Non '#'; copy it
      push(@result, $token); }
    elsif (($token = shift(@in))->[1] != CC_PARAM) {    # Not multiple '#'; read arg.
      if (my $arg = $args[ord($$token[0]) - ord('0') - 1]) {
        push(@result, @$arg); } }                       # ->unlist, assuming it's a Tokens() !!!
    else {                                              # Duplicated '#', copy 2nd '#'
      push(@result, $token); } }
  return @result; }

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
