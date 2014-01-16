# /=====================================================================\ #
# |  LaTeXML::Global                                                    | #
# | Global constants, accessors and constructors                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#======================================================================
#  This module collects all the commonly useful constants and constructors
# that other modules and package implementations are likely to need.
# This should be used in a context where presumably all the required
# LaTeXML modules that implement the various classes have already been loaded.
#
# Yes, a lot of stuff is exported, polluting your namespace.
# Thus, you use this module only if you _need_ the functionality!
#======================================================================
package LaTeXML::Global;
use strict;
use warnings;
use LaTeXML::Error;
use LaTeXML::Common::XML;
use Time::HiRes;

use base qw(Exporter);
our @EXPORT = (    # Global STATE; This gets bound by LaTeXML.pm
  qw( *STATE),
  # Catcode constants
  qw( CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH
    CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
    CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
    CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
    CC_CS      CC_NOTEXPANDED CC_MARKER),
  # Token constructors
  qw( &T_BEGIN &T_END &T_MATH &T_ALIGN &T_PARAM &T_SUB &T_SUPER &T_SPACE
    &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
    &T_CR &T_MARKER
    &Token &Tokens
    &Tokenize &TokenizeInternal &Explode &ExplodeText &UnTeX
    &StartSemiverbatim &EndSemiverbatim),
  # Number & Dimension constructors
  qw( &Number &Float &Dimension &MuDimension &Glue &MuGlue &Pair &PairList),
  # Box constructor
  qw( &Box ),
  # Fonts
  qw( &Color &Black &White),
  # Progress reporting
  qw( &NoteProgress &NoteProgressDetailed &NoteBegin &NoteEnd),
  # And some generics
  qw(&Stringify &ToString &Revert &Equals),
  # And some really simple useful stuff.
  qw(&min &max),
  # And, anything exported from LaTeXML::Error
  @LaTeXML::Error::EXPORT,
  # And, anything exported from LaTeXML::Common::XML
  @LaTeXML::Common::XML::EXPORT
);

#======================================================================
# Catcodes & Standard Token constructors.
#  CC_whatever names the catcode numbers
#  T_whatever creates a token with the corresponding catcode,
#   some take a string argument, if they don't have a `standard' character.

#local $LaTeXML::STATE;

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

#======================================================================
# These belong to Mouth, but make more sense here.

# WARNING: These two utilities bind $STATE to simple State objects with known fixed catcodes.
# The State normally contains ALL the bindings, etc and links to other important objects.
# We CAN do that here, since we are ONLY tokenizing from a new Mouth, bypassing stomach & gullet.
# However, be careful with any changes.

our $STD_CATTABLE;
our $STY_CATTABLE;

# Tokenize($string); Tokenizes the string using the standard cattable, returning a LaTeXML::Core::Tokens
sub Tokenize {
  my ($string) = @_;
  $STD_CATTABLE = LaTeXML::State->new(catcodes => 'standard') unless $STD_CATTABLE;
  local $LaTeXML::Global::STATE = $STD_CATTABLE;
  return LaTeXML::Core::Mouth->new($string)->readTokens; }

# TokenizeInternal($string); Tokenizes the string using the internal cattable, returning a LaTeXML::Core::Tokens
sub TokenizeInternal {
  my ($string) = @_;
  $STY_CATTABLE = LaTeXML::State->new(catcodes => 'style') unless $STY_CATTABLE;
  local $LaTeXML::Global::STATE = $STY_CATTABLE;
  return LaTeXML::Core::Mouth->new($string)->readTokens; }

sub StartSemiverbatim {
  my $state = $LaTeXML::Global::STATE;
  $state->pushFrame;
  $state->assignValue(MODE => 'text'); # only text mode makes sense here... BUT is this shorthand safe???
  $state->assignValue(IN_MATH => 0);
  map { $state->assignCatcode($_ => CC_OTHER, 'local') }
    @{ $state->lookupValue('SPECIALS') };
  $state->assignMathcode('\'' => 0x8000, 'local');
  $state->assignValue(font => $state->lookupValue('font')->merge(encoding => 'ASCII'), 'local'); # try to stay as ASCII as possible
  return; }

sub EndSemiverbatim {
  $LaTeXML::Global::STATE->popFrame;
  return; }

#======================================================================
# Token List constructors.

# Return a LaTeXML::Core::Tokens made from the arguments (tokens)
sub Tokens {
  my (@tokens) = @_;
  return LaTeXML::Core::Tokens->new(@tokens); }

# Explode a string into a list of tokens w/catcode OTHER (except space).
sub Explode {
  my ($string) = @_;
  return (defined $string
    ? map { ($_ eq ' ' ? T_SPACE() : T_OTHER($_)) } split('', $string)
    : ()); }

# Similar to Explode, but convert letters to catcode LETTER
# Hopefully, this is essentially correct WITHOUT resorting to catcode lookup?
sub ExplodeText {
  my ($string) = @_;
  return (defined $string
    ? map { ($_ eq ' ' ? T_SPACE() : (/[a-zA-Z]/ ? T_LETTER($_) : T_OTHER($_))) }
      split('', $string)
    : ()); }

# Reverts an object into TeX code, as a Tokens list, that would create it.
# Note that this is not necessarily the original TeX.
sub Revert {
  my ($thing) = @_;
  return (defined $thing ? (ref $thing ? map { $_->unlist } $thing->revert : Explode($thing)) : ()); }

my $UNTEX_LINELENGTH = 78;    # [CONSTANT]

sub UnTeX {
  my ($thing) = @_;
  return unless defined $thing;
  my @tokens = (ref $thing ? $thing->revert : Explode($thing));
  my $string = '';
  my $length = 0;
  #  my $level = 0;
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
    #    if($cc == CC_BEGIN){ $level++; }
    # Seems a reasonable & safe time to line break, for readability, etc.
    if (($cc == CC_SPACE) && ($s eq "\n")) {    # preserve newlines already present
      if ($length > 0) {
        $string .= $s; $length = 0; } }
    elsif ((($cc == CC_LETTER) || (($cc == CC_OTHER) && ($s =~ /^\d+$/)))    # Letter(s) or digit(s)
      && ($prevcc == CC_CS) && ($prevs =~ /(.)$/)
      && (($LaTeXML::Global::STATE->lookupCatcode($1) || CC_COMMENT) == CC_LETTER)) {
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
    #    if($cc == CC_END  ){ $level--; }
    $prevs = $s; $prevcc = $cc; }
  return $string; }

#======================================================================
# Constructors for number and dimension types.

sub Number {
  my ($number) = @_;
  return LaTeXML::Common::Number->new($number); }

sub Float {
  my ($number) = @_;
  return LaTeXML::Common::Float->new($number); }

sub Dimension {
  my ($scaledpoints) = @_;
  return LaTeXML::Common::Dimension->new($scaledpoints); }

sub MuDimension {
  my ($scaledpoints) = @_;
  return LaTeXML::Core::MuDimension->new($scaledpoints); }

sub Glue {
  my ($scaledpoints, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Common::Glue->new($scaledpoints, $plus, $pfill, $minus, $mfill); }

sub MuGlue {
  my ($scaledpoints, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Core::MuGlue->new($scaledpoints, $plus, $pfill, $minus, $mfill); }

sub Pair {
  my ($x, $y) = @_;
  return LaTeXML::Core::Pair->new($x, $y); }

sub PairList {
  my (@pairs) = @_;
  return LaTeXML::Core::PairList->new(@pairs); }

#======================================================================
# Constructors for Boxes and Lists.

sub Box {
  my ($string, $font, $locator, $tokens) = @_;
  $font = $LaTeXML::Global::STATE->lookupValue('font') unless defined $font;
  $locator = $LaTeXML::Global::STATE->getStomach->getGullet->getLocator unless defined $locator;
  $tokens = T_OTHER($string) if $string && !defined $tokens;
  my $state = $LaTeXML::Global::STATE;
  if ($state->lookupValue('IN_MATH')) {
    my $attr = (defined $string) && $state->lookupValue('math_token_attributes_' . $string);
    return LaTeXML::Core::MathBox->new($string, $font->specialize($string), $locator, $tokens, $attr); }
  else {
    return LaTeXML::Core::Box->new($string, $font, $locator, $tokens); } }

#
# sub List {
#   my(@boxes)=@_;
# $ismath is NOT correct here!!!
# we need to know whether we were in math BEFORE digesting the boxes!
#   ( $ismath ? LaTeXML::Core::MathList->new(@boxes) : LaTeXML::Core::List->new(@boxes)); }

#======================================================================
# Colors
sub Color {
  my ($model, @components) = @_;
  return LaTeXML::Common::Color->new(ToString($model), map { ToString($_) } @components); }

use constant Black => bless ['rgb', 0, 0, 0], 'LaTeXML::Common::Color::rgb';
use constant White => bless ['rgb', 1, 1, 1], 'LaTeXML::Common::Color::rgb';

#**********************************************************************
# Progress reporting.

sub NoteProgress {
  my (@stuff) = @_;
  print STDERR @stuff if $LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0;
  return; }

sub NoteProgressDetailed {
  my (@stuff) = @_;
  print STDERR @stuff if $LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 1;
  return; }

sub NoteBegin {
  my ($state) = @_;
  if ($LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0) {
    $LaTeXML::Global::STATE->assignMapping('NOTE_TIMERS', $state, [Time::HiRes::gettimeofday]);
    print STDERR "\n($state..."; }
  return; }

sub NoteEnd {
  my ($state) = @_;
  if (my $start = $LaTeXML::Global::STATE->lookupMapping('NOTE_TIMERS', $state)) {
    $LaTeXML::Global::STATE->assignMapping('NOTE_TIMERS', $state, undef);
    if ($LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0) {
      my $elapsed = Time::HiRes::tv_interval($start, [Time::HiRes::gettimeofday]);
      print STDERR sprintf(" %.2f sec)", $elapsed); } }
  return; }

#**********************************************************************
# Generic functions
my %NOBLESS = map { ($_ => 1) } qw( SCALAR HASH ARRAY CODE REF GLOB LVALUE);    # [CONSTANT]

sub Stringify {
  my ($object) = @_;
  if    (!defined $object)          { return 'undef'; }
  elsif (!ref $object)              { return $object; }
  elsif ($NOBLESS{ ref $object })   { return "$object"; }
  elsif ($object->can('stringify')) { return $object->stringify; }
  # Have to handle LibXML stuff explicitly (unless we want to add methods...?)
  elsif ($object->isa('XML::LibXML::Node')) {
    if ($object->nodeType == XML_ELEMENT_NODE) {
      my $tag        = $LaTeXML::Global::STATE->getModel->getNodeQName($object);
      my $attributes = '';
      foreach my $attr ($object->attributes) {
        my $name = $attr->nodeName;
        my $val  = $attr->getData;
        $val = substr($val, 0, 30) . "..." if length($val) > 35;
        $attributes .= ' ' . $name . "=\"" . $val . "\""; }
      return "<" . $tag . $attributes . ($object->hasChildNodes ? ">..." : "/>");
    }
    elsif ($object->nodeType == XML_TEXT_NODE) {
      return "XMLText[" . $object->data . "]"; }
    elsif ($object->nodeType == XML_DOCUMENT_NODE) {
      return "XMLDocument[" . $$object . "]"; }
    else { return "$object"; } }
  else { return "$object"; } }

sub ToString {
  my ($object) = @_;
  my $r;
  return (defined $object
    ? (($r = ref $object) && !$NOBLESS{$r} ? $object->toString : "$object") : ''); }

# Just how deep of an equality test should this be?
sub Equals {
  my ($a, $b) = @_;
  return 1 if !(defined $a) && !(defined $b);    # both undefined, equal, I guess
  return 0 unless (defined $a) && (defined $b);  # else both must be defined
  my $refa = (ref $a) || '_notype_';
  my $refb = (ref $b) || '_notype_';
  return 0 if $refa ne $refb;                    # same type?
  return $a eq $b if ($refa eq '_notype_') || $NOBLESS{$refa};    # Deep comparison of builtins?
  return 1 if $a->equals($b);                                     # semi-shallow comparison?
       # Special cases? (should be methods, but that embeds State knowledge too low)

  if ($refa eq 'LaTeXML::Core::Token') {    # Check if they've been \let to the same defn.
    my $defa = $LaTeXML::Global::STATE->lookupDefinition($a);
    my $defb = $LaTeXML::Global::STATE->lookupDefinition($b);
    return $defa && $defb && ($defa eq $defb); }
  return 0; }

#**********************************************************************
sub min {
  my ($x, $y) = @_;
  return ($x < $y ? $x : $y); }

sub max {
  my ($x, $y) = @_;
  return ($x > $y ? $x : $y); }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Global> - global exports used within LaTeXML, and in Packages.

=head1 SYNOPSIS

use LaTeXML::Global;

=head1 DESCRIPTION

This module exports the various constants and constructors that are useful
throughout LaTeXML, and in Package implementations.

=head2 Global state

=over 4

=item C<< $STATE; >>

This is bound to the currently active L<LaTeXML::State> by an instance
of L<LaTeXML> during processing.

=back 

=head2 Tokens

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

=item C<< $tokens = Tokens(@token); >>

Creates a L<LaTeXML::Core::Tokens> from a list of L<LaTeXML::Core::Token>'s

=item C<< $tokens = Tokenize($string); >>

Tokenizes the C<$string> according to the standard cattable, returning a L<LaTeXML::Core::Tokens>.

=item C<< $tokens = TokenizeInternal($string); >>

Tokenizes the C<$string> according to the internal cattable (where @ is a letter),
returning a L<LaTeXML::Core::Tokens>.

=item C<< @tokens = Explode($string); >>

Returns a list of the tokens corresponding to the characters in C<$string>.
All tokens have catcode CC_OTHER, except for spaces which have catcode CC_SPACE.

=item C<< @tokens = ExplodeText($string); >>

Returns a list of the tokens corresponding to the characters in C<$string>.
All (roman) letters have catcode CC_LETTER, all others have catcode CC_OTHER,
except for spaces which have catcode CC_SPACE.

=item C<< $tokens = Revert($object); >>

Returns a Tokens list containing the TeX that would create C<$object>.
Note that this is not necessarily the original TeX code;
expansions or other substitutions may have taken place.

=item C<< StartSemiVerbatim(); ... ; EndSemiVerbatim(); >>

Desable disable most TeX catcodes.

=back

=head2 Boxes, etc.

=over 4

=item C<< $box = Box($string,$font,$locator,$tokens); >>

Creates a Box representing the C<$string> in the given C<$font>.
The C<$locator> records the document source position.
The C<$tokens> is a Tokens list containing the TeX that created
(or could have) the Box (See UnTeX).
If C<$font> or C<$locator> are undef, they are obtained from the
currently active L<LaTeXML::State>.  Note that $string can
be undef which contributes nothing to the generated document,
but does record the TeX code (in C<$tokens>).

=back

=head2 Numbers, etc.

=over 4

=item C<< $number = Number($num); >>

Creates a Number object representing C<$num>.

=item C<< $number = Float($num); >>

Creates a floating point object representing C<$num>;
This is not part of TeX, but useful.

=item C<< $dimension = Dimension($dim); >>

Creates a Dimension object.  C<$num> can be a string with the number and units
(with any of the usual TeX recognized units), or just a number standing for
scaled points (sp).

=item C<< $mudimension = MuDimension($dim); >>

Creates a MuDimension object; similar to Dimension.

=item C<< $glue = Glue($gluespec); >>

=item C<< $glue = Glue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a Glue object.  C<$gluespec> can be a string in the
form that TeX recognizes (number units optional plus and minus parts).
Alternatively, the dimension, plus and minus parts can be given separately:
C<$pfill> and C<$mfill> are 0 (when the C<$plus> or C<$minus> part is in sp)
or 1,2,3 for fil, fill or filll.

=item C<< $glue = MuGlue($gluespec); >>

=item C<< $glue = MuGlue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a MuGlue object, similar to Glue.


=item C<< $pair = Pair($num1,$num2); >>

Creates an object representing a pair of numbers;
Not a part of TeX, but useful for graphical objects.
The two components can be any numerical object.

=item C<< $pair = PairList(@pairs); >>

Creates an object representing a list of pairs of numbers;
Not a part of TeX, but useful for graphical objects.

=back

=head2 Error Reporting

The Error reporting functions all take a similar set of arguments,
the differences are in the implied severity of the situation,
and in the amount of detail that will be reported.

The C<$category> is a string naming a broad category of errors,
such as "undefined". The set is open-ended, but see the manual
for a list of recognized categories.  C<$object> is the object
whose presence or lack caused the problem.

C<$where> indicates where the problem occurred; passs in
the C<$gullet> or C<$stomach> if the problem occurred during
expansion or digestion; pass in a document node if it occurred there.
A string will be used as is; if an undefined value is used,
the error handler will try to guess.

The C<$message> should be a somewhat concise, but readable,
explanation of the problem, but ought to not refer to the
document or any "incident specific" information, so as to
support indexing in build systems.  C<@details> provides
additional lines of information that may be indident specific.

=over 4

=item C<< Fatal($category,$object,$where,$message,@details); >>

Signals an fatal error, printing C<$message> along with some context.
In verbose mode a stack trace is printed.

=item C<< Error($category,$object,$where,$message,@details); >>

Signals an error, printing C<$message> along with some context.
If in strict mode, this is the same as Fatal().
Otherwise, it attempts to continue processing..

=item C<< Warn($category,$object,$where,$message,@details); >>

Prints a warning message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< Info($category,$object,$where,$message,@details); >>

Prints an informational message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< NoteProgress($message); >>

Prints C<$message> unless the verbosity level below 0.
Typically just a short mark to indicate motion, but can be longer;
provide your own newlines, if needed.

=item C<< NoteProgressDetailed($message); >>

Like C<NoteProgress>, but for noiser progress, only prints when verbosity >= 1.

=back

=head2 Generic functions

=over 4

=item C<< Stringify($object); >>

Returns a string identifying C<$object>, for debugging.
Works on any values and objects, but invokes the stringify method on 
blessed objects.
More informative than the default perl conversion to a string.

=item C<< ToString($object); >>

Converts C<$object> to string attempting, when possible,
to generate straight text without TeX markup.
This is most useful for converting Tokens or Boxes to document
content or attribute values, or values to be used for pathnames,
keywords, etc.   Generally, however, it is not possible
to convert Whatsits generated by Constructors into clean strings,
without TeX markup.
Works on any values and objects, but invokes
the toString method on blessed objects.

=item C<< Equals($a,$b); >>

Compares the two objects for equality.  Works on any values and objects, 
but invokes the equals method on blessed objects, which does a
deep comparison of the two objects.

=item C<< Revert($object); >>

Converts C<$object> to a Tokens list containing the TeX that created it (or could have).
Note that this is not necessarily the original TeX code; expansions
or other substitutions may have taken place.

=item C<< UnTeX($object); >>

Converts C<$object> to a string containing TeX that created it (or could have).
Note that this is not necessarily the original TeX code; expansions
or other substitutions may have taken place.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

