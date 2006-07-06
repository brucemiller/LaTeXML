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
    else { Fatal("Unrecognized parameter specification at \"$proto\" for $for"); }
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
      Fatal("Unknown parameter type \"$spec\" in \"$proto\" for $for"); }}
  LaTeXML::Parameters->new(@params); }

#======================================================================

sub getParameters { @{$_[0]}; }

sub getNArgs {
  my($self)=@_;
  scalar(grep(!$$_{noValue}, @{$self})); }

sub stringify {
  my($self)=@_;
  my $string='';
  foreach my $parm (@$self){
    my $s = $parm->stringify;
    $string .= ' ' if ($string =~/\w$/)&&($s =~/^\w/);
    $string .= $s; }
  $string; }

sub equals {
  my($self,$other)=@_;
  (defined $other) && ((ref $self) eq (ref $other)) && ($self->stringify eq $other->stringify); }

sub untexArguments {
  my($self,@args)=@_;
  my $string = '';
  foreach my $spec (@$self){
    if($$spec{noValue}){ $string .= $$spec{matches}->[0]->untex; }
    elsif(defined(my $arg = shift(@args))){
      if(my $before = $$spec{before}){
	$string .= (ref $before ? $before->untex : $before); }
      $string .= $arg->untex;
      if(my $after = $$spec{after}){
	$string .= (ref $after ? $after->untex : $after); }
    }}
  $string; }

sub invocationArguments {
  my($self,@args)=@_;
  my @tokens = ();
  foreach my $spec (@$self){
    if($$spec{noValue}){ push(@tokens, $$spec{matches}->[0]->unlist); }
    elsif(defined(my $arg = shift(@args))){
      my($b,$a)=($$spec{before},$$spec{after});
      push(@tokens,($b eq '{' ? T_BEGIN : T_OTHER($b))) if $b;
      push(@tokens, $arg->unlist);
      push(@tokens,($a eq '}' ? T_END : T_OTHER($a))) if $a;
    }}
  @tokens; }

sub readArguments {
  my($self)=@_;
  my @args=();
  foreach my $spec (@$self){
    my $value = $spec->readArgument;
    push(@args,$value) unless $$spec{noValue}; }
  @args; }


sub digestArguments {
  my($self,@args)=@_;
  my @dargs=();
  foreach my $spec (@$self){
    if(!$$spec{noValue}){
      push(@dargs,$spec->digestArgument(shift(@args))); }}
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
  ($$self{open}||'').$$self{spec}.($$self{close}||''); }

sub readArgument {
  my($self)=@_;
  my($before,$after)=($$self{before}||'',$$self{after}||'');
  $GULLET->startSemiverbatim if $$self{verbatim};
  my $value;
  if(($$self{type}||'') eq 'KeyVal'){ # KeyVal get's special treatment.
    $value = $self->readKeyVal; }
  elsif($before || $after){	# If in braces, optional, or delimited, read tokens first
    if   ($before eq '{' ){ $value = $GULLET->readArg; }
    elsif($before eq '[' ){ $value = $GULLET->readOptional; }
    else                  { $value = $GULLET->readUntil($after); }
    $value = $self->reparseArgument($value) if $$self{type};
  }
  else {			# Else, just read primitive argument type.
    $value = $self->readArgumentAux; }
  $GULLET->endSemiverbatim if $$self{verbatim};
  if($value)             { $value; }
  elsif($$self{default}) { $$self{default}; }
  elsif($$self{optional}){ undef; }
  else { Fatal("Missing argument $$self{spec}"); }}

sub reparseArgument {
  my($self,$value)=@_;
  $GULLET->openMouth($value);
  $value = $self->readArgumentAux;
  $GULLET->skipSpaces;
  Fatal("Left over stuff in argument") if $GULLET->readToken;
  $GULLET->closeMouth; 
  $value; }

sub readArgumentAux {
  my($self)=@_;
  my $type = $$self{type} || '';
  if   ($type eq 'Token'    ){ $GULLET->readToken; }
  elsif($type eq 'XToken'   ){ $GULLET->readXToken; }
  elsif($type eq 'Number'   ){ $GULLET->readNumber; }
  elsif($type eq 'Dimension'){ $GULLET->readDimension; }
  elsif($type eq 'Glue'     ){ $GULLET->readGlue; }
  elsif($type eq 'MuGlue'   ){ $GULLET->readMuGlue; }
  elsif($type eq 'Match'    ){ $GULLET->readMatch(@{$$self{matches}}); }
  else { Fatal("Unknown argument type $$self{spec}"); }}

# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than parsing
# after the fact), since some values may have special catcode needs.
our $T_EQ = T_OTHER('=');
our $T_COMMA = T_OTHER(',');
sub readKeyVal {
  my($self)=@_;
  my $keyset = $$self{keyset};
  my @kv=();
  # Read the opening delimiter.
  my $close;
  my $t=$GULLET->readToken;
  if($$self{before} eq '{'){
    Fatal("Missing argument") unless $t->getCatcode == CC_BEGIN; 
    $close = T_END;}
  elsif($$self{before} eq '['){
    if(!($t->equals(T_OTHER('[')))){ 
      $GULLET->unread($t); return undef; }
    $close = T_OTHER(']'); }
  # Now start reading keyval pairs.
  while(1) {
    $GULLET->skipSpaces; 
    # Read the keyword.
    my($ktoks,$delim)=$GULLET->readUntil($T_EQ,$T_COMMA,$close);
#    my $key= $ktoks && $ktoks->toString; $key=~s/\s//g if $key;
Fatal("What's up?") unless $ktoks;
    my $key= $ktoks->toString; $key=~s/\s//g;
    if($key){
      my $keydef=$STATE->lookup('value','KEYVAL@'.$keyset.'@'.$key) || {};
      my $value;
      if($delim->equals($T_EQ)){	# Got =, so read the value
	$GULLET->startSemiverbatim if $$keydef{verbatim};
	($value,$delim)=$GULLET->readUntil($T_COMMA,$close);
	$GULLET->endSemiverbatim if $$keydef{verbatim};
	$value = $keydef->reparseArgument($value) if $$keydef{type};
      }
      else {			# Else, get default value.
	$value = $STATE->lookup('value','KEYVAL@'.$keyset.'@'.$key.'@default'); }
      push(@kv,$key);
      push(@kv,$value); }
    last if $delim->equals($close); }

  LaTeXML::KeyVals->new($keyset,@kv); }

sub digestArgument {
  my($self,$arg)=@_;
  if($$self{noDigest}){ $arg; }
  elsif(!(ref $arg)){   $arg; }
  elsif(($$self{type} ||'') eq 'KeyVal'){
    $arg->digestValues; }
  else {
    $STOMACH->digest($arg,$$self{nofilter}); }}

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

sub getStringValue {
  my($self,$key)=@_;
  if(defined(my $value = $$self{hash}{$key})){
    $value->toString; }}

sub getKeys {
  my($self)=@_;
  keys %{$$self{hash}}; }

sub getKeyVals {
  my($self)=@_;
  @{$$self{keyvals}}; }

sub digestValues {
  my($self)=@_;
  my $keyset = $$self{keyset};
  my @kv=@{$$self{keyvals}};
  my @dkv=();
  while(@kv){
    my($key,$value)=(shift(@kv),shift(@kv));
    push(@dkv,$key); 
    my $keydef=$STATE->lookup('value','KEYVAL@'.$keyset.'@'.$key);
    if($keydef){
      push(@dkv,$keydef->digestArgument($value)); }
    else {
      push(@dkv,$STOMACH->digest($value)); }}
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

__END__

=pod 

=head1 LaTeXML::Parameters, LaTeXML::Parameter, LaTeXML::KeyVal

=head2 DESCRIPTION

Provides a representation for the parameter lists of L<LaTeXML::Definition>s.
C<LaTeXML::Parameters> represents the complete parameter list, 
C<LaTeXML::Parameter> represents a single parameter,
C<LaTeXML::KeyVal> represents parameters handled by LaTeX's keyval package.

=head2 Parameters Methods

=over 4

=item C<< $parameters = parseParameters($prototype,$for); >>

B<This needs documenting!>

=item C<< @parameters = $parameters->getParameters; >>

Return the list of C<LaTeXML::Parameter> containin in C<$parameters>.

=item C<< $string = $parameters->untexArguments(@args); >>

Return the string representing the TeX form that the given C<@args>
would have needed to be in order to be recognized as the correct 
parameter sequence.  This takes into acount optional arguments,
TeX delimited parameters and so fort.

=item C<< @tokens = $parameters->invocationArguments(@args); >>

Return a list of L<LaTeXML::Token> that would represent the arguments
such that they can be parsed by the Gullet.

=item C<< @args = $parameters->readArguments; >>

Read the arguments according to this C<$parameters> from the current C<$GULLET>.
This takes into account any special forms of arguments, such as optional,
delimited, etc.

=item C<< @args = digestArguments(@args); >>

Digests the arguments according to C<$parameters> using the current C<$STOMACH>.

=back

=head2 Parameter Methods

=over 4

=item C<< $parameter->readArgument; >>

Read the appropriate data from the current C<$GULLET> according to C<$parameter>.

=back

=head2 KeyVal Methods

=over 4

=item C<< $value = $keyval->getValue($key); >>

Return the value associated with C<$key> in the C<$keyval>.

=item C<< $value = $keyval->getStringValue($key); >>

Return the value, converted to a string, associated with C<$key> in the C<$keyval>.

=item C<< @keys = $keyval->getKeys; >>

Return the keys that have values bound in the C<$keyval>.

=item C<< @keyvals = $keyval->getKeyVals; >>

Return the alternating keys and values bound in the C<$keyval>.

=item C<< $keyval->digestValues; >>

Return a new C<LaTeXML::KeyVals> object with all values digested as appropriate.

=back

=cut
