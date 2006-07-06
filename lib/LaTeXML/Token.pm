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
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

#======================================================================
# See LaTeXML::Global for constructors.

#======================================================================
# Categories of Category codes.
# For Tokens with these catcodes, only the catcode is relevant for comparison.
# (if they even make it to a stage where they get compared)
our @primitive_catcode = (1,1,1,1,
			  1,1,1,1,
			  1,0,1,0,
			  0,0,0,0,
			  0,1);

my @standardchar=("\\",'{','}','$',
                    '&',"\n",'#','^', 
		    '_',undef,undef,undef,
 		    undef,undef,'%',undef);

our @CC_NAME=qw(Escape Begin End Math Align EOL Parameter Superscript Subscript
		Ignore Space Letter Other Active Comment Invalid
		ControlSequence NotExpanded);
our @CC_SHORT_NAME = qw(T_ESCAPE T_BEGIN T_END T_MATH
			T_ALIGN T_EOL T_PARAM T_SUPER
			T_SUB T_IGNORE T_SPACE T_LETTER
			T_OTHER T_ACTIVE T_COMMENT T_INVALID
			T_CS T_NOTEXPANDED
		       );

#======================================================================
# Accessors.

sub isaToken { 1; }

# Get the CS Name of the token. This is the name that definitions will be
# stored under; It's the same for various `different' BEGIN tokens, eg.
sub getCSName {
  my($token)=@_;
  my $cc = $$token[1];
  ($primitive_catcode[$cc] ? $CC_NAME[$cc] : $$token[0]); }

# Return the string or character part of the token
sub getString  { $_[0]->[0]; }
# Return the character code of  character part of the token, or 256 if it is a control sequence
sub getCharcode{ ($_[0]->[1] == CC_CS ? 256 : ord($_[0]->[0])); }
# Return the catcode of the token.
sub getCatcode { $_[0]->[1]; }

sub getDefinition { $STOMACH->lookupDefinition($_[0]); }

# Defined so a Token or Tokens can be used interchangeably.
sub unlist { ($_[0]); }
sub getLocator { ''; }

#======================================================================
# Note that this converts the string to a more `user readable' form using `standard' chars for catcodes.
# We'll need to be careful about using string instead of untex for internal purposes where the
# actual character is needed.
sub untex {
  my($self)=@_;
  ($standardchar[$$self[1]] || $$self[0]); }

sub toString { $_[0]->[0]; }

# Convenience, for a CS token.
# Return the expansion (Tokens) that would invoke it with the given args.
sub invocation {
  my($self,@args)=@_;
  $self->getDefinition->invocation(@args); }

#======================================================================
# Methods for overloaded ops.

# Compare two tokens; They are equal if they both have same catcode,
# and either the catcode is one of the primitive ones, or thier strings
# are equal.
sub equals {
  my($a,$b)=@_;
  (defined $b
   && (ref $a) eq (ref $b)) 
    && ($$a[1] eq $$b[1])
      && ($primitive_catcode[$$a[1]] || ($$a[0] eq $$b[0])); }

# Primarily for error reporting.
sub stringify {
  my($self)=@_;
  $CC_SHORT_NAME[$$self[1]].'['.$$self[0].']'; }

#**********************************************************************
# LaTeXML::Tokens
#   A blessed reference to a list of LaTeXML::Token's
#   It implements the core API of Mouth, as if pre-tokenized.
#**********************************************************************
package LaTeXML::Tokens;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,@tokens)=@_;
  bless [@tokens],$class; }

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

# Methods for overloaded ops.
sub equals {
  my($a,$b)=@_;
  return 0 unless defined $b && (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while(@a && @b && ($a[0]->equals($b[0]))){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub stringify {
  my($self)=@_;
  "Tokens[".join(',',map($_->toString,@$self))."]"; }

#======================================================================
# The following implements the Mouth API, so that a Token list can
# act as a pre-tokenized source of tokens.

sub hasMoreInput {
  my($self)=@_;
  scalar(@$self); }

sub readToken {
  my($self)=@_;
  return unless @$self;
  shift(@$self); }

sub getLocator { ''; }

#**********************************************************************
package LaTeXML::Number;
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);
use strict;

sub new {
  my($class,$number)=@_;
  bless [$number||"0"],$class; }

sub getValue { $_[0]->[0]; }
sub toString { $_[0]->[0]; }
sub untex    { $_[0]->toString.'\relax'; }
sub unlist   { $_[0]; }

sub negate   { (ref $_[0])->new(- $_[0]->getValue); }
sub add      { (ref $_[0])->new($_[0]->getValue + $_[1]->getValue); }
# arg 2 is a number
sub multiply { (ref $_[0])->new($_[0]->getValue * $_[1]); }

sub stringify { "Number[".$_[0]->[0]."]"; }

#**********************************************************************
package LaTeXML::Dimension;
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Number);
use strict;

sub new {
  my($class,$sp)=@_;
  $sp = "0" unless $sp;
  if($sp =~ /^(\d*\.?\d*)([a-zA-Z][a-zA-Z])$/){ # Dimensions given.
    $sp = $1 * $STOMACH->convertUnit($2); }
  bless [$sp||"0"],$class; }

sub toString    { ($_[0]->[0]/65536).'pt'; }

sub stringify { "Dimension[".$_[0]->[0]."]"; }
#**********************************************************************
package LaTeXML::MuDimension;
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Dimension);

sub stringify { "MuDimension[".$_[0]->[0]."]"; }
#**********************************************************************
package LaTeXML::Glue;
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Dimension);
use strict;

our %fillcode=(fil=>1,fill=>2,filll=>3);
our @FILL=('','fil','fill','filll');
sub new {
  my($class,$sp,$plus,$pfill,$minus,$mfill)=@_;
  if((!defined $plus) && (!defined $pfill) && (!defined $minus) && (!defined $mfill)){
    if($sp =~ /^(\d*\.?\d*)$/){}
    elsif($sp =~ /^(\d*\.?\d*)(\w\w)(\s+plus(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z))(\s+minus(\d*\.?\d*)(fil|fill|filll|[a-zA-Z][a-zA-Z]))?$/){
      my($f,$u,$p,$pu,$m,$mu)=($1,$2,$4,$5,$7,$8);
      $sp = $f * $STOMACH->convertUnit($u);
      if(!$pu){}
      elsif($fillcode{$pu}){ $plus=$p; $pfill=$pu; }
      else { $plus = $p * $STOMACH->convertUnit($pu); $pfill=0; }
      if(!$mu){}
      elsif($fillcode{$mu}){ $minus=$m; $mfill=$mu; }
      else { $minus = $m * $STOMACH->convertUnit($mu); $mfill=0; }
    }}
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
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Glue);

sub stringify { "MuGlue[".join(',',@{$_[0]})."]"; }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Token, LaTeXML::Tokens, LaTeXML::Number, LaTeXML::Dimension, etc.

=head2 DESCRIPTION

This module defines Tokens (C<LaTeXML::Token>, C<LaTeXML::Tokens>)
and other things (C<LaTeXML::Number>, C<LaTeXML::Dimension>, C<LaTeXML::MuDimension>,
C<LaTeXML::Glue> and  C<LaTeXML::MuGlue>)  that get created during tokenization 
and  expansion.
C<LaTeXML::Token> represents a TeX token. C<LaTeXML::Tokens> represents a sequence of tokens.
Both packages extend L<LaTeXML::Object> and implement the methods for the overloaded operators.

=head2 Methods common to all Token level objects.

=over 4

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this C<$object>.

=item C<< $string = $object->toString; >>

Return a string representing C<$object>.

=item C<< $string = $object->untex; >>

Return the TeX form of C<$object>, suitable (hopefully) for processing by TeX.

=back

=head2 Methods specific to LaTeXML::Token

=over 4

=item C<< $string = $token->getCSName; >>

Return the string or character part of the C<$token>; for the special category
codes, returns the standard string (eg. C<T_BEGIN->getCSName> returns "{").

=item C<< $string = $token->getString; >>

Return the string or character part of the C<$token>.

=item C<< $code = $token->getCharcode; >>

Return the character code of the character part of the C<$token>, or 256 if it is a control sequence.

=item C<< $code = $token->getCatcode; >>

Return the catcode of the C<$token>.

=item C<< $defn = $token->getDefinition; >>

Return the current definition associated with C<$token> in C<$STOMACH>, or
undef if none.

=item C<< $tokens = $token->invocation(@args); >>

Return the L<LaTeXML::Tokens> representing the invocation of C<$token> acting
on the arguments in C<@args>.  C<$token> must have a associated definition.

=back

=head2 Methods specific to LaTeXML::Tokens

=over 4

=item C<< $tokenscopy = $tokens->clone; >>

Return a shallow copy of the $tokens.  This is useful before reading from a C<LaTeXML::Tokens>.

=item C<< $token = $tokens->readToken; >>

Returns (and remove) the next token from $tokens.  This is part of the public API of L<LaTeXML::Mouth>
so that a C<LaTeXML::Tokens> can serve as a L<LaTeXML::Mouth>.

=back

=head2 Methods that apply to the numeric objects

=over 4

=item C<< $n = $object->getValue; >>

Return the value in scaled points (ignoring shrink and stretch, if any).

=item C<< $n = $object->negate; >>

Return an object representing the negative of the C<$object>.

=item C<< $n = $object->add($other); >>

Return an object representing the sum of C<$object> and C<$other>

=item C<< $n = $object->multiply($n); >>

Return an object representing the product of C<$object> and C<$n> (a regular number).

=cut

