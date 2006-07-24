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
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Object);
#**********************************************************************
sub new {
  my($class)=@_;
  bless {mouth=>undef, mouthstack=>[], pushback=>[], autoclose=>1, pending_comments=>[]
	}, $class; }

#**********************************************************************
# Hmm, we should record in the output which files were included/required/etc.
# This is for the benefit of anything wanting to interpret the Math/TeX ???
# In which case, *.tex files that are included should probably be ignored
# (they're output will already be incorporated),
# But *.sty, *.cls etc, (or the *.pm equivalents) should be noted.
# However, if things are included via some other `package', presumably
# that package will be responsible for loading those extra pacakges, so
# they should be ignored too, right?
# NOTE: options from usepackage, etc, get carried to here.
# For latexml implementations, the global $LaTeXML::PACKAGE_OPTIONS gets 
# bound to them, but NOTHING is done to pass them to TeX style files!

# HMM: the packageLoaded check only makes sense for style files, and
# is probably only important for latexml implementations?
sub input {
  my($self,$name,$types,%options)=@_;
  $name = $name->toString if ref $name;
  # Try to find a Package implementing $name.
  local @LaTeXML::PACKAGE_OPTIONS = @{$options{options}||[]};
  $name = $1 if $name =~ /^\{(.*)\}$/; # just in case
  my $file = pathname_find($name,paths=>$STATE->lookupValue('SEARCHPATHS'),
			   types=>$types, installation_subdir=>'Package');
  if(! $file) {
    Error("Cannot find file $name of type ".join(', ',@{$types||[]})
	  ." in paths ".join(', ',@{$STATE->lookupValue('SEARCHPATHS')})); }
  elsif($file =~ /\.(ltxml|latexml)$/){		# Perl module.
    return if $STATE->lookupValue($file.'_loaded');
    $STATE->assignValue($file.'_loaded'=>1,'global');
    my($dir,$modname)=pathname_split($file);
    $self->openMouth(LaTeXML::PerlMouth->new($file),0);
    my $pmouth = $$self{mouth};
    do $file; 
    Fatal("Package $name had an error:\n  $@") if $@; 
    $self->closeMouth if $pmouth eq $$self{mouth}; # Close immediately, unless recursive input
  }
  elsif($file =~ /\.(sty|cls)$/){	# (attempt to) interpret a style file.
    return if $STATE->lookupValue($file.'_loaded');
    $STATE->assignValue($file.'_loaded'=>1,'global');
    $self->openMouth(LaTeXML::StyleMouth->new($file), 0);  }
  else {			# Else read as an included file.
    $self->openMouth(LaTeXML::FileMouth->new($file) ,0);  
    # AND if there are file-specific declarations, deal with those first!
    $file =~ s/\.tex//;
    if(my $conf = pathname_find("$file.latexml",paths=>$STATE->lookupValue('SEARCHPATHS'))){
      $self->input($conf); }
  }}

#**********************************************************************
# Start reading tokens from a new Mouth.
# This pushes the mouth as the current source that $gullet->readToken (etc) will read from.
# Once this Mouth has been exhausted, readToken, etc, will return undef,
# until you call $gullet->closeMouth to clear the source.
# Exception: if $toplevel=1, readXToken will step to next source
# Note that a Tokens can act as a Mouth.
sub openMouth {
  my($self,$mouth,$noautoclose)=@_;
  return unless $mouth;
  unshift(@{$$self{mouthstack}},[$$self{mouth},$$self{pushback},$$self{autoclose}]) if $$self{mouth};
  $$self{mouth}=$mouth; 
  $$self{pushback}=[];
  $$self{autoclose}=!$noautoclose; }

sub closeMouth {
  my($self,$forced)=@_;
  if(!$forced && (@{$$self{pushback}} || $$self{mouth}->hasMoreInput)){
    Error("Closing mouth with input remaining: ".Stringify($self->readToken)); }
  $$self{mouth}->finish;
  if(@{$$self{mouthstack}}){
    ($$self{mouth},$$self{pushback},$$self{autoclose}) = @{ shift(@{$$self{mouthstack}}) }; }
  else {
    $$self{pushback}=[];
    $$self{mouth}=Tokens(); 
    $$self{autoclose}=1; }}

sub getMouth { $_[0]->{mouth}; }
# Obscure, but the only way I can think of to End!! (see \bye or \end{document})
# Flush all sources (close all pending mouth's)
sub flush {
  my($self)=@_;
  $$self{mouth}->finish;
  foreach my $entry (@{$$self{mouthstack}}){
    $entry->[0]->finish; }
  $$self{pushback}=[];
  $$self{mouth}=Tokens();
  $$self{autoclose}=1;
  $$self{mouthstack}=[]; }


# User feedback for where something (error?) occurred.
sub getLocator {
  my($self,$long)=@_;
  my $loc = (defined $$self{mouth} ? $$self{mouth}->getLocator($long) : '');
  if(!$loc || $long){
    my($mouth,$pb)=($$self{mouth},$$self{pushback});
    $loc .= "\n  To be read again ".ToString(Tokens(@$pb)) if $long && @$pb;
    foreach my $frame ( @{$$self{mouthstack}} ){
      my($mouth,$pb)= @$frame;
      my $ml = $mouth->getLocator($long);
      $loc .= ' '.$ml if $ml;
      last if $loc && !$long;
      $loc .= "\n  To be read again ".ToString(Tokens(@$pb)) if $long && @$pb;
    }}
  $loc; }

#**********************************************************************
# Return $tokens with all tokens expanded
sub expandTokens {
  my($self,$tokens)=@_;
  $self->openMouth((ref $tokens eq 'LaTeXML::Token' ? Tokens($tokens) : $tokens->clone),1);
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
  my @result=();
  foreach my $t (@tokens){
    if($t->getCatcode == CC_PARAM){
      push(@result,$t); }
    elsif(defined(my $defn=$STATE->lookupDefinition($t))){
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
  my $token = shift(@{$$self{pushback}});
  return $token if defined $token;
  while(defined($token = $$self{mouth}->readToken()) && ($$token[1] == CC_COMMENT)){ # NOTE: Inlined ->getCatcode
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
####$toplevel=1;
  return shift(@{$$self{pending_comments}}) if $toplevel && @{$$self{pending_comments}};
  my($token,$cc,$defn);
  while(1){
    if(!defined($token = (@{$$self{pushback}} ? shift(@{$$self{pushback}}) : $$self{mouth}->readToken() ))){
      return undef unless $$self{autoclose} && $toplevel && @{$$self{mouthstack}};

#      print STDERR "Closing ".Stringify($$self{mouth})."\n ".LaTeXML::Error::stacktrace()."\n";

      $self->closeMouth; }		# Next input stream.
    elsif(($cc = $$token[1]) == CC_NOTEXPANDED){ # NOTE: Inlined ->getCatcode
      # Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
      # so this token should never leak out through an EXTERNAL call to readToken.
      return $self->readToken; } # Just return the next token.
    elsif($cc == CC_COMMENT){
      return $token if $toplevel;
      push(@{$$self{pending_comments}},$token); } # What to do with comments???
    elsif(defined($defn=$STATE->lookupDefinition($token)) && $defn->isExpandable){
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
  my($self,$token)=@_;
  if(my $tok=$self->readToken()){
    $self->unread($tok);
    $tok->equals($token); }
  else { 0; }}

# Match the input against one of the Token or Tokens in @choices; return the matching one or undef.
sub readMatch {
  my($self,@choices)=@_;
  foreach my $choice (@choices){
    my @tomatch=$choice->unlist;
    my @matched=();
    my $tok;
    while(@tomatch && defined($tok=$self->readToken)
	  && push(@matched,$tok) && ($tok->equals($tomatch[0]))){
      shift(@tomatch);
      if($tok->getCatcode == CC_SPACE){ # If this was space, SKIP any following!!!
	while(defined($tok=$self->readToken) && ($tok->getCatcode == CC_SPACE)){
	  push(@matched,$tok); }
	$self->unread($tok) if $tok; }
    }
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
    $keyword = $keyword->toString if ref $keyword;
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
  elsif(($tok->equals(T_OTHER('[')))){
    $self->readUntil(T_OTHER(']')); }
  else {
    $self->unread($tok);
    $default; }}

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
  my $defn = $STATE->lookupDefinition($token);
  if((defined $defn) && ($defn->isRegister eq $type)){
    $defn->valueOf($defn->readArguments($self)); }
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
	&& (($t->getString eq '+') || ($t->getString eq '-') || ($t->equals(T_SPACE)))){
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
  if($token && $token->getString =~ /^[\.\,]$/){
    $string .= '.'.$self->readDigits('0-9'); 
    $token = $self->readXToken; }
  if(length($string)>0){
    $self->unread($token) if $token && $token->getCatcode!=CC_SPACE;
    $string; }
  else {
    $self->unread($token);
    my $n = $self->readNormalInteger;
    (defined $n ? $n->valueOf : undef); }}

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
  elsif(defined (   $n = $self->readInternalDimension)){ Number($s * $n->valueOf); }
  elsif(defined (   $n = $self->readInternalGlue     )){ Number($s * $n->valueOf); }
  else{ Warn("Missing number, treated as zero.");        Number(0); }}

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
  elsif( $t->equals(T_OTHER("\'"))){		# Read Octal literal
    Number(oct($self->readDigits('0-7',1))); }
  elsif( $t->equals(T_OTHER("\""))){		# Read Hex literal
    Number(hex($self->readDigits('0-9A-F',1))); }
  elsif( $t->equals(T_OTHER("\`"))){		# Read Charcode
    my $s = $self->readToken->getString;
    $s =~ s/^\\//;
    Number(ord($s)); } # Only a character token!!! NOT expanded!!!!
  else {
    $self->unread($t);
    $self->readInternalInteger; }}

sub readInternalInteger{ $_[0]->readRegisterValue('Number'); }

#======================================================================
# Float, a floating point number.
# Similar to factor, but does NOT accept comma!
# This is NOT part of TeX, but is convenient.
sub readFloat {
  my($self)=@_;
  my $s = $self->readOptionalSigns;
  my $string = $self->readDigits('0-9');
  my $token = $self->readXToken;
  if($token && $token->getString =~ /^[\.]$/){
    $string .= '.'.$self->readDigits('0-9'); 
    $token = $self->readXToken; }
  my $n;
  if(length($string)>0){
    $self->unread($token) if $token && $token->getCatcode!=CC_SPACE;
    $n = $string; }
  else {
    $self->unread($token);
    $n = $self->readNormalInteger;
    $n = $n->valueOf if defined $n; }
  (defined $n ? Float($s*$n) : undef); }

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
  elsif(defined (   $d = $self->readInternalGlue)     ){ Dimension($s * $d->valueOf); }
  elsif(defined (   $d = $self->readFactor)           ){ 
    my $unit = $self->readUnit;
    if(!defined $unit){
      Warn("Illegal unit of measure (pt inserted).");
      $unit = 65536; }
    Dimension($s * $d * $unit); }
  else{ Warn("Missing number, treated as zero.");        Dimension(0); }}

# <unit of measure> = <optional spaces><internal unit>
#     | <optional true><physical unit><one optional space>
# <internal unit> = em <one optional space> | ex <one optional space> 
#     | <internal integer> | <internal dimen> | <internal glue>
# <physical unit> = pt | pc | in | bp | cm | mm | dd | cc | sp

# Read a unit, returning the equivalent number of scaled points, 
sub readUnit {
  my($self)=@_;
  if(defined(my $u=$self->readKeyword('ex','em'))){ $self->skip1Space; $STATE->convertUnit($u);  }
  elsif(defined($u=$self->readInternalInteger  )){ $u->valueOf; } # These are coerced to number=>sp
  elsif(defined($u=$self->readInternalDimension)){ $u->valueOf; }
  elsif(defined($u=$self->readInternalGlue     )){ $u->valueOf; }
  else {
    $self->readKeyword('true');	# But ignore, we're not bothering with mag...
    $u = $self->readKeyword('pt','pc','in','bp','cm','mm','dd','cc','sp');
    if($u){ $self->skip1Space; $STATE->convertUnit($u); }
    else  { undef; }}}

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
  if   (defined (my $m = $self->readFactor        )){
    my $munit = $self->readMuUnit;
    if(!defined $munit){
      Warn("Illegal unit of measure (mu inserted).");
      $munit = $STATE->convertUnit('mu'); }
    MuDimension($s * $m * $munit); }
  elsif(defined (   $m = $self->readInternalMuGlue)){ MuDimension($s * $m->valueOf); }
  else{ Warn("Expecting mudimen; assuming 0 ");       MuDimension(0); }}

sub readMuUnit {
  my($self)=@_;
  if   (my $m=$self->readKeyword('mu')){ $self->skip1Space; $STATE->convertUnit($m); }
  elsif($m=$self->readInternalMuGlue  ){ $m->valueOf; }
  else { undef; }}

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
      Warn("Missing number, treated as zero."); return Glue(0); }
    $d = $d->negate if $s < 0;
    my($r1,$f1,$r2,$f2);
    ($r1,$f1) = $self->readRubber if $self->readKeyword('plus');
    ($r2,$f2)  = $self->readRubber if $self->readKeyword('minus');
    Glue($d->valueOf*$s,$r1,$f1,$r2,$f2); }}

our %FILLS = (fil=>1,fill=>2,filll=>3);
sub readRubber {
  my($self,$mu)=@_;
  my $s = $self->readOptionalSigns;
  my $f = $self->readFactor;
  if(!defined $f){
    $f = ($mu ? $self->readMuDimension : $self->readDimension);
    ($f->valueOf * $s, 0); }
  elsif(defined(my $fil = $self->readKeyword('filll','fill','fil'))){
    ($s*$f,$FILLS{$fil}); }
  elsif($mu){
    my $u = $self->readMuUnit;
    if(!defined $u){
      Warn("Illegal unit of measure (mu inserted).");
      $u = $STATE->convertUnit('mu'); }
    ($s*$f*$u,0); }
  else {
    my $u = $self->readUnit;
    if(!defined $u){
      Warn("Illegal unit of measure (pt inserted).");
      $u = 65536; }
    ($s*$f*$u,0); }}

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
      Warn("Missing number, treated as zero."); return MuGlue(0); }
    $d = $d->negate if $s < 0;
    my($r1,$f1,$r2,$f2);
    ($r1,$f1) = $self->readRubber(1) if $self->readKeyword('plus');
    ($r2,$f2)  = $self->readRubber(1) if $self->readKeyword('minus');
    MuGlue($d->valueOf*$s,$r1,$f1,$r2,$f2); }}

# Return a muglue value or undef.
sub readInternalMuGlue { $_[0]->readRegisterValue('MuGlue'); }

#======================================================================
# See pp 272-275 for lists of the various registers.
# These are implemented in Primitive.pm

#**********************************************************************
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::Gullet> -- expands expandable tokens and parses common token sequences.

=head1 DESCRIPTION

The C<LaTeXML::Gullet> reads tokens (L<LaTeXML::Token>) from a L<LaTeXML::Mouth>.
It is responsible for expanding macros and expandable control sequences,
if the current definition associated with the token in the L<LaTeXML::State>
is an L<LaTeXML::Expandable> definition. The C<LaTeXML::Gullet> also provides a
variety of methods for reading  various types of input such as arguments, optional arguments,
as well as for parsing L<LaTeXML::Number>, L<LaTeXML::Dimension>, etc, according
to TeX's rules.

=head2 Managing Input

=over 4

=item C<< $gullet->input($name,$types,%options); >>

Input the file named C<$name>; Searches for matching files in the
current C<searchpath> with an extension being one of  C<$types> (an array
of strings). If the found file has a perl extension (pm, ltxml, or latexml), 
it will be executed (loaded).  If the found file has a TeX extension
(tex, sty, cls) it will be opened and latexml will prepare to read
from it.

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

Return a L<LaTeXML::Tokens> being the expansion of all the tokens in C<$tokens>.
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

Push the C<@tokens> back into the input stream to be re-read.

=back

=head2 Mid-level methods

=over 4

=item C<< $token = $gullet->readNonSpace; >>

Read and return the next non-space token from the input, discarding any spaces.

=item C<< $gullet->skipSpaces; >>

Skip the next spaces from the input.

=item C<< $gullet->skip1Space; >>

Skip the next token from the input if it is a space.

=item C<< $tokens = $gullet->readBalanced; >>

Read a sequence of tokens from the input until the balancing '}' (assuming the '{' has
already been read). Returns a L<LaTeXML::Tokens>.

=item C<< $boole = $gullet->ifNext($token); >>

Returns true if the next token in the input matches C<$token>;
the possibly matching token remains in the input.

=item C<< $tokens = $gullet->readMatch(@choices); >>

Read and return whichever of C<@choices> (each should be a L<LaTeXML::Tokens>)
matches the input, or undef if none do.

=item C<< $keyword = $gullet->readKeyword(@keywords); >>

Read and return whichever of C<@keywords> (each should be a string) matches the input, or undef
if none do.  This is similar to readMatch, but case and catcodes are ignored.
Also, leading spaces are skipped.

=item C<< $tokens = $gullet->readUntil(@delims); >>

Read and return a (balanced) sequence of L<LaTeXML::Tokens> until  matching one of the tokens
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

Read a L<LaTeXML::Number> according to TeX's rules of the various things that
can be used as a numerical value. 

=item C<< $dimension = $gullet->readDimension; >>

Read a L<LaTeXML::Dimension> according to TeX's rules of the various things that
can be used as a dimension value.

=item C<< $mudimension = $gullet->readMuDimension; >>

Read a L<LaTeXML::MuDimension> according to TeX's rules of the various things that
can be used as a mudimension value.

=item C<< $glue = $gullet->readGlue; >>

Read a  L<LaTeXML::Glue> according to TeX's rules of the various things that
can be used as a glue value.

=item C<< $muglue = $gullet->readMuGlue; >>

Read a L<LaTeXML::MuGlue> according to TeX's rules of the various things that
can be used as a muglue value.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

