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
    my ($spec,$ispec,$open,$close);
    if   ($p =~ s/^((\{)([^\}]*)(\}))\s*//){ ($spec,$ispec,$open,$close)=($1,$3,$2,$4); }
    elsif($p =~ s/^((\[)([^\]]*)(\]))\s*//){ ($spec,$ispec,$open,$close)=($1,$3,$2,$4); }
    elsif($p =~ s/^([^\s]*)\s*//          ){ ($spec,$ispec,$open,$close)=($1,$1,'',''); }
    else { Error("Unrecognized parameter specification at \"$proto\" for $for"); }
    $ispec =~ /^(\w*)(:([^\Q$close\E\s\{\[]*))?$/;
    my($type,$extra)=($1,$3);
    if($type eq 'Until'){
      push(@params, LaTeXML::Parameter->new(spec=>$spec, after=>Tokenize($extra))); }
    elsif($type =~ /^(Ignore|Flag|Literal|Keyword)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>'Match', before=>$open, after=>$close,
					   matches=>[map(Tokenize($_),split('\|',$extra))],
					   allowmissing=>($type=~/^(Ignore|Flag)$/ ? 1:0),
					   novalue=>($type=~/^(Ignore|Literal)$/ ? 1:0))); }
    elsif($type eq 'KeyVal'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>'KeyVal', keyset=>$extra, 
					   before=>$open, after=>$close)); }
    elsif($type eq 'Default'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, default=>Tokenize($extra), 
					   before=>$open, after=>$close)); }
    elsif($type eq 'any'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, before=>$open, after=>$close)); }
    elsif($type eq ''){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, before=>$open, after=>$close)); }
    elsif($type eq 'semiverb'){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, verbatim=>1, before=>$open, after=>$close)); }
    elsif($type =~ /^(Token|XToken)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>$type, before=>$open, after=>$close)); }
    elsif($type =~ /^(Number|Dimension|Glue|MuGlue)$/){
      push(@params,LaTeXML::Parameter->new(spec=>$spec, type=>$type, before=>$open, after=>$close,
					   noDigest=>1)); }
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
    if($$spec{novalue}){ $string .= $$spec{matches}->[0]->untex; }
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
    push(@args,$value) unless $$spec{novalue}; }
  @args; }


sub digestArguments {
  my($self,$stomach,@args)=@_;
  my @dargs=();
  foreach my $spec (@$self){
    if(!$$spec{novalue}){
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

# verbatim ?
# Ignore|Flag|Literal|Keyword => readMatch??
sub readArgument {
  my($self,$gullet)=@_;
  my($before,$after)=($$self{before}||'',$$self{after}||'');
  my $verb = $$self{verbatim};
  my $allowmissing = $$self{allowmissing};
  if($verb){
    $$gullet{stomach}->bgroup(1);
    $$gullet{stomach}->setCatcode(CC_OTHER,'^','_','@','~','&','$','#','%'); } # should '%' too ?
  my $value;
  if($before || $after){
    my $tokens;
    if   ($before eq '{' ){ $tokens = $gullet->readArg; }
    elsif($before eq '[' ){ $tokens = $gullet->readOptional; $allowmissing=1;}
    else                  { $tokens = $gullet->readUntil($after); }
    if(!$$self{type}){ 
      $value = $tokens; }
    elsif($tokens){
      $gullet->openMouth($tokens);
      $value = $self->readArgumentAux($gullet);
      $gullet->skipSpaces;
      Error("Left over stuff in argument") if $gullet->readToken;
      $gullet->closeMouth; }}
  else {
    $value = $self->readArgumentAux($gullet); }
  if($verb){$$gullet{stomach}->egroup(1);}
  if($value){ $value; }
  elsif($$self{default}) { $$self{default}; }
  elsif($allowmissing){ undef; }
  else { Error("Missing argument $$self{spec}"); }}

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
  elsif($type eq 'KeyVal'   ){ $self->readKeyVal($gullet);}
  else { Error("Unknown argument type $$self{spec}"); }}

# Work in how default gets applied?
sub readKeyVal {
  my($self,$gullet)=@_;
  my $keyset = $$self{keyset};
  my $stomach = $$gullet{stomach};
#print STDERR "Reading keyvals for $keyset\n";
  my @kv=();
  $gullet->skipSpaces; 
  while(1){
    # Read balanced till comma or end of input.
    my @toks=();
    my ($key,$value);
    while(my $tok = $gullet->readToken){
      if($tok eq T_OTHER('=')){	# If got an =, the preceding is the key
	$key=Tokens(@toks)->toString; $key=~s/\s//g; @toks=(); }
      elsif($tok eq T_OTHER(',')){
	last; }
      else {
	push(@toks,$tok);
	if($tok->getCatcode == CC_BEGIN){ # And if it's a BEGIN, copy till balanced END
	  push(@toks,$gullet->readBalanced->unlist,T_END); }}}
    if($key){			# Got key, rest is value.
      $value = Tokens(@toks); 
      my $keydef=$stomach->getValue('KEYVAL@'.$keyset.'@'.$key);
      if($keydef && $$keydef{type}){
	$gullet->openMouth($value);
#	$value = $keydef->readArgumentAux($gullet);
	$value = $keydef->readArgument($gullet);
	$gullet->closeMouth; }}
    elsif(@toks){		# No =, so @toks is key, and use default.
      $key=Tokens(@toks)->toString; $key=~s/\s//g; 
      if(my $keydef=$stomach->getValue('KEYVAL@'.$keyset.'@'.$key.'@default')){
	$value=$keydef; }}
    else {			# Nothing found.
      last; }
#print STDERR "Read Keyval $keyset : $key->$value\n";
    push(@kv,$key);
    push(@kv,$value); 
    $gullet->skipSpaces; }
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
# Where does this really belong?
# It's only a special representation of something that can only appear
# as a control sequence argument.

package LaTeXML::KeyVals;
use LaTeXML::Global;
our @ISA=qw(LaTeXML::Object);

# Spec??
sub new {
  my($class,$keyset,@pairs)=@_;
  bless {keyset=>$keyset, keyvals=>[@pairs]},$class; }

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

