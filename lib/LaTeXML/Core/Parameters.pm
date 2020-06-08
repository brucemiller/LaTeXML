# /=====================================================================\ #
# |  LaTeXML::Core::Parameters                                          | #
# | Representation of Parameters for Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Parameters;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Parameter;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Token;
use base qw(LaTeXML::Common::Object);

sub new {
  my ($class, @paramspecs) = @_;
  return bless [@paramspecs], $class; }

sub getParameters {
  my ($self) = @_;
  return @$self; }

sub stringify {
  my ($self) = @_;
  my $string = '';
  foreach my $parameter (@$self) {
    my $s = $parameter->stringify;
    $string .= ' ' if ($string =~ /\w$/) && ($s =~ /^\w/);
    $string .= $s; }
  return $string; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other)
    && ((ref $self) eq (ref $other)) && ($self->stringify eq $other->stringify); }

sub getNumArgs {
  my ($self) = @_;
  my $n = 0;
  foreach my $parameter (@$self) {
    $n++ unless $$parameter{novalue}; }
  return $n; }

sub revertArguments {
  my ($self, @args) = @_;
  my @tokens = ();
  foreach my $parameter (@$self) {
    next if $$parameter{novalue};
    push(@tokens, $parameter->revert(shift(@args))); }
  return @tokens; }

sub readArguments {
  my ($self, $gullet, $fordefn) = @_;
  my @args = ();
  foreach my $parameter (@$self) {
    my $value = $parameter->read($gullet, $fordefn);
    if (!$$parameter{novalue}) {
      $value = rescanMatchTokens($value);
      push(@args, $value); } }
  return @args; }

sub readArgumentsAndDigest {
  my ($self, $stomach, $fordefn) = @_;
  my @args   = ();
  my $gullet = $stomach->getGullet;
  foreach my $parameter (@$self) {
    my $value = $parameter->read($gullet, $fordefn);
    if (!$$parameter{novalue}) {
      $value = rescanMatchTokens($value);
      $value = $parameter->digest($stomach, $value, $fordefn);
      push(@args, $value); } }
  return @args; }

sub reparseArgument {
  my ($self, $gullet, $tokens) = @_;
  if (defined $tokens) {
    return $gullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {    # start with empty mouth
        my ($gulletx) = @_;
        $gulletx->unread($tokens);                                         # but put back tokens to be read
        my @values = $self->readArguments($gulletx);
        $gulletx->skipSpaces;
        return @values; }); }
  else {
    return (); } }

# Special case, group match tokens together exactly (and only) when building parameter lists
sub rescanMatchTokens {
  my ($tokens) = @_;
  if (ref $tokens eq 'LaTeXML::Core::Tokens' && scalar(@$tokens) >= 2) {
    my @toks      = @$tokens;
    my @rescanned = ();
    while (my $t = shift @toks) {
      if ($$t[1] == CC_PARAM && @toks) {
        my $next_t = shift @toks;
        if ($$next_t[1] == CC_OTHER && $$next_t[0] =~ /^\d$/) {
          # only group clear match token cases
          push(@rescanned, T_MATCH($next_t)); }
        else {    # any other case, preserve as-is, let the higher level call resolve any errors
                  # e.g. \detokenize{#,} is legal, while \textbf{#,} is not
          push(@rescanned, $t, $next_t); }
      } else {
        push(@rescanned, $t); } }
    return Tokens(@rescanned);
  } else {
    return $tokens; } }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Parameters> - formal parameters.

=head1 DESCRIPTION

Provides a representation for the formal parameters of L<LaTeXML::Core::Definition>s:
It extends L<LaTeXML::Common::Object>.

=head2 METHODS

=over 4

=item C<< @parameters = $parameters->getParameters; >>

Return the list of C<LaTeXML::Core::Parameter> contained in C<$parameters>.

=item C<< @tokens = $parameters->revertArguments(@args); >>

Return a list of L<LaTeXML::Core::Token> that would represent the arguments
such that they can be parsed by the Gullet.

=item C<< @args = $parameters->readArguments($gullet,$fordefn); >>

Read the arguments according to this C<$parameters> from the C<$gullet>.
This takes into account any special forms of arguments, such as optional,
delimited, etc.

=item C<< @args = $parameters->readArgumentsAndDigest($stomach,$fordefn); >>

Reads and digests the arguments according to this C<$parameters>, in sequence.
this method is used by Constructors.

=back

=head1 SEE ALSO

L<LaTeXML::Core::Parameter>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
