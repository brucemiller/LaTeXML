# /=====================================================================\ #
# |  LaTeXML::Definition                                                | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
#   When they're evaluated:
#     expandible : in Gullet
#     primitive  : in Stomach
#     constructor: in Intestine
#  What happens:
#     replacement or code ???
# Note, I've got all sorts of letters defined in LaTeX.pm in order to
# specify thier math properties.
# But, of course, catcodes can change and A can be made a macro.
# So, it aint really the right place to put this info.
# Distinguish these things!!

# Maybe a Char definition ??
# (there's a whole mess of parameters that go with chars too....)
#**********************************************************************

#**********************************************************************
package LaTeXML::Definition;
use strict;
use LaTeXML::Error;
use LaTeXML::Token;
use Exporter;
use LaTeXML::Object;
our @ISA = qw(Exporter LaTeXML::Object);
our @EXPORT = qw(parsePrototype);

#**********************************************************************
our %definition_options=map(($_=>1),qw(parameters
				       isPrefix isConditional

				       parameterType readonly chardef getter setter
				       beforeDigest afterDigest
				       mode
				       mathConstructor untex
				       floats mathclass
				       captureBody));

sub new {
  my($class,$cs,$paramlist,$replacement,@plist)=@_;
  my %properties=@plist;
  my @unknown = grep( ! $definition_options{$_}, keys %properties);
  Warn("Definition for $cs, unknown options: ".join(', ',@unknown)) if @unknown;
  $cs = $cs->getString if ref $cs;
  my $self={cs=>$cs, parameters=>($paramlist || []), replacement=>$replacement, %properties};
  bless $self,$class; 
  $$self{parameterType}='' unless $$self{parameterType};
  $$self{beforeDigest} =[] unless $$self{beforeDigest};
  $$self{afterDigest}  =[] unless $$self{afterDigest};
  Message("Defining $cs".$self->showParameters()) if Debugging('macros');
  $self; }

sub getCS         { $_[0]->{cs}; }
sub isExecutable  { 1; }
sub isExpandable  { 0; }
sub isParameter   { ''; }
sub isPrefix      { 0; }

sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.$$self{cs}.']'; }

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

#======================================================================
# Parsing a parameter list spec.
sub parsePrototype {
  my($proto)=@_;
  my $p = $proto;
  $p =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Error("Definition prototype doesn't have proper control sequence: $proto") if @junk;
  $p =~ s/^\s*//;
  my @params=();
  while($p){
    my ($spec,$ispec,$open,$close);
    if   ($p =~ s/^((\{)([^\}]*)(\}))\s*//){ ($spec,$ispec,$open,$close)=($1,$3,$2,$4); }
    elsif($p =~ s/^((\[)([^\]]*)(\]))\s*//){ ($spec,$ispec,$open,$close)=($1,$3,$2,$4); }
    elsif($p =~ s/^([^\s]*)\s*//          ){ ($spec,$ispec,$open,$close)=($1,$1,'',''); }
    else { Error("Unrecognized parameter specification at \"$proto\" for $cs"); }
    $ispec =~ /^(\w*)(:([^\Q$close\E\s\{\[]*))?$/;
    my($type,$extra)=($1,$3);
    if($type eq 'Until'){
      push(@params,{ spec=>$spec, after=>Tokenize($extra)}); }
    elsif($type =~ /^(Ignore|Flag|Literal|Keyword)$/){
      push(@params,{ spec=>$spec, type=>'Match', before=>$open, after=>$close,
		     matches=>[map(Tokenize($_),split('\|',$extra))],
		     allowmissing=>($type=~/^(Ignore|Flag)$/ ? 1:0),
		     novalue=>($type=~/^(Ignore|Literal)$/ ? 1:0)}); }
    elsif($type eq 'KeyVal'){
      push(@params,{ spec=>$spec, type=>'KeyVal', keyset=>$extra, before=>$open, after=>$close}); }
    elsif($type eq 'Default'){
      push(@params,{ spec=>$spec, default=>Tokenize($extra), before=>$open, after=>$close}); }
    elsif($type eq 'any'){
      push(@params,{ spec=>$spec, before=>$open, after=>$close}); }
    elsif($type eq ''){
      push(@params,{ spec=>$spec, before=>$open, after=>$close}); }
    elsif($type eq 'semiverb'){
      push(@params,{ spec=>$spec, verbatim=>1, before=>$open, after=>$close}); }
    elsif($type =~ /^(Token|XToken|Number|Dimension|Glue|MuGlue)$/){
      push(@params,{ spec=>$spec, type=>$type, before=>$open, after=>$close}); }
    else {
      Error("Unknown parameter type \"$spec\" in \"$proto\" for $cs"); }}
  ($cs,[@params]); }


our %parameter_specs = (any      => { name=>'any',      reader=>sub{ $_[0]->readArg; }, 
				      before=>'{', after=>'}'},
			semiverb => { name=>'semiverb', reader=>sub{ $_[0]->readSemiverbatim; }, 
				      before=>'{', after=>'}', nofilter=>1},
			Token    => { name=>'Token',    reader=>sub{ $_[0]->readToken; }},
			XToken   => { name=>'XToken',   reader=>sub{ $_[0]->readXToken; }},
			Number   => { name=>'Number',   reader=>sub{ $_[0]->readNumber; }},
			Dimension=> { name=>'Dimension',reader=>sub{ $_[0]->readDimension; }},
			Glue     => { name=>'Glue',     reader=>sub{ $_[0]->readGlue; }},
			MuGlue   => { name=>'MuGlue',   reader=>sub{ $_[0]->readMuGlue; },},
			);
our %paramtypes=map(($_=>1),qw(any semiverb Token XToken Number Dimension Glue MuGlue));

sub ZZZparsePrototype {
  my($proto)=@_;
  my $p = $proto;
  $p =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Error("Definition prototype doesn't have proper control sequence: $proto") if @junk;
  my @params=();
  while($p){
    if($p =~ s/^\{([^\}]+)\}//){ # {type:options|...}
      my ($spec,@extra) = ($1);
      if($spec =~ /^(\w+):(.*)$/){
	$spec = $1; @extra = map(Tokenize($_),split('\|',$2)); }
      if($spec eq 'Until'){
	push(@params,{ name=>'Until', reader=>sub{ $_[0]->readUntil($extra[0]); }, 
		       after=>$extra[0]->untex}); }
      elsif($spec =~ /^(Ignore|Flag|Literal|Keyword)$/){
	push(@params,{ name=>$spec, reader=>sub{ $_[0]->readMatch(@extra); }, extra=>[@extra],
		       allowmissing=>($spec=~/^(Ignore|Flag)$/ ? 1:0),
		       novalue=>($spec=~/^(Ignore|Literal)$/ ? 1:0)}); }
      elsif($spec eq 'KeyVal'){
	push(@params,{ name=>'KeyVal', reader=>sub { $_[0]->parseKeyVal($extra[0]->toString,$_[0]->readArg); },
		       before=>'{', after=>'}'}); }
      elsif($parameter_specs{$spec}){
	push(@params,$parameter_specs{$spec}); }
      else {
	Error("Unknown parameter type \"$spec\" in \"$proto\" for $cs"); }
    }
    elsif($p =~ s/^\[([^\]]*)\]//){ # Optional
      my ($spec,@extra) = ($1);
      if($spec =~ /^(\w+):(.*)$/){
	$spec = $1; @extra = map(Tokenize($_),split('\|',$2)); }
      if($spec eq 'Default'){
	push(@params,{ name=>'Optional', reader=>sub{ $_[0]->readOptional($extra[0]); },
		       allowmissing=>1, before=>'[', after=>']', extra=>[$extra[0]]}); }
      elsif($spec eq ''){
	push(@params,{ name=>'Optional', reader=>sub{ $_[0]->readOptional(); },
		       allowmissing=>1, before=>'[', after=>']', extra=>[]}); }
      elsif($spec eq 'KeyVal'){
	push(@params,{ name=>'KeyVal', reader=>sub { $_[0]->parseKeyVal($extra[0]->toString,$_[0]->readOptional()); },
		       allowmissing=>1, before=>'[', after=>']'}); }
      else {
	Error("Unknown optional parameter type \"$spec\" in \"$proto\" for $cs"); }
    }
    else {
	Error("Unknown parameter spec in \"$proto\" for $cs"); }
  }
  ($cs,[@params]); }
sub YYparsePrototype {
  my($proto)=@_;
  my $p = $proto;
  $p =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Error("Definition prototype doesn't have proper control sequence: $proto") if @junk;
  my @params=();
  while($p){
    if($p =~ s/^\{([^\}]+)\}//){ # {type} or {type}until
      my ($spec,@extra) = ($1);
      if($spec =~ /^(\w+):(.*)$/){
	$spec = $1; @extra = map(Tokenize($_),split('\|',$2)); }
      if($spec eq 'Until'){
	push(@params,{ name=>'Until', reader=>sub{ $_[0]->readUntil($extra[0]); }, 
		       after=>$extra[0]->untex}); }
      elsif($spec eq 'Ignore'){
	push(@params,{ name=>'Ignore', reader=>sub{ $_[0]->readMatch(@extra); },
		       allowmissing=>1, novalue=>1, extra=>[@extra]}); }
      elsif($spec eq 'Flag'){
	push(@params,{ name=>'Flag', reader=>sub{ $_[0]->readMatch(@extra); }, 
		       allowmissing=>1, extra=>[@extra]}); }
      elsif($spec eq 'Literal'){
	push(@params,{ name=>'Literal', reader=>sub{ $_[0]->readMatch(@extra); },
		       novalue=>1, extra=>[@extra]}); }
      elsif($spec eq 'Keyword'){
	push(@params,{ name=>'Keyword', reader=>sub{ $_[0]->readMatch(@extra); }, 
		       extra=>[@extra]}); }
      elsif($parameter_specs{$spec}){
	push(@params,$parameter_specs{$spec}); }
      else {
	Error("Unknown parameter type \"$spec\" in \"$proto\" for $cs"); }
    }
    elsif($p =~ s/^\[([^\]]*)\]//){ # Optional
      my ($spec,@extra) = ($1);
      if($spec =~ /^(\w+):(.*)$/){
	$spec = $1; @extra = map(Tokenize($_),split('\|',$2)); }
      if($spec eq 'Default'){
	push(@params,{ name=>'Optional', reader=>sub{ $_[0]->readOptional($extra[0]); },
		       allowmissing=>1, before=>'[', after=>']', extra=>[$extra[0]]}); }
      elsif($spec eq ''){
	push(@params,{ name=>'Optional', reader=>sub{ $_[0]->readOptional(); },
		       allowmissing=>1, before=>'[', after=>']', extra=>[]}); }
      else {
	Error("Unknown optional parameter type \"$spec\" in \"$proto\" for $cs"); }
    }
    else {
	Error("Unknown parameter spec in \"$proto\" for $cs"); }
  }
  ($cs,[@params]); }
sub XXparsePrototype {
  my($proto)=@_;
  my $p = $proto;
  $p =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Error("Definition prototype doesn't have proper control sequence: $proto") if @junk;
  my @params=();
  while($p){
    if($p =~ s/^\{([^\}]+)\}//){ # {type} or {type}until
      Error("Unknown parameter type \"$1\" in \"$proto\" for $cs") unless $parameter_specs{$1};
      if(($1 eq 'arg') && ($p =~ s/^([^\{\[\?]+)//)){ # Followed by literal text!!
	my $expected=Tokenize($1);
	push(@params,{ name=>'until', reader=>sub{ $_[0]->readUntil($expected); }, after=>$expected->untex}); } # Until
      else {
	push(@params,$parameter_specs{$1}); }}
    elsif($p =~ s/^([a-zA-Z]*|.)\?\?//){ # Ignore: *?? or by?? 
      my $expected=Tokenize($1);
      push(@params,{ name=>'ignore', reader=>sub{ $_[0]->readMatch($expected); }, 
		     allowmissing=>1, novalue=>1, extra=>[$expected]}); }
    elsif($p =~ s/^([a-zA-Z]*|.)\?//){ # Flag: *? or by?
      my $expected=Tokenize($1);
      push(@params,{ name=>'flag', reader=>sub{ $_[0]->readMatch($expected); }, 
		     allowmissing=>1, extra=>[$expected]}); }
    elsif($p =~ s/^\[([^\]]*)\]//){ # Optional: [default]
      my $default= ($1 ? Tokenize($1) : undef);
print STDERR "Non empty default \"$default\" for optional arg of $cs\n" if $default;
      push(@params,{ name=>'optional', reader=>sub{ $_[0]->readOptional($default); }, allowmissing=>1, 
		     before=>'[', after=>']', extra=>[$default]}); }
    elsif($p =~ s/^([^{\[\?]+)//){ # Literal text required
      my $expected=Tokenize($1);
      push(@params,{ name=>'literal', reader=>sub{ $_[0]->readMatch($expected); }, 
		     novalue=>1, extra=>[$expected]}); }
  }
  ($cs,[@params]); }

sub showParameters {
  my($self)=@_;
  my $string="";
  my $params=$$self{parameters};
  return $string unless $params;
  foreach my $p (@$params){
#    $string .= '{'.$$p{name} . ($$p{extra} ? ':'.join('|',@{$$p{extra}}) : '') . '}'; }
    $string .= ($$p{open}||' ').$$p{spec}.($$p{close}||''); }
  $string; }

sub showArguments {
  my($self,@args)=@_;
#  join(', ',map("\"".(ref $_ ? $_->untex : $_)."\"",@args)); }
  my $string = ' ';
  foreach my $spec (@{$$self{parameters}}){
    if($$spec{novalue}){ $string .= $$spec{extra}->[0]->untex; }
    elsif(defined(my $arg = shift(@args))){
      $string .= $$spec{before} if $$spec{before};
      $string .= $arg->untex;
      $string .= $$spec{after} if $$spec{after};
    }}
  $string; }

#======================================================================
# Read the arguments for this control sequence, according to parameter list.

sub readArguments {
  my($self,$gullet)=@_;
  my @args=();
  foreach my $spec (@{$$self{parameters}}){
#    my $value = &{$$spec{reader}}($gullet);
    my $value = $gullet->readArgument(%{$spec});
#    Error("Missing arg ($$spec{spec}) for $$self{cs}")
#      unless (defined $value) || $$spec{allowmissing}; 
    push(@args,$value) unless $$spec{novalue}; }
  @args; }

#**********************************************************************
# Expandable control sequences;  Expanded in the Gullet.
#**********************************************************************
package LaTeXML::Expandable;
use LaTeXML::Token; 
use LaTeXML::Error;
our @ISA = qw(LaTeXML::Definition);

sub new {
  my($class,$cs,$paramlist,$expansion)=@_;
  my $self= bless {cs=>$cs, parameters=>($paramlist || []), expansion=>$expansion}, $class;
  Message("Defining Expandable ".$cs->getString.$self->showParameters) if Debugging('macros');
  $self; }

sub isExpandable  { 1; }
sub isConditional { $_[0]->{isConditional}; }
sub getExpansion  { $_[0]->{expansion}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub expand {
  my($self,$gullet)=@_;
  Message("Expanding $$self{cs}".$self->showParameters) if Debugging('macros');
  my @args = $self->readArguments($gullet);
  my $expansion = $$self{expansion};
  my @result=();
  if(ref $expansion eq 'CODE'){
    @result = &$expansion($gullet,@args); }
  elsif(ref $expansion eq 'LaTeXML::Tokens'){
    @result = substituteTokens($expansion,@args); }
  else {
    Error("Attempt to expand token \"$$self{cs}\" which doesn't appear to be expandable."); }
  Message("Expansion ".$$self{cs}.$self->showArguments(@args)." => ".Tokens(@result)->untex)
    if Debugging('macros');
  @result; }

sub substituteTokens {
  my($tokens,@args)=@_;
  my @in = $tokens->unlist;
  my @result=();
  while(@in){
    my $token;
    if(($token=shift(@in))->getCatcode != CC_PARAM){ # Non '#'; copy it
      push(@result,$token); }
    elsif(($token=shift(@in))->getCatcode != CC_PARAM){ # Not multiple '#'; read arg.
      push(@result,@{$args[ord($token->getString)-ord('0')-1]}); }
    else {		# Multiple '#', copy till non # loosing one of the #'s
      push(@result,$token); }}
  @result; }

#**********************************************************************
# Primitive control sequences; Executed in the Stomach.
#**********************************************************************

package LaTeXML::Primitive;
use LaTeXML::Error;
our @ISA = qw(LaTeXML::Definition);

sub isPrefix      { $_[0]->{isPrefix}; }

sub executeBeforeDigest {
  my($self,$stomach)=@_;
  map(&$_($stomach), @{$$self{beforeDigest}}); }

sub executeAfterDigest {
  my($self,$stomach,@whatever)=@_;
  map(&$_($stomach,@whatever), @{$$self{afterDigest}}); }

# Digest the primitive; this should occur in the stomach.
sub digest {
  my($self,$stomach)=@_;
  Message("Digesting ".$$self{cs}.$self->showParameters) if Debugging('macros');
  my $replacement = $$self{replacement};
  my @pre = $self->executeBeforeDigest($stomach);
  my @stuff;
  if(ref $replacement eq 'CODE'){
    my @args = $self->readArguments($stomach->getGullet);
    @stuff = &{$replacement}($stomach, @args);
    Message("Digested ".$$self{cs}.$self->showArguments(@args)." => ".join('',@stuff))
      if Debugging('macros'); }
  # $replacement could also conceivably be a box/list/whatsit ? Is that useful?
  else {
    Error("Attempt to invoke the primitive \"$$self{cs}\" which doesn't appear to be expandable."); }
  my @post = $self->executeAfterDigest($stomach);
  (@pre,@stuff,@post); }

#**********************************************************************
# A `Generalized' parameter;
# includes the normal ones, as well as registers and 
# eventually things like catcode, 
package LaTeXML::Parameter;
use LaTeXML::Error;
our @ISA = qw(LaTeXML::Primitive);

sub isPrefix    { 0; }
sub isParameter { $_[0]->{parameterType}; }
sub isReadonly  { $_[0]->{readonly}; }

sub getValue {
  my($self,$stomach,@args)=@_;
  &{$$self{getter}}($stomach,@args); }

sub setValue {
  my($self,$stomach,$value,@args)=@_;
  &{$$self{setter}}($stomach,$value,@args);
  return; }

# No before/after daemons ???
sub digest {
  my($self,$stomach)=@_;
  Message("Assigning $$self{cs}".$self->showParameters) if Debugging('macros');
  my $gullet = $stomach->getGullet;
  my @args = $self->readArguments($gullet);
  $gullet->readKeyword('=');	# Ignore 
  my $value = $gullet->readValue($self->isParameter);
  $self->setValue($stomach,$value,@args);
  Message("Assigned ".$$self{cs}.$self->showArguments(@args)." => ".$value)
      if Debugging('macros');
  return; }

#**********************************************************************
# Constructor control sequences.  These are executed in the Intestine,
# BUT, they are converted to a Whatsit in the Stomach!
# In particular, beforeDigest, reading args and afterDigest are executed
# in the Stomach.
#**********************************************************************
package LaTeXML::Constructor;
use LaTeXML::Error;
use LaTeXML::Box;
our @ISA = qw(LaTeXML::Primitive);

sub floats { $_[0]->{floats}; }
sub getMathClass { $_[0]->{mathclass} || 'symbol'; }

sub getConstructor {
  my($self,$ismath)=@_;
  (($ismath && defined $$self{mathConstructor}) ? $$self{mathConstructor} : $$self{replacement}); }

sub untex {
  my($self,$whatsit,@params)=@_;
  my $untex = $$self{untex};
  if((defined $untex) && (ref $untex eq 'CODE')){
    return &$untex($whatsit,@params); }
  else {
    return "" if grep(/nofloats/,@params) && $self->floats;
    my $string = '';
    if(defined $untex){
      $string = $untex;
      $string =~ s/#(\d)/ $whatsit->getArg($1)->untex(@params); /eg; }
    else {
      $string= $$self{cs};
      my @args = $whatsit->getArgs;
      $string .= ' ' unless scalar(@args) || ($string=~/\W$/) || !($string =~ /^\\/);
      foreach my $spec (@{$$self{parameters}}){
	if($$spec{novalue}){ $string .= $$spec{extra}->[0]->untex; }
	elsif(defined(my $arg = shift(@args))){
	  $string .= $$spec{before} if $$spec{before};
	  # KeyVal??
	  $string .= $arg->untex;
	  $string .= $$spec{after} if $$spec{after};
	}}
      Error("Undeclared args remain for $$self{cs}")  if(@args);
    }
    if(defined (my $body = $whatsit->getBody)){
      $string .= $body->untex(@params);
      $string .= $whatsit->getTrailer->untex(@params); }
    $string; }}

# Digest the constructor; This should occur in the Stomach (NOT the Intestine)
# to create a Whatsit, which will be further processed in the Intestine
sub digest {
  my($self,$stomach)=@_;
  Message("Digesting Constructor $$self{cs}".$self->showParameters) if Debugging('macros');
  # Call any `Before' code.
  my @pre = $self->executeBeforeDigest($stomach);
  # Parse AND digest the arguments to the Constructor
  my @args = $self->readArguments($stomach->getGullet);
  my @dargs=();
  foreach my $spec (@{$$self{parameters}}){
    if(!$$spec{novalue}){
      my $arg = shift(@args);
#	push(@dargs,(ref $arg ? $stomach->digestTokens($arg,$$spec{nofilter}) : $arg)); }}}
      push(@dargs,(ref $arg ? $arg->digest($stomach,$$spec{nofilter}) : $arg)); }}
  my $whatsit = Whatsit($self,$stomach,[@dargs]);
  my @post = $self->executeAfterDigest($stomach,$whatsit);
  Message("Digested ".$$self{cs}.$self->showArguments(@args)." => ".$whatsit)
    if Debugging('macros');
  if($$self{captureBody}){
    my @body = $stomach->readAndDigestBody;
    $whatsit->setBody(@post,@body); @post=();
    Message("Added body to $$self{cs}") if Debugging('macros');
  }
  (@pre,$whatsit,@post); 
}

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Definition, LaTeXML::Expandable, LaTeXML::Primitive, LaTeXML::Parameter, LaTeXML::Constructor.

=head2 DESCRIPTION

These represent the various executables corresponding to control sequences.
LaTeXML::Expandable represents macros and other expandable control sequences like \if, etc
that are carried out in the Gullet during expansion.
LaTeXML::Primitive represents primitive control sequences that are primarily carried out
for side effect during digestion in the Stomach.
LaTeXML::Parameter is set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.
LaTeXML::Constructor represents control sequences that contribute arbitrary XML fragments
to the document tree.

More documentation needed, but see LaTeXML::Package for the main user access to these.

=cut
