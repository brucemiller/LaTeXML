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
#======================================================================
package LaTeXML::Global;
use strict;
use Exporter;
use LaTeXML::Error;

our @ISA = qw(Exporter);
our @EXPORT = ( 
	       # Global State accessors
	       qw(&STOMACH &INTESTINE &DEFINITION &MODEL),

	       # Catcode constants
	       qw(CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH
		  CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
		  CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
		  CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
		  CC_CS      CC_NOTEXPANDED),
	       qw(&getStandardCattable &getInternalCattable),
	       # Token constructors
	       qw(&T_BEGIN &T_END &T_MATH &T_ALIGN &T_PARAM &T_SUB &T_SUPER &T_SPACE 
		  &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
		  &CheckTokens
		  &Token &Tokens
		  &Tokenize &TokenizeInternal &Explode),
	       qw(&roman &Roman),
	       # Number & Dimension constructors
	       qw(&Number &Dimension &MuDimension &Glue &MuGlue),
	       # Font constructors
	       qw(&Font &MathFont),
	       # Digested thing constructors
	       qw(&Box &List &MathBox &MathList &Whatsit
		  &CheckBoxes),
	       # And export whatever LaTeXML::Error exports
	       @LaTeXML::Error::EXPORT);

#======================================================================
# NOTE: These globals must be bound (local) in Stomach, or wherever...
sub STOMACH()   { $LaTeXML::STOMACH; }
sub INTESTINE() { $LaTeXML::INTESTINE; }
sub MODEL()     { $LaTeXML::MODEL; }
sub DEFINITION(){ $LaTeXML::DEFINITION; }

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
  LaTeXML::Mouth->new('',$string,cattable=>getStandardCattable)->readTokens; }

# tokenize($string); Tokenizes the string using the internal cattable, returning a LaTeXML::Tokens
sub TokenizeInternal {
  my($string)=@_;
  LaTeXML::Mouth->new('',$string,cattable=>getInternalCattable)->readTokens; }

#======================================================================
# Token List constructors.

sub CheckTokens {
  map((ref $_ eq 'LaTeXML::Token')||TypeError($_,'Token'),@_); }

# Return a LaTeXML::Tokens made from the arguments (tokens)
sub Tokens {
  CheckTokens(@_);
  LaTeXML::Tokens->new(@_); }

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

our %boxtypes=map(($_=>1), qw(LaTeXML::Box LaTeXML::MathBox LaTeXML::Comment LaTeXML::List 
			      LaTeXML::MathList LaTeXML::Whatsit));
sub CheckBoxes {
  map( $boxtypes{ref $_} || TypeError($_,"Box|Comment|List|MathList|Whatsit"),@_); }

# Concise exported constructors for various Digested objects.
sub Box     { LaTeXML::Box->new(@_); }
sub List    { CheckBoxes(@_); LaTeXML::List->new(@_); }
sub MathBox { LaTeXML::MathBox->new(@_); }
sub MathList{ CheckBoxes(@_); LaTeXML::MathList->new(@_); }
sub Whatsit { LaTeXML::Whatsit->new(@_); }

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

=head2 EXPORTS

=over 4

=item C<< $catcode = CC_ESCAPE; >>

A constant for the escape category code; and also:
C<CC_BEGIN>, C<CC_END>, C<CC_MATH>, C<CC_ALIGN>, C<CC_EOL>, C<CC_PARAM>, C<CC_SUPER>,
C<CC_SUB>, C<CC_IGNORE>, C<CC_SPACE>, C<CC_LETTER>, C<CC_OTHER>, C<CC_ACTIVE>, C<CC_COMMENT>, 
C<CC_INVALID>, C<CC_CS>, C<CC_NOTEXPANDED>.  [The last 2 are (apparent) extensions, 
with catcodes 16 and 17, respectively].

=item C<< $token = Token($string,$cc); >>

Creates a LaTeXML::Token with the given content and catcode.  The following shorthand versions
are also exported for convenience:
C<T_BEGIN>, C<T_END>, C<T_MATH>, C<T_ALIGN>, C<T_PARAM>, C<T_SUB>, C<T_SUPER>, C<T_SPACE>, 
C<T_LETTER($letter)>, C<T_OTHER($char)>, C<T_ACTIVE($char)>, C<T_COMMENT($comment)>, C<T_CS($cs)>

=item C<< $tokens = Tokens(@token); >>

Creates a L<LaTeXML::Tokens> from a list of L<LaTeXML::Token>'s

=item C<< $tokens = Tokenize($string); >>

Tokenizes the $string according to the standard cattable, returning a L<LaTeXML::Tokens>.

=item C<< $tokens = TokenizeInternal($string); >>

Tokenizes the $string according to the internal cattable (where @ is a letter), 
returning a L<LaTeXML::Tokens>.

=item C<< @tokens = Explode($string); >>

Returns a list of the tokens corresponding to the characters in $string.

=item C<< @tokens = roman($number); >>

Formats the $number in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

Formats the $number in (uppercase) roman numerals, returning a list of the tokens.

=item C<< $number = Number($num); >>

Creates a Number object representing $num.

=item C<< $dimension = Dimension($dim); >>

Creates a Dimension object.  $num can be a string with the number and units
(with any of the usual TeX recognized units), or just a number standing for
scaled points (sp).

=item C<< $mudimension = MuDimension($dim); >>

Creates a MuDimension object; similar to Dimension.

=item C<< $glue = Glue($gluespec); >>
=item C<< $glue = Glue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a Glue object.  $gluespec can be a string in the
form that TeX recognizes (number units optional plus and minus parts).
Alternatively, the dimension, plus and minus parts can be given separately:
$pfill and $mfill are 0 (when the $plus or $minus part is in sp)
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

=head2 Font related

=over 4

=item C<< $font = Font(%components); >>

Creates a Font object, components are C<family>, C<series>, C<shape>, C<size> and C<color>.

=item C<< $font = MathFont(%components); >>

Creates a MathFont object, components are the same as Font, with the addition of
C<forcebold> for use when all symbols should be bold (such as with amsmath's \boldsymbol).

=back

=head2 Constructors for Digested objects

=over 4

=item C<< $box = Box($string,$font); >>

Create a L<LaTeXML::Box> for the given $string, in the given $font.

=item C<< $mathbox = MathBox($string,$font); >>

Create a  L<LaTeXML::MathBox> for the given $string, in the given $font.

=item C<< $list = List(@boxes); >>

Create a L<LaTeXML::List> containing the given @boxes.

=item C<< $mathlist = MathList(@mathboxes); >>

Create a L<LaTeXML::MathList> containing the given @mathboxes.

=item C<< $whatsit = Whatsit($defn,$stomach,$args,%data); >>

Create a L<LaTeXML::Whatsit> according to $defn, with the given $args (an 
array reference containing the arguments) and any extra relevant %data.

=back

=cut

