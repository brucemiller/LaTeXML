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
  $type.'['.($$self{alias}||$$self{cs}->getCSName).' '.Stringify($$self{parameters}).']'; }

sub toString {
  my($self)=@_;
  $$self{cs}->toString.' '.ToString($$self{parameters} ||''); }

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

# Known traits:
#    isConditional: whether this expandable is some form of \ifxxx
sub new {
  my($class,$cs,$parameters,$expansion,%traits)=@_;
  Fatal("Defining Expandable ".Stringify($cs)." but expansion is neither Tokens nor CODE: $expansion.")
    unless (ref $expansion) =~ /^(LaTeXML::Tokens|CODE)$/;
  if(ref $expansion eq 'LaTeXML::Tokens'){
    my $level=0;
    foreach my $t ($expansion->unlist){
      $level++ if $t->equals(T_BEGIN);
      $level-- if $t->equals(T_END); }
    Fatal("Defining Macro ".Stringify($cs).": replacement has unbalanced {}: ".ToString($expansion)) if $level;  }
  bless {cs=>$cs, parameters=>$parameters, expansion=>$expansion,
	 locator=>"defined ".$STATE->getStomach->getGullet->getLocator,
	 %traits}, $class; }

sub isExpandable  { 1; }
sub isConditional { $_[0]->{isConditional}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my($self,$gullet)=@_;
  if($self->isConditional){
    $STATE->assignValue(current_if_level=>($STATE->lookupValue('current_if_level')||0)+1, 'global'); }
  $self->doInvocation($gullet,$self->readArguments($gullet)); }

sub doInvocation {
  my($self,$gullet,@args)=@_;
  my $expansion = $$self{expansion};
  (ref $expansion eq 'CODE' 
   ? &$expansion($gullet,@args)
   : substituteTokens($expansion,map($_ && Tokens($_->revert),@args))); }

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
  (defined $other
   && (ref $self) eq (ref $other)) && Equals($$self{parameters},$$other{parameters})
     && Equals($$self{expansion},$$other{expansion}); }

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
  Fatal("Defining Primitive ".Stringify($cs)." but replacement is not CODE: $replacement.")
    unless ref $replacement eq 'CODE';
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$STATE->getStomach->getGullet->getLocator, %traits}, $class; }

sub isPrefix      { $_[0]->{isPrefix}; }

sub executeBeforeDigest {
  my($self,$stomach)=@_;
  my $pre = $$self{beforeDigest};
  ($pre ? map(&$_($stomach), @$pre) : ()); }

sub executeAfterDigest {
  my($self,$stomach,@whatever)=@_;
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
	 locator=>"defined ".$STATE->getStomach->getGullet->getLocator, %traits}, $class; }

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
sub invoke {
  my($self,$stomach)=@_;
  my $gullet=$stomach->getGullet;
  my @args = $self->readArguments($gullet);
  $gullet->readKeyword('=');	# Ignore 
  my $value = $gullet->readValue($self->isRegister);
  $self->setValue($value,@args);
  return; }

#**********************************************************************
# A CharDef is a specialized register;
# You can't assign it; when you invoke the control sequence, it returns
# the result of evaluating the character (more like a regular primitive).

package LaTeXML::CharDef;
use LaTeXML::Global;
use base qw(LaTeXML::Register);

sub new {
  my($class,$cs,$value,%traits)=@_;
  bless {cs=>$cs, parameters=>undef,
	 value=>$value, char=>T_OTHER(chr($value->valueOf)),
	 registerType=>'Number', readonly=>1,
	 locator=>"defined ".$STATE->getStomach->getGullet->getLocator, %traits}, $class; }

sub valueOf  { $_[0]->{value}; }
sub setValue { Error("Cannot assign to chardef ".$_[0]->getCSName); return; }
sub invoke   { 
  my($self,$stomach)=@_;
  $stomach->invokeToken($$self{char}); }

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
#    properties : a hash of default values for properties to store in the Whatsit.
sub new {
  my($class,$cs,$parameters,$replacement,%traits)=@_;
  Fatal("Defining Constructor ".Stringify($cs)." but replacement is not a string or CODE: $replacement")
    unless (defined $replacement) && (!(ref $replacement) || (ref $replacement eq 'CODE'));
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$STATE->getStomach->getGullet->getLocator, %traits,
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
      $props{$key} = &$value($stomach,@args); }
    elsif($value && ($value =~/^\#(\d)$/)){
      $props{$key} = $args[$1-1]->toString; }}
  $props{font}    = $font   unless defined $props{font};
  $props{locator} = $stomach->getGullet->getLocator unless defined $props{locator};
  $props{isMath}  = $ismath unless defined $props{isMath};
  $props{level}   = $stomach->getBoxingLevel;

  # Now create the Whatsit, itself.
  my $whatsit = LaTeXML::Whatsit->new($self,[@args],%props);

  # Call any 'After' code.
  my @post = $self->executeAfterDigest($stomach,$whatsit);
  if(my $id = $props{id}){
    $STATE->assignValue('xref:'.$id=>$whatsit,'global'); }
  if($$self{captureBody}){
    $whatsit->setBody(@post,$stomach->digestNextBody); @post=(); }
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
our $QNAME_RE = "([\\w\\-_:]+)";
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
  my $code =
    " sub $name {\n"
    ."my(".join(', ','$document', map("\$arg$_",1..$nargs),'%prop').")=\@_;\n"
      .($floats ? "my \$savenode;\n" :'')
	. $body
	  . ($floats ? "\$document->setNode(\$savenode) if defined \$savenode;\n" : '')
	    . "}\n" ;
###print STDERR "Compilation of \"$constructor\" => \n$code\n";

  eval $code;
  Fatal("Compilation of \"$constructor\" => \n$code\nFailed; $@") if $@; 
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
      Fatal("Missing \"?>\" in constructor template at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif(s|^\s*<$QNAME_RE||so){
      my($tag,$av) = ($1,translate_avpairs());
      if($float){
#	$code .= "\$savenode=\$document->floatToElement('$tag') unless \$document->isOpenable('$tag');\n";
	$code .= "\$savenode=\$document->floatToElement('$tag');\n";
	$float = undef; }
      $code .= "\$document->openElement('$tag'".($av? ", $av" : '').");\n";
      $code .= "\$document->closeElement('$tag');\n" if s|^/||; # Empty element.
      Fatal("Missing \">\" in constructor template at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif(s|^\s*</$QNAME_RE\s*>||so){
      $code .= "\$document->closeElement('$1');\n"; }
    # Substitutable value: argument, property...
    elsif(/^$VALUE_RE/o){ 
      $code .= "\$document->absorb(".translate_value().");\n"; }
    # Attribute: a=v; assigns in current node? [May conflict with random text!?!]
    elsif(s|^$QNAME_RE\s*=\s*||so){
      my $key = $1;
      if($float){
	$code .= "\$savenode=\$document->floatToAttribute('$key');\n";
	$float = undef; }
      $code .= "\$document->getNode->setAttribute('$key',ToString(".translate_string().")) if \$savenode;\n"; }
    # Else random text
    elsif(s/^$TEXT_RE//so){	# Else, just some text.
      $code .= "\$document->absorb('".slashify($1)."');\n"; }
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
    Fatal("Unbalanced conditional in constructor template \"$_\""); }}

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, #prop, and also &function(args,...)
sub translate_value {
  my $value;
  if(s/^\&([\w\:]*)\(//){	# Recognize a function call, w/args
    my $fcn = $1;
    # Hack: If no explict package, assume name it must be accessible via Pool
    $fcn = "LaTeXML::Package::Pool::$fcn" unless $fcn =~/:/;
    my @args = ();
    while(! /^\s*\)/){
      if(/^\s*([\'\"])/){ push(@args,translate_string()); }
      else              { push(@args,translate_value()); }
      last unless s/^\s*\,\s*//; }
    Error("Missing ')' in &$fcn(...) in constructor pattern for $LaTeXML::ConstructorCompiler::NAME")
      unless s/\)//;
    $value = "$fcn(".join(',',@args).")"; }
  elsif(s/^\#(\d+)//     ){	# Recognize an explicit #1 for whatsit args
    my $n = $1;
    if(($n < 1) || ($n > $LaTeXML::ConstructorCompiler::NARGS)){
      Error("Illegal argument number $n in constructor for "
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
  else { join('.',map( (/^\'/ ? $_ : "(ref $_? $_->toString:'')"),@values)); }}

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

C<LaTeXML::Definition>  - Control sequence definitions,
including specializations C<LaTeXML::Expandable>, C<LaTeXML::Primitive>, 
C<LaTeXML::Register>, C<LaTeXML::Constructor>

=head1 DESCRIPTION

These represent the various executables corresponding to control sequences.
See L<LaTeXML::Package> for the most convenient means of creating them.

=over 4

=item C<LaTeXML::Expandable>

represents macros and other expandable control sequences like C<\if>, etc
that are carried out in the Gullet during expansion. The results of invoking an
C<LaTeXML::Expandable> should result in a list of C<LaTeXML::Token>s.

=item C<LaTeXML::Primitive>

represents primitive control sequences that are primarily carried out
for side effect during digestion in the L<LaTeXML::Stomach> and for changing
the L<LaTeXML::State>.  The results of invoking a C<LaTeXML::Primitive>, if any,
should be a list of digested items (C<LaTeXML::Box>, C<LaTeXML::List>
or C<LaTeXML::Whatsit>).

=item C<LaTeXML::Register>

is set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.

=item C<LaTeXML::Constructor>

represents control sequences that contribute arbitrary XML fragments
to the document tree.  During digestion, these control sequences record the arguments 
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

Primitive definitions may have lists of subroutines, called C<beforeDigest> and C<afterDigest>,
that are executed before (and before the arguments are read) and after digestion.
These should either end with C<return;>, C<()>, or return a list of digested 
objects (L<LaTeXML::Box> or similar) that will be contributed to the current list.

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

A constructor has as it's C<replacement> either a subroutine, or a string pattern representing
the XML fragment it should generate.  In the case of a string pattern, the pattern is
compiled into a subroutine on first usage by the internal class C<LaTeXML::ConstructorCompiler>.
Like primitives, constructors may have C<beforeDigest> and C<afterDigest>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
