
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

sub isExpandable {
  return 1; }

sub isProtected {
  my ($self) = @_;
  return $$self{isProtected}; }

# For \if expandables!!!!
sub getTest {
  my ($self) = @_;
  return $$self{test}; }

sub getExpansion {
  my ($self) = @_;
  my $expansion = $$self{expansion};
  if (defined $expansion && !ref $expansion) { # Tokenization DEFERRED till actually used (shaves > 5%)
    require LaTeXML::Package;                  # make sure present, but no imports
    $$self{expansion} = $expansion = LaTeXML::Package::TokenizeInternal($expansion);
    if (!$$self{parameters}) {                 # And prepare for future simpler expansions
      $$self{trivial_expansion} = $$self{expansion}->substituteParameters(); } }
  return $expansion; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub doInvocation {
  my ($self, $gullet, @args) = @_;
  my $expansion = $$self{expansion};
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
      print STDERR "\n" . $self->tracingCSName
        . ' -> ' . tracetoString($expansion) . "\n";
      print STDERR $self->tracingArgs(@args) . "\n" if @args;
      @result = $expansion->substituteParameters(@args)->unlist; } }
  else {
    if (ref $expansion eq 'CODE') {
      @result = &$expansion($gullet, @args); }
    else {
      # but for tokens, make sure args are proper Tokens (lists)
      @result = $expansion->substituteParameters(@args)->unlist; } }
  # Getting exclusive requires dubious Gullet support!
  push(@result, T_MARKER($profiled)) if $profiled;
  return Tokens(@result); }

# print a string of tokens like TeX would when tracing.
sub tracetoString {
  my ($tokens) = @_;
  return join('', map { ($_->getCatcode == CC_CS ? $_->getString . ' ' : $_->getString) }
      $tokens->unlist); }

sub equals {
  my ($self, $other) = @_;
  return (defined $other && (ref $self) eq (ref $other))
    && Equals($$self{parameters},  $$other{parameters})
    && Equals($self->getExpansion, $other->getExpansion); }

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
