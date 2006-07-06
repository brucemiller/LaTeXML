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
use LaTeXML::Object;
use LaTeXML::Parameters;
our @ISA = qw(LaTeXML::Object);

#**********************************************************************

sub isaDefinition { 1; }
sub getCS        { $_[0]->{cs}; }
sub isExpandable { 0; }
sub isRegister   { ''; }
sub isPrefix     { 0; }
sub getLocator   { $_[0]->{locator}; }

sub readArguments {
  my($self)=@_;
  my $params = $$self{parameters};
  ($params ? $params->readArguments : ()); }

sub showInvocation {
  my($self,@args)=@_;
  my $params = $$self{parameters};
  ($params ? $$self{cs}->untex.$params->untexArguments(@args) : $$self{cs}->untex); }

#======================================================================
# Overriding methods
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.($$self{alias}||$$self{cs}->getCSName).Stringify($$self{parameters}).']'; }

sub toString {
  my($self)=@_;
  $$self{cs}->toString.($$self{parameters} ||''); }

# Return the Tokens that would invoke the given definition with arguments.
sub invocation {
  my($self,@args)=@_;
  Tokens($$self{cs},$$self{parameters}->invocationArguments(@args)); }


#**********************************************************************
# Expandable control sequences (& Macros);  Expanded in the Gullet.
#**********************************************************************
package LaTeXML::Expandable;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Definition);

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
    Fatal("Defining Macro ".Stringify($cs).": replacement has unbalanced {}: ".$expansion->untex) if $level;  }
  bless {cs=>$cs, parameters=>$parameters, expansion=>$expansion,
	 locator=>"defined ".$GULLET->getLocator,
	 %traits}, $class; }

sub isExpandable  { 1; }
sub isConditional { $_[0]->{isConditional}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my($self)=@_;
  my @args = $self->readArguments;
  my $expansion = $$self{expansion};
  (ref $expansion eq 'CODE' 
   ? &$expansion($self,@args)
   : substituteTokens($expansion,@args)); }

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
our @ISA = qw(LaTeXML::Definition);

# Known traits:
#    isPrefix : whether this primitive is a TeX prefix, \global, etc.
sub new {
  my($class,$cs,$parameters,$replacement,%traits)=@_;
  # Could conceivably have $replacement being a List or Box?
  Fatal("Defining Primitive ".Stringify($cs)." but replacement is not CODE: $replacement.")
    unless ref $replacement eq 'CODE';
#  $cs = $cs->untex if ref $cs;
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$GULLET->getLocator, %traits}, $class; }

sub isPrefix      { $_[0]->{isPrefix}; }

sub executeBeforeDigest {
  my($self)=@_;
  my $pre = $$self{beforeDigest};
  ($pre ? map(&$_($self), @$pre) : ()); }

sub executeAfterDigest {
  my($self,@whatever)=@_;
  my $post = $$self{afterDigest};
  ($post ? map(&$_(@whatever), @$post) : ()); }

# Digest the primitive; this should occur in the stomach.
sub invoke {
  my($self)=@_;
  my @pre = $self->executeBeforeDigest;
  my @args = $self->readArguments;
  (@pre,
   &{$$self{replacement}}($self, @args),
   $self->executeAfterDigest($self,@args)); }

sub equals {
  my($self,$other)=@_;
  (defined $other
   && (ref $self) eq (ref $other)) && Equals($$self{parameters},$$other{parameters})
     && Equals($$self{replacement},$$other{replacement}); }

#**********************************************************************
# A `Generalized' register;
# includes the normal ones, as well as registers and 
# eventually things like catcode, 
package LaTeXML::Register;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Primitive);

# Known Traits:
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    readonly : whether this register can only be read
sub new {
  my($class,$cs,$parameters,$type,$getter,$setter ,%traits)=@_;
  bless {cs=>$cs, parameters=>$parameters,
	 registerType=>$type, getter => $getter, setter => $setter,
	 locator=>"defined ".$GULLET->getLocator, %traits}, $class; }

sub isPrefix    { 0; }
sub isRegister { $_[0]->{registerType}; }
sub isReadonly  { $_[0]->{readonly}; }

sub getValue {
  my($self,@args)=@_;
  &{$$self{getter}}(@args); }

sub setValue {
  my($self,$value,@args)=@_;
  &{$$self{setter}}($value,@args);
  return; }

# No before/after daemons ???
sub invoke {
  my($self)=@_;
  my @args = $self->readArguments;
  $GULLET->readKeyword('=');	# Ignore 
  my $value = $GULLET->readValue($self->isRegister);
  $self->setValue($value,@args);
  return; }

#**********************************************************************
# Constructor control sequences.  These are executed in the Intestine,
# BUT, they are converted to a Whatsit in the Stomach!
# In particular, beforeDigest, reading args and afterDigest are executed
# in the Stomach.
#**********************************************************************
package LaTeXML::Constructor;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Primitive);

# Known traits:
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    untex : pattern for reverting to TeX form
#    captureBody : whether to capture the following List as a `body` 
#        (for environments, math modes)
#    properties : a hash of default values for properties to store in the Whatsit.
sub new {
  my($class,$cs,$parameters,$replacement,%traits)=@_;
  Fatal("Defining Constructor ".Stringify($cs)." but replacement is not a string or CODE: $replacement")
    unless (defined $replacement) && (!(ref $replacement) || (ref $replacement eq 'CODE'));
#  if(!ref $replacement){
#    $replacement = LaTeXML::ConstructorCompiler::compileConstructor($replacement,$cs
#								    ($parameters ? $parameters->getNArgs:0));}
  bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
	 locator=>"defined ".$GULLET->getLocator, %traits}, $class; }

#sub getConstructor { $_[0]->{replacement}; }
sub getConstructor {
  my($self)=@_;
  my $replacement = $$self{replacement};
  if(!ref $replacement){
    $$self{replacement} = $replacement 
      = LaTeXML::ConstructorCompiler::compileConstructor($replacement,$self->getCS,
							 ($$self{parameters} ? $$self{parameters}->getNArgs:0));}
  $replacement; }

sub untex {
  my($self,$whatsit)=@_;
  my $untex = $$self{untex};
  if((defined $untex) && (ref $untex eq 'CODE')){
    return &$untex($whatsit); }
  else {
    my $string = '';
    if(defined $untex){
      my $p;
      $string = $untex;
      $string =~ s/#(\d)/ $whatsit->getArg($1)->untex; /eg; 
      $string =~ s/#(\w+)/ (ref($p=$whatsit->getProperty($1))?$p->untex:$p); /eg; }
    else {
      $string= $$self{alias}||$$self{cs}->untex;
      my @args = $whatsit->getArgs;
      $string .= ' ' unless scalar(@args) || ($string=~/\W$/) || !($string =~ /^\\/);
      my $params = $$self{parameters};
      $string .= $params->untexArguments(@args) if $params;
    }
    if(defined (my $body = $whatsit->getBody)){
      $string .= $body->untex;
      $string .= $whatsit->getTrailer->untex; }
    $string; }}

# Digest the constructor; This should occur in the Stomach (NOT the Intestine)
# to create a Whatsit, which will be further processed in the Intestine
sub invoke {
  my($self)=@_;
  # Call any `Before' code.
  my @pre = $self->executeBeforeDigest;
  # Parse AND digest the arguments to the Constructor
  my @args = $self->readArguments;
  if(my $params = $$self{parameters}){
    @args = $params->digestArguments(@args); }
  my %props = %{$$self{properties} || {} };
  foreach my $key (keys %props){
    my $value = $props{$key};
    if(ref $value eq 'CODE'){
      $props{$key} = &$value($self); }
    elsif($value && ($value =~/^\#(\d)$/)){
      $props{$key} = $args[$1-1]->toString; }}
  my $whatsit = Whatsit($self,[@args],%props);
  my @post = $self->executeAfterDigest($whatsit,@args);
  if(my $id = $props{id}){
    $STOMACH->recordID($id,$whatsit); }
  if($$self{captureBody}){
    $whatsit->setBody(@post,$STOMACH->digestNextBody); @post=(); }
  (@pre,$whatsit,@post); }

#**********************************************************************
package LaTeXML::ConstructorCompiler;
use LaTeXML::Global;
our $VALUE_RE = "(\\#)";
our $COND_RE  = "\\?($VALUE_RE|IfMath)";
our $QNAME_RE = "([\\w\\-_:]+)";
our $TEXT_RE  = "(.[^\\#<\\?]*)";

our $GEN=0;
sub compileConstructor {
  my($constructor,$cs,$nargs)=@_;
  return sub {} unless $constructor;
  my $name = $cs->getCSName;
  $name =~ s/\W//g;
  $name = "constructor_".$name.'_'.$GEN++;
  my $floats = ($constructor =~ s/^\^\s*//);	# Grab float marker.
  my $body = translate_constructor($constructor,$floats);
  my $code =
    " sub $name {\n"
    ."my(".join(', ','$whatsit', map("\$arg$_",1..$nargs),'$prop').")=\@_;\n"
      ."my \$intestine = \$INTESTINE;\n"
      .($floats ? "my \$savenode;\n" :'')
	. $body
	  . ($floats ? "\$intestine->setNode(\$savenode) if defined \$savenode;\n" : '')
	    . "}\n" ;
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
      $code .= "\$intestine->insertPI('$pi'".($av? ", $av" : '').");\n";
      Fatal("Missing \"?>\" in constructor template at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif(s|^\s*<$QNAME_RE||so){
      my($tag,$av) = ($1,translate_avpairs());
      if($float){
	$code .= "\$savenode=\$intestine->floatToElement('$tag');\n";
	$float = undef; }
      $code .= "\$intestine->openElement('$tag'".($av? ", $av" : '').");\n";
      $code .= "\$intestine->closeElement('$tag');\n" if s|^/||; # Empty element.
      Fatal("Missing \">\" in constructor template at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif(s|^\s*</$QNAME_RE\s*>||so){
      $code .= "\$intestine->closeElement('$1');\n"; }
    # Substitutable value: argument, property...
    elsif(/^$VALUE_RE/o){ 
      $code .= "\$intestine->absorb(".translate_value().");\n"; }
    # Attribute: a=v; assigns in current node? [May conflict with random text!?!]
    elsif(s|^$QNAME_RE\s*=\s*||so){
      my $key = $1;
      if($float){
	$code .= "\$savenode=\$intestine->floatToAttribute('$key');\n";
	$float = undef; }
      $code .= "\$intestine->getNode->setAttribute('$key',".translate_string().");\n"; }
    # Else random text
    elsif(s/^$TEXT_RE//so){	# Else, just some text.
      $code .= "\$intestine->absorb('".slashify($1)."');\n"; }
  }
  $code; }

sub slashify {
  my($string)=@_;
  $string =~ s/\\/\\\\/g;
  $string; }

# parse a conditional in a constructor
# Conditionals are of the form ?value(...)(...),
# Return the translated condition, along with the strings for the if and else clauses.
# It does NOT handled nested conditionals!!! (yet...)
sub parse_conditional {
  s/^\?//;			# Remove leading "?"
  my $bool = (s/^IfMath// ? '$whatsit->isMath'
	      : 'defined('.translate_value().')');
  if(s/^\((.*?)\)(\((.*?)\))?//s){
    ($bool,$1,$3); }
  else {
    Fatal("Unbalanced conditional in constructor template \"$_\""); }}

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, %prop, possibly followed by {foo}, for KeyVals,
# Future enhancements? array ref, &foo(xxx) for function calls, ...
sub translate_value {
  my $value;
  if   (s/^\#(\d+)//     ){ $value = "\$arg$1" }
  elsif(s/^\#([\w\-_]+)//){ $value = "\$\$prop{'$1'}"; }
  elsif(s/$TEXT_RE//so    ){ $value = "'".slashify($1)."'"; }
  # &foo(...) ? Function (but not &foo; !!!)
  # Maybe shouldn't give an error?????
  if(s/^\{$QNAME_RE\}//o){				       # Then accept {key} modifier.
    $value = "((defined $value)&& $value->getValue('$1'))"; }
  # Array???
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

=head1 LaTeXML::Definition, LaTeXML::Expandable, LaTeXML::Primitive, LaTeXML::Register, LaTeXML::Constructor.

=head2 DESCRIPTION

These represent the various executables corresponding to control sequences.
C<LaTeXML::Expandable> represents macros and other expandable control sequences like \if, etc
that are carried out in the Gullet during expansion.
C<LaTeXML::Primitive> represents primitive control sequences that are primarily carried out
for side effect during digestion in the Stomach.
C<LaTeXML::Register> is set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.
C<LaTeXML::Constructor> represents control sequences that contribute arbitrary XML fragments
to the document tree.

More documentation needed, but see LaTeXML::Package for the main user access to these.

=head2 Methods in general

=over 4

=item C<< $defn->readArguments; >>

Reads the arguments for this C<$defn> from the current C<$GULLET>,
returning a list of L<LaTeXML::Tokens>.

=item C<< $defn->invoke; >>

Invoke the action of the C<$defn>.  For expandable definitions, this is done in
the Gullet, and returns a list of L<LaTeXML::Token>s.  For primitives, it
is carried out in the Stomach, and returns a list of L<LaTeXML::Box>es.
For a constructor, it is also carried out by the Stomach, and returns a L<LaTeXML::Whatsit>.
That whatsit will be responsible for constructing the XML document fragment, when the
L<LaTeXML::Intestine> invokes C<$whatsit->beAbsorbed;>.

Primitives and Constructors also support before and after daemons, lists of subroutines
that are executed before and after digestion.  These can be useful for changing modes, etc.

=back

=head2 More about Constructors

A constructor has as it's C<replacement> either a subroutine, or a string pattern representing
the XML fragment it should generate.  In the case of a string pattern, the pattern is
compiled into a subroutine on first usage by the internal class C<LaTeXML::ConstructorCompiler>.
See L<LaTeXML::Package> for a full description of the syntax.

=cut
