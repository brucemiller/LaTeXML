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
    my $arg = shift(@args);
    if (my $retoker = $$parameter{reversion}) {
      push(@tokens, &$retoker($arg, @{ $$parameter{extra} || [] })); }
    else {
      push(@tokens, Revert($arg)) if ref $arg; } }
  return @tokens; }

sub readArguments {
  my ($self, $gullet, $fordefn) = @_;
  my @args = ();
  foreach my $parameter (@$self) {
    #    my $value = &{$$parameter{reader}}($gullet,@{$$parameter{extra}||[]});
    my $value = $parameter->read($gullet);
    if ((!defined $value) && !$$parameter{optional}) {
      Error('expected', $parameter, $gullet,
        "Missing argument " . ToString($parameter) . " for " . ToString($fordefn),
        $gullet->showUnexpected); }
    push(@args, $value) unless $$parameter{novalue}; }
  return @args; }

sub readArgumentsAndDigest {
  my ($self, $stomach, $fordefn) = @_;
  my @args   = ();
  my $gullet = $stomach->getGullet;
  foreach my $parameter (@$self) {
    #    my $value = &{$$parameter{reader}}($gullet,@{$$parameter{extra}||[]});
    my $value = $parameter->read($gullet);
    if ((!defined $value) && !$$parameter{optional}) {
      Error('expected', $parameter, $stomach,
        "Missing argument " . Stringify($parameter) . " for " . Stringify($fordefn),
        $gullet->showUnexpected); }
    if (!$$parameter{novalue}) {
      $STATE->beginSemiverbatim() if $$parameter{semiverbatim};    # Corner case?
      $value = $value->beDigested($stomach) if (ref $value) && !$$parameter{undigested};
      $STATE->endSemiverbatim() if $$parameter{semiverbatim};      # Corner case?
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
