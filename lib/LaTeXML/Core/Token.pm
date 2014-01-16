# /=====================================================================\ #
# |  LaTeXML::Core::Token, LaTeXML::Core::Tokens                        | #
# | Representation of Token(s)                                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
#   A Token represented as a pair: [string,catcode]
# string is a character or control sequence.
# Yes, a bit inefficient, but code is clearer...
#**********************************************************************
package LaTeXML::Core::Token;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

#======================================================================
# See LaTeXML::Global for constructors.

#======================================================================
# Categories of Category codes.
# For Tokens with these catcodes, only the catcode is relevant for comparison.
# (if they even make it to a stage where they get compared)
my @primitive_catcode = (    # [CONSTANT]
  1, 1, 1, 1,
  1, 1, 1, 1,
  1, 0, 1, 0,
  0, 0, 0, 0,
  0, 1);
my @executable_catcode = (    # [CONSTANT]
  0, 1, 1, 1,
  1, 0, 0, 1,
  1, 0, 0, 0,
  0, 1, 0, 0,
  1, 0);

my @standardchar = (          # [CONSTANT]
  "\\",  '{',   '}',   q{$},
  q{&},  "\n",  q{#},  q{^},
  q{_},  undef, undef, undef,
  undef, undef, q{%},  undef);

my @CC_NAME =                 #[CONSTANT]
  qw(Escape Begin End Math
  Align EOL Parameter Superscript
  Subscript Ignore Space Letter
  Other Active Comment Invalid
  ControlSequence NotExpanded);
my @PRIMITIVE_NAME = (        # [CONSTANT]
  'Escape',    'Begin', 'End',       'Math',
  'Align',     'EOL',   'Parameter', 'Superscript',
  'Subscript', undef,   'Space',     undef,
  undef,       undef,   undef,       undef,
  undef,       'NotExpanded');
my @CC_SHORT_NAME =           #[CONSTANT]
  qw(T_ESCAPE T_BEGIN T_END T_MATH
  T_ALIGN T_EOL T_PARAM T_SUPER
  T_SUB T_IGNORE T_SPACE T_LETTER
  T_OTHER T_ACTIVE T_COMMENT T_INVALID
  T_CS T_NOTEXPANDED
);

#======================================================================
# Accessors.

sub isaToken { return 1; }

# Get the CS Name of the token. This is the name that definitions will be
# stored under; It's the same for various `different' BEGIN tokens, eg.
sub getCSName {
  my ($token) = @_;
  return $PRIMITIVE_NAME[$$token[1]] || $$token[0]; }

# Get the CSName only if the catcode is executable!
sub getExecutableName {
  my ($self) = @_;
  my ($cs, $cc) = @$self;
  return $executable_catcode[$cc] && ($PRIMITIVE_NAME[$cc] || $cs); }

# Return the string or character part of the token
sub getString {
  my ($self) = @_;
  return $$self[0]; }

# Return the character code of  character part of the token, or 256 if it is a control sequence
sub getCharcode {
  my ($self) = @_;
  return ($$self[1] == CC_CS ? 256 : ord($$self[0])); }

# Return the catcode of the token.
sub getCatcode {
  my ($self) = @_;
  return $$self[1]; }

sub isExecutable {
  my ($self) = @_;
  return $executable_catcode[$$self[1]]; }

# Defined so a Token or Tokens can be used interchangeably.
sub unlist {
  my ($self) = @_;
  return ($self); }

my @NEUTRALIZABLE = (    # [CONSTANT]
  0, 0, 0, 1,
  1, 0, 1, 1,
  1, 0, 0, 0,
  0, 1, 1, 0,
  0, 0);

# neutralize really should only retroactively imitate what Semiverbatim would have done.
# So, it needs to neutralize those in SPECIALS
sub neutralize {
  my ($self) = @_;
  my ($ch, $cc) = @$self;
  return ($NEUTRALIZABLE[$cc] && (grep { $ch } @{ $STATE->lookupValue('SPECIALS') })
    ? T_OTHER($ch) : $self); }

#======================================================================
# Note that this converts the string to a more `user readable' form using `standard' chars for catcodes.
# We'll need to be careful about using string instead of reverting for internal purposes where the
# actual character is needed.

# Should revert do something with this???
#  ($standardchar[$$self[1]] || $$self[0]); }

sub revert {
  my ($self) = @_;
  return $self; }

sub toString {
  my ($self) = @_;
  return $$self[0]; }

sub beDigested {
  my ($self, $stomach) = @_;
  return $stomach->digest($self); }

#======================================================================
# Methods for overloaded ops.

# Compare two tokens; They are equal if they both have same catcode,
# and either the catcode is one of the primitive ones, or thier strings
# are equal.
# NOTE: That another popular equality checks whether the "meaning" (defn) are the same.
# That is NOT done here; see Equals(x,y).
sub equals {
  my ($a, $b) = @_;
  return
    (defined $b
      && (ref $a) eq (ref $b))
    && ($$a[1] == $$b[1])
    && ($primitive_catcode[$$a[1]] || ($$a[0] eq $$b[0])); }

my @CONTROLNAME = (    #[CONSTANT]
  qw( NUL SOH STX ETX EOT ENQ ACK BEL BS HT LF VT FF CR SO SI
    DLE DC1 DC2 DC3 DC4 NAK SYN ETB CAN EM SUB ESC FS GS RS US));
# Primarily for error reporting.
sub stringify {
  my ($self) = @_;
  my $string = $$self[0];
  # Make the token's char content more printable, since this is for error messages.
  if (length($string) == 1) {
    my $c = ord($string);
    if ($c < 0x020) {
      $string = 'U+' . sprintf("%04x", $c) . '/' . $CONTROLNAME[$c]; } }
  return $CC_SHORT_NAME[$$self[1]] . '[' . $string . ']'; }

#======================================================================

1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Token> - representation of a token.

=head1 DESCRIPTION

This module defines Token (C<LaTeXML::Core::Token>)
that get created during tokenization and  expansion.

A C<LaTeXML::Core::Token> represents a TeX token which is a pair of a character or string and
a category code.

=head2 METHODS

=over 4

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this C<$object>.

=item C<< $string = $object->toString; >>

Return a string representing C<$object>.

=item C<< $string = $token->getCSName; >>

Return the string or character part of the C<$token>; for the special category
codes, returns the standard string (eg. C<T_BEGIN->getCSName> returns "{").

=item C<< $string = $token->getString; >>

Return the string or character part of the C<$token>.

=item C<< $code = $token->getCharcode; >>

Return the character code of the character part of the C<$token>,
or 256 if it is a control sequence.

=item C<< $code = $token->getCatcode; >>

Return the catcode of the C<$token>.

=back

=head1 AUTHOR

pBruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

