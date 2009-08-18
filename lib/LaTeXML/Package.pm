# /=====================================================================\ #
# |  LaTeXML::Package                                                   | #
# | Exports of Defining forms for Package writers                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Package;
use strict;
use Exporter;
use LaTeXML::Global;
use LaTeXML::Definition;
use LaTeXML::Parameters;
use LaTeXML::Util::Pathname;
use Text::Balanced;
use base qw(Exporter);
our @EXPORT = (qw(&DefExpandable
		  &DefMacro &DefMacroI
		  &DefPrimitive  &DefPrimitiveI &DefRegister &DefRegisterI
		  &DefConstructor &DefConstructorI
		  &dualize_arglist
		  &DefMath &DefMathI &DefEnvironment &DefEnvironmentI
		  &convertLaTeXArgs),

	       # Class, Package and File loading.
	       qw(&RequirePackage &LoadClass &FindFile
		  &DeclareOption &PassOptions &ProcessOptions &ExecuteOptions
		  &AddToMacro),

	       # Counter support
	       qw(&NewCounter &CounterValue &StepCounter &RefStepCounter &RefStepID &ResetCounter
		  &GenerateID),

	       # Document Model
	       qw(&Tag &DocType &RelaxNGSchema &RegisterNamespace),

	       # Document Rewriting
	       qw(&DefRewrite &DefMathRewrite
		  &DefLigature &DefMathLigature),

	       # Mid-level support for writing definitions.
	       qw(&Expand &Invocation &Digest
		  &RawTeX &Let),

	       # Support for structured/argument readers
	       qw(&ReadParameters &DefParameterType  &DefColumnType),

	       # Access to State
	       qw(&LookupValue &AssignValue
		  &PushValue &PopValue &UnshiftValue &ShiftValue
		  &LookupCatcode &AssignCatcode
		  &LookupMeaning &LookupDefinition &InstallDefinition),

	       # Random low-level token or string operations.
	       qw(&CleanLabel &CleanIndexKey &CleanBibKey &CleanURL
		  &UTF
		  &roman &Roman),
	       # Math & font state.
	       qw(&MergeFont),

	       qw(&CheckOptions),

	       @LaTeXML::Global::EXPORT);

#**********************************************************************
#   Initially, I thought LaTeXML Packages should try to be like perl modules:
# once loaded, you didn't need to re-load them, only `initialize' them to
# install their definitions into the current stomach.  I tried to achieve
# that through various package tricks.
#    But ultimately, most of a package _is_ installing defns in the stomach,
# and it's probably better to allow a more TeX-like evaluation of definitions
# in order, so \let and such work as expected.
#    So, it got simpler!
# Still, it would be nice if there were `compiled' forms of .ltxml files!
#**********************************************************************

sub UTF {
  my($code)=@_;
  pack('U',$code); }

sub coerceCS {
  my($cs)=@_;
  $cs = T_CS($cs) unless ref $cs;
  $cs = T_CS(ToString($cs)) unless ref $cs eq 'LaTeXML::Token';
  $cs;}

sub parsePrototype {
  my($proto)=@_;
  my $oproto = $proto;
  my $cs;
  if($proto =~ s/^\\csname\s+(.*)\\endcsname//){
    $cs = T_CS('\\'.$1); }
  elsif($proto =~ s/^(\\[a-zA-Z@]+)//){ # Match a cs
    $cs = T_CS($1); }
  elsif($proto =~ s/^(\\.)//){ # Match a single char cs, env name,...
    $cs = T_CS($1); }
  elsif($proto =~ s/^(.)//){ # Match an active char
    ($cs) = TokenizeInternal($1)->unlist; }
  else {
    Fatal(":misdefined:$proto Definition prototype doesn't have proper control sequence: \"$proto\""); }
  $proto =~ s/^\s*//;
  ($cs, parseParameters($proto,$cs)); }

# Convert a LaTeX-style argument spec to our Package form.
# Ie. given $nargs and $optional, being the two optional arguments to
# something like \newcommand, convert it to the form we use
sub XXXXconvertLaTeXArgs {
  my($nargs,$optional)=@_;
  $nargs = (ref $nargs ? $nargs->toString : $nargs || 0);
  my $default = ($optional ? $optional->toString : undef);
  join('', ($optional ? ($default ? "[Default:$default]" : "[]") : ''),
       map('{}',1..($optional ? $nargs-1 : $nargs))); }

sub convertLaTeXArgs {
  my($nargs,$optional)=@_;
  $nargs = $nargs->toString if ref $nargs;
  $nargs = 0 unless $nargs;
  my @params = ();
  if($optional){
    push(@params,LaTeXML::Parameters::newParameter('Optional',
						  "[Default:".$optional->toString."]",
						  extra=>[$optional,undef]));
    $nargs--; }
  push(@params,map(LaTeXML::Parameters::newParameter('Plain','{}'), 1..$nargs));
  LaTeXML::Parameters->new(@params); }

#======================================================================
# Convenience functions for writing definitions.
#======================================================================

sub LookupValue  { $STATE->lookupValue(@_); }
sub AssignValue  { $STATE->assignValue(@_); return; }
sub PushValue    { $STATE->pushValue(@_);  return; }
sub PopValue     { $STATE->popValue(@_); }
sub UnshiftValue { $STATE->unshiftValue(@_);  return; }
sub ShiftValue   { $STATE->shiftValue(@_); }
sub LookupCatcode{ $STATE->lookupCatcode(@_); }
sub AssignCatcode{ $STATE->assignCatcode(@_); return; }

sub LookupMeaning      { $STATE->lookupMeaning(@_); }
sub LookupDefinition   { $STATE->lookupDefinition(@_); }
sub InstallDefinition  { $STATE->installDefinition(@_); }
sub Let {
  my($token1,$token2,$scope)=@_;
  ($token1)=TokenizeInternal($token1)->unlist unless ref $token1;
  ($token2)=TokenizeInternal($token2)->unlist unless ref $token2;
  $STATE->assignMeaning($token1,$STATE->lookupMeaning($token2),$scope); 
  return; }

sub Digest {
  $STATE->getStomach->digest(map((ref $_ ? $_ : Tokenize($_)),@_)); }

sub ReadParameters {
  my($gullet,$spec)=@_;
  my $for = T_OTHER("Anonymous");
  my $parm = parseParameters($spec,$for);
  ($parm ? $parm->readArguments($gullet,$for) : ()); }

# Merge the current font with the style specifications
sub MergeFont { AssignValue(font=>LookupValue('font')->merge(@_), 'local'); }

# Dumb place for this, but where else...
# The TeX way! (bah!! hint: try a large number)
my @rmletters=('i','v',  'x','l', 'c','d', 'm');
sub roman_aux {
  my($n)=@_;
  my $div= 1000;
  my $s=($n>$div ? ('m' x int($n/$div)) : '');
  my $p=4;
  while($n %= $div){
    $div /= 10;
    my $d = int($n/$div);
    if($d%5==4){ $s.= $rmletters[$p]; $d++;}
    if($d > 4 ){ $s.= $rmletters[$p+int($d/5)]; $d %=5; }
    if($d) {     $s.= $rmletters[$p] x $d; }
    $p -= 2;}
  $s; }

# Convert the number to lower case roman numerals, returning a list of LaTeXML::Token
sub roman { Explode(roman_aux(@_)); }
# Convert the number to upper case roman numerals, returning a list of LaTeXML::Token
sub Roman { Explode(uc(roman_aux(@_))); }

#======================================================================
# Cleaners
#======================================================================
# Gradually rethink all these and clarify.
#  Are they intended to be valid ID's (or fragment ids?)

sub CleanLabel {
  my($label,$prefix)=@_;
  my $key = ToString($label);
  $key =~ s/\s+/_/g;
  ($prefix||"LABEL").":".$key; }

sub CleanIndexKey {
  my($key)=@_;
  $key = ToString($key);
  $key =~ s/[^a-zA-Z0-9]//g;
## Shouldn't be case insensitive?
##  $key =~ tr|A-Z|a-z|;
  $key; }

# used as id.
sub CleanBibKey {
  my($key)=@_;
  $key = lc(ToString($key));
  $key =~ s/\s//g;
  $key; }

sub CleanURL {
  my($url)=@_;
  $url = ToString($url);
  $url =~ s/\\~{}/~/g;
  $url; }

#======================================================================
# Defining new Control-sequence Parameter types.
#======================================================================

our $parameter_options = {nargs=>1,reversion=>1,optional=>1,novalue=>1,
			  semiverbatim=>1,undigested=>1};
sub DefParameterType {
  my($type,$reader,%options)=@_;
  CheckOptions("DefParameterType $type",$parameter_options,%options);
  $LaTeXML::Parameters::PARAMETER_TABLE{$type}={reader=>$reader,%options};
  return; 
}

sub DefColumnType {
  my($proto,$expansion)=@_;
  $proto =~ s/^(.)//;
  my $char = $1;
  $proto =~ s/^\s*//;
  my $params = parseParameters($proto,$char);
  $expansion = TokenizeInternal($expansion) unless ref $expansion;
  DefMacroI(T_CS('\NC@rewrite@'.$char),$params,$expansion); }

#======================================================================
# Counters
#======================================================================
# This is modelled on LaTeX's counter mechanisms, but since it also
# provides support for ID's, even where there is no visible reference number,
# it is defined in genera.
# These id's should be both unique, and parallel the visible reference numbers
# (as much as possible).  Also, for consistency, we add id's to unnumbered
# document elements (eg from \section*); this requires an additional counter
# (eg. UNsection) and  mechanisms to track it.

# Defines a new counter named $ctr.
# If $within is defined, $ctr will be reset whenever $within is incremented.
# Keywords:
#  idprefix : specifies a prefix to be used in formatting ID's for document structure elements
#           counted by this counter.  Ie. subsection 3 in section 2 might get: id="S2.SS3"
#  idwithin : specifies that the ID is composed from $idwithin's ID,, even though
#           the counter isn't numbered within it.  (mainly to avoid duplicated ids)
#   nested : a list of counters that correspond to scopes which are "inside" this one.
#           Whenever any definitions scoped to this counter are deactivated,
#           the inner counter's scopes are also deactivated.
#           NOTE: I'm not sure this is even a sensible implementation,
#           or why inner should be different than the counters reset by incrementing this counter.

sub NewCounter { 
  my($ctr,$within,%options)=@_;
  my $unctr = "UN$ctr";		# UNctr is counter for generating ID's for UN-numbered items.
  DefRegisterI(T_CS("\\c\@$ctr"),undef,Number(0));
  AssignValue("\\c\@$ctr"=>Number(0),'global');
  AssignValue("\\cl\@$ctr"=>Tokens(),'global') unless LookupValue("\\cl\@$ctr");
  DefRegisterI(T_CS("\\c\@$unctr"),undef,Number(0));
  AssignValue("\\c\@$unctr"=>Number(0),'global');
  AssignValue("\\cl\@$unctr"=>Tokens(),'global') unless LookupValue("\\cl\@$unctr");
  AssignValue("\\cl\@$within" =>
	      Tokens(T_CS($ctr),T_CS($unctr),
		     (LookupValue("\\cl\@$within") ? LookupValue("\\cl\@$within")->unlist :())),
	      'global') if $within;
  AssignValue("\\cl\@UN$within" =>
	      Tokens(T_CS($unctr),
		     (LookupValue("\\cl\@UN$within") ? LookupValue("\\cl\@UN$within")->unlist :())),
	      'global') if $within;
  AssignValue('nested_counters_'.$ctr =>$options{nested}) if $options{nested};
  DefMacroI(T_CS("\\the$ctr"),undef,"\\arabic{$ctr}",scope=>'global');
  my $prefix = $options{idprefix};
  AssignValue('@ID@prefix@'.$ctr=>$prefix) if $prefix;
  $prefix = LookupValue('@ID@prefix@'.$ctr) unless $prefix;
  if(defined $prefix){
    if(my $idwithin = $options{idwithin} || $within){
      DefMacroI(T_CS("\\the$ctr\@ID"),undef,
	       "\\expandafter\\ifx\\csname the$idwithin\@ID\\endcsname\\\@empty"
	       ."\\else\\csname the$idwithin\@ID\\endcsname.\\fi"
	       ." $prefix\\csname \@$ctr\@ID\\endcsname",
		scope=>'global'); }
    else {
      DefMacroI(T_CS("\\the$ctr\@ID"),undef,"$prefix\\csname \@$ctr\@ID\\endcsname",
		scope=>'global'); }
    DefMacroI(T_CS("\\\@$ctr\@ID"),undef,"0",scope=>'global'); }
  return; }

sub CounterValue {
  my($ctr)=@_;
  $ctr = $ctr->toString if ref $ctr;
  my $value = LookupValue('\c@'.$ctr);
  if(!$value){
    Warn(":expected:<counter> Counter $ctr was not defined; assuming 0");
    $value = Number(0); }
  $value; }

sub StepCounter {
  my($ctr)=@_;
  my $value = CounterValue($ctr);
  AssignValue("\\c\@$ctr"=>$value->add(Number(1)),'global');
  DefMacroI(T_CS("\\\@$ctr\@ID"),undef, Tokens(Explode(LookupValue('\c@'.$ctr)->valueOf)),
	    scope=>'global');
  # and reset any within counters!
  if(my $nested = LookupValue("\\cl\@$ctr")){
    foreach my $c ($nested->unlist){
      ResetCounter($c->toString); }}
  Expand(T_CS("\\the$ctr")); }

# HOW can we retract this?
sub RefStepCounter {
  my($ctr)=@_;
  my $v = StepCounter($ctr);
  DefMacroI(T_CS("\\\@$ctr\@ID"),undef, Tokens(Explode(LookupValue('\c@'.$ctr)->valueOf)),
	    scope=>'global');
  my $id = Expand(T_CS("\\the$ctr\@ID"));
  DefMacroI(T_CS('\@currentlabel'),undef,$v);
  DefMacroI(T_CS('\@currentID'),undef,$id);

  # Any scopes activated for previous value of this counter (& any nested counters) must be removed.
  # This may also include scopes activated for \label
  deactivateCounterScope($ctr);
  # And install the scope (if any) for this reference number.
  AssignValue(current_counter=>$ctr,'local');
  AssignValue('scopes_for_counter:'.$ctr => [$ctr.':'.ToString($v)],'local');
  $STATE->activateScope($ctr.':'.ToString($v));
  (refnum=>$v, id=>$id); }

sub deactivateCounterScope {
  my($ctr)=@_;
#  print STDERR "Unusing scopes for $ctr\n";
 if(my $scopes = LookupValue('scopes_for_counter:'.$ctr)){
    map($STATE->deactivateScope($_), @$scopes); }
  foreach my $inner_ctr (@{LookupValue('nested_counters_'.$ctr) || []}){
    deactivateCounterScope($inner_ctr); }}

# For UN-numbered units
sub RefStepID {
  my($ctr)=@_;
  my $unctr = "UN$ctr";
  my $v = StepCounter($unctr);
  DefMacroI(T_CS("\\\@$ctr\@ID"),undef,
	    Tokens(T_OTHER('x'),Explode(LookupValue('\c@'.$unctr)->valueOf)),
	    scope=>'global');
  my $id = Expand(T_CS("\\the$ctr\@ID"));
  DefMacroI(T_CS('\@currentID'),undef,$id);
  (id=>$id); }

sub ResetCounter {
  my($ctr)=@_;
  AssignValue('\c@'.$ctr => Number(0),'global'); 
  # and reset any within counters!
  if(my $nested = LookupValue("\\cl\@$ctr")){
    foreach my $c ($nested->unlist){
      ResetCounter($c->toString); }}
  return;}

#**********************************************************************
# This function computes an xml:id for a node, if it hasn't already got one.
# It is suitable for use in Tag afterOpen as
#  Tag('ltx:para',afterOpen=>sub { GenerateID(@_,'p'); });
# It generates an id of the form <parentid>.<prefix><number>
sub GenerateID {
  my($document,$node,$whatsit,$prefix)=@_;
  if(!$node->hasAttribute('xml:id')){
    my $parent =  $document->findnode('ancestor::*[@xml:id][1]',$node)
      || $document->getDocument->documentElement;
    my $ctrkey = '_ID_counter_'.$prefix;
    my $ctr = ($parent && $parent->getAttribute($ctrkey)) || 0;
## Old versions don't like this!!!
##    my $parent_id = $parent && $parent->getAttribute('xml:id');
    my $parent_id = $parent && $parent->getAttributeNS("http://www.w3.org/XML/1998/namespace",'id');

    my $id = ($parent_id ? $parent_id."." : '').$prefix. (++$ctr);
    $parent->setAttribute($ctrkey=>$ctr) if $parent;
    $document->setAttribute($node,'xml:id'=>$id);
}}

#======================================================================
# Readers for reading various data types
#======================================================================

sub Expand            { $STATE->getStomach->getGullet->expandTokens(@_); }

sub Invocation        {
  my($token,@args)=@_;
  if(my $defn = LookupDefinition((ref $token ? $token : T_CS($token)))){
    Tokens($defn->invocation(@args)); }
  else {
    Fatal(":undefined:".Stringify($token)." Cannot invoke ".Stringify($token)."; it is undefined");
    Tokens(); }}

#======================================================================
# Non-exported support for defining forms.
#======================================================================
sub CheckOptions {
  my($operation,$allowed,%options)=@_;
  my @badops = grep(!$$allowed{$_}, keys %options);
  Error(":misdefined:$operation $operation does not accept options:".join(', ',@badops)) if @badops;
}

sub requireMath {
  my $cs = ToString($_[0]);
  Warn(":unexpected:$cs $cs should only appear in math mode") unless LookupValue('IN_MATH');
  return; }

sub forbidMath {
  my $cs = ToString($_[0]);
  Warn(":unexpected:$cs $cs should not appear in math mode") if LookupValue('IN_MATH');
  return; }


#**********************************************************************
# Definitions
#**********************************************************************

#======================================================================
# Defining Expandable Control Sequences.
#======================================================================
# Define an expandable control sequence. It will be expanded in the Gullet.
# The $replacement should be a LaTeXML::Tokens (the arguments will be
# substituted for any #1,...), or a sub which returns a list of tokens (or just return;).
# Those tokens, if any, will be reinserted into the input.
# There are no options to these definitions.
our $expandable_options = {isConditional=>1, scope=>1, locked=>1};
sub DefExpandable {
  my($proto,$expansion,%options)=@_;
  Warn(":misdefined:DefExpandable DefExpandable ($proto) is deprecated; use DefMacro");
  DefMacro($proto,$expansion,%options); }

# Define a Macro: Essentially an alias for DefExpandable
# For convenience, the $expansion can be a string which will be tokenized.
our $macro_options = {isConditional=>1, scope=>1, locked=>1};
sub DefMacro {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefMacro ($proto)",$macro_options,%options);
  DefMacroI(parsePrototype($proto),$expansion,%options); }

sub DefMacroI {
  my($cs,$paramlist,$expansion,%options)=@_;
  if(!defined $expansion){ $expansion = Tokens(); }
  $cs = coerceCS($cs);
  $STATE->installDefinition(LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options),
			    $options{scope});
  AssignValue(ToString($cs).":locked"=>1) if $options{locked};
  return; }

sub RawTeX {
  my($text)=@_;
  Digest(TokenizeInternal($text));
  return; }

#======================================================================
# Define a primitive control sequence. 
#======================================================================
# Primitives are executed in the Stomach.
# The $replacement should be a sub which returns nothing, or a list of Box's or Whatsit's.
# The options are:
#    isPrefix  : 1 for things like \global, \long, etc.
#    registerType : for parameters (but needs to be worked into DefParameter, below).

our $primitive_options = {isPrefix=>1,scope=>1, requireMath=>1,
			  forbidMath=>1,beforeDigest=>1, locked=>1};
sub DefPrimitive {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefPrimitive ($proto)",$primitive_options,%options);
  DefPrimitiveI(parsePrototype($proto),$replacement,%options); }

sub DefPrimitiveI {
  my($cs,$paramlist,$replacement,%options)=@_;
  $replacement = sub { (); } unless defined $replacement;
  $cs = coerceCS($cs);
  $STATE->installDefinition(LaTeXML::Primitive
			    ->new($cs,$paramlist,$replacement,
				  beforeDigest=> flatten(($options{requireMath} ? (sub{requireMath($cs);}):()),
							 ($options{forbidMath}  ? (sub{forbidMath($cs);}):()),
							 $options{beforeDigest}),
				  isPrefix=>$options{isPrefix}),
			    $options{scope});
  AssignValue(ToString($cs).":locked"=>1) if $options{locked};
  return; }

our $register_options = {readonly=>1, getter=>1, setter=>1};
our %register_types = ('LaTeXML::Number'   =>'Number',
		       'LaTeXML::Dimension'=>'Dimension',
		       'LaTeXML::Glue'     =>'Glue',
		       'LaTeXML::MuGlue'   =>'MuGlue',
		       'LaTeXML::Tokens'   =>'Tokens',
		       );
sub DefRegister {
  my($proto,$value,%options)=@_;
  CheckOptions("DefRegsiter ($proto)",$register_options,%options);
  DefRegisterI(parsePrototype($proto),$value,%options); }

sub DefRegisterI {
  my($cs,$paramlist,$value,%options)=@_;
  $cs = coerceCS($cs);
  my $type = $register_types{ref $value};
  my $name = $cs->toString;
  my $getter = $options{getter} 
    || sub { LookupValue(join('',$name,map($_->toString,@_))) || $value; };
  my $setter = $options{setter} 
    || ($options{readonly}
	? sub { my($value,@args)=@_; 
		Error(":unexpected:$name Cannot assign to register $name"); return; }
	: sub { my($value,@args)=@_; 
		AssignValue(join('',$name,map($_->toString,@args)) => $value); });
  # Not really right to set the value!
  AssignValue($cs->toString =>$value) if defined $value;
  $STATE->installDefinition(LaTeXML::Register->new($cs,$paramlist, $type,$getter,$setter,
						   readonly=>$options{readonly}),
			   'global');
  return; }

sub flatten {
  [map((defined $_ ? (ref $_ eq 'ARRAY' ? @$_ : ($_)) : ()), @_)]; }

#======================================================================
# Define a constructor control sequence. 
#======================================================================
# The arguments, if any, will be collected and processed in the Stomach, and
# a Whatsit will be constructed.
# It is the Whatsit that will be processed in the Document: It is responsible
# for constructing XML Nodes.  The $replacement should be a sub which inserts nodes, 
# or a string specifying a constructor pattern (See somewhere).
#
# Options are:
#   bounded         : any side effects of before/after daemans are bounded; they are
#                     automatically enclosed by bgroup/egroup pair.
#   mode            : causes a switch into the given mode during the Whatsit building in the stomach.
#   reversion       : a string representing the preferred TeX form of the invocation.
#   beforeDigest    : code to be executed (in the stomach) before parsing & constructing the Whatsit.
#                     Can be used for changing modes, beginning groups, etc.
#   afterDigest     : code to be executed (in the stomach) after parsing & constructing the Whatsit.
#                     useful for setting Whatsit properties,
#   properties      : a hashref listing default values of properties to assign to the Whatsit.
#                     These properties can be used in the constructor.
our $constructor_options = {mode=>1, requireMath=>1, forbidMath=>1, font=>1,
			    reversion=>1, properties=>1, alias=>1, nargs=>1,
			    beforeDigest=>1, afterDigest=>1, beforeConstruct=>1, afterConstruct=>1,
			    captureBody=>1, scope=>1, bounded=>1, locked=>1};
sub DefConstructor {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefConstructor ($proto)",$constructor_options,%options);
  DefConstructorI(parsePrototype($proto),$replacement,%options); }

sub DefConstructorI {
  my($cs,$paramlist,$replacement,%options)=@_;
  $cs = coerceCS($cs);
  my $mode = $options{mode};
  my $bounded = $options{bounded};
  $STATE->installDefinition(LaTeXML::Constructor
			    ->new($cs,$paramlist,$replacement,
				  beforeDigest=> flatten(($options{requireMath} ? (sub{requireMath($cs);}):()),
							 ($options{forbidMath}  ? (sub{forbidMath($cs);}):()),
							 ($mode ? (sub { $_[0]->beginMode($mode); })
							  :($bounded ? (sub {$_[0]->bgroup;}) :()) ),
							 ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
							 $options{beforeDigest}),
				  afterDigest => flatten($options{afterDigest},
							 ($mode ? (sub { $_[0]->endMode($mode) })
							  : ($bounded ? (sub{$_[0]->egroup;}):()) )),
				  beforeConstruct=> flatten($options{beforeConstruct}),
				  afterConstruct => flatten($options{afterConstruct}),
				  nargs       => $options{nargs},
				  alias       => $options{alias},
				  reversion   => ($options{reversion} && !ref $options{reversion} 
						  ? Tokenize($options{reversion}) : $options{reversion}),
				  captureBody => $options{captureBody},
				  properties  => $options{properties}||{}),
			    $options{scope});
  AssignValue(ToString($cs).":locked"=>1) if $options{locked};
  return; }

# DefMath Define a Mathematical symbol or function.
# There are two sets of cases:
#  (1) If the presentation appears to be TeX code, we create an XMDual,
# since the presentation may end up with structure, etc.
#  (2) But if the presentation is a simple string, or unicode, 
# it is just the content of the symbol; even if the function takes arguments.
# ALSO
#  arrange that the operator token gets cs="$cs"
# ALSO
#  Possibly some trick with SUMOP/INTOP affecting limits ?
#  Well, not exactly, but....
# HMM.... Still fishy.
# When to make a dual ?
# If the $presentation seems to be TeX (ie. it involves #1... but not ONLY!)
our $math_options = {name=>1, meaning=>1, omcd=>1, reversion=>1, alias=>1,
		     role=>1, operator_role=>1, reorder=>1, dual=>1,
		     style=>1, font=>1, size=>1,
		     scriptpos=>1,operator_scriptpos=>1,
		     beforeDigest=>1, afterDigest=>1, scope=>1, nogroup=>1,locked=>1};
our $XMID=0;
sub next_id {
##  "LXID".$XMID++; }
  my $docid = LookupValue('DOCUMENTID');
  ($docid ? "$docid.XM" : 'XM').++$XMID; }

sub dualize_arglist {
  my(@args)=@_;
  my(@cargs,@pargs);
  foreach my $arg (@args){
    if(defined $arg){
#      my $id = next_id();
#      push(@cargs, Invocation(T_CS('\@XMArg'),T_OTHER($id),$arg));
#      push(@pargs, Invocation(T_CS('\@XMRef'),T_OTHER($id))); }

      StepCounter('@XMARG');
      DefMacroI(T_CS('\@@XMARG@ID'),undef, Tokens(Explode(LookupValue('\c@@XMARG')->valueOf)),
		scope=>'global');
      my $id = Expand(T_CS('\the@XMARG@ID'));
      push(@cargs, Invocation(T_CS('\@XMArg'),$id,$arg));
      push(@pargs, Invocation(T_CS('\@XMRef'),$id)); }
    else {
      push(@cargs,undef);
      push(@pargs,undef); }}
  ( [@cargs],[@pargs] ); }
# Quick reversal!
#  ( [@pargs],[@cargs] ); }

sub DefMath {
  my($proto,$presentation,%options)=@_;
  CheckOptions("DefMath ($proto)",$math_options,%options);
  DefMathI(parsePrototype($proto),$presentation,%options); }

sub DefMathI {
  my($cs,$paramlist,$presentation,%options)=@_;
  $cs = coerceCS($cs);
  my $nargs = ($paramlist ? scalar($paramlist->getParameters): 0);
  my $csname = $cs->getString;
  my $meaning = $options{meaning};
  my $name = $csname;
  $name =~ s/^\\//;
  $name = $options{name} if defined $options{name};
  $name = undef if (defined $name)
    && (($name eq $presentation) || ($name eq '')
	|| ((defined $meaning) && ($meaning eq $name)));
  my $attr="name='#name' meaning='#meaning' omcd='#omcd' style='#style' size='#size'";
  $options{role} = 'UNKNOWN'
    if ($nargs == 0) && !defined $options{role};
  $options{operator_role} = 'UNKNOWN'
    if ($nargs > 0) && !defined $options{operator_role};
  $options{reversion} = Tokenize($options{reversion})
    if $options{reversion} && !ref $options{reversion};
  # Store some data for introspection
  AssignValue(join("##","math_definition",$csname,$nargs,
		   $options{role}||$options{operator_role}||'',$name||'',
		   (defined $options{meaning} ? $options{meaning} :''),
		   $STATE->getStomach->getGullet->getMouth->getSource,
		   (ref $presentation ? '' : $presentation))=>1, global=>1);

  my %common =(alias=>$options{alias}||$cs->getString,
	       (defined $options{reversion}
		? (reversion=>$options{reversion}) : ()),
	       beforeDigest=> flatten(sub{requireMath($csname);},
				      ($options{nogroup}
				       ? ()
				       :(sub{$_[0]->bgroup;})),
				      ($options{font}
				       ? (sub { MergeFont(%{$options{font}});})
				       :()),
				      $options{beforeDigest}),
	       afterDigest => flatten($options{afterDigest},
				      ($options{nogroup} 
				       ? ()
				       :(sub{$_[0]->egroup;}))),
	       beforeConstruct=> flatten($options{beforeConstruct}),
	       afterConstruct => flatten($options{afterConstruct}),
	       properties => {name=>$name, meaning=>$meaning,
			      omcd=>$options{omcd},
			      role => $options{role},
			      operator_role=>$options{operator_role},
			      style=>$options{style}, 
			      size=>$options{size},
			      scriptpos=>$options{scriptpos},
			      operator_scriptpos=>$options{operator_scriptpos}},
	       scope=>$options{scope});
  # If single character, Make the character active in math.
  if(length($csname) == 1){
    AssignCatcode('math:'.$csname=>1, $options{scope}); }

  # If the presentation is complex, and involves arguments,
  # we will create an XMDual to separate content & presentation.
  # This involves creating 3 control sequences:
  #   \cs              macro that expands into \DUAL{pres}{content}
  #   \cs@content      constructor creates the content branch
  #   \cs@presentation macro that expands into code in the presentation branch.
###  if((ref $presentation eq 'CODE')
###     || ((ref $presentation) && grep($_->equals(T_PARAM),$presentation->unlist))
  if((ref $presentation) || ($presentation =~ /\#\d|\\./)){
    my $cont_cs = T_CS($csname."\@content");
    my $pres_cs = T_CS($csname."\@presentation");
    # Make the original CS expand into a DUAL invoking a presentation macro and content constructor
    $STATE->installDefinition(LaTeXML::Expandable->new($cs,$paramlist, sub {
         my($self,@args)=@_;
	 my($cargs,$pargs)=dualize_arglist(@args);
	 Invocation(T_CS('\DUAL'),
		    ($options{role} ? T_OTHER($options{role}):undef),
		    Invocation($cont_cs,@$cargs),
		    Invocation($pres_cs,@$pargs) )->unlist; }),
      $options{scope});
    # Make the presentation macro.
    $presentation = TokenizeInternal($presentation) unless ref $presentation;
    $presentation = Invocation(T_CS('\@ASSERT@MEANING'), T_OTHER($meaning), $presentation)
      if $meaning;
    $STATE->installDefinition(LaTeXML::Expandable->new($pres_cs, $paramlist,
						       $presentation),
			      $options{scope});
    $STATE->installDefinition(LaTeXML::Constructor->new($cont_cs,$paramlist,
         ($nargs == 0 
	  ? "<ltx:XMTok $attr role='#role' scriptpos='#scriptpos'/>"
	  : "<ltx:XMApp role='#role' scriptpos='#scriptpos'>"
	  .   "<ltx:XMTok $attr role='#operator_role'"
	  .             " scriptpos='#operator_scriptpos'/>"
	  .   join('',map("#$_", 
		  ($options{reorder}? @{$options{reorder}} : (1..$nargs))))
	  ."</ltx:XMApp>"),
      %common), $options{scope}); }
  else {
    my $end_tok = (defined $presentation ? ">$presentation</ltx:XMTok>" : "/>");
    $common{properties}{font} = sub { LookupValue('font')->specialize($presentation); };
    $STATE->installDefinition(LaTeXML::Constructor->new($cs,$paramlist,
         ($nargs == 0 
	  # If trivial presentation, allow it in Text
	  ? ($presentation !~ /(\(|\)|\\)/
	     ? "?#isMath(<ltx:XMTok role='#role' scriptpos='#scriptpos'"
	     .           " font='#font' $attr$end_tok)"
	     .         "($presentation)"
	     : "<ltx:XMTok role='#role' scriptpos='#scriptpos'"
	     .           " font='#font' $attr$end_tok")
	  : "<ltx:XMApp role='#role' scriptpos='#scriptpos'>"
	  .   "<ltx:XMTok $attr font='#font' role='#operator_role'"
	  .             " scriptpos='#operator_scriptpos' $end_tok"
	  .   join('',map("<ltx:XMArg>#$_</ltx:XMArg>", 1..$nargs))
	  ."</ltx:XMApp>"),
         %common), $options{scope}); }
  AssignValue(ToString($cs).":locked"=>1) if $options{locked};
  return; }

#======================================================================
# Define a LaTeX environment
# Note that the body of the environment is treated is the 'body' parameter in the constructor.
our $environment_options = {mode=>1, requireMath=>1, forbidMath=>1,
			    properties=>1, nargs=>1, font=>1,
			    beforeDigest=>1, afterDigest=>1, beforeConstruct=>1, afterConstruct=>1,
			    afterDigestBegin=>1, beforeDigestEnd=>1,
			    scope=>1, locked=>1};
sub DefEnvironment {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefEnvironment ($proto)",$environment_options,%options);
##  $proto =~ s/^\{([^\}]+)\}\s*//; # Pull off the environment name as {name}
##  my $paramlist=parseParameters($proto,"Environment $name");
##  my $name = $1;
  my($name,$paramspec)=Text::Balanced::extract_bracketed($proto,'{}');
  $name =~ s/[\{\}]//g;
  $paramspec =~ s/^\s*//;
  my $paramlist=parseParameters($paramspec,"Environment $name");
  DefEnvironmentI($name,$paramlist,$replacement,%options); }

sub DefEnvironmentI {
  my($name,$paramlist,$replacement,%options)=@_;
  my $mode = $options{mode};
  $name = $name->toString if ref $name;
  # This is for the common case where the environment is opened by \begin{env}
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\begin{$name}"), $paramlist,$replacement,
				   beforeDigest=>flatten(($options{requireMath} ? (sub{requireMath($name);}):()),
							 ($options{forbidMath}  ? (sub{forbidMath($name);}):()),
							 ($mode ? (sub { $_[0]->beginMode($mode);})
							  : (sub {$_[0]->bgroup;})),
							 sub { AssignValue(current_environment=>$name); },
							 ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
							 $options{beforeDigest}),
				   afterDigest =>flatten($options{afterDigestBegin}),
				   beforeConstruct=> flatten(sub{$STATE->pushFrame;},$options{beforeConstruct}),
				   # Curiously, it's the \begin whose afterConstruct gets called.
				   afterConstruct => flatten($options{afterConstruct},sub{$STATE->popFrame;}),
				   nargs=>$options{nargs},
				   captureBody=>1, 
				   properties=>$options{properties}||{},
				  ), $options{scope});
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end{$name}"),"","",
				   beforeDigest =>flatten($options{beforeDigestEnd}),
				   afterDigest=>flatten($options{afterDigest},
							sub { my $env = LookupValue('current_environment');
							      Error(":unexpected:\\end{$name} Cannot close environment $name; current are "
								    .join(', ',$STATE->lookupStackedValues('current_environment')))
								unless $env && $name eq $env; 
							    return; },
							($mode ? (sub { $_[0]->endMode($mode);})
							 :(sub{$_[0]->egroup;}))),
				  ),$options{scope});
  # For the uncommon case opened by \csname env\endcsname
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\$name"), $paramlist,$replacement,
				   beforeDigest=>flatten(($options{requireMath} ? (sub{requireMath($name);}):()),
							 ($options{forbidMath}  ? (sub{forbidMath($name);}):()),
							 ($mode ? (sub { $_[0]->beginMode($mode);}):()),
							 ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
							 $options{beforeDigest}),
				   afterDigest =>flatten($options{afterDigestBegin}),
				   beforeConstruct=> flatten(sub{$STATE->pushFrame;},$options{beforeConstruct}),
				   # Curiously, it's the \begin whose afterConstruct gets called.
				   afterConstruct => flatten($options{afterConstruct},sub{$STATE->popFrame;}),
				   nargs=>$options{nargs},
				   captureBody=>T_CS("\\end$name"), # Required to capture!!
				   properties=>$options{properties}||{}),
			     $options{scope});
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end$name"),"","",
				   beforeDigest =>flatten($options{beforeDigestEnd}),
				   afterDigest=>flatten($options{afterDigest},
							($mode ? (sub { $_[0]->endMode($mode);}):())),
				  ),$options{scope});
  if($options{locked}){
    AssignValue("\\begin{$name}:locked"=>1);
    AssignValue("\\end{$name}:locked"=>1);
    AssignValue("\\$name:locked"=>1);
    AssignValue("\\end$name:locked"=>1); }
  return; }

#======================================================================
# Declaring and Adjusting the Document Model.
#======================================================================

# Specify the properties of a Node tag.
our $tag_options = {autoOpen=>1, autoClose=>1, afterOpen=>1, afterClose=>1};

sub Tag {
  my($tag,%properties)=@_;
  CheckOptions("Tag ($tag)",$tag_options,%properties);
  my $model = $STATE->getModel;
  $model->setTagProperty($tag,autoOpen=>$properties{autoOpen})
    if $properties{autoOpen};
  $model->setTagProperty($tag,autoClose=>$properties{autoClose})
    if $properties{autoClose};
  # ADD after daemons to any already present.
  $model->setTagProperty($tag,
	 afterOpen=>flatten($model->getTagProperty($tag,'afterOpen'),
			    $properties{afterOpen}))
    if $properties{afterOpen};
  $model->setTagProperty($tag,
         afterClose=>flatten($model->getTagProperty($tag,'afterClose'),
			     $properties{afterClose}))
    if $properties{afterClose};
  return; }

sub DocType {
  my($rootelement,$pubid,$sysid,%namespaces)=@_;
  my $model = $STATE->getModel;
  $model->setDocType($rootelement,$pubid,$sysid);
  foreach my $prefix (keys %namespaces){
    $model->registerDocumentNamespace($prefix=>$namespaces{$prefix}); }
  return; }

# What verb here? Set, Choose,...
sub RelaxNGSchema {
  my($schema,%namespaces)=@_;
  my $model = $STATE->getModel;
  $model->setRelaxNGSchema($schema,);
  foreach my $prefix (keys %namespaces){
    $model->registerDocumentNamespace($prefix=>$namespaces{$prefix}); }
  return; }
  
sub RegisterNamespace {
  my($prefix,$namespace)=@_;
  $STATE->getModel->registerNamespace($prefix=>$namespace);
  return; }

sub RegisterDocumentNamespace {
  my($prefix,$namespace)=@_;
  $STATE->getModel->registerDocumentNamespace($prefix=>$namespace);
  return; }

#======================================================================
# Package, Class and File Loading
#======================================================================

# Find a file:
# If the raw option is given, 
#   it searches for the file.
# If $ext is given or $file ends with a known extension
# (eg. .sty for packages, .cls for classes, etc):
#    the file is sought first as $file.$ext.ltxml then as $file.$ext
# Otherwise, the file is sought in a more TeX-like fashion:
#    the file is sought as $file.tex.ltxml, $file.tex, $file.ltxml or $file.
# [ie. if raw=>1, we do _not_ loo for .ltxml forms]
our $findfile_options = {raw=>1, type=>1};
sub FindFile {
  my ($file,%options)=@_;
  CheckOptions("FindFile ($file)",$findfile_options,%options);
  my $paths = LookupValue('SEARCHPATHS');
  $file = ToString($file);
  $file .= ".$options{type}" if $options{type};
  if($options{raw}){
    pathname_find("$file",paths=>$paths); }
  elsif($options{type} || ($file =~ /\.(tex|pool|sty|cls|clo|cnf|cfg)$/)){ # explicit or known extensions
    pathname_find("$file.ltxml",paths=>$paths,installation_subdir=>'Package')
      || pathname_find("$file",paths=>$paths); }
  else {
    pathname_find("$file.tex.ltxml",paths=>$paths,installation_subdir=>'Package')
      || pathname_find("$file.tex",paths=>$paths)
	|| pathname_find("$file.ltxml",paths=>$paths,installation_subdir=>'Package')
	  || pathname_find("$file",paths=>$paths); }}

# Declare an option for the current package or class
# If $option is undef, it is the default.
# $code can be a sub (as a primitive), or a string to be expanded.
# (effectively a macro)

sub DeclareOption {
  my($option,$code)=@_;
  $option = ToString($option) if ref $option;
  PushValue('@declaredoptions',$option) if $option;
  my $cs = ($option ? '\ds@'.$option : '\default@ds');
  # print STDERR "Declaring option: ".($option ? $option : '<default>')."\n";
  if((!defined $code) || (ref $code eq 'CODE')){
    DefPrimitiveI($cs,undef,$code); }
  else {
    DefMacroI($cs,undef,$code); }
  return; }

# Pass the sequence of @options to the package $name (if $ext is 'sty'),
# or class $name (if $ext is 'cls').
sub PassOptions {
  my($name,$ext,@options)=@_;
  PushValue('opt@'.$name.'.'.$ext, map(ToString($_),@options));
  # print STDERR "Passing to $name.$ext options: ".join(', ',@options)."\n";
  return; }

# Process the options passed to the currently loading package or class.
# If inorder=>1, they are processed in the order given (like \ProcessOptions*),
# otherwise, they are processed in the order declared.
# Unless noundefine=>1 (like for \ExecuteOptions), all option definitions
# undefined after execution.
our $processoptions_options = {inorder=>1};
sub ProcessOptions {
  my(%options)=@_;
  CheckOptions("ProcessOptions",$processoptions_options,%options);
  my $name = ToString(Digest(T_CS('\@currname')));
  my $ext  = ToString(Digest(T_CS('\@currext')));
  my @declaredoptions = @{LookupValue('@declaredoptions')};
  my @curroptions     = @{LookupValue('opt@'.$name.'.'.$ext)};
#  print STDERR "\nProcessing options for $name.$ext: ".join(', ',@curroptions)."\n";

  my $defaultcs = T_CS('\default@ds');
  # Execute options in declared order (unless \ProcessOptions*)

  if($options{inorder}){	# Execute options in order (eg. \ProcessOptions*)
    foreach my $option (@curroptions){
      DefMacroI('\CurrentOption',undef,$option);
      my $cs = T_CS('\ds@'.$option);
      if(LookupDefinition($cs)){
#	print STDERR "\nUsing option $option to $name.$ext\n";
	Digest($cs); }
      elsif($defaultcs){
#	print STDERR "\nUsing option $option to $name.$ext with default handler\n";
	Digest($defaultcs); }}}
  else {			# Execute options in declared order (eg. \ProcessOptions)
    foreach my $option (@declaredoptions){
      if(grep($option eq $_,@curroptions)){
	@curroptions = grep($option ne $_, @curroptions); # Remove it, since it's been handled.
#	 print STDERR "\nUsing option $option  to $name.$ext\n";
	DefMacroI('\CurrentOption',undef,$option);
	Digest(T_CS('\ds@'.$option)); }}
    # Now handle any remaining options (eg. default options), in the given order.
    foreach my $option (@curroptions){
      DefMacroI('\CurrentOption',undef,$option);
#      print STDERR "\nUsing option $option to $name.$ext with default handler\n";
      Digest($defaultcs); }}
  # Now, undefine the handlers?
  foreach my $option (@declaredoptions){
    Let(T_CS('\ds@'.$option),T_CS('\relax')); }
  return; }

sub ExecuteOptions {
  my(@options)=@_;
  my %unhandled=();
  foreach my $option (@options){
    my $cs = T_CS('\ds@'.$option);
    if(LookupDefinition($cs)){
      DefMacroI('\CurrentOption',undef,$option);
      Digest($cs); }
    else {
      $unhandled{$option}=1; }}
  Warn(":unexpected:<option> Unrecognized options passed to ExecuteOptions: ".join(', ',sort keys %unhandled))
    if keys %unhandled; 
  return; }

sub resetOptions {
  AssignValue('@declaredoptions',[]);
  Let(T_CS('\default@ds'),
      (ToString(Digest(T_CS('\@currext'))) eq 'cls'
       ? T_CS('\OptionNotUsed') : T_CS('\@unknownoptionerror')));
}

sub AddToMacro {
  my($cs,$tokens)=@_;
  # Needs error checking!
  my $defn = LookupDefinition($cs);
  DefMacroI($cs,undef,Tokens($defn->getExpansion->unlist,$tokens->unlist)); }

our $require_options = {options=>1, withoptions=>1, type=>1, as_class=>1, raw=>1, after=>1};
sub RequirePackage {
  my($package,%options)=@_;
  $package = ToString($package) if ref $package;
  $package =~ s/^\s*//;  $package =~ s/\s*$//;
  CheckOptions("RequirePackage ($package)",$require_options,%options);
  my $prevname = LookupDefinition(T_CS('\@currname')) && ToString(Digest(T_CS('\@currname')));
  my $prevext  = LookupDefinition(T_CS('\@currext')) && ToString(Digest(T_CS('\@currext')));

  $options{type} = 'sty' unless $options{type};
  # This package will be treated somewhat as if it were a class if as_class is true
  # OR if it is loaded by such a class, and has withoptions true!!!
  $options{as_class} = 1 if  $options{withoptions}
    && grep($prevname eq $_, @{LookupValue('@masquerading@as@class')||[]});
  my $filetype = $options{type};
  my $type = ($options{as_class} ? 'cls' : $options{type});
  # For \RequirePackageWithOptions, pass the options from the outer class/style to the inner one.
  if($options{withoptions} && $prevname){
    PassOptions($package,$type,@{LookupValue('opt@'.$prevname.".".$prevext)}); }
  DefMacroI('\@currname',undef,Tokens(Explode($package)));
  DefMacroI('\@currext',undef,Tokens(Explode($type)));
  # reset options
  resetOptions();
  PassOptions($package,$type,@{$options{options} || []});
  if(my $file = FindFile($package, type=>$filetype, raw=>$options{raw})){
    # Note which packages are pretending to be classes.
    PushValue('@masquerading@as@class',$package) if $options{as_class};
    DefMacroI(T_CS("\\$package.$type-hook"),undef,$options{after} || '');
    my $gullet = $STATE->getStomach->getGullet;
    $gullet->input($file,undef,%options); 
    Digest(T_CS("\\$package.$type-hook"));
    DefMacroI('\@currname',undef,Tokens(Explode($prevname))) if $prevname;
    DefMacroI('\@currext',undef,Tokens(Explode($prevext))) if $prevext;
    resetOptions(); } # And reset options afterwards, too.
  else {
    $STATE->noteStatus(missing=>$package);
    Error(":missing_file:$package Cannot find package $package"
	  .($type eq 'sty' ? '' : "(w/type=$type)")
	  ." in paths ".join(', ',@{$STATE->lookupValue('SEARCHPATHS')})); }
  return; }

our $loadclass_options = {options=>1, withoptions=>1, after=>1};
sub LoadClass {
  my($class,%options)=@_;
  $class = ToString($class) if ref $class;
  $class =~ s/^\s*//;  $class =~ s/\s*$//;
  CheckOptions("LoadClass ($class)",$loadclass_options,%options);
  $options{type} = 'cls' unless $options{type};
  my $type = $options{type};
  my $prevname = LookupDefinition(T_CS('\@currname')) && ToString(Digest(T_CS('\@currname')));
  my $prevext  = LookupDefinition(T_CS('\@currext')) && ToString(Digest(T_CS('\@currext')));
  # For \LoadClassWithOptions, pass the options from the outer class to the inner one.
  if($options{withoptions} && $prevname){
    PassOptions($class,$type,@{LookupValue('opt@'.$prevname.".".$prevext)}); }
  DefMacroI('\@currname',undef,Tokens(Explode($class)));
  DefMacroI('\@currext',undef,Tokens(Explode($type)));
  PassOptions($class,$type,@{$options{options} || []});
  # What about "global options" ??????
  resetOptions();
  my $classfile = FindFile($class, type=>$type, raw=>$options{raw});
  if(!$classfile || ($classfile =~ /\.\Q$type\E$/)){
    Warn(":missing_file:$class.cls.ltxml No LaTeXML implementation of class $class found, using article");
    if(!($classfile = FindFile("article.cls"))){
      Fatal(":missing_file:article.cls.ltxml Installation error: Cannot find article implementation!"); }}
  DefMacroI(T_CS("\\$class.$type-hook"),undef,$options{after} || '');
  my $gullet = $STATE->getStomach->getGullet;
##  $gullet->openMouth(Tokens(T_CS("\\$class.$type-hook")));
  $gullet->input($classfile,undef,%options);
  Digest(T_CS("\\$class.$type-hook"));
  DefMacroI('\@currname',undef,Tokens(Explode($prevname))) if $prevname;
  DefMacroI('\@currext',undef,Tokens(Explode($prevext))) if $prevext;
  resetOptions();  # And reset options afterwards, too.
  return; }


#======================================================================
# Defining Rewrite rules that act on the DOM

our $rewrite_options = {label=>1,scope=>1, xpath=>1, match=>1,
			 attributes=>1, replace=>1, regexp=>1};
sub DefRewrite {
  my(@specs)=@_;
  CheckOptions("DefRewrite",$rewrite_options,@specs);
  $STATE->getModel->addRewriteRule('text',@specs); 
  return; }

sub DefMathRewrite {
  my(@specs)=@_;
  CheckOptions("DefRewrite",$rewrite_options,@specs);
  $STATE->getModel->addRewriteRule('math',@specs); 
  return; }

our $ligature_options = {fontTest=>1};
sub DefLigature {
  my($regexp,%options)=@_;
  CheckOptions("DefLigature",$ligature_options,%options);
  $STATE->getModel->addLigature($regexp,%options);
  return; }

#our $math_ligature_options = {fontTest=>1, nodeText=>1, attributes=>1};
sub DefMathLigature {
  my($matcher)=@_;
#  CheckOptions("DefMathLigature",$math_ligature_options,%options);
  $STATE->getModel->addMathLigature($matcher);
  return; }
#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Package> - Support for package implementations and document customization.

=head1 SYNOPSIS

This package defines and exports most of the procedures users will need
to customize or extend LaTeXML. The LaTeXML implementation of some
package might look something like the following, but see the
installed C<LaTeXML/Package> directory for realistic examples.

  use LaTeXML::Package;
  use strict;
  #
  # Load "anotherpackage"
  RequirePackage('anotherpackage');
  #
  # A simple macro, just like in TeX
  DefMacro('\thesection', '\thechapter.\roman{section}');
  #
  # A constructor defines how a control sequence generates XML:
  DefConstructor('\thanks{}', "<ltx:thanks>#1</ltx:thanks>");
  #
  # And a simple environment ...
  DefEnvironment('{abstract}','<abstract>#body</abstract>');
  #
  # A math  symbol \Real to stand for the Reals:
  DefMath('\Real', "\x{211D}", role=>'ID');
  #
  # Or a semantic floor:
  DefMath('\floor{}','\left\lfloor#1\right\rfloor');
  #
  # More esoteric ...
  # Use a RelaxNG schema
  RelaxNGSchema("MySchema");
  # Or use a special DocType if you have to:
  # DocType("rootelement",
  #         "-//Your Site//Your DocType",'your.dtd',
  #          prefix=>"http://whatever/");
  #
  # Allow sometag elements to be automatically closed if needed
  Tag('prefix:sometag', autoClose=>1);
  #
  # Don't forget this, so perl knows the package loaded.
  1;


=head1 DESCRIPTION

To provide a LaTeXML-specific version of a LaTeX package C<mypackage.sty>
or class C<myclass.cls> (so that eg. C<\usepackage{mypackage}> works),
you create the file C<mypackage.sty.ltxml> or C<myclass.cls.ltxml>
and save it in the searchpath (current directory, or one of the directories
given to the --path option, or possibly added to the variable SEARCHPATHS).
Similarly, to provide document-specific customization for, say, C<mydoc.tex>,
you would create the file C<mydoc.latexml> (typically in the same directory).
However,  in the first cases, C<mypackage.sty.ltxml> are loaded I<instead> of
C<mypackage.sty>, while a file like C<mydoc.latexml> is loaded in I<addition> to
C<mydoc.tex>.
In either case, you'll C<use LaTeXML::Package;> to import the various declarations
and defining forms that allow you to specify what should be done with various
control sequences, whether there is special treatment of certain document elements,
and so forth.  Using C<LaTeXML::Package> also imports the functions and variables
defined in L<LaTeXML::Global>, so see that documentation as well.

Since LaTeXML attempts to mimic TeX, a familiarity with TeX's processing
model is also helpful.  Additionally, it is often useful, when implementing
non-trivial behaviour, to think TeX-like.

Many of the following forms take code references as arguments or options.
That is, either a reference to a defined sub, C<\&somesub>, or an
anonymous function S<sub { ... }>.  To document these cases, and the
arguments that are passed in each case, we'll use a notation like
S<CODE($token,..)>.

=head2 Control Sequences

Many of the following forms define the behaviour of control sequences.
In TeX you'll typically only define macros. In LaTeXML, we're
effectively redefining TeX itself,  so we define macros as well as primitives,
registers, constructors and environments.  These define the behaviour
of these commands when processed during the various phases of LaTeX's
immitation of TeX's digestive tract.

The first argument to each of these defining forms (C<DefMacro>, C<DefPrimive>, etc)
is a I<prototype> consisting of the control sequence being defined along with
the specification of parameters required by the control sequence.
Each parameter describes how to parse tokens following the control sequence into
arguments or how to delimit them.  To simplify coding and capture common idioms
in TeX/LaTeX programming, latexml's parameter specifications are more expressive
than TeX's  C<\def> or LaTeX's C<\newcommand>.  Examples of the prototypes for
familiar TeX or LaTeX control sequences are:

   DefConstructor('\usepackage[]{}',...
   DefPrimitive('\multiply Variable SkipKeyword:by Number',..
   DefPrimitive('\newcommand OptionalMatch:* {Token}[][]{}', ...

=head3 Control Sequence Parameters

The general syntax for parameter for a control sequence is something like

  OpenDelim? Modifier? Type (: value (| value)* )? CloseDelim?

The enclosing delimiters, if any, are either {} or [], affect the way the
argument is delimited.  With {}, a regular TeX argument (token or sequence
balanced by braces) is read before parsing according to the type (if needed).
With [], a LaTeX optional argument is read, delimited by (non-nested) square brackets.

The modifier can be either C<Optional> or C<Skip>, allowing the argument to
be optional. For C<Skip>, no argument is contributed to the argument list.

The shorthands {} and [] default the type to C<Plain> and reads a normal
TeX argument or LaTeX default argument.

The predefined argument types are as follows.

=over

=item C<Plain>, C<Semiverbatim>

Reads a standard TeX argument being either the next token, or if the
next token is an {, the balanced token list.  In the case of C<Semiverbatim>,
many catcodes are disabled, which is handy for URL's, labels and similar.

=item C<Token>, C<XToken>

Read a single TeX Token.  For C<XToken>, if the next token is expandable,
it is repeatedly expanded until an unexpandable token remains, which is returned.

=item C<Number>, C<Dimension>, C<Glue> or C<MuGlue>

Read an Object corresponding to Number, Dimension, Glue or MuGlue,
using TeX's rules for parsing these objects.

=item C<Until:>I<match>

Reads tokens until a match to the tokens I<match> is found, returning
the tokens preceding the match.  This corresponds to TeX delimited arguments.

=item C<UntilBrace>

Reads tokens until the next open brace C<{>.  
This corresponds to the peculiar TeX construct C<\def\foo#{...>.

=item C<Match:>I<match(|match)*>, C<Keyword:>I<match(|match)*>

Reads tokens expecting a match to one of the token lists I<match>,
returning the one that matches, or undef.
For C<Keyword>, case and catcode of the I<matches> are ignored.
Additionally, any leading spaces are skipped.

=item C<Balanced>

Read tokens until a closing }, but respecting nested {} pairs.

=item C<Variable>

Reads a token, expanding if necessary, and expects a control sequence naming
a writable register.  If such is found, it returns an array of the corresponding
definition object, and any arguments required by that definition.

=item C<SkipSpaces>

Skips any space tokens, but contributes nothing to the argument list.

=back

=head3 Control of Scoping

Most defining commands accept an option to control how the definition is stored,
C<< scope=>$scope >>, where C<$scope> can be c<'global'> for global definitions,
C<'local'>, to be stored in the current stack frame, or a string naming a I<scope>.
A scope saves a set of definitions and values that can be activated at a later time.

Particularly interesting forms of scope are those that get automatically activated
upon changes of counter and label.  For example, definitions that have
C<< scope=>'section:1.1' >>  will be activated when the section number is "1.1",
and will be deactivated when the section ends.

=head3 Macros

=over

=item C<< DefMacro($prototype,$string | $tokens | $code,%options); >>

Defines the macro expansion for C<$prototype>.  If a C<$string> is supplied, it will be
tokenized at definition time, and any macro arguments will be substituted for parameter
indicators (eg #1) at expansion time; the result is used as the expansion of
the control sequence. 
The only option, other than C<scope>, is C<isConditional> which should be true,
for conditional control sequences (TeX uses these to keep track of conditional
nesting when skipping to \else or \fi).

If defined by C<$code>, the form is C<CODE($gullet,@args)> and it
must return a list of L<LaTeXML::Token>'s.

=item C<< DefMacroI($cs,$paramlist,$string | $tokens | $code,%options); >>

Internal form of C<DefMacro> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.
Also, slightly more efficient for macros with no arguments (use C<undef> for
C<$paramlist>).

=back

=head3 Primitives

=over

=item C<< DefPrimitive($prototype,CODE($stomach,@args),%options); >>

Define a primitive control sequence.
These are usually done for side effect and
so CODE should end with C<return;>, but can also
return a list of digested items.

The only option is for the special case: C<< isPrefix=>1 >> is used for assignment
prefixes (like \global).

=item C<< DefPrimitiveI($cs,$paramlist,CODE($stomach,@args),%options); >>

Internal form of C<DefPrimitive> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=item C<< DefRegister($prototype,$value,%options); >>

Defines a register with the given initial value (a Number, Dimension, Glue, MuGlue or Tokens
--- I haven't handled Box's yet).  Usually, the C<$prototype> is just the control sequence,
but registers are also handled by prototypes like C<\count{Number}>. C<DefRegister> arranges
that the register value can be accessed when a numeric, dimension, ... value is being read,
and also defines the control sequence for assignment.

Options are

=over

=item C<readonly>

specifies if it is not allowed to change this value.

=item C<getter>=>CODE(@args)
=item C<setter>=>CODE($value,@args)

By default the value is stored in the State's Value table under a name concatenating the 
control sequence and argument values.  These options allow other means of fetching and
storing the value.

=back

=item C<< DefRegisterI($cs,$paramlist,$value,%options); >>

Internal form of C<DefRegister> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=back

=head3 Constructors

=over

=item C<< DefConstructor($prototype,$xmlpattern | $code,%options); >>

The Constructor is where LaTeXML really starts getting interesting;
invoking the control sequence will generate an arbitrary XML
fragment in the document tree.  More specifically: during digestion, the arguments
will be read and digested, creating a L<LaTeXML::Whatsit> to represent the object. During
absorbtion by the L<LaTeXML::Document>, the C<Whatsit> will generate the XML fragment according
to the replacement C<$xmlpattern>, or by executing C<CODE>.

The C<$xmlpattern> is simply a bit of XML as a string with certain substitutions to be made.
The substitutions are of the following forms:

If code is supplied,  the form is C<CODE($document,@args,%properties)>

=over

=item  #1, #2 ... #name

These are replaced by the corresponding argument (for #1) or property (for #name)
stored with the Whatsit. Each are turned into a string when it appears as
in an attribute position, or recursively processed when it appears as content.

=item C<&function(@args)>

Another form of substituted value is prefixed with C<&> which invokes a function.
For example, C< &func(#1) > would invoke the function C<func> on the first argument
to the control sequence; what it returns will be inserted into the document.

=item C<?COND(pattern)>  or C<?COND(ifpattern)(elsepattern)>

Patterns can be conditionallized using this form.  The C<COND> is any
of the above expressions, considered true if the result is non-empty.
Thus C<< ?#1(<foo/>) >> would add the empty element C<foo> if the first argument
were given.

=item C<^>

If the constuctor I<begins> with C<^>, the XML fragment is allowed to I<float up>
to a parent node that is allowed to contain it, according to the Document Type.

=back

The Whatsit property C<font> is defined by default.  Additional properties
C<body> and C<trailer> are defined when C<captureBody> is true, or for environments.
By using C<< $whatsit->setProperty(key=>$value); >> within C<afterDigest>,
or by using the C<properties> option, other properties can be added.

DefConstructor options are

=over

=item  mode=>(text|display_math|inline_math)

Changes to this mode during digestion.

=item  bounded=>boolean

If true, TeX grouping (ie. C<{}>) is enforced around this invocation.

=item  requireMath=>boolean

=item  forbidMath=>boolean

These specify whether the given constructor can only appear,
or cannot appear, in math mode.

=item  font=>{fontspec...}

Specifies the font to be set by this invocation.
See L</MergeFont>
If the font change is to only apply to this construct,
you would also use C<<bounded=>1>>.

=item  reversion=>$texstring or CODE($whatsit,#1,#2,...)

Specifies the reversion of the invocation back into TeX tokens
(if the default reversion is not appropriate).
The $textstring string can include #1,#2...
The CODE is called with the $whatsit and digested arguments.

=item  properties=>{prop=>value,...} or CODE($stomach,#1,#2...)

This option supplies additional properties to be set on the
generated Whatsit.  In the first form, the values can
be of any type, but (1) if it is a code references, it takes
the same args ($stomach,#1,#2,...) and should return a value.
and (2) if the value is a string, occurances of #1 (etc) are
replaced by the corresponding argument.
In the second form, the code should return a hash of properties.

=item  beforeDigest=>CODE($stomach)

This option supplies a Daemon to be executed during digestion 
just before the Whatsit is created.  The CODE should either
return nothing (return;) or a list of digested items (Box's,List,Whatsit).
It can thus change the State and/or add to the digested output.

=item  afterDigest=>CODE($stomach,$whatsit)

This option supplies a Daemon to be executed during digestion
just after the Whatsit is created. it should either return
nothing (return;) or digested items.  It can thus change the State,
modify the Whatsit, and/or add to the digested output.

=item  beforeConstruct=>CODE($document,$whatsit)

Supplies CODE to execute before constructing the XML
(generated by $replacement).

=item  afterConstruct=>CODE($document,$whatsit)

Supplies CODE to execute after constructing the XML.

=item  captureBody=>boolean or Token

if true, arbitrary following material will be accumulated into
a `body' until the current grouping level is reverted,
or till the C<Token> is encountered if the option is a C<Token>.
This body is available as the C<body> property of the Whatsit.
This is used by environments and math.

=item  alias=>$control_sequence

Provides a control sequence to be used when reverting Whatsit's back to Tokens,
in cases where it isn't the command used in the C<$prototype>.

=item  nargs=>$nargs

This gives a number of args for cases where it can't be infered directly
from the C<$prototype> (eg. when more args are explictly read by Daemons).

=item  scope=>$scope

See L</scope>.

=back

=item C<< DefConstructorI($cs,$paramlist,$xmlpattern | $code,%options); >>

Internal form of C<DefConstructor> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=item C<< DefMath($prototype,$tex,%options); >>

A common shorthand constructor; it defines a control sequence that creates a mathematical object,
such as a symbol, function or operator application.  
The options given can effectively create semantic macros that contribute to the eventual
parsing of mathematical content.
In particular, it generates an XMDual using the replacement $tex for the presentation.
The content information is drawn from the name and options

These C<DefConstructor> options also apply:

  reversion, alias, beforeDigest, afterDigest,
  beforeConstruct, afterConstruct and scope.

Additionally, it accepts

=over

=item  style=>astyle

adds a style attribute to the object.

=item  name=>aname

gives a name attribute for the object

=item  omcd=>cdname

gives the OpenMath content dictionary that name is from.

=item  role=>grammatical_role

adds a grammatical role attribute to the object; this specifies
the grammatical role that the object plays in surrounding expressions.
This direly needs documentation!

=item  font=>{fontspec}

Specifies the font to be used for when creating this object.
See L</MergeFont>.

=item scriptpos=>boolean

Controls whether any sub and super-scripts will be stacked over or under this
object, or whether they will appear in the usual position.

WRONG: Redocument this!

=item operator_role=>grammatical_role

=item operator_scriptpos=>boolean

These two are similar to C<role> and C<scriptpos>, but are used in
unusual cases.  These apply to the given attributes to the operator token
in the content branch.

=item  nogroup=>boolean

Normally, these commands are digested with an implicit grouping around them,
so that changes to fonts, etc, are local.  Providing C<<noggroup=>1>> inhibits this.

=back

=item C<< DefMathI($cs,$paramlist,$tex,%options); >>

Internal form of C<DefMath> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=item C<< DefEnvironment($prototype,$replacement,%options); >>

Defines an Environment that generates a specific XML fragment.  The C<$replacement> is
of the same form as that for DefConstructor, but will generally include reference to
the C<#body> property. Upon encountering a C<\begin{env}>:  the mode is switched, if needed,
else a new group is opened; then the environment name is noted; the beforeDigest daemon is run.
Then the Whatsit representing the begin command (but ultimately the whole environment) is created
and the afterDigestBegin daemon is run.
Next, the body will be digested and collected until the balancing C<\end{env}>.   Then,
any afterDigest daemon is run, the environment is ended, finally the mode is ended or
the group is closed.  The body and C<\end{env}> whatsit are added to the C<\begin{env}>'s whatsit
as body and trailer, respectively.


It shares options with C<DefConstructor>:

 mode, requireMath, forbidMath, properties, nargs,
 font, beforeDigest, afterDigest, beforeConstruct, 
 afterConstruct and scope.

Additionally, C<afterDigestBegin> is effectively an C<afterDigest>
for the C<\begin{env}> control sequence.


=item C<< DefEnvironmentI($name,$paramlist,$replacement,%options); >>

Internal form of C<DefEnvironment> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=back

=head2 Class and Packages

=over

=item C<< RequirePackage($package,%options); >>

Finds and loads a package implementation (usually C<*.sty.ltxml>, unless C<raw> is specified)
for the required C<$package>.
The options are:

=over

=item C<< type=>type >> specifies the file type (default C<sty>.

=item C<< options=>[...] >> specifies a list of package options.

=item C<< raw=>1 >> specifies that it is allowable to try to read a raw TeX style file.

=back

=item C<< LoadClass($class,%options); >>

Finds and loads a class definition (usually C<*.cls.ltxml>).
The only option is

=over

=item C<< options=>[...] >> specifies a list of class options.

=back

=item C<< FindFile($name,%options); >>

Find an appropriate file with the given C<$name> in the current directories
in C<SEARCHPATHS>.
If a file ending with C<.ltxml> is found, it will be preferred.
The options are:

=over

=item C<< type=>type >> specifies the file type (default C<sty>.

=item C<< raw=>1 >> specifies that it is allowable to try to read a raw TeX style file.

=back

=item C<< DeclareOption($option,$code); >>

Declares an option for the current package or class.
The C<$code> can be a string or Tokens (which will be macro expanded),
or can be a code reference which is treated as a primitive.

If a package or class wants to accomodate options, it should start
with one or more C<DeclareOptions>, followed by C<ProcessOptions()>.

=item C<< PassOptions($name,$ext,@options); >>

Causes the given C<@options> (strings) to be passed to the
package (if C<$ext> is C<sty>) or class (if C<$ext> is C<cls>)
named by C<$name>.

=item C<< ProcessOptions(); >>

Processes the options that have been passed to the current package
or class in a fashion similar to LaTeX.  If the keyword
C<< inorder=>1 >> is given, the options are processed in the
order they were used, like C<ProcessOptions*>.

=item C<< ExecuteOptions(@options); >>

Process the options given explicitly in C<@options>.

=back

=head2 Counters and IDs

=over 4

=item C<< NewCounter($ctr,$within,%options); >>

Defines a new counter, like LaTeX's \newcounter, but extended.
It defines a counter that can be used to generate reference numbers,
and defines \the$ctr, etc. It also defines an "uncounter" which
can be used to generate ID's (xml:id) for unnumbered objects.
C<$ctr> is the name of the counter.  If defined, C<$within> is the name
of another counter which, when incremented, will cause this counter
to be reset.
The options are

   idprefix  Specifies a prefix to be used to generate ID's
             when using this counter
   nested    Not sure that this is even sane.

=item C<< $num = CounterValue($ctr); >>

Fetches the value associated with the counter C<$ctr>.

=item C<< $tokens = StepCounter($ctr); >>

Analog of C<\stepcounter>, steps the counter and returns the expansion of
C<\the$ctr>.  Usually you should use C<RefStepCounter($ctr)> instead.

=item C<< $keys = RefStepCounter($ctr); >>

Analog of C<\refstepcounter>, steps the counter and returns a hash
containing the keys C<refnum=>$refnum, id=>$id>.  This makes it
suitable for use in a C<properties> option to constructors.
The C<id> is generated in parallel with the reference number
to assist debugging.

=item C<< $keys = RefStepID($ctr); >>

Like to C<RefStepCounter>, but only steps the "uncounter",
and returns only the id;  This is useful for unnumbered cases
of objects that normally get both a refnum and id.

=item C<< ResetCounter($ctr); >>

Resets the counter C<$ctr> to zero.

=item C<< GenerateID($document,$node,$whatsit,$prefix); >>

Generates an ID for nodes during the construction phase, useful
for cases where the counter based scheme is inappropriate.
The calling pattern makes it appropriate for use in Tag, as in
   Tag('ltx:para',sub { GenerateID(@_,'p'); })

If C<$node> doesn't already have an xml:id set, it computes an
appropriate id by concatenating the xml:id of the closest
ancestor with an id (if any), the prefix and a unique counter.

=back

=head2 Document Model

Constructors define how TeX markup will generate XML fragments, but the
Document Model is used to control exactly how those fragments are assembled.

=over

=item C<< Tag($tag,%properties); >>

Declares properties of elements with the name C<$tag>.

The recognized properties are:

=over

=item autoOpen=>boolean

Specifies whether this $tag can be automatically opened
if needed to insert an element that can only
be contained by $tag.
This property can help match the more  SGML-like LaTeX to XML.

=item  autoClose=>boolean

Specifies whether this $tag can be automatically closed
if needed to close an ancestor node, or insert
an element into an ancestor.
This property can help match the more  SGML-like LaTeX to XML.

=item afterOpen=>CODE($document,$box)

Provides CODE to be run whenever a node with this $tag
is opened.  It is called with the document being constructed,
and the initiating digested object as arguments.
It is called after the node has been created, and after
any initial attributes due to the constructor (passed to openElement)
are added.

=item afterClose=>CODE($document,$box)

Provides CODE to be run whenever a node with this $tag
is closed.  It is called with the document being constructed,
and the initiating digested object as arguments.

=back

=item C<< RelaxNGSchema($schemaname); >>

Specifies the schema to use for determining document model.
You can leave off the extension; it will look for C<.rng>,
and maybe eventually, C<.rnc> once that is implemented.

=item C<< RegisterNamespace($prefix,$URL); >>

Declares the C<$prefix> to be associated with the given C<$URL>.
These prefixes may be used in ltxml files, particularly for
constructors, xpath expressions, etc.  They are not necessarily
the same as the prefixes that will be used in the generated document
(See DocType or RelaxNGSchema).

=item C<< RegisterDocumentNamespace($prefix,$URL); >>

Declares the C<$prefix> to be associated with the given C<$URL>
used within the generated XML. They are not necessarily
the same as the prefixes used in code (RegisterNamespace).
This function is less rarely needed, as the namespace declarations
are generally obtained from the DTD or Schema themselves
(See DocType or RelaxNGSchema).

=item C<< DocType($rootelement,$publicid,$systemid,%namespaces); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document.  The hash C<%namespaces> specifies
the namespaces prefixes that are expected to be found in the DTD, along with
each associated namespace URI.  Use the prefix C<#default> for the default namespace
(ie. the namespace of non-prefixed elements in the DTD).

The prefixes defined for the DTD may be different from the prefixes used in
implementation CODE (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined for the DTD.

=back

=head2 Document Rewriting

During document construction, as each node gets closed, the text content gets simplfied.
We'll call it I<applying ligatures>, for lack of a better name.

=over

=item C<< DefLigature($regexp,%options); >>

Apply the regular expression (given as a string: "/fa/fa/" since it will
be converted internally to a true regexp), to the text content.
The only option is C<fontTest=CODE($font)>; if given, then the substitution
is applied only when C<fontTest> returns true.

Predefined Ligatures combine sequences of "." or single-quotes into appropriate
Unicode characters.

=item C<< DefMathLigature(CODE($document,@nodes)); >>

CODE is called on each sequence of math nodes at a given level.  If they should
be replaced, return a list of C<($n,$string,%attributes)> to replace
the text content of the first node with C<$string> content and add the given attributes.
The next C<$n-1> nodes are removed.  If no replacement is called for, CODE
should return undef.

Predefined Math Ligatures combine letter or digit Math Tokens (XMTok) into multicharacter
symbols or numbers, depending on the font (non math italic).

=back

After document construction, various rewriting and augmenting of the
document can take place.

=over

=item C<< DefRewrite(%specification); >>

=item C<< DefMathRewrite(%specification); >>

These two declarations define document rewrite rules that are applied to the
document tree after it has been constructed, but before math parsing, or
any other postprocessing, is done.  The C<%specification> consists of a 
seqeuence of key/value pairs with the initial specs successively narrowing the
selection of document nodes, and the remaining specs indicating how
to modify or replace the selected nodes.

The following select portions of the document:

=over

=item label =>$label

Selects the part of the document with label=$label

=item scope =>$scope

The $scope could be "label:foo" or "section:1.2.3" or something
similar. These select a subtree labelled 'foo', or
a section with reference number "1.2.3"

=item xpath =>$xpath

Select those nodes matching an explicit xpath expression.

=item match =>$TeX

Selects nodes that look like what the processing of $TeX would produce.

=item regexp=>$regexp

Selects text nodes that match the regular expression.

=back

The following act upon the selected node:

=over

=item attributes => $hash

Adds the attributes given in the hash reference to the node.

=item replace =>$replacement

Interprets the $replacement as TeX code to generate nodes that will
replace the selected nodes.

=back

=back

=head2 Mid-Level support

=over

=item C<< $tokens = Expand($tokens); >>

Expands the given C<$tokens> according to current definitions.

=item C<< $boxes = Digest($tokens); >>

Processes and digestes the C<$tokens>.  Any arguments needed by
control sequences in C<$tokens> must be contained within the C<$tokens> itself.

=item C<< @tokens = Invocation($cs,@args); >>

Constructs a sequence of tokens that would invoke the token C<$cs>
on the arguments.

=item C<< RawTeX('... tex code ...'); >>

RawTeX is a convenience function for including chunks of raw TeX (or LaTeX) code
in a Package implementation.  It is useful for copying portions of the normal
implementation that can be handled simply using macros and primitives.

=item C<< Let($token1,$token2); >>

Gives C<$token1> the same `meaning' (definition) as C<$token2>; like TeX's \let.

=back

=head2 Argument Readers

=over

=item C<< ReadParameters($gullet,$spec); >>

Reads from C<$gullet> the tokens corresponding to C<$spec>
(a Parameters object).

=item C<< DefParameterType($type,CODE($gullet,@values),%options); >>

Defines a new Parameter type, C<$type>, with CODE for its reader.

Options are:

=over

=item reversion=>CODE($arg,@values);

This CODE is responsible for converting a previously parsed argument back
into a sequence of Token's.

=item optional=>boolean

whether it is an error if no matching input is found.

=item novalue=>boolean

whether the value returned should contribute to argument lists, or
simply be passed over.

=item semiverbatim=>boolean

whether the catcode table should be modified before reading tokens.

=back

=item C<< DefColumnType($proto,$expansion); >>

Defines a new column type for tabular and arrays.
C<$proto> is the prototype for the pattern, analogous to the pattern
used for other definitions, except that macro being defined is a single character.
The C<$expansion> is a string specifying what it should expand into,
typically more verbose column specification.

=back

=head2 Access to State

=over

=item C<< $value = LookupValue($name); >>

Lookup the current value associated with the the string C<$name>.

=item C<< AssignValue($name,$value,$scope); >>

Assign $value to be associated with the the string C<$name>, according
to the given scoping rule.

Values are also used to specify most configuration parameters (which can
therefor also be scoped).  The recognized configuration parameters are:

 VERBOSITY         : the level of verbosity for debugging
                     output, with 0 being default.
 STRICT            : whether errors (eg. undefined macros)
                     are fatal.
 INCLUDE_COMMENTS  : whether to preserve comments in the
                     source, and to add occasional line
                     number comments. (Default true).
 PRESERVE_NEWLINES : whether newlines in the source should
                     be preserved (not 100% TeX-like).
                     By default this is true.
 SEARCHPATHS       : a list of directories to search for
                     sources, implementations, etc.

=item C<< PushValue($type,$name,@values); >>

This is like C<AssignValue>, but pushes values onto 
the end of the value, which should be a LIST reference.
Scoping is not handled here (yet?), it simply pushes the value
onto the last binding of C<$name>.

=item C<< UnshiftValue($type,$name,@values); >>

Similar to  C<PushValue>, but pushes a value onto 
the front of the values, which should be a LIST reference.

=item C<< $value = LookupCatcode($char); >>

Lookup the current catcode associated with the the character C<$char>.

=item C<< AssignCatcode($char,$catcode,$scope); >>

Set C<$char> to have the given C<$catcode>, with the assignment made
according to the given scoping rule.

This method is also used to specify whether a given character is
active in math mode, by using C<math:$char> for the character,
and using a value of 1 to specify that it is active.

=item C<< $meaning = LookupMeaning($token); >>

Looks up the current meaning of the given C<$token> which may be a
Definition, another token, or the token itself if it has not
otherwise been defined.

=item C<< $defn = LookupDefinition($token); >>

Looks up the current definition, if any, of the C<$token>.

=item C<< InstallDefinition($defn); >>

Install the Definition C<$defn> into C<$STATE> under its
control sequence.

=back

=head2 Low-level Functions

=over

=item C<< CleanLabel($label,$prefix); >>

Cleans a C<$label> of disallowed characters,
prepending C<$prefix> (or C<LABEL>, if none given).

=item C<< CleanIndexKey($key); >>

Cleans an index key, so it can be used as an ID.

=item C<< CleanBibKey($key); >>

Cleans a bibliographic citation key, so it can be used as an ID.

=item C<< CleanURL($url); >>

Cleans a url.

=item C<< UTF($code); >>

Generates a UTF character, handy for the the 8 bit characters.
For example, C<UTF(0xA0)> generates the non-breaking space.

=item C<< MergeFont(%style); >>

Set the current font by merging the font style attributes with the current font.
The attributes and likely values (the values aren't required to be in this set):

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : tiny, footnote, small, normal, large,
          Large, LARGE, huge, Huge
 color  : any named color, default is black

Some families will only be used in math.
This function returns nothing so it can be easily used in beforeDigest, afterDigest.

=item C<< @tokens = roman($number); >>

Formats the C<$number> in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

Formats the C<$number> in (uppercase) roman numerals, returning a list of the tokens.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
