# /=====================================================================\ #
# |  LaTeXML::Token, LaTeXML::Tokens                                    | #
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
package LaTeXML::Token;
use strict;
use Exporter;
use LaTeXML::Error;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object Exporter);
our @EXPORT = ( qw(CC_ESCAPE  CC_BEGIN  CC_END     CC_MATH 
		   CC_ALIGN   CC_EOL    CC_PARAM   CC_SUPER
		   CC_SUB     CC_IGNORE CC_SPACE   CC_LETTER
		   CC_OTHER   CC_ACTIVE CC_COMMENT CC_INVALID
		   CC_CS      CC_NOTEXPANDED
		   &T_BEGIN &T_END &T_MATH &T_ALIGN &T_PARAM &T_SUB &T_SUPER &T_SPACE 
		   &T_LETTER &T_OTHER &T_ACTIVE &T_COMMENT &T_CS
		   @CC_NAME
		   &Token &Tokens &Number &Dimension &MuDimension &Glue &MuGlue
		   &Tokenize &TokenizeInternal &Explode &roman &Roman
		   &getStandardCattable &getInternalCattable));

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

# Return a LaTeXML::Tokens made from the arguments (tokens)
sub Tokens {
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
sub Number      { LaTeXML::Number->new(@_); }
sub Dimension   { LaTeXML::Dimension->new(@_); }
sub MuDimension { LaTeXML::MuDimension->new(@_); }
sub Glue        { LaTeXML::Glue->new(@_); }
sub MuGlue      { LaTeXML::MuGlue->new(@_); }

#**********************************************************************
# Methods and internals follow.
#**********************************************************************
#======================================================================
my @standardchar=("\\",'{','}','$',
                    '&',"\n",'#','^', 
		    '_',undef,undef,undef,
 		    undef,undef,'%',undef);

our @CC_NAME=qw(Escape Begin End Math Align EOL Parameter Superscript Subscript
		Ignore Space Letter Other Active Comment Invalid
		ControlSequence NotExpanded);
our @CC_SHORT_NAME=qw(Esc Beg End Math Align EOL Param Sup Sub
		      Ignore Space Letter Other Active Comment Invalid
		      CS NotExp);
#======================================================================
# Accessors.
# Return the string or character part of the token
sub getString  { $_[0]->[0]; }
# Return the character code of  character part of the token, or 256 if it is a control sequence
sub getCharcode{ ($_[0]->[1] == CC_CS ? 256 : ord($_[0]->[0])); }
# Return the catcode of the token.
sub getCatcode { $_[0]->[1]; }

# Defined so a Token or Tokens can be used interchangeably.
sub unlist { ($_[0]); }

#======================================================================
# For a Token used as a Meaning ????
# Note that the token may be bound to a definition which IS executable,
# but then we should have ended up with that definition as the meaning.
sub isExecutable { 0; }

sub digest {
  my($self,$stomach)=@_;
  $stomach->digestTokens(Tokens($self)); }

#======================================================================
# Note that this converts the string to a more `user readable' form using `standard' chars for catcodes.
# We'll need to be careful about using string instead of untex for internal purposes where the
# actual character is needed.
sub untex {
  my($self)=@_;
  ($standardchar[$$self[1]] || $$self[0]); }

sub toString { $_[0]->[0]; }
#======================================================================
# Methods for overloaded ops.
sub equals {
  my($a,$b)=@_;
  ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]) && ($$a[1] eq $$b[1]); }

# Primarily for error reporting.
sub stringify {
  my($self)=@_;
  "Token[".$$self[0].','.$CC_SHORT_NAME[$$self[1]]."]"; }

#**********************************************************************
# LaTeXML::Tokens
#   A blessed reference to a list of LaTeXML::Token's
#   It implements the core API of Mouth, as if pre-tokenized.
#**********************************************************************
package LaTeXML::Tokens;
use strict;
use LaTeXML::Error;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

# Can't use Token, and this is the only one needed here.
use constant CC_COMMENT => 14;

sub new {
  my($class,@tokens)=@_;
  map((ref $_ eq 'LaTeXML::Token')||TypeError($_,'Token'),@tokens);
  bless [@tokens],$class; }

sub typecheck {
  map((ref $_ eq 'LaTeXML::Token')||TypeError($_,'Token'),@_); }

# Return a list of the tokens making up this Tokens
sub unlist { @{$_[0]}; }

# Return a shallow copy of the Tokens
sub clone {
  my($self)=@_;
  bless [@$self], ref $self; }

sub toString { join('',map($_->toString, @{$_[0]})); }

# Return a string containing the TeX form of the Tokens
sub untex {
  my($self)=@_;
  my $string = '';
  my $prevmac=0;
  foreach my $token (@$self){
    next if $token->getCatcode == CC_COMMENT;
    my $s = $token->untex();
    $string .= ' ' if $prevmac && ($s =~ /^\w/);
    $string .= $s;
    $prevmac = ($s  =~ /^\\/) if $s; }
  $string; }

sub digest {
  my($self,$stomach)=@_;
  $stomach->digestTokens($self->clone); }

# Methods for overloaded ops.
sub equals {
  my($a,$b)=@_;
  return 0 unless (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while(@a && @b && ($a[0] eq $b[0])){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub stringify {
  my($self)=@_;
  "Tokens[".join('',map($_->getString,@$self))."]"; }

#======================================================================
# The following implements the Mouth API, so that a Token list can
# act as a pre-tokenized source of tokens.

sub readToken {
  my($self)=@_;
  return unless @$self;
  shift(@$self); }

sub getContext { 
  my($self)=@_;
  my $msg=$self;
  if(@$msg > 100){
    $msg = bless [@$self[0..100]], ref $self; }
  "  pending tokens: ". $msg->untex."\n"; }

#**********************************************************************
package LaTeXML::Number;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);
use strict;

sub new {
  my($class,$number)=@_;
  bless [$number||"0"],$class; }

sub isExecutable { 0; }
sub getValue { $_[0]->[0]; }
sub toString { $_[0]->[0]; }
sub untex    { $_[0]->toString.'\relax'; }
sub unlist   { $_[0]; }

sub digest { $_[0]; }

sub negate   { (ref $_[0])->new(- $_[0]->getValue); }
sub add      { (ref $_[0])->new($_[0]->getValue + $_[1]->getValue); }
# arg 2 is a number
sub multiply { (ref $_[0])->new($_[0]->getValue * $_[1]); }

sub stringify { "Number[".$_[0]->[0]."]"; }

#**********************************************************************
package LaTeXML::Dimension;
our @ISA=qw(LaTeXML::Number);
use strict;

sub new {
  my($class,$sp)=@_;
  $sp = "0" unless $sp;
  if($sp =~ /^(\d*\.?\d*)([a-zA-Z][a-zA-Z])$/){ # Dimensions given.
    $sp = $1 * $LaTeXML::STOMACH->convertUnit($2); }
  bless [$sp||"0"],$class; }

sub toString    { ($_[0]->[0]/65536).'pt'; }

sub stringify { "Dimension[".$_[0]->[0]."]"; }
#**********************************************************************
package LaTeXML::MuDimension;
our @ISA=qw(LaTeXML::Dimension);

sub stringify { "MuDimension[".$_[0]->[0]."]"; }
#**********************************************************************
package LaTeXML::Glue;
our @ISA=qw(LaTeXML::Dimension);
use strict;

our %fillcode=(fil=>1,fill=>2,filll=>3);
our @FILL=('','fil','fill','filll');
sub new {
  my($class,$sp,$plus,$pfill,$minus,$mfill)=@_;
  if((!defined $plus) && (!defined $pfill) && (!defined $minus) && (!defined $mfill)
     && ($sp =~ /^(\d*\.?\d*)(\w\w)(\s+plus(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z))(\s+minus(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z]))?$/)){
    my($f,$u,$p,$pu,$m,$mu)=($1,$2,$4,$5,$7,$8);
    $sp = $f * $LaTeXML::STOMACH->convertUnit($u);
    if(!$pu){}
    elsif($fillcode{$pu}){ $plus=$p; $pfill=$pu; }
    else { $plus = $p * $LaTeXML::STOMACH->convertUnit($pu); $pfill=0; }
    if(!$mu){}
    elsif($fillcode{$mu}){ $minus=$m; $mfill=$mu; }
    else { $minus = $m * $LaTeXML::STOMACH->convertUnit($mu); $mfill=0; }
  }
  bless [$sp||"0",$plus||"0",$pfill||0,$minus||"0",$mfill||0],$class; }

#sub getStretch { $_[0]->[1]; }
#sub getShrink  { $_[0]->[2]; }

sub toString { 
  my($self)=@_;
  my ($sp,$plus,$pfill,$minus,$mfill)=@$self;
  my $string = ($sp/65536)."pt";
  $string .= ' plus '. ($pfill ? $plus .$FILL[$pfill] : ($plus/65536) .'pt') if $plus != 0;
  $string .= ' minus '.($mfill ? $minus.$FILL[$mfill] : ($minus/65536).'pt') if $minus != 0;
  $string; }
sub negate      { 
  my($pts,$p,$pf,$m,$mf)=@{$_[0]};
  (ref $_[0])->new(-$pts,-$p,$pf,-$m,$mf); }

sub add         { 
  my($self,$other)=@_;
  my($pts,$p,$pf,$m,$mf)=@$self;
  if(ref $other eq 'LaTeXML::Glue'){
    my($pts2,$p2,$pf2,$m2,$mf2)=@$other;
    $pts += $pts2;
    if($pf == $pf2){ $p+=$p2; }
    elsif($pf < $pf2){ $p=$p2; $pf=$pf2; }
    if($mf == $mf2){ $m+=$m2; }
    elsif($mf < $mf2){ $m=$m2; $mf=$mf2; }
    (ref $_[0])->new($pts,$p,$pf,$m,$mf); }
  else {
    (ref $_[0])->new($pts+$other->getValue,$p,$pf,$m,$mf); }}

sub multiply    { 
  my($self,$other)=@_;
  my($pts,$p,$pf,$m,$mf)=@$self;
  (ref $_[0])->new($pts*$other,$p*$other,$pf,$m*$other,$mf); }

sub stringify { "Glue[".join(',',@{$_[0]})."]"; }
#**********************************************************************
package LaTeXML::MuGlue;
our @ISA=qw(LaTeXML::Glue);

sub stringify { "MuGlue[".join(',',@{$_[0]})."]"; }
#**********************************************************************
package LaTeXML::KeyVals;
our @ISA=qw(LaTeXML::Object);

# Spec??
sub new {
  my($class,$keyset,@pairs)=@_;
  bless {keyset=>$keyset, keyvals=>[@pairs]},$class; }

sub digest {
  my($self,$stomach)=@_;
  my @kv=@{$$self{keyvals}};
  my @dkv=();
  while(@kv){
    my($key,$value)=(shift(@kv),shift(@kv));
    push(@dkv,$key); 
    push(@dkv,$value->digest($stomach)); }
  (ref $self)->new($$self{keyset},@dkv); }

sub untex {
  my($self)=@_;
  my $string='';
  my @kv=@{$$self{keyvals}};
  while(@kv){
    my($key,$value)=(shift(@kv),shift(@kv));
    $string .= ', ' if $string;
    $string .= $key.'='.$value->untex; }
  $string; }

sub toString {
  my($self)=@_;
  my $string='';
  my @kv=@{$$self{keyvals}};
  while(@kv){
    my($key,$value)=(shift(@kv),shift(@kv));
    $string .= ', ' if $string;
    $string .= $key.'='.$value->toString; }
  $string; }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Token and LaTeXML::Tokens

=head2 SYNOPSIS

use LaTeXML::Token;

=head2 DESCRIPTION

 This module defines Tokens (LaTeXML::Token, LaTeXML::Tokens)
  and other things (LaTeXML::Number, LaTeXML::Dimension, LaTeXML::MuDimension, 
LaTeXML::Glue and  LaTeXML::MuGlue)  that get created during tokenization and
 expansion. [LaTeXML::KeyVal is also defined here]
 LaTeXML::Token represents a TeX token. LaTeXML::Tokens represents a sequence of tokens.
 Both packages extend LaTeXML::Object and implement the methods for the overloaded operators.

=head2 EXPORTS

This module exports various constants and functions useful for creating and manipulating Tokens.

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

=item C<< $string = $CC_NAME[$catcode] >>

Returns a string naming the $catcode, for constructing debugging messages.

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

=head2 Methods common to all Token level objects.

=over 4

=item C<< $bool = $object->isExecutable; >>

Returns whether this is an executable object (in the sense of macro or primitive);
 In these cases, it always returns 0 (false).  This is defined since
the Meaning of a Token may be a Token.

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this $object.

=item C<< $string = $object->toString; >>

Return a string representing $object.

=item C<< $string = $object->untex; >>

Return the TeX form of $object, suitable (hopefully) for processing by TeX.

=back

=head2 Methods specific to LaTeXML::Token

=over 4

=item C<< $string = $token->getString; >>

Return the string or character part of the $token.

=item C<< $code = $token->getCharcode; >>

Return the character code of the character part of the $token, or 256 if it is a control sequence.

=item C<< $code = $token->getCatcode; >>

Return the catcode of the $token.

=back

=head2 Methods specific to LaTeXML::Tokens

=over 4

=item C<< $tokenscopy = $tokens->clone; >>

Return a shallow copy of the $tokens.  This is useful before reading from a LaTeXML::Tokens.

=item C<< $token = $tokens->readToken; >>

Returns (and remove) the next token from $tokens.  This is part of the public API of L<LaTeXML::Mouth>
so that a $tokens can serve as a Mouth.

=item C<< $string = $tokens->getContext; >>

Return a description of $tokens.   This is part of the public API of L<LaTeXML::Mouth>
so that a $tokens can serve as a Mouth.

=back

=head2 Methods that apply to the numeric objects

=over 4

=item C<< $n = $object->getValue; >>

Return the value in scaled points (ignoring shrink and stretch, if any).


=item C<< $n = $object->negate; >>

Return an object representing the negative of the object.

=item C<< $n = $object->negate($other); >>

Return an object representing the sum of this object and $other

=item C<< $n = $object->multiply($n); >>

Return an object representing the product of this object and $n (a regular number).

=cut

