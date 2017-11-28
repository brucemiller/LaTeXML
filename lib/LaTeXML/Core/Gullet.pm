# /=====================================================================\ #
# |  LaTeXML::Core::Gullet                                              | #
# | Analog of TeX's Gullet; deals with expansion and arg parsing        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Gullet;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Mouth;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::Number;
use LaTeXML::Common::Float;
use LaTeXML::Common::Dimension;
use LaTeXML::Common::Glue;
use LaTeXML::Core::MuGlue;
use base qw(LaTeXML::Common::Object);
#**********************************************************************
# sub new {
#   my ($class) = @_;
#   return bless {
#     mouth => undef,
#     pending_comments => LaTeXML::Core::Tokenstack::new(),
#     }, $class; }

#**********************************************************************
# Start reading tokens from a new Mouth.
# This pushes the mouth as the current source that $gullet->readToken (etc) will read from.
# Once this Mouth has been exhausted, readToken, etc, will return undef,
# until you call $gullet->closeMouth to clear the source.
# Exception: if $toplevel=1, readXToken will step to next source
# Note that a Tokens can act as a Mouth.
# sub openMouth {
#   my ($self, $mouth, $noautoclose) = @_;
#   return unless $mouth;
#   if(my $previous = $self->getMouth){
#     $mouth->setPreviousMouth($previous); }
#   $self->setMouth($mouth);
#   $mouth->setAutoclose( ! $noautoclose);
#   return; }

# sub closeMouth {
#   my ($self, $forced) = @_;
#   my $mouth = $self->getMouth;
#   if (!$forced && $mouth->hasMoreInput) {
#     my $next = Stringify($self->readToken);
#     Error('unexpected', $next, $self, "Closing mouth with input remaining '$next'"); }
#   $mouth->finish;
#   if(my $previous = $mouth->getPreviousMouth){
#     $self->setMouth($previous); }
#   else {
#     $self->setMouth(LaTeXML::Core::Mouth->new());
#     $self->getMouth->setAutoclose(1);  }
#   return; }

# # temporary, for XSUB
# sub nextMouth {
#   my ($self) = @_;
#   my $mouth = $self->getMouth;
#   return unless $mouth->getAutoclose && $mouth->getPreviousMouth;
#   $self->closeMouth;    # Next input stream.
#   return $self->getMouth; }

# # temporary, for XSUB
# sub invokeExpandable {
#   my ($self, $defn, $token) = @_;
#   #  local $LaTeXML::CURRENT_TOKEN = $token;
#   return $defn->invoke($token,$self); }

# sub getMouth {
#   my ($self) = @_;
#   return $self->getMouth; }

# sub mouthIsOpen {
#   my ($self, $mouth) = @_;
#   for(my $m = $self->getMouth; $m ; $m = $m->getPreviousMouth){
#     return 1 if $m eq $mouth; } }

# This flushes a mouth so that it will be automatically closed, next time it's read
# Corresponds (I think) to TeX's \endinput
sub flushMouth {
  my ($self) = @_;
  my $mouth = $self->getMouth;
  $mouth->finish;;    # but not close!
  $mouth->setAutoclose(1);
  return; }

# Obscure, but the only way I can think of to End!! (see \bye or \end{document})
# Flush all sources (close all pending mouth's)
# sub flush {
#   my ($self) = @_;
#   my $mouth = $self->getMouth;
#   $mouth->finish;
#   for(my $m = $mouth; $m ; $m = $m->getPreviousMouth){
#     $m->finish; }
#   $self->setMouth(LaTeXML::Core::Mouth->new());
#   $self->getMouth->setAutoclose(1);
#   return; }

# Do something, while reading stuff from a specific Mouth.
# This reads ONLY from that mouth (or any mouth openned by code in that source),
# and the mouth should end up empty afterwards, and only be closed here.
# sub readingFromMouth {
#   my ($self, $mouth, $closure) = @_;
#   if (ref $mouth eq 'LaTeXML::Core::Tokens') {
#     my $tokens = $mouth;
#     $mouth = LaTeXML::Core::Mouth->new();
#     $mouth->unread($tokens); }
#   $self->openMouth($mouth, 1);    # only allow mouth to be explicitly closed here.
#   my ($result, @result);
#   if (wantarray) {
#     @result = &$closure($self); }
#   else {
#     $result = &$closure($self); }
#   # $mouth must still be open, with (at worst) empty autoclosable mouths in front of it
#   while (1) {
#     my $m = $self->getMouth;
#     if ($m eq $mouth) {
#       $self->closeMouth(1); last; }
#     elsif (! $m->getPreviousMouth) {
#       Error('unexpected', '<closed>', $self, "Mouth is unexpectedly already closed",
#         "Reading from " . Stringify($mouth) . ", but it has already been closed."); }
#     elsif (!$m->getAutoclose || $self->getMouth->hasMoreInput) {
#       my $next = Stringify($self->readToken);
#       Error('unexpected', $next, $self, "Unexpected input remaining: '$next'",
#         "Finished reading from " . Stringify($mouth) . ", but it still has input.");
#       $m->finish;
#       $self->closeMouth(1); }    # ?? if we continue?
#     else {
#       $self->closeMouth; } }
#   return (wantarray ? @result : $result); }

sub readingFromMouth {
  my ($self, $mouth, $closure) = @_;
  # if (ref $mouth eq 'LaTeXML::Core::Tokens') {
  #   my $tokens = $mouth;
  #   $mouth = LaTeXML::Core::Mouth->new();
  #   $mouth->unread($tokens); }
  $mouth = $self->openMouth($mouth, 1);    # only allow mouth to be explicitly closed here.
  my ($result, @result);
  if (wantarray) {
    @result = &$closure($self); }
  else {
    $result = &$closure($self); }
  # $mouth must still be open, with (at worst) empty autoclosable mouths in front of it
  $self->closeThisMouth($mouth); 
  return (wantarray ? @result : $result); }

sub getSource {
  my ($self) = @_;
  my $mouth = $self->getMouth;
  my $source = defined $mouth && $mouth->getSource;
  if (!$source) {
  for(my $m = $mouth; $m ; $m = $m->getPreviousMouth){
      $source = $m->getSource;
      last if $source; } }
  return $source; }

sub getSourceMouth {
  my ($self) = @_;
  my $mouth = $self->getMouth;
  my $source = defined $mouth && $mouth->getSource;
  if (!$source || ($source eq "Anonymous String")) {
  for(my $m = $mouth; $m ; $m = $m->getPreviousMouth){
      $source = $m->getSource if $m->isInteresting;
      last if $source; } }
  return $mouth; }

# Handy message generator when we didn't get something expected.
sub showUnexpected {
  my ($self) = @_;
  my $token = $self->readToken;
  my $message = ($token ? "Next token is " . Stringify($token) : "Input is empty");
  #unshift(@{ $$self{pushback} }, $token);    # Unread
  return $message; }

sub show_pushback {
  my ($pb) = @_;
  my @pb = @$pb;
  @pb = (@pb[0 .. 50], T_OTHER('...')) if scalar(@pb) > 55;
  return (@pb ? "\n  To be read again " . ToString(Tokens(@pb)) : ''); }

#**********************************************************************
# Not really 100% sure how this is supposed to work
# See TeX Ch 20, p216 regarding noexpand, \edef with token list registers, etc.
# Solution: Duplicate param tokens, stick NOTEXPANDED infront of expandable tokens.
# sub neutralizeTokens {
#   my ($self, $tokens) = @_;
#   my @result = ();
#   foreach my $token ($tokens->unlist) {
#     if ($token->getCatcode == CC_PARAM) {
#       push(@result, $token); }
#     elsif (defined(my $defn = LaTeXML::Core::State::lookupDefinition($STATE, $token))) {
#       push(@result, Token('\noexpand', CC_NOTEXPANDED)); }
#     push(@result, $token); }
#   return Tokens(@result); }

# Read the next raw line (string);
# primarily to read from the Mouth, but keep any unread input!
sub readRawLine {
  my ($self) = @_;
  # If we've got unread tokens, they presumably should come before the Mouth's raw data
  # but we'll convert them back to string.
  my $mouth = $self->getMouth;
  my @tokens = $mouth->getPushback;
  my @markers = grep { $_->getCatcode == CC_MARKER } @tokens;
  if (@markers) {    # Whoops, profiling markers!
    @tokens = grep { $_->getCatcode != CC_MARKER } @tokens;    # Remove
    map { LaTeXML::Core::Definition::stopProfiling($_, 'expand') } @markers; }
  # If we still have peeked tokens, we ONLY want to combine it with the remainder
  # of the current line from the Mouth (NOT reading a new line)
  if (@tokens) {
    my $rest = $mouth->readRawLine(1);
    return ToString(Tokens(@tokens)) . (defined $rest ? $rest : ''); }
  # Otherwise, read the next line from the Mouth.
  else {
    return $mouth->readRawLine; } }


#**********************************************************************
# Higher-level readers: Read various types of things from the input:
#  tokens, non-expandable tokens, args, Numbers, ...
#**********************************************************************
# Note that this returns an empty array if [] is present,
# otherwise $default or undef.
# sub readOptional {
#   my ($self, $default) = @_;
#   my $tok = $self->readNonSpace;
#   if (!defined $tok) {
#     return; }
#   elsif (($tok->equals(T_OTHER('[')))) {
#     return $self->readUntil(T_OTHER(']')); }
#   else {
#     $self->getMouth->unread($tok);    # Unread
#     return $default; } }

#**********************************************************************
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Gullet> - expands expandable tokens and parses common token sequences.

=head1 DESCRIPTION

A C<LaTeXML::Core::Gullet> reads tokens (L<LaTeXML::Core::Token>) from a L<LaTeXML::Core::Mouth>.
It is responsible for expanding macros and expandable control sequences,
if the current definition associated with the token in the L<LaTeXML::Core::State>
is an L<LaTeXML::Core::Definition::Expandable> definition. The C<LaTeXML::Core::Gullet> also provides a
variety of methods for reading  various types of input such as arguments, optional arguments,
as well as for parsing L<LaTeXML::Common::Number>, L<LaTeXML::Common::Dimension>, etc, according
to TeX's rules.

It extends L<LaTeXML::Common::Object>.

=head2 Managing Input

=over 4

=item C<< $gullet->openMouth($mouth, $noautoclose); >>

Is this public? Prepares to read tokens from C<$mouth>.
If $noautoclose is true, the Mouth will not be automatically closed
when it is exhausted.

=item C<< $gullet->closeMouth; >>

Is this public? Finishes reading from the current mouth, and
reverts to the one in effect before the last openMouth.

=item C<< $gullet->flush; >>

Is this public? Clears all inputs.

=item C<< $gullet->getLocator; >>

Returns a string describing the current location in the input stream.

=back

=head2 Low-level methods

=over 4

=item C<< $tokens = $gullet->expandTokens($tokens); >>

Return the L<LaTeXML::Core::Tokens> resulting from expanding all the tokens in C<$tokens>.
This is actually only used in a few circumstances where the arguments to
an expandable need explicit expansion; usually expansion happens at the right time.

=item C<< @tokens = $gullet->neutralizeTokens(@tokens); >>

Another unusual method: Used for things like \edef and token registers, to
inhibit further expansion of control sequences and proper spawning of register tokens.

=item C<< $token = $gullet->readToken; >>

Return the next token from the input source, or undef if there is no more input.

=item C<< $token = $gullet->readXToken($toplevel,$commentsok); >>

Return the next unexpandable token from the input source, or undef if there is no more input.
If the next token is expandable, it is expanded, and its expansion is reinserted into the input.
If C<$commentsok>, a comment read or pending will be returned.

=item C<< $gullet->unread(@tokens); >>

Push the C<@tokens> back into the input stream to be re-read.

=back

=head2 Mid-level methods

=over 4

=item C<< $token = $gullet->readNonSpace; >>

Read and return the next non-space token from the input after discarding any spaces.

=item C<< $gullet->skipSpaces; >>

Skip the next spaces from the input.

=item C<< $gullet->skip1Space; >>

Skip the next token from the input if it is a space.

=item C<< $tokens = $gullet->readBalanced; >>

Read a sequence of tokens from the input until the balancing '}' (assuming the '{' has
already been read). Returns a L<LaTeXML::Core::Tokens>.

=item C<< $boole = $gullet->ifNext($token); >>

Returns true if the next token in the input matches C<$token>;
the possibly matching token remains in the input.

=item C<< $tokens = $gullet->readMatch(@choices); >>

Read and return whichever of C<@choices>
matches the input, or undef if none do.
Each of the choices is an L<LaTeXML::Core::Tokens>.

=item C<< $keyword = $gullet->readKeyword(@keywords); >>

Read and return whichever of C<@keywords> (each a string) matches the input, or undef
if none do.  This is similar to readMatch, but case and catcodes are ignored.
Also, leading spaces are skipped.

=item C<< $tokens = $gullet->readUntil(@delims); >>

Read and return a (balanced) sequence of L<LaTeXML::Core::Tokens> until  matching one of the tokens
in C<@delims>.  In a list context, it also returns which of the delimiters ended the sequence.

=back

=head2 High-level methods

=over 4

=item C<< $tokens = $gullet->readArg; >>

Read and return a TeX argument; the next Token or Tokens (if surrounded by braces).

=item C<< $tokens = $gullet->readOptional($default); >>

Read and return a LaTeX optional argument; returns C<$default> if there is no '[',
otherwise the contents of the [].

=item C<< $thing = $gullet->readValue($type); >>

Reads an argument of a given type: one of 'Number', 'Dimension', 'Glue', 'MuGlue' or 'any'.

=item C<< $value = $gullet->readRegisterValue($type); >>

Read a control sequence token (and possibly it's arguments) that names a register,
and return the value.  Returns undef if the next token isn't such a register.

=item C<< $number = $gullet->readNumber; >>

Read a L<LaTeXML::Common::Number> according to TeX's rules of the various things that
can be used as a numerical value.

=item C<< $dimension = $gullet->readDimension; >>

Read a L<LaTeXML::Common::Dimension> according to TeX's rules of the various things that
can be used as a dimension value.

=item C<< $glue = $gullet->readGlue; >>

Read a  L<LaTeXML::Common::Glue> according to TeX's rules of the various things that
can be used as a glue value.

=item C<< $muglue = $gullet->readMuGlue; >>

Read a L<LaTeXML::Core::MuGlue> according to TeX's rules of the various things that
can be used as a muglue value.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

