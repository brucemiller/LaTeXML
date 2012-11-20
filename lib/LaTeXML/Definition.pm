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
  my $source = $STATE->getStomach->getGullet->getMouth;
  if(ref $expansion eq 'LaTeXML::Tokens'){
    my $level=0;
    foreach my $t ($expansion->unlist){
      $level++ if $t->equals(T_BEGIN);
      $level-- if $t->equals(T_END); }
    Fatal('misdefined',$cs,$source,"Expansion of '".ToString($cs)."' has unbalanced {}",
	  "Expansion is ".ToString($expansion)) if $level;  }
  bless {cs=>$cs, parameters=>$parameters, expansion=>$expansion,
	 locator=>"from ".$source->getLocator(-1),
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
  my $r;
  (ref $expansion eq 'CODE' 
   ? &$expansion($gullet,@args)
   : substituteTokens($expansion,
		      map($_ && (($r=ref $_) && ($r eq 'LaTeXML::Tokens')
				 ? $_
				 : ($r && ($r eq 'LaTeXML::Token')
				    ? Tokens($_)
				    : Tokens(Revert($_)))),
			  @args))); }

# NOTE: Assumes $tokens is a Tokens list of Token's and each arg either undef or also Tokens
# Using inline accessors on those assumptions
sub substituteTokens {
  my($tokens,@args)=@_;
  my @in = @{$tokens};		# ->unlist
  my @result=();
  while(@in){
    my $token;
    if(($token=shift(@in))->[1] != CC_PARAM){ # Non '#'; copy it
      push(@result,$token); }
    elsif(($token=shift(@in))->[1] != CC_PARAM){ # Not multiple '#'; read arg.
      if(my $arg = $args[ord($token->[0])-ord('0')-1]){
	push(@result,@$arg); }}	# ->unlist, assuming it's a Tokens() !!!
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
  my $source = $STATE->getStomach->getGullet->getMouth;
  Fatal('misdefined',$cs,$source,"Conditional '".ToString($cs)."' has neither a test nor a skipper.")
    unless $test or $traits{skipper};
  bless {cs=>$cs, parameters=>$parameters, test=>$test,
	 locator=>"from ".$source->getLocator(-1),
	 %traits}, $class; }

sub isConditional { 1; }

sub getTest { $_[0]->{test}; }

# Note that although conditionals are Expandable,
# they do NOT defined as macros, so they don't need to handle doInvocation,

sub invoke {
  my($self,$gullet)=@_;
  # Keep a stack of the conditionals we are processing.
  local $LaTeXML::IFFRAME= {token=>$LaTeXML::CURRENT_TOKEN, start=>$gullet->getLocator,
			   parsing=>1, elses=>0};
  $STATE->unshiftValue(if_stack=>$LaTeXML::IFFRAME);

  my @args = $self->readArguments($gullet);
  $$LaTeXML::IFFRAME{parsing}=0; # Now, we're done parsing the Test clause.

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

# NOTE that there are 2 kinds of "nested" ifs.
#  \if's inside the body of either the true or false branch
# are easily skipped by tracking a level of if nesting and skipping over the
# same number of \fi as you find \if.
#  \if's that get expanded while evaluating the test clause itself
# are considerably trickier. There's a frame on the if-stack for this \if
# that's above the one we're currently processing; typically the \else & \fi
# may still remain, but we need to either evaluate them a normal
# if we're continuing to follow the true branch, or skip oever them if
# we're trying to find the \else for the false branch.
# The danger is mistaking the \else that's associated with the test clause's \if
# and taking it for the \else that we're skipping to!
# Canonical example:
#   \if\ifx AA XY junk \else blah \fi True \else False \fi
# The inner \ifx should expand to "XY junk", since A==A
sub skipConditionalBody {
  my($gullet,$nskips)=@_;
  my $level=1;
  my $n_ors = 0;
  my $start = $gullet->getLocator;
  my($fi,$or,$ls);		# defns of \fi,\or,\else (once we've looked them up)
  while(my $t= $gullet->readToken){
    # The only Interesting tokens are bound to defns (defined OR \let!!!)
    if(defined(my $defn = $STATE->lookupDefinition($t))){
      if($defn->isConditional){ # Found a new \ifxx (in body)
	$level++; }
      elsif($defn eq ($fi||($fi=$STATE->lookupDefinition(T_CS('\fi'))))){ #  Found a \fi
	# But is it for a condition nested in the test clause?
	if($STATE->lookupValue('if_stack')->[0] ne $LaTeXML::IFFRAME){
	  $STATE->shiftValue('if_stack'); } # then DO pop that conditional's frame; it's DONE!
	elsif(!--$level){		    # If no more nesting, we're done.
	  fiHandler($gullet); return; }} # Note, fiHandler called from here.
      elsif($level > 1){	# Ignore \else,\or nested in the body.
      }
      elsif(($defn eq ($or||($or=$STATE->lookupDefinition(T_CS('\or'))))) && (++$n_ors == $nskips)){
	return; }
      elsif(($defn eq ($ls||($ls=$STATE->lookupDefinition(T_CS('\else'))))) && $nskips
	    # Found \else and we're looking for one?
	    # Make sure this \else is NOT for a nested \if that is part of the test clause!
	    && ($STATE->lookupValue('if_stack')->[0] eq $LaTeXML::IFFRAME)){
	# No need to actually call elseHandler, but note that we've seen an \else!
	$STATE->lookupValue('if_stack')->[0]->{elses}=1;
	return; }}}
  Fatal('expected','\fi',$gullet,"Missing \\fi or \\else, conditional fell off end",
	"Conditional started at $start"); }

sub ifHandler   { 
  my($gullet,$boolean)=@_;
  skipConditionalBody($gullet,-1) unless $boolean; return; }

# These next two should NOT be called by Conditionals,
# but they complete the set of conditional operations.
# (See TeX.pool for how to bind to \else, \if...)
sub elseHandler { 
  my($gullet)=@_;
  my $stack =$STATE->lookupValue('if_stack');
  if(!($stack && $$stack[0])){ # No if stack entry ?
    Error('unexpected',$LaTeXML::CURRENT_TOKEN,$gullet,
	  "Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." since we seem not to be in a conditional");
    return; }
  elsif($$stack[0]{parsing}){	# Defer expanding the \else if we're still parsing the test
    (T_CS('\relax'),$LaTeXML::CURRENT_TOKEN); }
  elsif($$stack[0]{elses}){	# Already seen an \else's at this level?
    Error('unexpected',$LaTeXML::CURRENT_TOKEN,$gullet,"Extra ".Stringify($LaTeXML::CURRENT_TOKEN));
    return; }
  else {
    local $LaTeXML::IFFRAME = $stack->[0];
    skipConditionalBody($gullet,0); return; }}

sub fiHandler {
  my($gullet)=@_;
  my $stack=$STATE->lookupValue('if_stack');
  if(!($stack && $$stack[0])){ # No if stack entry ?
    Error('unexpected',$LaTeXML::CURRENT_TOKEN,$gullet,
	  "Didn't expect a ".Stringify($LaTeXML::CURRENT_TOKEN)
	  ." since we seem not to be in a conditional");
    return; }
  elsif($$stack[0]{parsing}){	# Defer expanding the \else if we're still parsing the test
    (T_CS('\relax'),$LaTeXML::CURRENT_TOKEN); }
  else {			# "expand" by removing the stack entry for this level
    $STATE->shiftValue('if_stack'); # Done with this frame
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
  my $source = $STATE->getStomach->getGullet->getMouth;
  Fatal('misdefined',$cs,$source,"Primitive replacement for '".ToString($cs)."' is not CODE",
	"Replacement is $replacement")
    unless ref $replacement eq 'CODE';
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"from ".$source->getLocator(-1),
	 %traits}, $class; }

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
	 locator=>"from ".$STATE->getStomach->getGullet->getMouth->getLocator(-1),
	 %traits}, $class; }

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
	 locator=>"from ".$STATE->getStomach->getGullet->getMouth->getLocator(-1),
	 %traits}, $class; }

sub valueOf  { $_[0]->{value}; }
sub setValue { Error('unexpected',$_[0],undef,"Can't assign to chardef ".$_[0]->getCSName); return; }
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
  my $source = $STATE->getStomach->getGullet->getMouth;
  Fatal('misdefined',$cs,$source,
	"Constructor replacement for '".ToString($cs)."' is not a string or CODE",
	"Replacement is $replacement")
    unless (defined $replacement) && (!(ref $replacement) || (ref $replacement eq 'CODE'));
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"from ".$source->getLocator(-1), %traits,
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
  if(my $cap = $$self{captureBody}){
    $whatsit->setBody(@post,$stomach->digestNextBody((ref $cap ? $cap : undef))); @post=(); }
  (@pre,$whatsit,@post); }

sub doAbsorbtion {
  my($self,$document,$whatsit)=@_;
  # First, compile the constructor pattern, if needed.
  my $replacement = $$self{replacement};
  if(!ref $replacement){
    $$self{replacement} = $replacement = LaTeXML::ConstructorCompiler::compileConstructor($self); }
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
  my($constructor)=@_;
  my $replacement = $$constructor{replacement};
  return sub {} unless $replacement;
  my $cs   = $constructor->getCS;
  my $name = $cs->getCSName;
  my $nargs = $$constructor{nargs};
  local $LaTeXML::Constructor::CONSTRUCTOR = $constructor;
  local $LaTeXML::Constructor::NAME = $name;
  local $LaTeXML::Constructor::NARGS = $nargs;
  $name =~ s/\W//g;
  $name = "constructor_".$name.'_'.$GEN++;
  my $floats = ($replacement =~ s/^\^\s*//);	# Grab float marker.
  my $body = translate_constructor($replacement,$floats);
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
###print STDERR "Compilation of \"$replacement\" => \n$code\n";

  eval $code;
  Fatal('misdefined',$name,$constructor,
	"Compilation of constructor code for '$name' failed",
	"\"$replacement\" => $code",$@) if $@;
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
      Fatal('misdefined',$LaTeXML::Constructor::NAME,$LaTeXML::Constructor::CONSTRUCTOR,
	    "Missing \"?>\" in constructor template at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif(s|^\s*<$QNAME_RE||so){
      my($tag,$av) = ($1,translate_avpairs());
      if($float){
#	$code .= "\$savenode=\$document->floatToElement('$tag') unless \$document->isOpenable('$tag');\n";
	$code .= "\$savenode=\$document->floatToElement('$tag');\n";
	$float = undef; }
      $code .= "\$document->openElement('$tag'".($av? ", $av" : '').");\n";
      $code .= "\$document->closeElement('$tag');\n" if s|^/||; # Empty element.
      Fatal('misdefined',$LaTeXML::Constructor::NAME,$LaTeXML::Constructor::CONSTRUCTOR,
	    "Missing \">\" in constructor template at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif(s|^</$QNAME_RE\s*>||so){
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
  if(my $if = Text::Balanced::extract_bracketed($_,'()')){
    $if =~ s/^\(//;    $if =~ s/\)$//;
    my $else = Text::Balanced::extract_bracketed($_,'()');
    $else =~ s/^\(// if $else;    $else =~ s/\)$// if $else;
    ($bool,$if,$else); }
  else {
    Fatal('misdefined',$LaTeXML::Constructor::NAME,$LaTeXML::Constructor::CONSTRUCTOR,
	  "Unbalanced conditional in constructor template \"$_\""); }}

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
    Error('misdefined',$LaTeXML::Constructor::NAME,$LaTeXML::Constructor::CONSTRUCTOR,
	  "Missing ')' in &$fcn(...) in constructor pattern for $LaTeXML::Constructor::NAME")
      unless s/\)//;
    $value = "$fcn(".join(',',@args).")"; }
  elsif(s/^\#(\d+)//     ){	# Recognize an explicit #1 for whatsit args
    my $n = $1;
    if(($n < 1) || ($n > $LaTeXML::Constructor::NARGS)){
      Error('misdefined',$LaTeXML::Constructor::NAME,$LaTeXML::Constructor::CONSTRUCTOR,
	    "Illegal argument number $n in constructor for "
	    ."$LaTeXML::Constructor::NAME which takes $LaTeXML::Constructor::NARGS args");
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
