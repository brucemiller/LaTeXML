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
use LaTeXML::Common::XML;
use Time::HiRes;

use base qw(Exporter);
our  @EXPORT = ( 
	       # Global STATE; This gets bound by LaTeXML.pm
	       qw( *STATE),
	       # Catcode constants
	       qw( CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH
		   CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
		   CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
		   CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
		   CC_CS      CC_NOTEXPANDED ),
	       # Token constructors
	       qw( &T_BEGIN &T_END &T_MATH &T_ALIGN &T_PARAM &T_SUB &T_SUPER &T_SPACE 
		   &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
		   &T_CR
		   &Token &Tokens
		   &Tokenize &TokenizeInternal &Explode &ExplodeText &UnTeX
		   &StartSemiverbatim &EndSemiverbatim),
	       # Number & Dimension constructors
		qw( &Number &Float &Dimension &MuDimension &Glue &MuGlue &Pair &PairList),
	       # Box constructor
		qw( &Box ),
	       # Error & Progress reporting
	       qw( &NoteProgress &NoteBegin &NoteEnd &Fatal &Error &Warn &Info),
	       # And some generics
	       qw(&Stringify &ToString &Revert &Equals),
	       # And, anything exported from LaTeXML::Common::XML
	       @LaTeXML::Common::XML::EXPORT
);

#======================================================================
# Catcodes & Standard Token constructors.
#  CC_whatever names the catcode numbers
#  T_whatever creates a token with the corresponding catcode, 
#   some take a string argument, if they don't have a `standard' character.

use constant CC_ESCAPE  =>  0;
use constant CC_BEGIN   =>  1;
use constant CC_END     =>  2;
use constant CC_MATH    =>  3;
use constant CC_ALIGN   =>  4;
use constant CC_EOL     =>  5;
use constant CC_PARAM   =>  6;
use constant CC_SUPER   =>  7;
use constant CC_SUB     =>  8;
use constant CC_IGNORE  =>  9;
use constant CC_SPACE   => 10;
use constant CC_LETTER  => 11;
use constant CC_OTHER   => 12;
use constant CC_ACTIVE  => 13;
use constant CC_COMMENT => 14;
use constant CC_INVALID => 15;  
# Extended Catcodes for expanded output.
use constant CC_CS      => 16;
use constant CC_NOTEXPANDED => 17;
# Can use constants here; they should never be modified.
our $CONSTANT_T_BEGIN = bless ['{',   1], 'LaTeXML::Token';
our $CONSTANT_T_END   = bless ['}',   2], 'LaTeXML::Token';
our $CONSTANT_T_MATH  = bless ['$',   3], 'LaTeXML::Token';
our $CONSTANT_T_ALIGN = bless ['&',   4], 'LaTeXML::Token';
our $CONSTANT_T_PARAM = bless ['#',   6], 'LaTeXML::Token';
our $CONSTANT_T_SUPER = bless ['^',   7], 'LaTeXML::Token';
our $CONSTANT_T_SUB   = bless ['_',   8], 'LaTeXML::Token';
our $CONSTANT_T_SPACE = bless [' ',  10], 'LaTeXML::Token';
our $CONSTANT_T_CR    = bless ["\n", 10], 'LaTeXML::Token';

# Too bad we can't REALLY get inlining here...
sub T_BEGIN() { $CONSTANT_T_BEGIN; }
sub T_END()   { $CONSTANT_T_END; }
sub T_MATH()  { $CONSTANT_T_MATH; }
sub T_ALIGN() { $CONSTANT_T_ALIGN; }
sub T_PARAM() { $CONSTANT_T_PARAM; }
sub T_SUPER() { $CONSTANT_T_SUPER; }
sub T_SUB()   { $CONSTANT_T_SUB; }
sub T_SPACE() { $CONSTANT_T_SPACE; }
sub T_CR()    { $CONSTANT_T_CR; }
sub T_LETTER  { bless [$_[0],11], 'LaTeXML::Token'; }
sub T_OTHER   { bless [$_[0],12], 'LaTeXML::Token'; }
sub T_ACTIVE  { bless [$_[0],13], 'LaTeXML::Token'; }
sub T_COMMENT { bless ['%'.($_[0]||''),14], 'LaTeXML::Token'; }
sub T_CS      { bless [$_[0],16], 'LaTeXML::Token'; }

sub Token {
  my($string,$cc)=@_;
  bless [$string,(defined $cc ? $cc : CC_OTHER)], 'LaTeXML::Token'; }

#======================================================================
# These belong to Mouth, but make more sense here.

# WARNING: These two utilities bind $STATE to simple State objects with known fixed catcodes.
# The State normally contains ALL the bindings, etc and links to other important objects.
# We CAN do that here, since we are ONLY tokenizing from a new Mouth, bypassing stomach & gullet.
# However, be careful with any changes.

our $STD_CATTABLE;
our $STY_CATTABLE;

# Tokenize($string); Tokenizes the string using the standard cattable, returning a LaTeXML::Tokens
sub Tokenize         {
  my($string)=@_;
  $STD_CATTABLE = LaTeXML::State->new(catcodes=>'standard') unless $STD_CATTABLE;
  local $LaTeXML::STATE = $STD_CATTABLE;
  LaTeXML::Mouth->new($string)->readTokens; }

# TokenizeInternal($string); Tokenizes the string using the internal cattable, returning a LaTeXML::Tokens
sub TokenizeInternal { 
  my($string)=@_;
  $STY_CATTABLE = LaTeXML::State->new(catcodes=>'style') unless  $STY_CATTABLE;
  local $LaTeXML::STATE = $STY_CATTABLE;
  LaTeXML::Mouth->new($string)->readTokens; }

sub StartSemiverbatim() {
  $LaTeXML::STATE->pushFrame;
  $LaTeXML::STATE->assignValue(MODE=>'text'); # only text mode makes sense here... BUT is this shorthand safe???
  $LaTeXML::STATE->assignValue(IN_MATH=>0);
  map($LaTeXML::STATE->assignCatcode($_=>CC_OTHER,'local'),@{$LaTeXML::STATE->lookupValue('SPECIALS')});
  $LaTeXML::STATE->assignCatcode('math:\''=>0,'local');
  $LaTeXML::STATE->assignValue(font=>$LaTeXML::STATE->lookupValue('font')->merge(encoding=>'ASCII'), 'local'); # try to stay as ASCII as possible
  return; }

sub EndSemiverbatim() {  $LaTeXML::STATE->popFrame; }

#======================================================================
# Token List constructors.

# Return a LaTeXML::Tokens made from the arguments (tokens)
sub Tokens {
  my(@tokens)=@_;
  # Flatten any Tokens to Token's
  @tokens = map( ( (((ref $_)||'') eq 'LaTeXML::Tokens') ? $_->unlist : $_), @tokens);
  # And complain about any remaining Non-Token's
  map( ((ref $_) && $_->isaToken)|| Fatal(":misdefined:<unknown> Expected Token, got ".Stringify($_)), @tokens);
  LaTeXML::Tokens->new(@tokens); }

# Explode a string into a list of tokens w/catcode OTHER (except space).
sub Explode {
  my($string)=@_;
  (defined $string ? map(($_ eq ' ' ? T_SPACE() : T_OTHER($_)),split('',$string)) : ()); }

# Similar to Explode, but convert letters to catcode LETTER
# Hopefully, this is essentially correct WITHOUT resorting to catcode lookup?
sub ExplodeText {
  my($string)=@_;
  (defined $string
   ? map(($_ eq ' ' ? T_SPACE() : (/[a-zA-Z]/ ? T_LETTER($_) : T_OTHER($_))),split('',$string))
   : ()); }

# Reverts an object into TeX code, as a Tokens list, that would create it.
# Note that this is not necessarily the original TeX.
sub Revert {
  my($thing)=@_;
  (defined $thing ? (ref $thing ? $thing->revert : Explode($thing)) : ()); }

sub UnTeX {
  my($thing)=@_;
  return undef unless defined $thing;
  my @tokens = (ref $thing ? $thing->revert : Explode($thing));
  my $string = '';
  my $prevmac=0;
  foreach my $token (@tokens){
    next if $token->getCatcode == CC_COMMENT;
    my $s = $token->getString();
    $string .= ' ' if $prevmac && ($s =~ /^\w/);
    $string .= $s;
    $prevmac = ($s  =~ /^\\/) if $s; }
  $string; }

#======================================================================
# Constructors for number and dimension types.

sub Number      { LaTeXML::Number->new(@_); }
sub Float       { LaTeXML::Float->new(@_); }
sub Dimension   { LaTeXML::Dimension->new(@_); }
sub MuDimension { LaTeXML::MuDimension->new(@_); }
sub Glue        { LaTeXML::Glue->new(@_); }
sub MuGlue      { LaTeXML::MuGlue->new(@_); }
sub Pair        { LaTeXML::Pair->new(@_); }
sub PairList    { LaTeXML::PairList->new(@_); }

#======================================================================
# Constructors for Boxes and Lists.

sub Box {
  my($string,$font,$locator,$tokens)=@_;
  $font = $LaTeXML::Global::STATE->lookupValue('font') unless defined $font;
  $locator = $LaTeXML::Global::STATE->getStomach->getGullet->getLocator unless defined $locator;
  $tokens  = T_OTHER($string) if $string && !defined $tokens;
  if($LaTeXML::Global::STATE->lookupValue('IN_MATH')){
    LaTeXML::MathBox->new($string,$font->specialize($string),$locator,$tokens); }
  else {
    LaTeXML::Box->new($string, $font, $locator,$tokens); }}

#
# sub List {
#   my(@boxes)=@_;
# $ismath is NOT correct here!!!
# we need to know whether we were in math BEFORE digesting the boxes!
#   ( $ismath ? LaTeXML::MathList->new(@boxes) : LaTeXML::List->new(@boxes)); }

#**********************************************************************
# Error & Progress reporting.


sub NoteProgress { 
  print STDERR @_ if $LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0;
  return; }

our %note_timers=();
sub NoteBegin {
  my($state)=@_;
  $note_timers{$state}=[Time::HiRes::gettimeofday];
  print STDERR "\n($state..." if $LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0; }

sub NoteEnd {
  my($state)=@_;
  if(my $start = $note_timers{$state}){
    my $elapsed = Time::HiRes::tv_interval($start,[Time::HiRes::gettimeofday]);
    undef $note_timers{$state};
    print STDERR sprintf(" %.2f sec)",$elapsed) if $LaTeXML::Global::STATE->lookupValue('VERBOSITY') >= 0; }}

sub Fatal { 
  my($message)=@_;
  if(!$LaTeXML::Error::InHandler && defined($^S)){
    $LaTeXML::Global::STATE->noteStatus('fatal');
    $message
      = LaTeXML::Error::generateMessage("Fatal",$message,1,
		       ($LaTeXML::Global::STATE->lookupValue('VERBOSITY') > 0
			? ("Stack Trace:",LaTeXML::Error::stacktrace()):()));
  }
  local $LaTeXML::Error::InHandler=1;
  die $message; 
  return; }

# Note that "100" is hardwired into TeX, The Program!!!
our $MAXERRORS=100;

# Should be fatal if strict is set, else warn.
sub Error {
  my($msg)=@_;
  if($LaTeXML::Global::STATE->lookupValue('STRICT')){
    Fatal($msg); }
  else {
    $LaTeXML::Global::STATE->noteStatus('error');
    print STDERR LaTeXML::Error::generateMessage("Error",$msg,1,"Continuing... Expect trouble.\n")
      unless $LaTeXML::Global::STATE->lookupValue('VERBOSITY') < -2; }
  if(($LaTeXML::Global::STATE->getStatus('error')||0) > $MAXERRORS){
    Fatal(":too_many:$MAXERRORS Too many errors!"); }
  return; }

# Warning message; results may be OK, but somewhat unlikely
sub Warn {
  my($msg)=@_;
  $LaTeXML::Global::STATE->noteStatus('warning');
  print STDERR LaTeXML::Error::generateMessage("Warning",$msg,0)
    unless $LaTeXML::Global::STATE->lookupValue('VERBOSITY') < -1; 
  return; }

# Informational message; results likely unaffected
# but the message may give clues about subsequent warnings or errors
sub Info {
  my($msg)=@_;
  $LaTeXML::Global::STATE->noteStatus('info');
  print STDERR LaTeXML::Error::generateMessage("Info",$msg,0)
    unless $LaTeXML::Global::STATE->lookupValue('VERBOSITY') < 0;
  return; }

#**********************************************************************
# Generic functions
our %NOBLESS= map(($_=>1), qw( SCALAR HASH ARRAY CODE REF GLOB LVALUE));

sub Stringify {
  my($object)=@_;
  if(!defined $object){ 'undef'; }
  elsif(!ref $object){ $object; }
  elsif($NOBLESS{ref $object}){ "$object"; }
  elsif($object->can('stringify')){ $object->stringify; }
  # Have to handle LibXML stuff explicitly (unless we want to add methods...?)
  elsif($object->isa('XML::LibXML::Node')){
    if($object->nodeType == XML_ELEMENT_NODE){ 
      my $tag = $LaTeXML::Global::STATE->getModel->getNodeQName($object);
      my $attributes ='';
      foreach my $attr ($object->attributes){
	my $name = $attr->nodeName;
	next if $name =~ /^_/;
	my $val = $attr->getData;
	$val = substr($val,0,30)."..." if length($val)>35;
	$attributes .= ' '. $name. "=\"".$val."\""; }
      "<".$tag.$attributes. ($object->hasChildNodes ? ">..." : "/>");
    }
    elsif($object->nodeType == XML_TEXT_NODE){
      "XMLText[".$object->data."]"; }
    elsif($object->nodeType == XML_DOCUMENT_NODE){
      "XMLDocument[".$$object."]"; }
    else { "$object"; }}
  else { "$object"; }}

sub ToString {
  my($object)=@_;
  (defined $object ? (((ref $object) && !$NOBLESS{ref $object}) ? $object->toString : "$object"):''); }

# Just how deep of an equality test should this be?
sub Equals {
  my($a,$b)=@_;
  return 1 if !(defined $a) && !(defined $b); # both undefined, equal, I guess
  return 0 unless (defined $a) && (defined $b); # else both must be defined
  my $refa = (ref $a) || '_notype_';
  my $refb = (ref $b) || '_notype_';
  return 0 if $refa ne $refb;					# same type?
  return $a eq $b if ($refa eq '_notype_') || $NOBLESS{$refa}; # Deep comparison of builtins?
  return 1 if $a->equals($b);					# semi-shallow comparison?
  # Special cases? (should be methods, but that embeds State knowledge too low)
  if($refa eq 'LaTeXML::Token'){ # Check if they've been \let to the same defn.
    my $defa = $LaTeXML::Global::STATE->lookupDefinition($a);
    my $defb = $LaTeXML::Global::STATE->lookupDefinition($b);
    return $defa && $defb && ($defa eq $defb); }
  return 0; }

#    && ( ((ref $a) && (ref $b) && ((ref $a) eq (ref $b)) && !$NOBLESS{ref $a})
#	 ? $a->equals($b) : ($a eq $b)); }

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

Creates a L<LaTeXML::Token> with the given content and catcode.
The following shorthand versions are also exported for convenience:

  T_BEGIN, T_END, T_MATH, T_ALIGN, T_PARAM,
  T_SUB, T_SUPER, T_SPACE, T_LETTER($letter),
  T_OTHER($char), T_ACTIVE($char),
  T_COMMENT($comment), T_CS($cs)

=item C<< $tokens = Tokens(@token); >>

Creates a L<LaTeXML::Tokens> from a list of L<LaTeXML::Token>'s

=item C<< $tokens = Tokenize($string); >>

Tokenizes the C<$string> according to the standard cattable, returning a L<LaTeXML::Tokens>.

=item C<< $tokens = TokenizeInternal($string); >>

Tokenizes the C<$string> according to the internal cattable (where @ is a letter),
returning a L<LaTeXML::Tokens>.

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

