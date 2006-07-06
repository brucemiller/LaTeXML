# /=====================================================================\ #
# |  LaTeXML::Parameters                                                | #
# | Representation of Parameters for Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Parameters;
use strict;
use LaTeXML::Object;
use LaTeXML::Global;
our @ISA = qw(Exporter LaTeXML::Object);
our @EXPORT = qw(parseParameters);

sub new {
  my($class,@paramspecs)=@_;
  bless [@paramspecs],$class; }

#**********************************************************************
# Parameter List & Arguments
#**********************************************************************
# You specify parameters to control sequences by providing a string containing
# a sequence of parameter specifiers.  For example:
#   "?*[]{any}" specifies the parameters of LaTeX's \section.
# The recognized parameter patterns are:
#   {any}    : A regular TeX argument: a single token or balanced {...}
#              But note that if followed by normal text (not one of the 
#              recognized parameter patterns), it acts as a delimited TeX argument.
#              The argument is a Tokens.
#   {Token}  : a single token
#   {XToken} : a single unexpandable token (expansion is done till we get one).
#   {semiverb}: like any, but w/catcodes restricted and filters disabled.
#              This is appropriate for pathnames, urls, etc.
#   {Number} : a number; tokens are expanded until a number is read.
#   {Dimension} : a dimension; tokens are expanded until a dimension is read.
#              The argument is a number representing scaled points (sp).
#   {Glue}   : A glue (a dimension with stretch and shrink)
#   {MuGlue} : A muglue (math glue)
#   ?chars    : Flag: Indicates chars are optional; the corresponding arg is 0 or 1
#             depending on whether the given chars were found or not.
#             [as set up, < can't be part of the chars !]
#   ??chars   : Ignorable (such as the ignorable "=" in \let<token>=<token>
#             The chars are read if present, but ignored; nothing is contributed to the arglist.
#   [default] : LaTeX style optional arg. If a [ is found, the arg is
#             the tokens until the following ].  Otherwise, the default,
#             if any, is returned, else "".
#   Otherwise : any other characters must match literally; nothing is contributed to the arglist.
#**********************************************************************
# Parsing a parameter list spec.
sub parseParameters {
  my($proto, $for)=@_;
  my $p = $proto;
  my @params=();
  while($p){
    my ($spec,$ispec,$open,$close,$opt);
    if   ($p =~ s/^((\{)([^\}]*)(\}))\s*//){ ($spec,$ispec,$open,$close,$opt)=($1,$3,$2,$4,0); }
    elsif($p =~ s/^((\[)([^\]]*)(\]))\s*//){ ($spec,$ispec,$open,$close,$opt)=($1,$3,$2,$4,1); }
    elsif($p =~ s/^([^\s]*)\s*//          ){ ($spec,$ispec,$open,$close,$opt)=($1,$1,'','',0); }
    else { Error("Unrecognized parameter specification at \"$proto\" for $for"); }
    $ispec =~ /^(\w*)(:([^\Q$close\E\s\{\[]*))?$/;
    my($type,$extra)=($1,$3);
    if($type eq 'Until'){
      push(@params, LaTeXML::Parameter->new(spec=>$spec, after=>Tokenize($extra))); }
    elsif($type =~ /^(Ignore|Flag|Literal|Keyword)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>'Match', before=>$open, after=>$close,
					   matches=>[map(Tokenize($_),split('\|',$extra))],
					   optional=>($type=~/^(Ignore|Flag)$/ ? 1:0),
					   noValue=>($type=~/^(Ignore|Literal)$/ ? 1:0))); }
    elsif($type eq 'KeyVal'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>'KeyVal', keyset=>$extra, 
					   before=>$open, after=>$close, optional=>$opt)); }
    elsif($type eq 'Default'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, default=>Tokenize($extra), 
					   before=>$open, after=>$close, optional=>$opt)); }
    elsif($type eq 'any'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, before=>$open, after=>$close, optional=>$opt)); }
    elsif($type eq ''){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, before=>$open, after=>$close, optional=>$opt)); }
    elsif($type eq 'semiverb'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, verbatim=>1,
					   before=>$open, after=>$close, optional=>$opt)); }
    elsif($type =~ /^(Token|XToken)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>$type,
					   before=>$open, after=>$close, optional=>$opt)); }
    elsif($type =~ /^(Number|Dimension|Glue|MuGlue)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>$type,
					   before=>$open, after=>$close, optional=>$opt, noDigest=>1)); }
    else {
      Error("Unknown parameter type \"$spec\" in \"$proto\" for $for"); }}
  LaTeXML::Parameters->new(@params); }

#======================================================================

sub stringify {
  my($self)=@_;
  join('',@$self); }

sub equals {
  my($self,$other)=@_;
  $self->stringify eq $other->stringify; }

sub untexArguments {
  my($self,@args)=@_;
  my $string = '';
  foreach my $spec (@$self){
    if($$spec{noValue}){ $string .= $$spec{matches}->[0]->untex; }
    elsif(defined(my $arg = shift(@args))){
      $string .= $$spec{before} if $$spec{before};
      $string .= $arg->untex;
      $string .= $$spec{after} if $$spec{after};
    }}
  $string; }

sub readArguments {
  my($self,$gullet)=@_;
  my @args=();
  foreach my $spec (@$self){
    my $value = $spec->readArgument($gullet);
    push(@args,$value) unless $$spec{noValue}; }
  @args; }


sub digestArguments {
  my($self,$stomach,@args)=@_;
  my @dargs=();
  foreach my $spec (@$self){
    if(!$$spec{noValue}){
      push(@dargs,$spec->digestArgument($stomach,shift(@args))); }}
  @dargs; }

#======================================================================
package LaTeXML::Parameter;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,%options)=@_;
  bless {%options}, $class; }

sub stringify {
  my($self)=@_;
  ($$self{open}||' ').$$self{spec}.($$self{close}||''); }
#  ($$self{open}||' ')
#    .$$self{spec}
#      .join(' ',map("$_=>$$self{$_}", grep($$self{$_}, keys %$self)))
#      .($$self{close}||''); }

sub readArgument {
  my($self,$gullet)=@_;
  my($before,$after)=($$self{before}||'',$$self{after}||'');
  $gullet->startSemiverbatim if $$self{verbatim};
  my $value;
  if(($$self{type}||'') eq 'KeyVal'){ # KeyVal get's special treatment.
    $value = $self->readKeyVal($gullet); }
  elsif($before || $after){	# If in braces, optional, or delimited, read tokens first
    if   ($before eq '{' ){ $value = $gullet->readArg; }
    elsif($before eq '[' ){ $value = $gullet->readOptional; }
    else                  { $value = $gullet->readUntil($after); }
    $value = $self->reparseArgument($gullet,$value) if $$self{type};
  }
  else {			# Else, just read primitive argument type.
    $value = $self->readArgumentAux($gullet); }
  $gullet->endSemiverbatim if $$self{verbatim};
  if($value)             { $value; }
  elsif($$self{default}) { $$self{default}; }
  elsif($$self{optional}){ undef; }
  else { Error("Missing argument $$self{spec}"); }}

sub reparseArgument {
  my($self,$gullet,$value)=@_;
  $gullet->openMouth($value);
  $value = $self->readArgumentAux($gullet);
  $gullet->skipSpaces;
  Error("Left over stuff in argument") if $gullet->readToken;
  $gullet->closeMouth; 
  $value; }

sub readArgumentAux {
  my($self,$gullet)=@_;
  my $type = $$self{type} || '';
  if   ($type eq 'Token'    ){ $gullet->readToken; }
  elsif($type eq 'XToken'   ){ $gullet->readXToken; }
  elsif($type eq 'Number'   ){ $gullet->readNumber; }
  elsif($type eq 'Dimension'){ $gullet->readDimension; }
  elsif($type eq 'Glue'     ){ $gullet->readGlue; }
  elsif($type eq 'MuGlue'   ){ $gullet->readMuGlue; }
  elsif($type eq 'Match'    ){ $gullet->readMatch(@{$$self{matches}}); }
  else { Error("Unknown argument type $$self{spec}"); }}

# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than parsing
# after the fact), since some values may have special catcode needs.
our $T_EQ = T_OTHER('=');
our $T_COMMA = T_OTHER(',');
sub readKeyVal {
  my($self,$gullet)=@_;
  my $keyset = $$self{keyset};
  my $stomach = $$gullet{stomach};
  my @kv=();
  # Read the opening delimiter.
  my $close;
  my $t=$gullet->readToken;
  if($$self{before} eq '{'){
    Error("Missing argument") unless $t->getCatcode == CC_BEGIN; 
    $close = T_END;}
  elsif($$self{before} eq '['){
    if(!($t eq T_OTHER('['))){ 
      $gullet->unread($t); return undef; }
    $close = T_OTHER(']'); }
  # Now start reading keyval pairs.
  while(1) {
    $gullet->skipSpaces; 
    # Read the keyword.
    my($ktoks,$delim)=$gullet->readUntil($T_EQ,$T_COMMA,$close);
    my $key=$ktoks->toString; $key=~s/\s//g;
    if($key){
      my $keydef=$stomach->getValue('KEYVAL@'.$keyset.'@'.$key) || {};
      my $value;
      if($delim eq $T_EQ){	# Got =, so read the value
	$gullet->startSemiverbatim if $$keydef{verbatim};
	($value,$delim)=$gullet->readUntil($T_COMMA,$close);
	$gullet->endSemiverbatim if $$keydef{verbatim};
	$value = $keydef->reparseArgument($gullet,$value) if $$keydef{type};
      }
      else {			# Else, get default value.
	$value = $stomach->getValue('KEYVAL@'.$keyset.'@'.$key.'@default'); }
      push(@kv,$key);
      push(@kv,$value); }
    last if $delim eq $close; }

  LaTeXML::KeyVals->new($keyset,@kv); }

sub digestArgument {
  my($self,$stomach,$arg)=@_;
  if($$self{noDigest}){ $arg; }
  elsif(!(ref $arg)){   $arg; }
  elsif(($$self{type} ||'') eq 'KeyVal'){
    $arg->digestValues($stomach); }
  else {
    $stomach->digest($arg,$$self{nofilter}); }}

#**********************************************************************
# KeyVals: representation of keyval arguments,
# Not necessarily a hash, since keys could be repeated and order may
# be significant.
#**********************************************************************
# Where does this really belong?
# The values can be Tokens, after parsing, or Boxes, after digestion.
# (or Numbers, etc. in either case)
# But also, it has a non-generic API used above...
# If Box-like, it could have a beAbsorbed method; which would do what?
# Should it convert to simple text? Or structure?
# If latter, there needs to be a key => tag mapping.

package LaTeXML::KeyVals;
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Object);

# Spec??
sub new {
  my($class,$keyset,@pairs)=@_;
  my %hash = ();
  my @pp=@pairs;
  while(@pp){
    my($k,$v) = (shift(@pp),shift(@pp));
    if(!defined $hash{$k}){ $hash{$k}=$v; }
    # Hmm, accumulate an ARRAY if multiple values for given key.
    # This is unlikely to be what the caller expects!! But what?
    elsif(ref $hash{$k} eq 'ARRAY'){ push(@{$hash{$k}},$v); }
    else { $hash{$k}=[$hash{$k},$v]; }}
  bless {keyset=>$keyset, keyvals=>[@pairs], hash=>{%hash}},$class; }

sub getValue {
  my($self,$key)=@_;
  $$self{hash}{$key}; }

sub getKeys {
  my($self)=@_;
  keys %{$$self{hash}}; }

sub getKeyVals {
  my($self)=@_;
  @{$$self{keyvals}}; }

sub digestValues {
  my($self,$stomach)=@_;
  my $keyset = $$self{keyset};
  my @kv=@{$$self{keyvals}};
  my @dkv=();
  while(@kv){
    my($key,$value)=(shift(@kv),shift(@kv));
    push(@dkv,$key); 
    my $keydef=$stomach->getValue('KEYVAL@'.$keyset.'@'.$key);
    if($keydef){
      push(@dkv,$keydef->digestArgument($stomach,$value)); }
    else {
      push(@dkv,$stomach->digest($value)); }}
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

#======================================================================
1;

