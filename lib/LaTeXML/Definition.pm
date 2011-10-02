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

package LaTeXML::Definition;
use strict;
use LaTeXML::Global;
use Exporter;
use LaTeXML::Parameters;
use base qw(LaTeXML::Object);

#**********************************************************************

sub isaDefinition { 1; }
sub getCS        { $_[0]->{cs}; }
sub getCSName    { (defined $_[0]->{alias} ? $_[0]->{alias} : $_[0]->{cs}->getCSName); }
sub isExpandable { 0; }
sub isConditional{ 0; }
sub isRegister   { ''; }
sub isPrefix     { 0; }
sub getLocator   { $_[0]->{locator}; }

sub readArguments {
  my($self,$gullet)=@_;
  my $params = $$self{parameters};
  ($params ? $params->readArguments($gullet,$self) : ()); }

sub getParameters { $_[0]->{parameters}; }
#======================================================================
# Overriding methods
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  my $name = ($$self{alias}||$$self{cs}->getCSName);
  $type.'['.($$self{parameters} ? $name.' '.Stringify($$self{parameters}) : $name).']'; }

sub toString {
  my($self)=@_;
  ($$self{parameters} ? ToString($$self{cs}).' '.ToString($$self{parameters}) : ToString($$self{cs})); }

# Return the Tokens that would invoke the given definition with arguments.
sub invocation {
  my($self,@args)=@_;
  ($$self{cs},($$self{parameters} ? $$self{parameters}->revertArguments(@args):())); }

#**********************************************************************
# Expandable control sequences (& Macros);  Expanded in the Gullet.
#**********************************************************************
package LaTeXML::Expandable;
use LaTeXML::Global;
use base qw(LaTeXML::Definition);

sub new {
  my($class,$cs,$parameters,$expansion,%traits)=@_;
  $expansion = Tokens($expansion) if ref $expansion eq 'LaTeXML::Token';
#  Fatal(":misdefined:".Stringify($cs)." expansion is neither Tokens nor CODE: $expansion.")
#    unless (ref $expansion) =~ /^(LaTeXML::Tokens|CODE)$/;
  if(ref $expansion eq 'LaTeXML::Tokens'){
    my $level=0;
    foreach my $t ($expansion->unlist){
      $level++ if $t->equals(T_BEGIN);
      $level-- if $t->equals(T_END); }
    Fatal(":misdefined:".Stringify($cs)." expansion has unbalanced {}: ".ToString($expansion)) if $level;  }
  bless {cs=>$cs, parameters=>$parameters, expansion=>$expansion,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator,
	 isProtected=>$STATE->getPrefix('protected'),
	 %traits}, $class; }

sub isExpandable  { 1; }
sub isProtected  { $_[0]->{isProtected}; }

sub getExpansion {
  my($self)=@_;
  if(! ref $$self{expansion}){
    $$self{expansion} = TokenizeInternal($$self{expansion}); }
  $$self{expansion}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my($self,$gullet)=@_;
  $self->doInvocation($gullet,$self->readArguments($gullet)); }

sub doInvocation {
  my($self,$gullet,@args)=@_;
  my $expansion = $self->getExpansion;
  (ref $expansion eq 'CODE' 
   ? &$expansion($gullet,@args)
   : substituteTokens($expansion,map($_ && Tokens(Revert($_)),@args))); }

sub substituteTokens {
  my($tokens,@args)=@_;
  my @in = $tokens->unlist;
  my @result=();
  while(@in){
    my $token;
    if(($token=shift(@in))->getCatcode != CC_PARAM){ # Non '#'; copy it
      push(@result,$token); }
    elsif(($token=shift(@in))->getCatcode != CC_PARAM){ # Not multiple '#'; read arg.
      push(@result,@{$args[ord($token->getString)-ord('0')-1]||[]}); }
    else {		# Duplicated '#', copy 2nd '#'
      push(@result,$token); }}
  @result; }

sub equals {
  my($self,$other)=@_;
  (defined $other && (ref $self) eq (ref $other))
    && Equals($$self{parameters},$$other{parameters})
      && Equals($self->getExpansion,$other->getExpansion); }

#**********************************************************************
# Conditional control sequences; Expandable
#   Expand enough to determine true/false, then maybe skip
#   record a flag somewhere so that \else or \fi is recognized
#   (otherwise, they should signal an error)
#**********************************************************************
package LaTeXML::Conditional;
use LaTeXML::Global;
use base qw(LaTeXML::Expandable);

sub new {
  my($class,$cs,$parameters,$test,%traits)=@_;
  Fatal(":misdefined:".Stringify($cs)." conditional has neither a test nor a skipper.")
    unless $test or $traits{skipper};
  bless {cs=>$cs, parameters=>$parameters, test=>$test,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator,
	 %traits}, $class; }

sub isConditional { 1; }

sub getTest { $_[0]->{test}; }

sub doInvocation {
  my($self,$gullet,@args)=@_;
##  my $level = ($STATE->lookupValue('current_if_level') || 0)+1;
##  $STATE->assignValue(current_if_level=>$level, 'global');
##  $STATE->assignValue(if_level=>$level, 'global');
##  $STATE->assignValue('if_level_'.$level.'_elses'=>0,'global');

  my $level = ($STATE->lookupValue('if_level') || 0)+1;
  $STATE->assignValue(if_level=>$level, 'global');
  $STATE->assignValue('if_level_'.$level.'_elses'=>0,'global');

  # The usual case
  if(my $test = $self->getTest){
    ifHandler($gullet, &$test($gullet,@args)); }
  # If there's no test, it must be the Special Case, \ifcase
  elsif(my $skipper = $$self{skipper}){
    &$skipper($gullet,@args); }}

#======================================================================
# Support for conditionals:

# Skipping for conditionals
#   0 : skip to \fi
#  -1 : skip to \else, if any, or \fi
#   n : skip to n-th \or, if any, or \else, if any, or \fi.
sub skipConditionalBody {
  my($gullet,$nskips)=@_;
  my $level=1;
  my $n_ors = 0;
  my $start = $gullet->getLocator;
  while(my $t= $gullet->readToken){
    if(defined(my $defn = $STATE->lookupDefinition($t))){
      if($defn->isExpandable && $defn->isConditional){
	$level++; }
      elsif(Equals($t,T_CS('\fi')) && (!--$level)){
	fiHandler($gullet); return; }
      elsif($level > 1){	# Ignore nested \else,\or
      }
      elsif(Equals($t,T_CS('\or')) && (++$n_ors == $nskips)){
	return; }
      elsif(Equals($t,T_CS('\else')) && $nskips){
##	my $curr=$STATE->lookupValue('current_if_level');
##	$STATE->assignValue('if_level_'.$curr.'_elses'=>1,'global');
	my $level=$STATE->lookupValue('if_level');
	$STATE->assignValue('if_level_'.$level.'_elses'=>1,'global');

	return; }}}
  Fatal(":expected:\\fi Missing \\fi or \\else, conditional fell off end (starting at $start)"); }

sub ifHandler   { 
  my($gullet,$boolean)=@_;
  skipConditionalBody($gullet,-1) unless $boolean; return; }

# These next two should NOT be called by Conditionals,
# but they complete the set of conditional operations.
# sub elseHandler { 
#   my($gullet)=@_;
#   my ($curr,$level) = ($STATE->lookupValue('current_if_level'),$STATE->lookupValue('if_level'));
#   if(!$curr){
#     Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
# 	  ." Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
# 	  ." since we seem not to be in a conditional");
#     return; }
#   elsif($STATE->lookupValue('if_level_'.$curr.'_elses')){
#     Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
# 	  ." Extra ".Stringify($LaTeXML::CURRENT_TOKEN));
#     return; }
#   elsif($curr > $level){
#     (T_CS('\relax'),T_CS('\else')); }
#   else {
#     skipConditionalBody($gullet,0); return; }}

# sub fiHandler {
#   my($gullet)=@_;
#   my ($curr,$level) = ($STATE->lookupValue('current_if_level'),$STATE->lookupValue('if_level'));
#   if(!$curr){
#     Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
# 	  ." Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
# 	  ." since we seem not to be in a conditional");
#     return; }
#   elsif($curr > $level){
#     (T_CS('\relax'),T_CS('\fi')); }
#   else {
#     $STATE->assignValue(current_if_level=>$curr-1, 'global');
#     $STATE->assignValue(if_level=>$curr-1, 'global');
#     return; }}

sub elseHandler { 
  my($gullet)=@_;
  my $level = $STATE->lookupValue('if_level');
  if(!$level){
    Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." since we seem not to be in a conditional");
    return; }
  elsif($STATE->lookupValue('if_level_'.$level.'_elses')){
    Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." Extra ".Stringify($LaTeXML::CURRENT_TOKEN));
    return; }
  else {
    skipConditionalBody($gullet,0); return; }}

sub fiHandler {
  my($gullet)=@_;
  my $level = $STATE->lookupValue('if_level');
  if(!$level){
    Error(":unexpected:".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." since we seem not to be in a conditional");
    return; }
  else {
    $STATE->assignValue(if_level=>$level-1, 'global');
    return; }}

#**********************************************************************
# Primitive control sequences; Executed in the Stomach.
#**********************************************************************

package LaTeXML::Primitive;
use LaTeXML::Global;
use base qw(LaTeXML::Definition);

# Known traits:
#    isPrefix : whether this primitive is a TeX prefix, \global, etc.
sub new {
  my($class,$cs,$parameters,$replacement,%traits)=@_;
  # Could conceivably have $replacement being a List or Box?
  Fatal(":misdefined:".Stringify($cs)."  Primitive replacement is not CODE: $replacement.")
    unless ref $replacement eq 'CODE';
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator, %traits}, $class; }

sub isPrefix      { $_[0]->{isPrefix}; }

sub executeBeforeDigest {
  my($self,$stomach)=@_;
  local $LaTeXML::State::UNLOCKED=1;
  my $pre = $$self{beforeDigest};
  ($pre ? map(&$_($stomach), @$pre) : ()); }

sub executeAfterDigest {
  my($self,$stomach,@whatever)=@_;
  local $LaTeXML::State::UNLOCKED=1;
  my $post = $$self{afterDigest};
  ($post ? map(&$_($stomach,@whatever), @$post) : ()); }

# Digest the primitive; this should occur in the stomach.
sub invoke {
  my($self,$stomach)=@_;
  ($self->executeBeforeDigest($stomach),
   &{$$self{replacement}}($stomach,$self->readArguments($stomach->getGullet)),
   $self->executeAfterDigest($stomach)); }

sub equals {
  my($self,$other)=@_;
  (defined $other
   && (ref $self) eq (ref $other)) && Equals($$self{parameters},$$other{parameters})
     && Equals($$self{replacement},$$other{replacement}); }

#**********************************************************************
# A `Generalized' register;
# includes the normal ones, as well as paramters,
# along with tables like catcode.

package LaTeXML::Register;
use LaTeXML::Global;
use base qw(LaTeXML::Primitive);

# Known Traits:
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    readonly : whether this register can only be read
sub new {
  my($class,$cs,$parameters,$type,$getter,$setter ,%traits)=@_;
  bless {cs=>$cs, parameters=>$parameters,
	 registerType=>$type, getter => $getter, setter => $setter,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator, %traits}, $class; }

sub isPrefix    { 0; }
sub isRegister { $_[0]->{registerType}; }
sub isReadonly  { $_[0]->{readonly}; }

sub valueOf {
  my($self,@args)=@_;
  &{$$self{getter}}(@args); }

sub setValue {
  my($self,$value,@args)=@_;
  &{$$self{setter}}($value,@args);
  return; }

# No before/after daemons ???
# (other than afterassign)
sub invoke {
  my($self,$stomach)=@_;
  my $gullet=$stomach->getGullet;
  my @args = $self->readArguments($gullet);
  $gullet->readKeyword('=');	# Ignore 
  my $value = $gullet->readValue($self->isRegister);
  $self->setValue($value,@args);

  if(my $after = $STATE->lookupValue('afterAssignment')){
    $STATE->assignValue(afterAssignment=>undef,'global');
    $gullet->unread($after); }	# primitive returns boxes, so these need to be digested!
  return; }

#**********************************************************************
# A CharDef is a specialized register;
# You can't assign it; when you invoke the control sequence, it returns
# the result of evaluating the character (more like a regular primitive).

package LaTeXML::CharDef;
use LaTeXML::Global;
use base qw(LaTeXML::Register);

sub new {
  my($class,$cs,$value,$internalcs,%traits)=@_;
  bless {cs=>$cs, parameters=>undef,
	 value=>$value, internalcs=>$internalcs,
	 registerType=>'Number', readonly=>1,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator, %traits}, $class; }

sub valueOf  { $_[0]->{value}; }
sub setValue { Error(":unexpected:".$_[0]->getCSName." Cannot assign to chardef ".$_[0]->getCSName); return; }
sub invoke   { 
  my($self,$stomach)=@_;
  if(my $cs = $$self{internalcs}){
    $stomach->invokeToken($cs); }}

#**********************************************************************
# Constructor control sequences.  
# They are first converted to a Whatsit in the Stomach, and that Whatsit's
# contruction is carried out to form parts of the document.
# In particular, beforeDigest, reading args and afterDigest are executed
# in the Stomach.
#**********************************************************************
package LaTeXML::Constructor;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Primitive);

# Known traits:
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    reversion : CODE or TOKENS for reverting to TeX form
#    captureBody : whether to capture the following List as a `body` 
#        (for environments, math modes)
#        If this is a token, it is the token that will be matched to end the body.
#    properties : a hash of default values for properties to store in the Whatsit.
sub new {
  my($class,$cs,$parameters,$replacement,%traits)=@_;
  Fatal(":misdefined:".Stringify($cs)." Constructor replacement is not a string or CODE: $replacement")
    unless (defined $replacement) && (!(ref $replacement) || (ref $replacement eq 'CODE'));
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$STATE->getStomach->getGullet->getMouth->getLocator, %traits,
#	 nargs =>(defined $traits{nargs} ? $traits{nargs}
#		  : ($parameters ? scalar(grep(! $_->getNoValue, $parameters->getParameters))
#		     : 0))}, $class; }
	 nargs =>(defined $traits{nargs} ? $traits{nargs}
		  : ($parameters ? $parameters->getNumArgs : 0))}, $class; }

sub getReversionSpec { $_[0]->{reversion}; }
sub getAlias     { $_[0]->{alias}; }

# Digest the constructor; This should occur in the Stomach to create a Whatsit.
# The whatsit which will be further processed to create the document.
sub invoke {
  my($self,$stomach)=@_;
  # Call any `Before' code.
  my @pre = $self->executeBeforeDigest($stomach);

  # Get some info before we process arguments...
  my $font = $STATE->lookupValue('font');
  my $ismath = $STATE->lookupValue('IN_MATH');
  # Parse AND digest the arguments to the Constructor
  my $params = $$self{parameters};
  my @args = ($params ? $params->readArgumentsAndDigest($stomach,$self) : ());
  @args = @args[0..$$self{nargs}-1];

  # Compute any extra Whatsit properties (many end up as element attributes)
  my $properties = $$self{properties};
  my %props = (!defined $properties ? ()
	       : (ref $properties eq 'CODE' ? &$properties($stomach,@args)
		  : %$properties));
  foreach my $key (keys %props){
    my $value = $props{$key};
    if(ref $value eq 'CODE'){
      $props{$key} = &$value($stomach,@args); }}
  $props{font}    = $font   unless defined $props{font};
  $props{locator} = $stomach->getGullet->getMouth->getLocator unless defined $props{locator};
  $props{isMath}  = $ismath unless defined $props{isMath};
  $props{level}   = $stomach->getBoxingLevel;

  # Now create the Whatsit, itself.
  my $whatsit = LaTeXML::Whatsit->new($self,[@args],%props);

  # Call any 'After' code.
  my @post = $self->executeAfterDigest($stomach,$whatsit);
  if(my $id = $props{id}){
    $STATE->assignValue('xref:'.$id=>$whatsit,'global'); }
  if(my $cap = $$self{captureBody}){
    $whatsit->setBody(@post,$stomach->digestNextBody((ref $cap ? $cap : undef))); @post=(); }
  (@pre,$whatsit,@post); }

sub doAbsorbtion {
  my($self,$document,$whatsit)=@_;
  # First, compile the constructor pattern, if needed.
  my $replacement = $$self{replacement};
  if(!ref $replacement){
    $$self{replacement} = $replacement
      = LaTeXML::ConstructorCompiler::compileConstructor($replacement,$self->getCS,$$self{nargs}); }
  # Now do the absorbtion.
  if(my $pre = $$self{beforeConstruct}){
    map(&$_($document,$whatsit), @$pre); }
  &{$replacement}($document,$whatsit->getArgs, $whatsit->getProperties); 
  if(my $post = $$self{afterConstruct}){
    map(&$_($document,$whatsit), @$post); }
}

#**********************************************************************
package LaTeXML::ConstructorCompiler;
use strict;
use LaTeXML::Global;

our $VALUE_RE = "(\\#|\\&[\\w\\:]*\\()";
our $COND_RE  = "\\?$VALUE_RE";
#our $QNAME_RE = "([\\w\\-_:]+)";
# Attempt to follow XML Spec, Appendix B
our $QNAME_RE = "((?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:)"
  .              "(?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:|\\p{M}|\\p{Lm}|\\p{Nd}|\\.|\\-)*)";
our $TEXT_RE  = "(.[^\\#<\\?\\)\\&\\,]*)";

our $GEN=0;
sub compileConstructor {
  my($constructor,$cs,$nargs)=@_;
  return sub {} unless $constructor;
  my $name = $cs->getCSName;
  local $LaTeXML::ConstructorCompiler::NAME = $name;
  local $LaTeXML::ConstructorCompiler::NARGS = $nargs;
  $name =~ s/\W//g;
  $name = "constructor_".$name.'_'.$GEN++;
  my $floats = ($constructor =~ s/^\^\s*//);	# Grab float marker.
  my $body = translate_constructor($constructor,$floats);
  # Compile the constructor pattern into an anonymous sub that will construct the requested XML.
  my $code =
    " sub $name {\n"
    ."my(".join(', ','$document', map("\$arg$_",1..$nargs),'%prop').")=\@_;\n"
      # Put the body in the Pool package, so that functions defined there can be used with &foo(..)
      ."package LaTeXML::Package::Pool;\n"
      .($floats ? "my \$savenode;\n" :'')
	. $body
	  . ($floats ? "\$document->setNode(\$savenode) if defined \$savenode;\n" : '')
	    . "}\n" ;
###print STDERR "Compilation of \"$constructor\" => \n$code\n";

  eval $code;
  Fatal(":misdefined:$name Compilation of \"$constructor\" => \n$code\nFailed; $@") if $@; 
  \&$name; }

sub translate_constructor {
  my($constructor,$float)=@_;
  my $code = '';
  local $_ = $constructor;
  while($_){
    if(/^$COND_RE/so){
      my($bool,$if,$else) = parse_conditional();
      $code .= "if($bool){\n".translate_constructor($if)."}\n"
	.($else ? "else{\n".translate_constructor($else)."}\n" : ''); }
    # Processing instruction: <?name a=v ...?>
    elsif(s|^\s*<\?$QNAME_RE||so){
      my($pi,$av) = ($1, translate_avpairs());
      $code .= "\$document->insertPI('$pi'".($av? ", $av" : '').");\n";
      Fatal(":misdefined:$LaTeXML::ConstructorCompiler::Name Missing \"?>\" in constructor template at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif(s|^\s*<$QNAME_RE||so){
      my($tag,$av) = ($1,translate_avpairs());
      if($float){
#	$code .= "\$savenode=\$document->floatToElement('$tag') unless \$document->isOpenable('$tag');\n";
	$code .= "\$savenode=\$document->floatToElement('$tag');\n";
	$float = undef; }
      $code .= "\$document->openElement('$tag'".($av? ", $av" : '').");\n";
      $code .= "\$document->closeElement('$tag');\n" if s|^/||; # Empty element.
      Fatal(":misdefined:$LaTeXML::ConstructorCompiler::Name Missing \">\" in constructor template at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif(s|^\s*</$QNAME_RE\s*>||so){
      $code .= "\$document->closeElement('$1');\n"; }
    # Substitutable value: argument, property...
    elsif(/^$VALUE_RE/o){ 
      $code .= "\$document->absorb(".translate_value().");\n"; }
    # Attribute: a=v; assigns in current node? [May conflict with random text!?!]
    elsif(s|^$QNAME_RE\s*=\s*||so){
      my $key = $1;
      my $value = translate_string();
      if(defined $value){
	if($float){
	  $code .= "\$savenode=\$document->floatToAttribute('$key');\n";
	  $float = undef; }
	$code .= "\$document->setAttribute(\$document->getElement,'$key',ToString(".$value."));\n"; }
      else {			# Whoops, must have been random text, after all.
#print STDERR "Whoops! Wasn't an attribute assignment: \"$key\"\n";
	$code .= "\$document->absorb('".slashify($key)."=');\n"; }}
    # Else random text
    elsif(s/^$TEXT_RE//so){	# Else, just some text.
      # Careful; need to respect the Whatsit's font, too!
      $code .= "\$document->absorbText('".slashify($1)."',\$prop{'font'});\n"; }
  }
  $code; }

sub slashify {
  my($string)=@_;
  $string =~ s/\\/\\\\/g;
  $string; }

# parse a conditional in a constructor
# Conditionals are of the form ?value(...)(...),
# Return the translated condition, along with the strings for the if and else clauses.
use Text::Balanced;
sub parse_conditional {
  s/^\?//;			# Remove leading "?"
  my $bool =  'ToString('.translate_value().')';
##  if(s/^\((.*?)\)(\((.*?)\))?//s){
##    ($bool,$1,$3); }
  if(my $if = Text::Balanced::extract_bracketed($_,'()')){
    $if =~ s/^\(//;    $if =~ s/\)$//;
    my $else = Text::Balanced::extract_bracketed($_,'()');
    $else =~ s/^\(// if $else;    $else =~ s/\)$// if $else;
    ($bool,$if,$else); }
  else {
    Fatal(":misdefined:$LaTeXML::ConstructorCompiler::Name Unbalanced conditional in constructor template \"$_\""); }}

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, #prop, and also &function(args,...)
sub translate_value {
  my $value;
  if(s/^\&([\w\:]*)\(//){	# Recognize a function call, w/args
    my $fcn = $1;
    my @args = ();
    while(! /^\s*\)/){
      if(/^\s*([\'\"])/){ push(@args,translate_string()); }
      else              { push(@args,translate_value()); }
      last unless s/^\s*\,\s*//; }
    Error(":expected:) Missing ')' in &$fcn(...) in constructor pattern for $LaTeXML::ConstructorCompiler::NAME")
      unless s/\)//;
    $value = "$fcn(".join(',',@args).")"; }
  elsif(s/^\#(\d+)//     ){	# Recognize an explicit #1 for whatsit args
    my $n = $1;
    if(($n < 1) || ($n > $LaTeXML::ConstructorCompiler::NARGS)){
      Error(":unexpected:#$n Illegal argument number $n in constructor for "
	    ."$LaTeXML::ConstructorCompiler::NAME which takes $LaTeXML::ConstructorCompiler::NARGS args");
      $value = "\"Missing\""; }
    else {
      $value = "\$arg$n" }}
  elsif(s/^\#([\w\-_]+)//){ $value = "\$prop{'$1'}"; } # Recognize #prop for whatsit properties
  elsif(s/$TEXT_RE//so    ){ $value = "'".slashify($1)."'"; }
  $value; }

# Parse a delimited string from the constructor (in $_), 
# for example, an attribute value.  Can contain substitutions (above),
# the result is a string.
# NOTE: UNLESS there is ONLY one substituted value, then return the value object.
# This is (hopefully) temporary to handle font objects as attributes.
# The DOM holds the font objects, rather than strings,
# to resolve relative fonts on output.
sub translate_string {
  my @values=();
  if(s/^\s*([\'\"])//){
    my $quote = $1;
    while($_ && !s/^$quote//){
      if   ( /^$COND_RE/o              ){
	my($bool,$if,$else) = parse_conditional();
	my $code = "($bool ?";
	{ local $_ = $if; $code .= translate_value(); }
	$code .= ":";
	if($else){ local $_ = $else; $code .= translate_value();}
	else { $code .= "''"; }
	$code .= ")";
	push(@values,$code); }
      elsif( /^$VALUE_RE/o             ){ push(@values,translate_value()); }
      elsif(s/^(.[^\#<\?\!$quote]*)//){ push(@values,"'".slashify($1)."'"); }}}
  if(!@values){ undef; }
  elsif(@values==1){ $values[0]; }
  else { join('.',map( (/^\'/ ? $_ : " ToString($_)"),@values)); }}

# Parse a set of attribute value pairs from a constructor pattern, 
# substituting argument and property values from the whatsit.
sub translate_avpairs {
  my @avs=();
  s|^\s*||;
  while($_){
    if(/^$COND_RE/o){
      my($bool,$if,$else) = parse_conditional();
      my $code = "($bool ? (";
      { local $_=$if; $code .= translate_avpairs(); }
      $code .= ") : (";
      { local $_=$else; $code .= translate_avpairs() if $else; }
      $code .= "))";
      push(@avs,$code); }
    elsif(/^%$VALUE_RE/){	# Hash?  Assume the value can be turned into a hash!
      s/^%//;			# Eat the "%" 
      push(@avs,'%{'.translate_value().'}'); }
    elsif(s|^$QNAME_RE\s*=\s*||o){
      my ($key,$value) = ($1,translate_string());
      push(@avs,"'$key'=>$value"); } # if defined $value; }
    else { last; }
    s|^\s*||; }
  join(', ',@avs); }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Definition>  - Control sequence definitions.

=head1 DESCRIPTION

These represent the various executables corresponding to control sequences.
See L<LaTeXML::Package> for the most convenient means to create them.

=over 4

=item C<LaTeXML::Expandable>

=begin latex

\label{LaTeXML::Expandable}

=end latex

represents macros and other expandable control sequences
that are carried out in the Gullet during expansion. The results of invoking an
C<LaTeXML::Expandable> should be a list of C<LaTeXML::Token>s.

=item C<LaTeXML::Primitive>

=begin latex

\label{LaTeXML::Primitive}

=end latex

represents primitive control sequences that are converted directly to
Boxes or Lists containing basic Unicode content, rather than structured XML,
or those executed for side effect during digestion in the L<LaTeXML::Stomach>,
changing the L<LaTeXML::State>.  The results of invoking a C<LaTeXML::Primitive>, if any,
should be a list of digested items (C<LaTeXML::Box>, C<LaTeXML::List>
or C<LaTeXML::Whatsit>).

=item C<LaTeXML::Register>

=begin latex

\label{LaTeXML::Register}

=end latex

is set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.

=item C<LaTeXML::CharDef>

=begin latex

\label{LaTeXML::CharDef}

=end latex

represents a further specialized Register for chardef.

=item C<LaTeXML::Constructor>

=begin latex

\label{LaTeXML::Constructor}

=end latex

represents control sequences that contribute arbitrary XML fragments
to the document tree.  During digestion, a C<LaTeXML::Constuctor> records the arguments 
used in the invokation to produce a L<LaTeXML::Whatsit>.  The resulting L<LaTeXML::Whatsit>
(usually) generates an XML document fragment when absorbed by an instance of L<LaTeXML::Document>.
Additionally, a C<LaTeXML::Constructor> may have beforeDigest and afterDigest daemons
defined which are executed for side effect, or for adding additional boxes to the output.

=back

More documentation needed, but see LaTeXML::Package for the main user access to these.

=head2 Methods in general

=over 4

=item C<< $token = $defn->getCS; >>

Returns the (main) token that is bound to this definition.

=item C<< $string = $defn->getCSName; >>

Returns the string form of the token bound to this definition,
taking into account any alias for this definition.

=item C<< $defn->readArguments($gullet); >>

Reads the arguments for this C<$defn> from the C<$gullet>,
returning a list of L<LaTeXML::Tokens>.

=item C<< $parameters = $defn->getParameters; >>

Return the C<LaTeXML::Parameters> object representing the formal parameters
of the definition.

=item C<< @tokens = $defn->invocation(@args); >>

Return the tokens that would invoke the given definition with the
provided arguments.  This is used to recreate the TeX code (or it's
equivalent).

=item C<< $defn->invoke; >>

Invoke the action of the C<$defn>.  For expandable definitions, this is done in
the Gullet, and returns a list of L<LaTeXML::Token>s.  For primitives, it
is carried out in the Stomach, and returns a list of L<LaTeXML::Box>es.
For a constructor, it is also carried out by the Stomach, and returns a L<LaTeXML::Whatsit>.
That whatsit will be responsible for constructing the XML document fragment, when the
L<LaTeXML::Document> invokes C<$whatsit->beAbsorbed($document);>.

Primitives and Constructors also support before and after daemons, lists of subroutines
that are executed before and after digestion.  These can be useful for changing modes, etc.

=back

=head2 More about Primitives

Primitive definitions may have lists of daemon subroutines, C<beforeDigest> and C<afterDigest>,
that are executed before (and before the arguments are read) and after digestion.
These should either end with C<return;>, C<()>, or return a list of digested 
objects (L<LaTeXML::Box>, etc) that will be contributed to the current list.

=head2 More about Registers

Registers generally store some value in the current C<LaTeXML::State>, but are not
required to. Like TeX's registers, when they are digested, they expect an optional
C<=>, and then a value of the appropriate type. Register definitions support these
additional methods:

=over 4

=item C<< $value = $register->valueOf(@args); >>

Return the value associated with the register, by invoking it's C<getter> function.
The additional args are used by some registers
to index into a set, such as the index to C<\count>.

=item C<< $register->setValue($value,@args); >>

Assign a value to the register, by invoking it's C<setter> function.

=back

=head2 More about Constructors

=begin latex

\label{LaTeXML::ConstructorCompiler}

=end latex

A constructor has as it's C<replacement> a subroutine or a string pattern representing
the XML fragment it should generate.  In the case of a string pattern, the pattern is
compiled into a subroutine on first usage by the internal class C<LaTeXML::ConstructorCompiler>.
Like primitives, constructors may have C<beforeDigest> and C<afterDigest>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
