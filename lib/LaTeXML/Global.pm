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
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = ( 
	       # Global State accessors
	       qw( *GULLET *STOMACH *INTESTINE *MODEL),
	       # Catcode constants
	       qw( CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH
		   CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
		   CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
		   CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
		   CC_CS      CC_NOTEXPANDED ),
	       qw( &getStandardCattable &getInternalCattable ),
	       # Token constructors
	       qw( &T_BEGIN &T_END &T_MATH &T_ALIGN &T_PARAM &T_SUB &T_SUPER &T_SPACE 
		   &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
		   &CheckTokens
		   &Token &Tokens
		   &Tokenize &TokenizeInternal &Explode ),
	       qw( &roman &Roman ),
	       # Number & Dimension constructors
	       qw( &Number &Dimension &MuDimension &Glue &MuGlue),
	       # Font constructors
	       qw( &Font &MathFont ),
	       # Digested thing constructors
	       qw( &Box &List &MathBox &MathList &Whatsit &CheckBoxes ),
	       # Other generally useful operations
	       qw( &requireMath &forbidMath ),
	       # Error & Progress reporting
	       qw( &NoteProgress &Fatal &Error &Warn ),
	       # And some generics
	       qw(&Stringify &ToString  &Equals)
);

#======================================================================
# NOTE: These globals must be bound (local) by LaTeXML

# These should just be deprecated, since I'm exporting the symbols now.
sub GULLET()    { $LaTeXML::Global::GULLET; }
sub STOMACH()   { $LaTeXML::Global::STOMACH; }
sub INTESTINE() { $LaTeXML::Global::INTESTINE; }
sub MODEL()     { $LaTeXML::Global::MODEL; }

#======================================================================
# Catcodes & Standard Token constructors.
#  CC_whatever names the catcode numbers
#  T_whatever creates a token with the corresponding catcode, 
#   some take a string argument, if they don't have a `standard' character.
use constant CC_ESCAPE  =>  0;
use constant CC_BEGIN   =>  1;  sub T_BEGIN()  { bless ['{',   1], 'LaTeXML::Token'; }
use constant CC_END     =>  2;  sub T_END()    { bless ['}',   2], 'LaTeXML::Token'; }
use constant CC_MATH    =>  3;  sub T_MATH()   { bless ['$',   3], 'LaTeXML::Token'; }
use constant CC_ALIGN   =>  4;  sub T_ALIGN()  { bless ['&',   4], 'LaTeXML::Token'; }
use constant CC_EOL     =>  5;
use constant CC_PARAM   =>  6;  sub T_PARAM()  { bless ['#',   6], 'LaTeXML::Token'; }
use constant CC_SUPER   =>  7;  sub T_SUPER()  { bless ['^',   7], 'LaTeXML::Token'; }
use constant CC_SUB     =>  8;  sub T_SUB()    { bless ['_',   8], 'LaTeXML::Token'; }
use constant CC_IGNORE  =>  9;
use constant CC_SPACE   => 10;  sub T_SPACE()  { bless [' ',  10], 'LaTeXML::Token'; }
use constant CC_LETTER  => 11;  sub T_LETTER   { bless [$_[0],11], 'LaTeXML::Token'; }
use constant CC_OTHER   => 12;  sub T_OTHER    { bless [$_[0],12], 'LaTeXML::Token'; }
use constant CC_ACTIVE  => 13;  sub T_ACTIVE   { bless [$_[0],13], 'LaTeXML::Token'; }
use constant CC_COMMENT => 14;  sub T_COMMENT  { bless ['%'.($_[0]||''),14], 'LaTeXML::Token'; }
use constant CC_INVALID => 15;  
# Extended Catcodes for expanded output.
use constant CC_CS      => 16;  sub T_CS       { bless [$_[0],16], 'LaTeXML::Token'; }
use constant CC_NOTEXPANDED => 17;

sub Token {
  my($string,$cc)=@_;
  bless [$string,(defined $cc ? $cc : CC_OTHER)], 'LaTeXML::Token'; }

#======================================================================
our $STD_CATTABLE;		# Standard Catcodes
our $STY_CATTABLE;		# Catcodes for `style files'

BEGIN {
  # Setup default catcodes.
  $$STD_CATTABLE{"\\"} = CC_ESCAPE;
  $$STD_CATTABLE{"{"}  = CC_BEGIN;
  $$STD_CATTABLE{"}"}  = CC_END;
  $$STD_CATTABLE{"\$"} = CC_MATH;
  $$STD_CATTABLE{"\&"} = CC_ALIGN;
  $$STD_CATTABLE{"\n"} = CC_EOL;
  $$STD_CATTABLE{"#"}  = CC_PARAM;
  $$STD_CATTABLE{"^"}  = CC_SUPER;
  $$STD_CATTABLE{"_"}  = CC_SUB;
  $$STD_CATTABLE{" "}  = CC_SPACE;
  $$STD_CATTABLE{"\t"} = CC_SPACE;
  $$STD_CATTABLE{"%"}  = CC_COMMENT;
  $$STD_CATTABLE{"~"}  = CC_ACTIVE;
  $$STD_CATTABLE{chr(0)}= CC_IGNORE;
  for(my $c=ord('A'); $c <= ord('Z'); $c++){
    $$STD_CATTABLE{chr($c)}   = CC_LETTER;
    $$STD_CATTABLE{chr($c+ord('a')-ord('A'))}= CC_LETTER;
  }
  $STY_CATTABLE = {%$STD_CATTABLE};
  $$STY_CATTABLE{"@"}  = CC_LETTER;
}

# Return the Standard Cattable (a hash: char=>catcode).
sub getStandardCattable { $STD_CATTABLE; }
# Return the Internal Cattable; @ is treated as a letter.
sub getInternalCattable    { $STY_CATTABLE; }

#======================================================================
# These belong to Mouth, but make more sense here.

# tokenize($string); Tokenizes the string using the standard cattable, returning a LaTeXML::Tokens
sub Tokenize {
  my($string)=@_;
  LaTeXML::Mouth->new($string,cattable=>getStandardCattable)->readTokens; }

# tokenize($string); Tokenizes the string using the internal cattable, returning a LaTeXML::Tokens
sub TokenizeInternal {
  my($string)=@_;
  LaTeXML::Mouth->new($string,cattable=>getInternalCattable)->readTokens; }

#======================================================================
# Token List constructors.

sub CheckTokens {
  map( ((ref $_) && $_->isaToken)|| Fatal("Expected Token, got ".Stringify($_)), @_);
  @_; }

# Return a LaTeXML::Tokens made from the arguments (tokens)
sub Tokens { LaTeXML::Tokens->new(CheckTokens(@_)); }

# Explode a string into a list of tokens w/catcode OTHER (except space).
sub Explode {
  my($string)=@_;
  map(($_ eq ' ' ? T_SPACE() : T_OTHER($_)),split('',$string)); }

# Dumb place for this, but where else...
# The TeX way! (bah!! hint: try a large number)
my @rmletters=('i','v',  'x','l', 'c','d', 'm');
sub roman_aux {
  my($n)=@_;
  my $div= 1000;
  my $s=($n>$div ? ('m' x int($n/$div)) : '');
  my $p=4;
  while($n %= $div){
    $div /= 10;
    my $d = int($n/$div);
    if($d%5==4){ $s.= $rmletters[$p]; $d++;}
    if($d > 4 ){ $s.= $rmletters[$p+int($d/5)]; $d %=5; }
    if($d) {     $s.= $rmletters[$p] x $d; }
    $p -= 2;}
  $s; }

# Convert the number to lower case roman numerals, returning a list of LaTeXML::Token
sub roman { Explode(roman_aux(@_)); }
# Convert the number to upper case roman numerals, returning a list of LaTeXML::Token
sub Roman { Explode(uc(roman_aux(@_))); }

#======================================================================
# Constructors for number and dimension types.

sub Number      { LaTeXML::Number->new(@_); }
sub Dimension   { LaTeXML::Dimension->new(@_); }
sub MuDimension { LaTeXML::MuDimension->new(@_); }
sub Glue        { LaTeXML::Glue->new(@_); }
sub MuGlue      { LaTeXML::MuGlue->new(@_); }

#======================================================================
# Constructors for fonts.

sub Font     { 'LaTeXML::Font'->new(@_); }
sub MathFont { 'LaTeXML::MathFont'->new(@_); }

#======================================================================
# Constructors for Digested objects: Box, List, Whatsit.

sub CheckBoxes {
  map( ((ref $_) && $_->isaBox)|| Fatal("Expected Box, got ".Stringify($_)), @_);
  @_; }

# Concise exported constructors for various Digested objects.
sub Box     { 'LaTeXML::Box'->new(@_); }
sub List    { 'LaTeXML::List'->new(CheckBoxes(@_)); }
sub MathBox { 'LaTeXML::MathBox'->new(@_); }
sub MathList{ 'LaTeXML::MathList'->new(CheckBoxes(@_)); }
sub Whatsit { 'LaTeXML::Whatsit'->new(@_); }

#**********************************************************************
sub requireMath() {
  Fatal("Current operation can only appear in math mode") unless $LaTeXML::Global::STOMACH->inMath;
  return; }

sub forbidMath() {
  Fatal("Current operation can not appear in math mode") if $LaTeXML::Global::STOMACH->inMath;
  return; }

#**********************************************************************
# Error & Progress reporting.

$LaTeXML::Global::VERBOSITY = 0;

sub NoteProgress { 
  print STDERR @_ unless $LaTeXML::Global::VERBOSITY < 0; }

sub Fatal { 
  my($message)=@_;
  if(!$LaTeXML::Error::InHandler && defined($^S)){
    $message
      = LaTeXML::Error::generateMessage("Fatal",$message,1,
		       ($LaTeXML::Global::VERBOSITY > 0 ? ("Stack Trace:",LaTeXML::Error::stacktrace()):()));
  }
  local $LaTeXML::Error::InHandler=1;
  die $message; }

# Should be fatal if strict is set, else warn.
sub Error {
  my($msg)=@_;
  if($LaTeXML::Global::STRICT){
    Fatal($msg); }
  else {
    print STDERR LaTeXML::Error::generateMessage("Error",$msg,0,"Continuing... Expect trouble.\n")
      unless $LaTeXML::Global::VERBOSITY < -1; }}

sub Warn {
  my($msg)=@_;
  print STDERR LaTeXML::Error::generateMessage("Warning",$msg,0)
    unless $LaTeXML::Global::VERBOSITY < 0; }

#**********************************************************************
# Generic functions
our %NOBLESS= map(($_=>1), qw( SCALAR HASH ARRAY CODE REF GLOB LVALUE));

sub Stringify {
  my($object)=@_;
  (defined $object ? (((ref $object) && !$NOBLESS{ref $object}) ? $object->stringify : "$object")
   : 'undef'); }

sub ToString {
  my($object)=@_;
  (defined $object ? (((ref $object) && !$NOBLESS{ref $object}) ? $object->toString : "$object"):''); }

sub Equals {
  my($a,$b)=@_;
  (defined $a) && (defined $b)
    && ( ((ref $a) && (ref $b) && ((ref $a) eq (ref $b)) && !$NOBLESS{ref $a})
	 ? $a->equals($b) : ($a eq $b)); }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Global

=head2 SYNOPSIS

use LaTeXML::Global;

=head2 DESCRIPTION

This module exports the various constants and constructors that are useful
throughout LaTeXML, and in Package implementations.

=head2 Global state

=over 4

=item C<< $GULLET, $STOMACH, $INTESTINE, $MODEL; >>

These are bound to the currently active L<LaTeXML::Gullet>, L<LaTeXML::Stomach>,
L<LaTeXML::Intestine> and L<LaTeXML::Model> by an instance of L<LaTeXML> during
processing.

=back 

=head2 Token related exports

=over 4

=item C<< $catcode = CC_ESCAPE; >>

A constant for the escape category code; and also:
C<CC_BEGIN>, C<CC_END>, C<CC_MATH>, C<CC_ALIGN>, C<CC_EOL>, C<CC_PARAM>, C<CC_SUPER>,
C<CC_SUB>, C<CC_IGNORE>, C<CC_SPACE>, C<CC_LETTER>, C<CC_OTHER>, C<CC_ACTIVE>, C<CC_COMMENT>, 
C<CC_INVALID>, C<CC_CS>, C<CC_NOTEXPANDED>.  [The last 2 are (apparent) extensions, 
with catcodes 16 and 17, respectively].

=item C<< $token = Token($string,$cc); >>

Creates a L<LaTeXML::Token> with the given content and catcode.  The following shorthand versions
are also exported for convenience:
C<T_BEGIN>, C<T_END>, C<T_MATH>, C<T_ALIGN>, C<T_PARAM>, C<T_SUB>, C<T_SUPER>, C<T_SPACE>, 
C<T_LETTER($letter)>, C<T_OTHER($char)>, C<T_ACTIVE($char)>, C<T_COMMENT($comment)>, C<T_CS($cs)>

=item C<< $tokens = Tokens(@token); >>

Creates a L<LaTeXML::Tokens> from a list of L<LaTeXML::Token>'s

=item C<< $tokens = Tokenize($string); >>

Tokenizes the C<$string> according to the standard cattable, returning a L<LaTeXML::Tokens>.

=item C<< $tokens = TokenizeInternal($string); >>

Tokenizes the C<$string> according to the internal cattable (where @ is a letter),
returning a L<LaTeXML::Tokens>.

=item C<< @tokens = Explode($string); >>

Returns a list of the tokens corresponding to the characters in C<$string>.

=item C<< @tokens = roman($number); >>

Formats the C<$number> in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

Formats the C<$number> in (uppercase) roman numerals, returning a list of the tokens.

=item C<< $number = Number($num); >>

Creates a Number object representing C<$num>.

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

=item C<< $cattable = getStandardCattable; >>

Returns the standard cattable; a reference to a hash mapping characters to catcodes.

=item C<< $cattable = getInternalCattable; >>

Returns the internal cattable; a reference to a hash mapping characters to catcodes.
This is the same as the standard cattable, but treats @ as a letter.

=back

=head2 Font related exports

=over 4

=item C<< $font = Font(%components); >>

Creates a Font object, components are C<family>, C<series>, C<shape>, C<size> and C<color>.

=item C<< $font = MathFont(%components); >>

Creates a MathFont object, components are the same as Font, with the addition of
C<forcebold> for use when all symbols should be bold (such as with amsmath's \boldsymbol).

=back

=head2 Box related exports

=over 4

=item C<< $box = Box($string,$font,$locator); >>

Create a L<LaTeXML::Box> for the given C<$string>, in the given C<$font>.
C<$locator> is a string indicating where the C<$string> came from; if not supplied,
the location will be determined from the C<$GULLET>.

=item C<< $mathbox = MathBox($string,$font,$locator); >>

Create a  L<LaTeXML::MathBox> for the given $string, in the given $font.
C<$locator> is a string indicating where the C<$string> came from; if not supplied,
the location will be determined from the C<$GULLET>.

=item C<< $list = List(@boxes); >>

Create a L<LaTeXML::List> containing the given C<@boxes>.

=item C<< $mathlist = MathList(@mathboxes); >>

Create a L<LaTeXML::MathList> containing the given C<@mathboxes>.

=item C<< $whatsit = Whatsit($defn,$args,%properties); >>

Create a L<LaTeXML::Whatsit> according to C<$defn> (a L<LaTeXML::Constructor>),
with the given C<$args> (an array reference containing the arguments) 
and any extra C<%properties>.
Specially recognized properties are:

   font   : the font object for any contained text.
   isMath : whether it represents a math object.
   locator: string indicating where in the source this was created

If the properties are not supplied, then the data is obtained from 
the current execution environment.

=back

=head2 Generally useful procedures

=over 4

=item C<< requireMath; >>

Signals an error unless we are currently in math mode.

=item C<< forbidMath; >>

Signals an error if we are currently in math mode.

=back

=head2 Error and Progress reporting procedures

=over 4

=item C<< Fatal($message); >>

Signals an fatal error, printing C<$message> along with some context.
In verbose mode a stack trace is printed.

=item C<< Error($message); >>

Signals an error, printing C<$message> along with some context.
If in strict mode, this is the same as Fatal().
Otherwise, it attempts to continue processing..

=item C<< Warn($message); >>

Prints a warning message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< NoteProgress($message); >>

Prints C<$message> unless the verbosity level below 0.

=back

=head2 Generic functions

=over 4

=item C<< Stringify($object); >>

Returns a short string identifying C<$object>, for debugging purposes.
Works on any values and objects, but invokes the stringify method on 
blessed objects.
More informative than the default perl conversion to a string.

=item C<< ToString($object); >>

Converts C<$object> to string; most useful for Tokens or Boxes where the
string content is desired.  Works on any values and objects, but invokes 
the toString method on blessed objects.

=item C<< Equals($a,$b); >>

Compares the two objects for equality.  Works on any values and objects, 
but invokes the equals method on blessed objects, which does a
deep comparison of the two objects.

=back
=cut

