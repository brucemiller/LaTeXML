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
use LaTeXML::Common::Object;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (
  # Catcode constants
  qw( CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH
    CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
    CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
    CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
    CC_CS      CC_NOTEXPANDED CC_MARKER),
  # Token constructors
  qw( T_BEGIN T_END T_MATH T_ALIGN T_PARAM T_SUB T_SUPER T_SPACE
    &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
    T_CR &T_MARKER
    &Token),
  # String exploders
  qw(&Explode &ExplodeText &UnTeX)
);

#======================================================================
# Constructors.

use constant CC_ESCAPE  => 0;
use constant CC_BEGIN   => 1;
use constant CC_END     => 2;
use constant CC_MATH    => 3;
use constant CC_ALIGN   => 4;
use constant CC_EOL     => 5;
use constant CC_PARAM   => 6;
use constant CC_SUPER   => 7;
use constant CC_SUB     => 8;
use constant CC_IGNORE  => 9;
use constant CC_SPACE   => 10;
use constant CC_LETTER  => 11;
use constant CC_OTHER   => 12;
use constant CC_ACTIVE  => 13;
use constant CC_COMMENT => 14;
use constant CC_INVALID => 15;
# Extended Catcodes for expanded output.
use constant CC_CS          => 16;
use constant CC_NOTEXPANDED => 17;
use constant CC_MARKER      => 18;    # non TeX extension!

# [The documentation for constant is a bit confusing about subs,
# but these apparently DO generate constants; you always get the same one]
# These are immutable
use constant T_BEGIN => bless ['{',  1],  'LaTeXML::Core::Token';
use constant T_END   => bless ['}',  2],  'LaTeXML::Core::Token';
use constant T_MATH  => bless ['$',  3],  'LaTeXML::Core::Token';
use constant T_ALIGN => bless ['&',  4],  'LaTeXML::Core::Token';
use constant T_PARAM => bless ['#',  6],  'LaTeXML::Core::Token';
use constant T_SUPER => bless ['^',  7],  'LaTeXML::Core::Token';
use constant T_SUB   => bless ['_',  8],  'LaTeXML::Core::Token';
use constant T_SPACE => bless [' ',  10], 'LaTeXML::Core::Token';
use constant T_CR    => bless ["\n", 10], 'LaTeXML::Core::Token';
sub T_LETTER { my ($c) = @_; return bless [$c, 11], 'LaTeXML::Core::Token'; }
sub T_OTHER  { my ($c) = @_; return bless [$c, 12], 'LaTeXML::Core::Token'; }
sub T_ACTIVE { my ($c) = @_; return bless [$c, 13], 'LaTeXML::Core::Token'; }
sub T_COMMENT { my ($c) = @_; return bless ['%' . ($c || ''), 14], 'LaTeXML::Core::Token'; }
sub T_CS { my ($c) = @_; return bless [$c, 16], 'LaTeXML::Core::Token'; }

# Illegal: don't use unless you know...
sub T_MARKER { my ($t) = @_; return bless [$t, 18], 'LaTeXML::Core::Token'; }

sub Token {
  my ($string, $cc) = @_;
  return bless [$string, (defined $cc ? $cc : CC_OTHER)], 'LaTeXML::Core::Token'; }

# Explode a string into a list of tokens, all w/catcode OTHER (except space).
sub Explode {
  my ($string) = @_;
  return (defined $string
    ? map { ($_ eq ' ' ? T_SPACE() : T_OTHER($_)) } split('', $string)
    : ()); }

# Similar to Explode, but convert letters to catcode LETTER and others to OTHER
# Hopefully, this is essentially correct WITHOUT resorting to catcode lookup?
sub ExplodeText {
  my ($string) = @_;
  return (defined $string
    ? map { ($_ eq ' ' ? T_SPACE() : (/[a-zA-Z]/ ? T_LETTER($_) : T_OTHER($_))) }
      split('', $string)
    : ()); }

my $UNTEX_LINELENGTH = 78;    # [CONSTANT]

sub UnTeX {
  my ($thing) = @_;
  return unless defined $thing;
  my @tokens = (ref $thing ? $thing->revert : Explode($thing));
  my $string = '';
  my $length = 0;
  my $level  = 0;
  my ($prevs, $prevcc) = ('', CC_COMMENT);
  while (@tokens) {
    my $token = shift(@tokens);
    my $cc    = $token->getCatcode;
    next if $cc == CC_COMMENT;
    my $s = $token->getString();
    if ($cc == CC_LETTER) {    # keep "words" together, just for aesthetics
      while (@tokens && ($tokens[0]->getCatcode == CC_LETTER)) {
        $s .= shift(@tokens)->getString; } }
    my $l = length($s);
    if ($cc == CC_BEGIN) { $level++; }
    # Seems a reasonable & safe time to line break, for readability, etc.
    if (($cc == CC_SPACE) && ($s eq "\n")) {    # preserve newlines already present
      if ($length > 0) {
        $string .= $s; $length = 0; } }
    # If this token is a letter (or otherwise starts with a letter or digit): space or linebreak
    elsif ((($cc == CC_LETTER) || (($cc == CC_OTHER) && ($s =~ /^(?:\p{IsAlpha}|\p{IsDigit})/)))
      && ($prevcc == CC_CS) && ($prevs =~ /(.)$/)
      && (($STATE->lookupCatcode($1) || CC_COMMENT) == CC_LETTER)) {
      # Insert a (virtual) space before a letter if previous token was a CS w/letters
      # This is required for letters, but just aesthetic for digits (to me?)
      # Of course, use a newline if we're already at end
      my $space = (($length > 0) && ($length + $l > $UNTEX_LINELENGTH) ? "\n" : ' ');
      $string .= $space . $s; $length += 1 + $l; }
    elsif (($length > 0) && ($length + $l > $UNTEX_LINELENGTH)    # linebreak before this token?
      && (scalar(@tokens) > 1)                                    # and not at end!
      ) {                                                         # Or even within an arg!
      $string .= "%\n" . $s; $length = $l; }                      # with %, so that it "disappears"
    else {
      $string .= $s; $length += $l; }
    if ($cc == CC_END) { $level--; }
    $prevs = $s; $prevcc = $cc; }
  # Patch up nesting for valid TeX !!!
  if ($level > 0) { $string = $string . ('}' x $level); }
  elsif ($level < 0) { $string = ('{' x -$level) . $string; }
  return $string; }

#======================================================================
# Categories of Category codes.
# For Tokens with these catcodes, only the catcode is relevant for comparison.
# (if they even make it to a stage where they get compared)
our @primitive_catcode = (    # [CONSTANT]
  1, 1, 1, 1,
  1, 1, 1, 1,
  1, 0, 1, 0,
  0, 0, 0, 0,
  0, 1);
our @executable_catcode = (    # [CONSTANT]
  0, 1, 1, 1,
  1, 0, 0, 1,
  1, 0, 0, 0,
  0, 1, 0, 0,
  1, 0);

our @standardchar = (          # [CONSTANT]
  "\\",  '{',   '}',   q{$},
  q{&},  "\n",  q{#},  q{^},
  q{_},  undef, undef, undef,
  undef, undef, q{%},  undef);

our @CC_NAME =                 #[CONSTANT]
  qw(Escape Begin End Math
  Align EOL Parameter Superscript
  Subscript Ignore Space Letter
  Other Active Comment Invalid
  ControlSequence NotExpanded);
our @PRIMITIVE_NAME = (        # [CONSTANT]
  'Escape',    'Begin', 'End',       'Math',
  'Align',     'EOL',   'Parameter', 'Superscript',
  'Subscript', undef,   'Space',     undef,
  undef,       undef,   undef,       undef,
  undef,       'NotExpanded');
our @CC_SHORT_NAME =           #[CONSTANT]
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
  0, 1, 0, 0,
  0, 0);

# neutralize really should only retroactively imitate what Semiverbatim would have done.
# So, it needs to neutralize those in SPECIALS
# NOTE that although '%' gets it's catcode changed in Semiverbatim,
# I'm pretty sure we do NOT want to neutralize comments (turn them into CC_OTHER)
# here, since if comments do get into the Tokens, that will introduce weird crap into the stream.
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

C<LaTeXML::Core::Token> - representation of a Token:
a pair of character and category code (catcode);
It extends L<LaTeXML::Common::Object>.

=head2 Exported functions

=over 4

=item C<< $catcode = CC_ESCAPE; >>

Constants for the category codes:

  CC_BEGIN, CC_END, CC_MATH, CC_ALIGN, CC_EOL,
  CC_PARAM, CC_SUPER, CC_SUB, CC_IGNORE,
  CC_SPACE, CC_LETTER, CC_OTHER, CC_ACTIVE,
  CC_COMMENT, CC_INVALID, CC_CS, CC_NOTEXPANDED.

[The last 2 are (apparent) extensions,
with catcodes 16 and 17, respectively].

=item C<< $token = Token($string,$cc); >>

Creates a L<LaTeXML::Core::Token> with the given content and catcode.
The following shorthand versions are also exported for convenience:

  T_BEGIN, T_END, T_MATH, T_ALIGN, T_PARAM,
  T_SUB, T_SUPER, T_SPACE, T_LETTER($letter),
  T_OTHER($char), T_ACTIVE($char),
  T_COMMENT($comment), T_CS($cs)

=item C<< @tokens = Explode($string); >>

Returns a list of the tokens corresponding to the characters in C<$string>.
All tokens have catcode CC_OTHER, except for spaces which have catcode CC_SPACE.

=item C<< @tokens = ExplodeText($string); >>

Returns a list of the tokens corresponding to the characters in C<$string>.
All (roman) letters have catcode CC_LETTER, all others have catcode CC_OTHER,
except for spaces which have catcode CC_SPACE.

=item C<< UnTeX($object); >>

Converts C<$object> to a string containing TeX that created it (or could have).
Note that this is not necessarily the original TeX code; expansions
or other substitutions may have taken place.

=back

=head2 Methods

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

