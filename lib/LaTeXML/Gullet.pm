# /=====================================================================\ #
# |  LaTeXML::Gullet                                                    | #
# | Analog of TeX's Gullet; deals with expansion and arg parsing        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Gullet;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

#=head1 LaTeXML::Gullet

#LaTeXML::Gullet  corresponds to TeX's Gullet.

#=cut

#**********************************************************************
sub new {
  my($class,$source,$stomach,%options)=@_;
  bless {stomach=>$stomach, mouth=>$source, mouthstack=>[], pushback=>[],
	 pending_comments=>[], %options}, $class; }

#**********************************************************************
# Accessors
sub getStomach { $_[0]->{stomach}; }

#**********************************************************************
# Start reading tokens from a new Mouth.
# This pushes the mouth as the current source that $gullet->readToken (etc) will read from.
# Once this Mouth has been exhausted, readToken, etc, will return undef,
# until you call $gullet->closeMouth to clear the source.
# Exception: if $toplevel=1, readXToken will step to next source
# Note that a Tokens can act as a Mouth.
sub openMouth {
  my($self,$mouth)=@_;
  return unless $mouth;
  unshift(@{$$self{mouthstack}},$$self{pushback},$$self{mouth}); 
  $$self{pushback}=[];
  $$self{mouth}=$mouth; }

sub closeMouth {
  my($self,$forced)=@_;
  if(!$forced && (@{$$self{pushback}} || $$self{mouth}->hasMoreInput)){
    Error("Closing mouth with input remaining: ".$self->getContext); } # Or Warn???
  if(@{$$self{mouthstack}}){
    $$self{pushback}= shift(@{$$self{mouthstack}}); 
    $$self{mouth}   = shift(@{$$self{mouthstack}}); }
  else {
    $$self{pushback}=[];
    $$self{mouth}=Tokens(); }}

# Obscure, but the only way I can think of to End!! (see \bye or \end{document})
# Flush all sources (close all pending mouth's)
sub flush {
  my($self)=@_;
  $$self{pushback}=[];
  $$self{mouth}=Tokens();
  $$self{mouthstack}=[]; }

# User feedback for where something (error?) occurred.
sub getContext {
  my($self,$short)=@_;
  my $msg ='';
  my @mouths = ($$self{pushback}, $$self{mouth}, @{$$self{mouthstack}});
  while(@mouths){
    my $pb = shift(@mouths);
    my $m = shift(@mouths);
    $msg .= $m->getContext($short);
    $msg .= "\n  To be read again ".Tokens(@$pb)->untex if !$short && @$pb;
  }
  $msg; }

sub getSourceLocation {
  my($self)=@_;
  my @mouths = ($$self{pushback}, $$self{mouth}, @{$$self{mouthstack}});
  while(@mouths){
    my $pb = shift(@mouths);
    my $m = shift(@mouths);
    my $f = $m->getPathname;
    return ($f, $m->getLinenumber) if $f; }
  ("Unknown",0); }

#**********************************************************************
# Return $tokens with all tokens expanded
sub expandTokens {
  my($self,$tokens)=@_;
  $self->openMouth($tokens->clone);
  my @expanded=();
  while(defined(my $t=$self->readXToken)){
    push(@expanded,$t);}
  $self->closeMouth;
  Tokens(@expanded); }

# Not really 100% sure how this is supposed to work
# See TeX Ch 20, p216 regarding noexpand, \edef with token list registers, etc.
# Solution: Duplicate param tokens, stick NOTEXPANDED infront of expandable tokens.
sub neutralizeTokens {
  my($self,@tokens)=@_;
  my $stomach = $$self{stomach};
  my @result=();
  foreach my $t (@tokens){
    if($t->getCatcode == CC_PARAM){    
      push(@result,$t); }
    elsif(defined(my $defn=$stomach->getDefinition($t))){
      push(@result,Token('\noexpand',CC_NOTEXPANDED)); }
    push(@result,$t); }
  @result; }

#**********************************************************************
# Low-level readers: read token, read expanded token
#**********************************************************************
# Note that every char (token) comes through here (maybe even twice, through args parsing),
# So, be Fast & Clean!  This method only reads from the current input stream (Mouth).
sub readToken {
  my($self)=@_;
  return shift(@{$$self{pushback}}) if @{$$self{pushback}};
  my $mouth = $$self{mouth};
  my $token;
  while(defined($token = $mouth->readToken()) && ($$token[1] == CC_COMMENT)){ # NOTE: Inlined ->getCatcode
    push(@{$$self{pending_comments}},$token); } # What to do with comments???
  return $token; }

# Unread tokens are assumed to be not-yet expanded.
sub unread {
  my($self,@tokens)=@_;
  unshift(@{$$self{pushback}},@tokens); }

# Read the next non-expandable token (expanding tokens until there's a non-expandable one).
# Note that most tokens pass through here, so be Fast & Clean! readToken is folded in.
# `Toplevel' processing, (if $toplevel is true), used at the toplevel processing by Stomach,
#  will step to the next input stream (Mouth)
# if one is available, and will also pass comments.
sub readXToken {
  my($self,$toplevel)=@_;
  return shift(@{$$self{pending_comments}}) if $toplevel && @{$$self{pending_comments}};
  my($token,$cc,$defn);
  my $stomach = $$self{stomach};
  while(1){
    if(!defined($token = (@{$$self{pushback}} ? shift(@{$$self{pushback}}) : $$self{mouth}->readToken() ))){
      return undef unless $toplevel && @{$$self{mouthstack}};
      $self->closeMouth; }		# Next input stream.
    elsif(($cc = $$token[1]) == CC_NOTEXPANDED){ # NOTE: Inlined ->getCatcode
      # Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
      # so this token should never leak out through an EXTERNAL call to readToken.
      return $self->readToken; } # Just return the next token.
    elsif($cc == CC_COMMENT){
      return $token if $toplevel;
      push(@{$$self{pending_comments}},$token); } # What to do with comments???
    elsif(defined($defn=$stomach->getDefinition($token)) && $defn->isExpandable){
      $self->unread($defn->invoke($self)); } # Expand and push back the result (if any) and continue
    else {
      return $token; }		# just return it
  }}

#**********************************************************************
# Mid-level readers: checking and matching tokens, strings etc.
#**********************************************************************
# The following higher-level parsing methods are built upon readToken & unread.
sub readNonSpace {
  my($self)=@_;
  my $tok;
  do { $tok=$self->readToken(); 
      } while(defined $tok && $tok->getCatcode == CC_SPACE);
  $tok; }

sub skipSpaces {
  my($self)=@_;
  my $tok = $self->readNonSpace;;
  $self->unread($tok) if defined $tok; }

sub skip1Space {
  my($self)=@_;
  my $tok=$self->readToken();
  $self->unread($tok) if $tok && ($tok->getCatcode != CC_SPACE); }

# <filler> = <optional spaces> | <filler>\relax<optional spaces>
sub skipFiller {
  my($self)=@_;
  while(1){
    my $tok = $self->readNonSpace;;
    return unless defined $tok;
    # Should \foo work too (where \let\foo\relax) ??
    if($tok->getString ne '\relax'){ $self->unread($tok); return; }
  }}
  
# Read a sequence of tokens balanced in {}
# assuming the { has already been read.
# Returns a Tokens list of the balanced sequence, omitting the closing }
sub readBalanced {
  my($self)=@_;
  my @tokens=();
  my ($tok,$level)=(undef,1);
  while($level && defined ($tok=$self->readToken())){
    my $cc = $tok->getCatcode;
    $level++ if $cc == CC_BEGIN;
    $level-- if $cc == CC_END;
    push(@tokens,$tok) if $level; }
  Tokens(@tokens); }

sub ifNext {
  my($self,$string,$cc)=@_;
  my $tok=$self->readToken();
  if(defined $string && ref $string eq 'LaTeXML::Token'){
    $cc=$string->getCatcode; $string=$string->getString; }
  return $tok if (defined $tok && ((!defined $string) || ($string eq $tok->getString))
		  && ((!defined $cc) || ($cc == $tok->getCatcode)) );
  $self->unread($tok) if defined $tok;
  0; }

# Match the input against one of the Token or Tokens in @choices; return the matching one or undef.
sub readMatch {
  my($self,@choices)=@_;
  foreach my $choice (@choices){
    my @tomatch=$choice->unlist;
    my @matched=();
    my $tok;
    while(@tomatch && defined($tok=$self->readToken) && push(@matched,$tok) && ($tok eq $tomatch[0])){ 
      shift(@tomatch); }
    return $choice unless @tomatch;	# All matched!!!
    $self->unread(@matched);	# Put 'em back and try next!
  }
  return undef; }

# Match the input against a set of keywords; Similar to readMatch, but the keywords are strings,
# and Case and catcodes are ignored; additionally, leading spaces are skipped.
sub readKeyword {
  my($self,@keywords)=@_;
  $self->skipSpaces;
  foreach my $keyword (@keywords){
    my @tomatch=split('',uc($keyword));
    my @matched=();
    my $tok;
    while(@tomatch && defined ($tok=$self->readToken) && push(@matched,$tok) 
	  && (uc($tok->getString) eq $tomatch[0])){ 
      shift(@tomatch); }
    return $keyword unless @tomatch;	# All matched!!!
    $self->unread(@matched);	# Put 'em back and try next!
  }
  return undef; }

# Return a (balanced) sequence tokens until a match against one of the Tokens in @delims.
# In list context, also returns the found delimiter.
sub readUntil {
  my($self,@delims)=@_;
  my ($found,@toks)=();
  while(!defined ($found=$self->readMatch(@delims))){
    my $tok=$self->readToken(); # Copy next token to args
    return undef unless defined $tok;
    push(@toks,$tok);
    if($tok->getCatcode == CC_BEGIN){ # And if it's a BEGIN, copy till balanced END
      push(@toks,$self->readBalanced->unlist,T_END); }}
  (wantarray ? (Tokens(@toks),$found) : Tokens(@toks)); }

#**********************************************************************
# Special case

sub readRawLines {
  my($self,$endline)=@_;
  # Should check that there's no pushback !?!?
  Error("Extra junk!?") if @{$$self{pushback}};
  my $mouth = $$self{mouth};
  my @lines = ();
  while(my $line = $mouth->readLine){
    push(@lines, $line); 
    last if $line eq $endline; }
  @lines; }

#**********************************************************************
# Higher-level readers: Read various types of things from the input:
#  tokens, non-expandable tokens, args, Numbers, ...
#**********************************************************************
sub readArg {
  my($self)=@_;
  my $tok = $self->readNonSpace;
  if(!defined $tok){
    undef; }
  elsif($tok->getCatcode == CC_BEGIN){
    $self->readBalanced; }
  else {
    Tokens($tok); }}

# Note that this returns an empty array if [] is present, 
# otherwise $default or undef.
sub readOptional {
  my($self,$default)=@_;
  my $tok = $self->readNonSpace;
  if(!defined $tok){ undef; }
  elsif(($tok eq T_OTHER('['))){
    $self->readUntil(T_OTHER(']')); }
  else {
    $self->unread($tok);
    $default; }}

# Like readarg, but with catcodes changed to a semi-verbatim form,
# such as for url's and such.
sub readSemiverbatim {
  my($self)=@_;
  $self->startSemiverbatim;
  my $arg = $self->readArg;
  $self->endSemiverbatim;
  $arg; }

sub startSemiverbatim {
  my($self)=@_;
  $$self{stomach}->bgroup(1);
  $$self{stomach}->setCatcode(CC_OTHER,'^','_','@','~','&','$','#','%');  # should '%' too ?
}
sub endSemiverbatim {
  my($self)=@_;
  $$self{stomach}->egroup(1); }

#**********************************************************************
#  Numbers, Dimensions, Glue
# See TeXBook, Ch.24, pp.269-271.
#**********************************************************************
sub readValue {
  my($self,$type)=@_;
  if   ($type eq 'Number'){ $self->readNumber; }
  elsif($type eq 'Dimension' ){ $self->readDimension; }
  elsif($type eq 'Glue'  ){ $self->readGlue; }
  elsif($type eq 'MuGlue'){ $self->readMuGlue; }
  elsif($type eq 'any'   ){ $self->readArg; }
}

sub readRegisterValue {
  my($self,$type)=@_;
  my $token = $self->readXToken;
  return unless defined $token;
  my $defn = $$self{stomach}->getDefinition($token);
  if((defined $defn) && ($defn->isRegister eq $type)){
    $defn->getValue($$self{stomach},$defn->readArguments($self)); }
  else {
    $self->unread($token); return; }}

#======================================================================
# some helpers...

# <optional signs> = <optional spaces> | <optional signs><plus or minus><optional spaces>
# return +1 or -1
sub readOptionalSigns {
  my($self)=@_;
  my ($sign,$t)=("+1",'');
  while(defined($t=$self->readXToken)
	&& (($t->getString eq '+') || ($t->getString eq '-') || ($t eq T_SPACE))){
    $sign = -$sign if ($t->getString eq '-'); }
  $self->unread($t) if $t;
  $sign; }

sub readDigits {
  my($self,$range,$skip)=@_;
  my $string='';
  my($t,$d);
  while(($t=$self->readXToken()) && (($d=$t->getString) =~ /^[$range]$/)){
      $string .= $d; }
  $self->unread($t) if $t && !($skip && $t->getCatcode == CC_SPACE);
  $string; }

# <factor> = <normal integer> | <decimal constant>
# <decimal constant> = . | , | <digit><decimal constant> | <decimal constant><digit>
# Return a number (perl number)
sub readFactor {
  my($self)=@_;
  my $string = $self->readDigits('0-9');
  my $token = $self->readXToken;
  if($token->getString =~ /^[\.\,]$/){
    $string .= '.'.$self->readDigits('0-9'); 
    $token = $self->readXToken; }
  if(length($string)>0){
    $self->unread($token) if $token && $token->getCatcode!=CC_SPACE;
    $string; }
  else {
    $self->unread($token);
    my $n = $self->readNormalInteger;
    (defined $n ? $n->getValue : undef); }}

#======================================================================
# Integer, Number
#======================================================================
# <number> = <optional signs><unsigned number>
# <unsigned number> = <normal integer> | <coerced integer>
# <coerced integer> = <internal dimen> | <internal glue>

sub readNumber {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  if   (defined (my $n = $self->readNormalInteger    )){ ($s < 0 ? $n->negate : $n); }
  elsif(defined (   $n = $self->readInternalDimension)){ Number($s * $n->getValue); }
  elsif(defined (   $n = $self->readInternalGlue     )){ Number($s * $n->getValue); }
  else{ SalvageError("Missing number, treated as zero.");        Number(0); }}

# <normal integer> = <internal integer> | <integer constant>
#   | '<octal constant><one optional space> | "<hexadecimal constant><one optional space>
#   | `<character token><one optional space>
# Return a Number or undef
sub readNormalInteger {
  my($self)=@_;
  my $t=$self->readXToken;
  if(!defined $t){}
  elsif(($t->getCatcode == CC_OTHER) && ($t->getString =~ /^[0-9]$/)){ # Read decimal literal
    Number(int($t->getString . $self->readDigits('0-9',1))); }
  elsif( $t eq T_OTHER("\'")){		# Read Octal literal
    Number(oct($self->readDigits('0-7',1))); }
  elsif( $t eq T_OTHER("\"")){		# Read Hex literal
    Number(hex($self->readDigits('0-9A-F',1))); }
  elsif( $t eq T_OTHER("\`")){		# Read Charcode
    my $s = $self->readToken->getString;
    $s =~ s/^\\//;
    Number(ord($s)); } # Only a character token!!! NOT expanded!!!!
  else {
    $self->unread($t);
    $self->readInternalInteger; }}

sub readInternalInteger{ $_[0]->readRegisterValue('Number'); }
#======================================================================
# Dimensions
#======================================================================
# <dimen> = <optional signs><unsigned dimen>
# <unsigned dimen> = <normal dimen> | <coerced dimen>
# <coerced dimen> = <internal glue>
sub readDimension {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  if   (defined (my $d = $self->readInternalDimension)){ ($s < 0 ? $d->negate : $d); }
  elsif(defined (   $d = $self->readInternalGlue)     ){ Dimension($s * $d->getValue); }
  elsif(defined (   $d = $self->readFactor)           ){ Dimension($s * $d * $self->readUnit); }
  else{ SalvageError("Missing number, treated as zero.");        Dimension(0); }}

# <unit of measure> = <optional spaces><internal unit>
#     | <optional true><physical unit><one optional space>
# <internal unit> = em <one optional space> | ex <one optional space> 
#     | <internal integer> | <internal dimen> | <internal glue>
# <physical unit> = pt | pc | in | bp | cm | mm | dd | cc | sp

# Read a unit, returning the equivalent number of scaled points, 
sub readUnit {
  my($self)=@_;
  if(my $u=$self->readKeyword('ex','em')){ $self->skip1Space; $$self{stomach}->convertUnit($u);  }
  elsif($u=$self->readInternalInteger  ){ $u->getValue; } # These are coerced to number=>sp
  elsif($u=$self->readInternalDimension){ $u->getValue; }
  elsif($u=$self->readInternalGlue     ){ $u->getValue; }
  else {
    $self->readKeyword('true');	# But ignore, we're not bothering with mag...
    $u = $self->readKeyword('pt','pc','in','bp','cm','mm','dd','cc','sp');
    if($u){ $self->skip1Space; $$self{stomach}->convertUnit($u); }
    else  { SalvageError("Illegal unit of measure (pt inserted)."); 65536; }}}

# Return a dimension value or undef
sub readInternalDimension { $_[0]->readRegisterValue('Dimension'); }

#======================================================================
# Mu Dimensions
#======================================================================
# <mudimen> = <optional signs><unsigned mudimem>
# <unsigned mudimen> = <normal mudimen> | <coerced mudimen>
# <normal mudimen> = <factor><mu unit>
# <mu unit> = <optional spaces><internal muglue> | mu <one optional space>
# <coerced mudimen> = <internal muglue>
sub readMuDimension {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  if   (defined (my $m = $self->readFactor        )){ MuDimension($s * $m * $self->readMuUnit); }
  elsif(defined (   $m = $self->readInternalMuGlue)){ MuDimension($s * $m->getValue); }
  else{ SalvageError("Expecting mudimen; assuming 0 ");       MuDimension(0); }}

sub readMuUnit {
  my($self)=@_;
  if   (my $m=$self->readKeyword('mu')){ $self->skip1Space; $$self{stomach}->convertUnit($m); }
  elsif($m=$self->readInternalMuGlue  ){ $m->getValue; }
  else { SalvageError("Illegal unit of measure (mu inserted)."); $$self{stomach}->convertUnit('mu'); }}

#======================================================================
# Glue
#======================================================================
# <glue> = <optional signs><internal glue> | <dimen><stretch><shrink>
# <stretch> = plus <dimen> | plus <fil dimen> | <optional spaces>
# <shrink>  = minus <dimen> | minus <fil dimen> | <optional spaces>
sub readGlue {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  my $n;
  if(defined ($n = $self->readInternalGlue)){
    ($s < 0 ? $n->negate : $n); }
  else{
    my $d = $self->readDimension;
    if(!$d){
      SalvageError("Missing number, treated as zero."); return Glue(0); }
    $d = $d->negate if $s < 0;
    my($r1,$f1,$r2,$f2);
    ($r1,$f1) = $self->readRubber if $self->readKeyword('plus');
    ($r2,$f2)  = $self->readRubber if $self->readKeyword('minus');
    Glue($d->getValue*$s,$r1,$f1,$r2,$f2); }}

our %FILLS = (fil=>1,fill=>2,filll=>3);
sub readRubber {
  my($self,$mu)=@_;
  my $s = $self->readOptionalSigns;
  my $f = $self->readFactor;
  if(!defined $f){
    $f = ($mu ? $self->readMuDimension : $self->readDimension);
    ($f->getValue * $s, 0); }
  elsif(my $fil = $self->readKeyword('filll','fill','fil')){
    ($s*$f,$FILLS{$fil}); }
  elsif(defined(my $u = ($mu ? $self->readMuUnit : $self->readUnit))){
    ($s*$f*$u,0); }
  else {
    SalvageError("Illegal unit of measure (pt inserted).");
    ($s*$f*65536,0); }}

# Return a glue value or undef.
sub readInternalGlue { $_[0]->readRegisterValue('Glue'); }

#======================================================================
# Mu Glue
#======================================================================
# <muglue> = <optional signs><internal muglue> | <mudimen><mustretch><mushrink>
# <mustretch> = plus <mudimen> | plus <fil dimen> | <optional spaces>
# <mushrink> = minus <mudimen> | minus <fil dimen> | <optional spaces>
sub readMuGlue {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  my $n;
  if(defined ($n = $self->readInternalMuGlue)){
    ($s < 0 ? $n->negate : $n); }
  else{
    my $d = $self->readMuDimension;
    if(!$d){
      SalvageError("Missing number, treated as zero."); return MuGlue(0); }
    $d = $d->negate if $s < 0;
    my($r1,$f1,$r2,$f2);
    ($r1,$f1) = $self->readRubber(1) if $self->readKeyword('plus');
    ($r2,$f2)  = $self->readRubber(1) if $self->readKeyword('minus');
    MuGlue($d->getValue*$s,$r1,$f1,$r2,$f2); }}

# Return a muglue value or undef.
sub readInternalMuGlue { $_[0]->readRegisterValue('MuGlue'); }

#======================================================================
# See pp 272-275 for lists of the various registers.
# These are implemented in Primitive.pm

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Gullet

=head2 DESCRIPTION

LaTeXML::Gullet reads tokens (L<LaTeXML::Token>) from a L<LaTeXML::Mouth> 
and (possibly) expands them.  It also provides a variety of methods for reading 
various types of input such as arguments, optional arguments, Numbers, etc.

=head2 Methods for managing input streams

=over 4

=item C<< $stomach = $gullet->getStomach; >>

Return the Stomach that uses this $gullet.

=item C<< $gullet->openMouth($mouth); >>

Is this public? Prepares to read tokens from $mouth.

=item C<< $gullet->closeMouth; >>

Is this public? Finishes reading from the current mouth, and
reverts to the one in effect before the last openMouth.

=item C<< $gullet->flush; >>

Is this public? Clears all inputs.

=item C<< $gullet->getContext; >>

Returns a string describing the current location in the input stream.

=back

=head2 Low-level methods 

=over 4

=item C<< $tokens = $gullet->expandTokens($tokens); >>

Return a L<LaTeXML::Tokens> being the expansion of all the tokens in $tokens.
This is actually only used in a few circumstances where the arguments to
an expandable need explicit expansion; usually expansion happens at the right time.

=item C<< @tokens = $gullet->neutralizeTokens(@tokens); >>

Another unusual method: Used for things like \edef and token registers, to
inhibit further expansion of control sequences and proper spawning of register tokens.

=item C<< $token = $gullet->readToken; >>

Return the next token from the input source, or undef if there is no more input.

=item C<< $token = $gullet->readXToken($toplevel); >>

Return the next unexpandable token from the input source, or undef if there is no more input.
If the next token is expandable, it is expanded, and its expansion is reinserted into the input.

=item C<< $gullet->unread(@tokens); >>

Push the @tokens back into the input stream to be re-read.

=back

=head2 Medium-level methods. 

=over 4

=item C<< $token = $gullet->readNonSpace; >>

Read and return the next non-space token from the input, discarding any spaces.

=item C<< $gullet->skipSpaces; >>

Skip the next spaces from the input.

=item C<< $gullet->skip1Space; >>

Skip the next token from the input if it is a space.

=item C<< $tokens = $gullet->readBalanced; >>

Read a sequence of tokens from the input until the balancing '}' (assuming the '{' has
already been read). Returns a LaTeXML::Tokens.

=item C<< $boole = $gullet->ifNext($string,$catcode); >>

Returns true if the next token in the input matches the $string and/or $catcode.
(either can be undef, or $string can be a token).

=item C<< $tokens = $gullet->readMatch(@choices); >>

Read and return whichever of @choices (each should be a Tokens) matches the input, or undef
if none do.

=item C<< $keyword = $gullet->readKeyword(@keywords); >>

Read and return whichever of @keywords (each should be a string) matches the input, or undef
if none do.  This is similar to readMatch, but case and catcodes are ignored.
Also, leading spaces are skipped.

=item C<< $tokens = $gullet->readUntil(@delims); >>

Read and return a (balanced) sequence of Tokens until  matching one of the Tokens
in t @delims.  In a list context, it also returns which of the delimiters ended the sequence.

=back

=head2 Higher-level methods used for parsing control sequence arguments. 

=over 4

=item C<< $tokens = $gullet->readArg; >>

Read and return a TeX argument; the next Token or Tokens (if surrounded by braces).

=item C<< $tokens = $gullet->readOptional($default); >>

Read and return a LaTeX optional argument; returns $default if there is no '[',
otherwise the contents of the [].

=item C<< $tokens = $gullet->readSemiverbatim; >>

Read and return a TeX argument, but with catcodes reset so that most annoying
characters are treated as OTHER; useful for reading pathnames, URL's, etc.

=item C<< $thing = $gullet->readValue($type); >>

Reads an argument of a given type: one of 'Number', 'Dimension', 'Glue', 'MuGlue' or 'any'.

=item C<< $value = $gullet->readRegisterValue($type); >>

Read a control sequence token (and possibly it's arguments) that names a register,
and return the value.  Returns undef if the next token isn't such a register.

=item C<< $number = $gullet->readNumber; >>

Read a Number (LaTeXML::Number) according to TeX's rules of the various things that
can be used as a numerical value. 

=item C<< $dimension = $gullet->readDimension; >>

Read a Dimension (LaTeXML::Dimension) according to TeX's rules of the various things that
can be used as a dimension value.

=item C<< $mudimension = $gullet->readMuDimension; >>

Read a MuDimension (LaTeXML::MuDimension) according to TeX's rules of the various things that
can be used as a mudimension value.

=item C<< $glue = $gullet->readGlue; >>

Read a Glue (LaTeXML::Glue) according to TeX's rules of the various things that
can be used as a glue value.

=item C<< $muglue = $gullet->readMuGlue; >>

Read a MuGlue (LaTeXML::MuGlue) according to TeX's rules of the various things that
can be used as a muglue value.

=back
