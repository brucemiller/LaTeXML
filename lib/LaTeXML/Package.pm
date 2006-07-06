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
use base qw(Exporter);
our @EXPORT = (qw(&DefExpandable &DefMacro
		  &DefPrimitive  &DefRegister
		  &DefConstructor &DefMath &dualize_arglist
		  &DefEnvironment
		  &DefRewrite &DefMathRewrite
		  &DefLigature &DefMathLigature
		  &RequirePackage
		  &RawTeX
		  &Tag &DocType &RegisterNamespace
		  &convertLaTeXArgs),

	       # Lower-level support for writing definitions.
	       # Access to State
	       qw(&LookupValue &AssignValue &PushValue
		  &LookupCatcode &AssignCatcode
		 &LookupMeaning &LookupDefinition &InstallDefinition &Let),
	       # Math & font state.
	       qw(&MergeFont),
	       # Explicit digestion
	       qw(&Digest),
	       # Support for structured/argument readers
	       qw(&DefParameterType
		  &StartSemiverbatim &EndSemiverbatim
		  &Expand &Invocation),
	       # Random low-level token operations.
	       qw(&roman &Roman),

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

sub parsePrototype {
  my($proto)=@_;
  my $oproto = $proto;
  $proto =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Fatal("Definition prototype doesn't have proper control sequence:"
	.($cs?$cs->toString:'')." then ".join('',map(ToString($_),@junk))." in \"$oproto\" ") if @junk;
  $proto =~ s/^\s*//;
  ($cs, parseParameters($proto,$cs)); }

# Convert a LaTeX-style argument spec to our Package form.
# Ie. given $nargs and $optional, being the two optional arguments to
# something like \newcommand, convert it to the form we use
sub convertLaTeXArgs {
  my($nargs,$optional)=@_;
  $nargs = (defined $nargs ? $nargs->toString : 0);
  my $default = ($optional ? $optional->toString : undef);
  join('', ($optional ? ($default ? "[Default:$default]" : "[]") : ''),
       map('{}',1..($optional ? $nargs-1 : $nargs))); }

#======================================================================
# Convenience functions for writing definitions.
#======================================================================

sub LookupValue  { $STATE->lookupValue(@_); }
sub AssignValue  { $STATE->assignValue(@_); return; }
sub PushValue    { $STATE->pushValue(@_);  return; }
sub LookupCatcode{ $STATE->lookupCatcode(@_); }
sub AssignCatcode{ $STATE->assignCatcode(@_); return; }

sub LookupMeaning      { $STATE->lookupMeaning(@_); }
sub LookupDefinition   { $STATE->lookupDefinition(@_); }
sub InstallDefinition  { $STATE->installDefinition(@_); }
sub Let {
  my($token1,$token2)=@_;
  ($token1)=TokenizeInternal($token1)->unlist unless ref $token1;
  ($token2)=TokenizeInternal($token2)->unlist unless ref $token2;
  $STATE->assignMeaning($token1,$STATE->lookupMeaning($token2)); 
  return; }

sub Digest       { $STATE->getStomach->digest(@_); }

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
# Defining new Control-sequence Parameter types.
#======================================================================

our $parameter_options = {nargs=>1,reversion=>1,optional=>1,novalue=>1,semiverbatim=>1};
sub DefParameterType {
  my($type,$reader,%options)=@_;
  CheckOptions("DefParameterType $type",$parameter_options,%options);
  $LaTeXML::Parameters::PARAMETER_TABLE{$type}={reader=>$reader,%options};
  return; 
}
#======================================================================
# Readers for reading various data types
#======================================================================

sub StartSemiverbatim() {
  $STATE->pushFrame;
  map($STATE->assignCatcode($_=>CC_OTHER,'local'),'^','_','@','~','&','$','#','%');}  # should '%' too ?
sub EndSemiverbatim() {  $STATE->popFrame; }

sub Expand            { $STATE->getStomach->getGullet->expandTokens(@_); }

sub Invocation        {
  my($token,@args)=@_;
  Tokens(LookupDefinition($token)->invocation(@args)); }

#======================================================================
# Non-exported support for defining forms.
#======================================================================
sub CheckOptions {
  my($operation,$allowed,%options)=@_;
  my @badops = grep(!$$allowed{$_}, keys %options);
  Error($operation." does not accept options:".join(', ',@badops)) if @badops;
}

sub requireMath() {
  Fatal("Current operation can only appear in math mode") unless LookupValue('IN_MATH');
  return; }

sub forbidMath() {
  Fatal("Current operation can not appear in math mode") if LookupValue('IN_MATH');
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
our $expandable_options = {isConditional=>1, scope=>1};
sub DefExpandable {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefExpandable ($proto)",$expandable_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  $STATE->installDefinition(LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options),
			    $options{scope});
  return; }

# Define a Macro: Essentially an alias for DefExpandable
# For convenience, the $expansion can be a string which will be tokenized.
our $macro_options = {scope=>1};
sub DefMacro {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefMacro ($proto)",$macro_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  $expansion = TokenizeInternal($expansion) unless ref $expansion;
  $STATE->installDefinition(LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options),
			    $options{scope});
  return; }

#======================================================================
# Define a primitive control sequence. 
#======================================================================
# Primitives are executed in the Stomach.
# The $replacement should be a sub which returns nothing, or a list of Box's or Whatsit's.
# The options are:
#    isPrefix  : 1 for things like \global, \long, etc.
#    registerType : for parameters (but needs to be worked into DefParameter, below).

our $primitive_options = {isPrefix=>1,scope=>1, requireMath=>1, forbidMath=>1};
sub DefPrimitive {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefPrimitive ($proto)",$primitive_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $replacement = sub { (); } unless defined $replacement;
  $STATE->installDefinition(LaTeXML::Primitive->new($cs,$paramlist,$replacement,
						    beforeDigest=> flatten(($options{requireMath} ? (\&requireMath):()),
									   ($options{forbidMath}  ? (\&forbidMath):()),
									   $options{beforeDigest}),
						    isPrefix=>$options{isPrefix}),
			    $options{scope});
  return; }

our $register_options = {readonly=>1, getter=>1, setter=>1};
our %register_types = ('LaTeXML::Number'   =>'Number',
		       'LaTeXML::Dimension'=>'Dimension',
		       'LaTeXML::Glue'     =>'Glue',
		       'LaTeXML::MuGlue'   =>'MuGlue',
		       'LaTeXML::Tokens'   =>'any',
		       );
sub DefRegister {
  my($proto,$value,%options)=@_;
  CheckOptions("DefRegsiter ($proto)",$register_options,%options);
  my $type = $register_types{ref $value};
  my ($cs,$paramlist)=parsePrototype($proto);
  my $name = $cs->toString;
  my $getter = $options{getter} 
    || sub { LookupValue(join('',$name,map($_->toString,@_))) || $value; };
  my $setter = $options{setter} 
    || sub { my($value,@args)=@_; 
	     AssignValue(join('',$name,map($_->toString,@args)) => $value); };
  # Not really right to set the value!
  AssignValue($cs->toString =>$value) if defined $value;
  $STATE->installDefinition(LaTeXML::Register->new($cs,$paramlist, $type,$getter,$setter,
						   readonly=>$options{readonly}),
			   'global');
  return; }

sub flatten {
  my @list=();
  foreach my $item (@_){
    if(ref $item eq 'ARRAY'){ push(@list,@$item); }
    elsif(defined $item)    { push(@list,$item); }}
  [@list]; }

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
			    captureBody=>1, scope=>1, bounded=>1};
sub DefConstructor {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefConstructor ($proto)",$constructor_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  my $mode = $options{mode};
  my $bounded = $options{bounded};
  $STATE->installDefinition(LaTeXML::Constructor
			    ->new($cs,$paramlist,$replacement,
				  beforeDigest=> flatten(($options{requireMath} ? (\&requireMath):()),
							 ($options{forbidMath}  ? (\&forbidMath):()),
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
our $math_options = {name=>1, omcd=>1, reversion=>1, alias=>1,
		     role=>1, operator_role=>1,
		     style=>1, size=>1, font=>1,
		     stackscripts=>1,operator_stackscripts=>1,
		     beforeDigest=>1, afterDigest=>1, scope=>1, nogroup=>1};
our $XMID=0;
sub next_id {
  "LXID".$XMID++; }

sub dualize_arglist {
  my(@args)=@_;
  my(@cargs,@pargs);
  foreach my $arg (@args){
    if(defined $arg){
      my $id = next_id();
      push(@cargs, Invocation(T_CS('\@XMArg'),T_OTHER($id),$arg));
      push(@pargs, Invocation(T_CS('\@XMRef'),T_OTHER($id))); }
    else {
      push(@cargs,undef);
      push(@pargs,undef); }}
  ( [@cargs],[@pargs] ); }
# Quick reversal!
#  ( [@pargs],[@cargs] ); }

sub DefMath {
  my($proto,$presentation,%options)=@_;
  CheckOptions("DefMath ($proto)",$math_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);  
  my $nargs = scalar($paramlist->getParameters);
  my $csname = $cs->getString;
  my $name = $csname;
  $name =~ s/^\\//;
  $name = $options{name} if defined $options{name};
  $name = undef if (defined $name) && (($name eq $presentation) || ($name eq ''));
  my $attr="name='#name' omcd='#omcd' style='#style' size='#size'";
  $options{role} = 'UNKNOWN' if ($nargs == 0) && !defined $options{role};
  $options{operator_role} = 'UNKNOWN' if ($nargs > 0) && !defined $options{operator_role};
  $options{reversion} = Tokenize($options{reversion})
    if $options{reversion} && !ref $options{reversion};
  my %common =(alias=>$options{alias}||$cs->getString,
	       (defined $options{reversion} ? (reversion=>$options{reversion}) : ()),
	       beforeDigest=> flatten(\&requireMath,
				      ($options{nogroup} ? ():(sub{$_[0]->bgroup;})),
				      ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
				      $options{beforeDigest}),
	       afterDigest => flatten($options{afterDigest},
				      ($options{nogroup} ? ():(sub{$_[0]->egroup;}))),
	       beforeConstruct=> flatten($options{beforeConstruct}),
	       afterConstruct => flatten($options{afterConstruct}),
	       properties => {name=>$name, omcd=>$options{omcd},
			      role => $options{role}, operator_role=>$options{operator_role},
			      style=>$options{style}, size=>$options{size},
			      stackscripts=>$options{stackscripts},
			      operator_stackscripts=>$options{operator_stackscripts}},
	       scope=>$options{scope});
  # If single character, Make the character active in math.
  if(length($csname) == 1){
    AssignCatcode('math:'.$csname=>1, $options{scope}); }

  if((ref $presentation) || ($presentation =~ /\#\d|\\./)){	      # Seems to have TeX! => XMDual
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
    $STATE->installDefinition(LaTeXML::Expandable->new($pres_cs, $paramlist,
							 (ref $presentation ? $presentation
							  : TokenizeInternal($presentation))),
				$options{scope});
    $STATE->installDefinition(LaTeXML::Constructor->new($cont_cs,$paramlist,
         ($nargs == 0 
	  ? "<ltx:XMTok $attr role='#role' stackscripts='#stackscripts'/>"
	  : "<ltx:XMApp role='#role' stackscripts='#stackscripts'>"
	  .  "<ltx:XMTok $attr role='#operator_role' stackscripts='#operator_stackscripts'/>"
	  .   join('',map("#$_", 1..$nargs))
	  ."</ltx:XMApp>"),
         %common), $options{scope}); }
  else {
    my $end_tok = (defined $presentation ? ">$presentation</ltx:XMTok>" : "/>");
    $common{properties}{font} = sub { LookupValue('font')->specialize($presentation); };
    $STATE->installDefinition(LaTeXML::Constructor->new($cs,$paramlist,
         ($nargs == 0 
	  ? "<ltx:XMTok role='#role' stackscripts='#stackscripts' font='#font' $attr$end_tok"
	  : "<ltx:XMApp role='#role' stackscripts='#stackscripts'>"
	  .  "<ltx:XMTok $attr font='#font' role='#operator_role' stackscripts='#operator_stackscripts'"
	  .  " $end_tok"
	  .   join('',map("<ltx:XMArg>#$_</ltx:XMArg>", 1..$nargs))
	  ."</ltx:XMApp>"),
         %common), $options{scope}); }
}

#======================================================================
# Define a LaTeX environment
# Note that the body of the environment is treated is the 'body' parameter in the constructor.
our $environment_options = {mode=>1, requireMath=>1, forbidMath=>1,
			    properties=>1, nargs=>1, font=>1,
			    beforeDigest=>1, afterDigest=>1, beforeConstruct=>1, afterConstruct=>1,
			    afterDigestBegin=>1, #beforeDigestEnd=>1
			    scope=>1};
sub DefEnvironment {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefEnvironment ($proto)",$environment_options,%options);
  $proto =~ s/^\{([^\}]+)\}\s*//; # Pull off the environment name as {name}
  my $name = $1;
  my $paramlist=parseParameters($proto,"Environment $name");
  my $mode = $options{mode};
  # This is for the common case where the environment is opened by \begin{env}
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\begin{$name}"), $paramlist,$replacement,
				   beforeDigest=>flatten(($options{requireMath} ? (\&requireMath):()),
							 ($options{forbidMath}  ? (\&forbidMath):()),
							 ($mode ? (sub { $_[0]->beginMode($mode);})
							  : (sub {$_[0]->bgroup;})),
							 sub { AssignValue(current_environment=>$name); },
							 ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
							 $options{beforeDigest}),
				   afterDigest =>flatten($options{afterDigestBegin}),
				   beforeConstruct=> flatten(sub{$STATE->pushFrame;},$options{beforeConstruct}),
				   nargs=>$options{nargs},
				   captureBody=>1, 
				   properties=>$options{properties}||{}),
			     $options{scope});
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end{$name}"),"","",
				   afterDigest=>flatten($options{afterDigest},
							sub { my $env = LookupValue('current_environment');
							      Error("Cannot close environment $name; current is $env")
								unless $name eq $env; 
							    return; },
							($mode ? (sub { $_[0]->endMode($mode);})
							 :(sub{$_[0]->egroup;}))),
				   afterConstruct => flatten($options{afterConstruct},sub{$STATE->popFrame;})),
			     $options{scope});
  # For the uncommon case opened by \csname env\endcsname
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\$name"), $paramlist,$replacement,
				   beforeDigest=>flatten(($options{requireMath} ? (\&requireMath):()),
							 ($options{forbidMath}  ? (\&forbidMath):()),
							 ($mode ? (sub { $_[0]->beginMode($mode);}):()),
							 ($options{font}? (sub { MergeFont(%{$options{font}});}):()),
							 $options{beforeDigest}),
				   beforeConstruct=> flatten(sub{$STATE->pushFrame;},$options{beforeConstruct}),
				   nargs=>$options{nargs},
				   captureBody=>1,
				   properties=>$options{properties}||{}),
			     $options{scope});
  $STATE->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end$name"),"","",
				   afterDigest=>flatten($options{afterDigest},
							($mode ? (sub { $_[0]->endMode($mode);}):())),
				   afterConstruct => flatten($options{afterConstruct},sub{$STATE->popFrame;})),
			     $options{scope});
  return; }

#======================================================================
# Specify the properties of a Node tag.
our $tag_options = {autoOpen=>1, autoClose=>1, afterOpen=>1, afterClose=>1};

sub Tag {
  my($tag,%properties)=@_;
  CheckOptions("Tag ($tag)",$tag_options,%properties);
  my $model = $STATE->getModel;
  $model->setTagProperty($tag,autoOpen=>$properties{autoOpen}) if $properties{autoOpen};
  $model->setTagProperty($tag,autoClose=>$properties{autoClose}) if $properties{autoClose};
  $model->setTagProperty($tag,afterOpen=>flatten($model->getTagProperty($tag,'afterOpen'),$properties{afterOpen}))
    if $properties{afterOpen};
  $model->setTagProperty($tag,afterClose=>flatten($model->getTagProperty($tag,'afterClose'),$properties{afterClose}))
    if $properties{afterClose};
  return; }

sub DocType {
  my($rootelement,$pubid,$sysid,%namespaces)=@_;
  $STATE->getModel->setDocType($rootelement,$pubid,$sysid,%namespaces);
  return; }

sub RegisterNamespace {
  my($prefix,$namespace)=@_;
  $STATE->getModel->registerNamespace($prefix,$namespace);
  return; }

our $require_options = {options=>1};
sub RequirePackage {
  my($package,%options)=@_;
  CheckOptions("RequirePackage ($package)",$require_options,%options);
  $STATE->getStomach->getGullet->input($package,['ltxml','sty'],%options); 
  return; }

sub RawTeX {
  my($text)=@_;
  Digest(TokenizeInternal($text));
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

C<LaTeXML::Package> -- Support for package implementations and document customization.

=head1 SYNOPSIS

This package defines and exports most of the procedures users will need
to customize or extend LaTeXML.

To implement the LaTeXML version of a LaTeX package C<somepackage.sty>, 
such that C<\usepackage{somepackage}> would load your custom implementation,
you would need to create the file C<somepackage.ltxml> (It can be anywhere
perl searches for modules [ie the list of directories C<@INC>, which typically
includes the working directory] or in any of those directories with
C<"LaTeXML/Package"> appended).

To customize the processing of a specific document, say
C<mydoc.tex>, you would create the file C<mydoc.latexml>
(sought in the same search path as above, but most likely in the
same directory as the document).

The contents of these packages would be something like the following code, 
which contains random `illustrative' samples collected from the TeX
and LaTeX packages.

  use LaTeXML::Package;
  use strict;

  # Load "anotherpackage"
  RequirePackage('anotherpackage');

  # A simple macro, should act just like in TeX, replacing the
  # token and its arguments, by another sequence of tokens.
  # For example, to change the style of section numbering
  DefMacro('\thesection', '\thechapter.\roman{section}');

  # A constructor defines how a control sequence will generate
  # an XML tree fragment.
  # This \thanks{text} to add a thanks element
  # with the argument as its content.
  DefConstructor('\thanks{}', "<thanks>#1</thanks>");

  # To define a symbol \Real to stand for the Reals, 
  # using double struck capital R for presentation
  # It plays a grammatical role as an ID (identifier).
  DefMath('\Real', "\x{211D}", role=>'ID');

  # To define a function \realpart.
  # This creates a `dual' whose presentation 
  # places BLACK-LETTER CAPITAL R in front of the argument,
  # and whose content representation applies a token
  # with name `realpart' to the argument.
  DefMath('\realpart{}', "\x{211C}");

  # Define a new math relational symbol.
  # This will create a `dual' whose presentation is a bold 'x', 
  # but whose content form has the name 'myrel'.
  DefMath('\myrel', "\mathbf{x}", role=>'RELOP');

  # Define the negation of myrel.
  DefMath('\notmyrel',  "\mathbf{not x}", role=>'RELOP');
  # and define a rewriter that combines \not and \in.
  DefMathRewrite(match=>'\not\myrel',replace=>'\notmyrel');

  # To define a floor function with the conventional presentation,
  # but still assuring the content form is unambiguous:
  DefMath('\floor{}','\left\lfloor#1\right\rfloor');

  # Don't forget this; it tells perl the package loaded successfully.
  1;

More complex usages are in the following example, mostly plucked from
various packages in LaTeXML.

  use LaTeXML::Package;
  use strict;

  # Use a special DocType, if not LaTeXML.dtd
  DocType("rootelement","-//Your Site//Your Document Type",'your.dtd',
          prefix=>"http://whatever/");

  # Allow sometag elements to be automatically closed if needed
  Tag('pre:sometag', autoClose=>1);

  # define a roman numeral conversion.
  DefExpandable('\romannumeral Number', sub { roman($_[1]); });

  # Make \pagestyle be ignored.
  DefPrimitive('\pagestyle{}',    undef);

  # These primitives implement LaTeX's \makeatletter and \makeatother.
  # They change the catcode but return nothing to the digested list.
  DefPrimitive('\makeatletter',sub { 
    AssignCatcode('@'=>CC_LETTER,'local'); });
  DefPrimitive('\makeatother', sub { 
    AssignCatcode('@'=>CC_OTHER, 'local');  });

  # Some frontmatter examples.

  # And with a bit of typical (but abbreviated) trickery that ressembles 
  # LaTeX's approach
  # define initial \@title and \@date (similar for \@author)
  DefMacro('\@title','');
  DefMacro('\@date','\today');
  # but make \date{something} save the date in \@date
  DefPrimitive('\date{}', sub { DefMacro('\@date',$_[1])});
  ...
  # The secret constructor \fmt@date creates the actual element,
  DefConstructor('\fmt@date{}', "<creationdate>#1</creationdate>");
  # It is used when the \maketitle is encountered.
  DefMacro('\maketitle', 
           '\fmt@title{\@title}\fmt@author{\@author}\fmt@date{\@date}');
  # And a simple environment ...
  DefEnvironment('{abstract}','<abstract>#body</abstract>');

  # a different complication:  Have \usepackage generate a processing instruction,
  # but have it's after daemon do the actual input.
  # The constructor pattern uses a conditional clause ?#1(...) that includes the
  # attribute options only if the first (optional) argument is non-empty.
  DefConstructor('\usepackage[]{}',"<?latexml package='#2' ?#1(options='#1')?>",
  	         afterDigest=>sub { RequirePackage($_[2]->toString); });
  # If you prefer to be a little less perl-cryptic, you could write
  DefConstructor('\usepackage[]{}',"<?latexml package='#2' ?#1(options='#1')?>",
  	         afterDigest=>sub { my($whatsit,$options,$package)=@_;
                                    RequirePackage($package->toString);  });

  # Don't forget this; it tells perl the package loaded successfully.
  1;


=head1 DESCRIPTION

You import (use) C<LaTeXML::Package> when implementing a C<Package>; 
the LaTeXML implementation of a LaTeX package.
It exports various declarations and defining forms that allow you to specify what should 
be done with various control sequences, whether there is special treatment of document elements,
and so forth.  Using C<LaTeXML::Package> also imports the functions and variables
defined in L<LaTeXML::Global>, so see that documentation as well.

=head2 Control Sequence Definitions

Many of the following defining forms define the behaviour of a control sequence (macro, 
primitive, register, etc). The general pattern is that the first argument is
a `prototype' of the control sequence and its arguments (described in detail in the
next section), and the second argument describes the replacement as a string, tokens or code.
The remaining arguments are generally optional keyword arguments providing further
control.

=head3 Control of Scoping

Most defining commands accept an option  C<< scope=>$scope >> which affects how the
definition is stored: C<$scope> can be 'global' for global definitions,
'local', to be stored in the current stack frame, or a string naming a I<scope>.
A scope saves a set of definitions and values that can be activated at a later time.

Particularly interesting forms of scope are those that get automatically activated
upon changes of counter and label.  For example, definitions that have
C<< scope=>'section:1.1' >>  will be activated when the section number is "1.1",
and will be deactivated when the section ends.


=head3 Control Sequence Prototypes

they take a `Prototype' as the first argument indicating
the control sequence to define and a sequence of parameter specifications.
Each parameter specification is of the form "{type}", "[type]" or simply "type".
For "{type}", a regular TeX argument (token or sequence of tokens with balanced braces)
is read, and the the result is parsed according to "type".  In the case of "[type]" a
LaTeX-style optional argument is read, and if the argument was given, it is parsed.  
Finally, the unbracketed forms are appropriate for TeX style arguments like Number, 
where tokens are parsed until a complete number is read.

If type is empty in the above (ie. "{}" or "[]"), no parsing of the argument is done,
and the argument value is simply the Tokens (or undef for [] when no option was provided).
The remaining recognized types are

  Semiverbatim  : Like {} but with many catcodes disabled.
  Token         : Read a single Token.
  XToken        : Read the next unexpandable Token after expandable 
                  ones have been expanded.
  Number        : Read a Number object (using TeX's rules for integers)
  Dimension     : Read a Dimension object (using TeX's rules for dimensions)
  Glue          : Read a Glue object (using TeX's rules for glue)
  MuGlue        : Read a MuGlue object (using TeX's rules for muglue)
  Until:...     : Read all tokens (with balanced braces) until matching 
                  the seqence given by "...".
  KeyVal:...    : Reads key-value pairs (like the keyval package), 
                  where "..." gives the keyset to use.  It parses each
                  value according to the keys defined for keyset by DefKeyVal.
  Default:...   : For an optional argument, "..." specifies the default 
                  if no argument is present.

In the following types, the part "..." following the colon are "|" separated
sequences of characters.  The input is expected to match one of the character sequences.

  Keyword:...   : Match one of the character sequences to the input.
                  The effective argument is the Tokens corresonding
                  to the matched sequence.
  Ignore:...    : Like Keyword, but allows the tokens to be missing, 
                  and doesn't contribute an item to the argument list.
  Flag:...      : Like Keyword, but allows the tokens to be missing 
                  (the argument value is undef if missing).
  Literal:...   : Like Keyword, but doesn't contribute an item
                  to the argument list; like TeX's delimted parameters.


Each item above, unless otherwise noted, contribute an item to the argument list.

=over 4

=item C<< DefExpandable($proto,$expansion,%options); >>

Defines an expandable control sequence. The C<$expansion> should be a CODE ref that will take
the Gullet and any macro arguments as arguments.  It should return the result as a list
of Token's.  The only option, other than C<scope>, is C<isConditional> which should be true, for conditional
control sequences (TeX uses these to keep track of conditional nesting when skipping
to \else or \fi).

=item C<< DefMacro($proto,$expansion,%options); >>

Defines the macro expansion for C<$proto>.  C<$expansion> can be a string (which will be tokenized
at definition time) or a LaTeXML::Tokens; any macro arguments will be substituted for parameter
indicators (eg #1) and the result is used as the expansion of the control sequence.
If $expansion is a CODE ref, it will be called with the Gullet and any macro arguments, as arguments,
and it should return a list of Token's. The only option is C<scope>.

=item C<< DefPrimitive($proto,$replacement,%options); >>

Define a primitive control sequence.  The C<$replacement> is a CODE ref that will be
called with the Stomach and any macro arguments as arguments.  Usually it should
return nothing (eg. end with return; ) since they are generally done for side-effect,
but otherwise should return a list of digested items.

The only option is for the special case: C<isPrefix=>1> is used for assignment
 prefixes (like \global).

=item C<< DefRegister($proto,$value,%options); >>

Defines a register with the given initial value (a Number, Dimension, Glue, MuGlue or Tokens
--- I haven't handled Box's yet).  Usually, the $proto is just the control sequence, but
registers are also handled by prototypes like "\count{Number}". DefRegister arranges
that the register value can be accessed when a numeric, dimension, ... value is being read,
and also defines the control sequence for assignment.

By default the value is stored in the Stomach's Value table under a name concatenating the 
control sequence and argument values.  A different correspondence can be made by supplying 
code to the getter and setter attributes. (See the source for examples; eg. \catcode).

The option readonly specifies if it is not allowed to change this value.

=item C<< DefConstructor($proto,$replacement,%options); >>

Defines a Constructor; invoking the control sequence will generate an arbitrary XML
fragment in the document tree.  More specifically: during digestion, the arguments
will be read and digested, creating a Whatsit to represent the object. During
absorbtion by the Document, the Whatsit will generate the XML fragment according
to the replacement pattern, or code based on the stored data.

The replacement is a pattern representing the XML fragment to be inserted,
or code called with the Document, arguments and properties.
The pattern is simply a bit of XML as a string with certain substitutions made.
Generally, #1, #2 ... is replaced by the corresponding argument (turned into
a string when it appears as an attribute, or recursively processed when it appears as
content). #name stands for named properties stored in the Whatsit. 
Another form of substituted value is prefixed with C<&> which invokes a function,
say C< &func(values) > which returns a string (or an object which will be converted
using C<toString>).

Additionally, the pattern can be conditionallized by surrounding portions of
the pattern by the IF construct ?#1(...) or IF-ELSE ?#1(...)(...) for inclusion 
only when the argument is defined.   Currently, conditionals can NOT be nested.
If the constuctor begins with '^', the XML fragment is allowed to `float up' to
a parent node that is allowed to contain it, according to the Document Type.

The Whatsit properties font, body and trailer are defined by default (the latter two
only when captureBody is true).  Other properties can be added to Whatsits
by using C<< $whatsit->setProperty(key=>$value); >> within C<afterDigest>.

DefConstructor options are

  mode           : Changes to this mode (text, display_math 
                   or inline_math) during digestion.
  reversion      : Specifies a pattern for reversion'ing the 
                   contstructor, if the default is not appropriate. 
                   A string (that can include #1,#2...) or code 
                   called with the $whatsit as argument.
  properties     : Given a hash value, this provides additional 
                   properties to be stored in the Whatsit, a property 
                   value can also be a CODE reference (it will be 
                   called with the defn and args as arguments), or a
                   string containing #1,... (in which case an argument
                   is substituted)
  beforeDigest   : supplies a Daemon to be executed during digestion 
                   just before the Whatsit is created.  It is called
                   with the definition as argument; it should either 
                   return nothing (return;) or a list of digested items.
  afterDigest    : supplies a Daemon to be executed during digestion 
                   just after the Whatsit is created.  It is called 
                   with the Whatit, the arguments and a hash ref (the 
                   properties) as arguments; it should either return 
                   nothing (return;) or digested items.
  captureBody    : if true, arbitrary following material will be 
                   accumulated into a `body' until the current grouping 
                   level is reverted. This is used by environments and math.

Note that all of these procedures exported by this module return nothing, 
except for those that are used to explicitly get something.  
They can thus be safely used in beforeDigest/afterDigest
modifiers without concern for puting something awkward into the List being built.

=item C<< DefMath($proto,$tex,%options); >>

A common shorthand constructor; it defines a control sequence that creates a mathematical object,
such as a symbol, function or operator application.  It generates an XMDual using the replacement
$tex for the presentation.  The content information is drawn from the name and options
The reversion option is the same as for DefConstructor; the remaining options clarify
the semantics of the object:

  style : adds a style attribute to the object.
  name  : gives a name attribute for the object
  omcd  : gives the OpenMath content dictionary that name is from.
  role  : adds a role attribute to the object; this specifies
          the grammatical role that the object plays in
          surrounding expressions.

The name and role attributes contribute to the eventual parsing of mathematical content.

=item C<< DefEnvironment($proto,$replacement,%options); >>

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

Options are:

  mode             : changes to this mode to process the
                     body in (eg. equation)
  beforeDigest     : code to execute before digesting 
                     the C<\begin{env}>; See C<DefConstructor>
  afterDigestBegin : code to execute after digesting C<\begin{env}>.
  afterDigest      : code to execute after digesting C<\end{env}>.


=item C<< Let($token1,$token2); >>

Gives C<$token1> the same `meaning' (definition) as C<$token2>; like TeX's \let.

=back

=head2 Document Declarations

=over 4

=item C<< Tag($tag,%properties); >>

Declares properties of elements with the name C<$tag>.
The recognized properties are:

  autoOpen  :  whether this $tag can be automatically opened
               if needed to insert an element that can only
               be contained by $tag.
  autoClose  : whether this $tag can be automatically closed 
               if needed to close an ancestor node, or insert
               an element into an ancestor.
  afterOpen  : provides code to be run whenever a node with 
               this $tag is opened.  It is called with the $node
               and the initiating digested object as arguments.
  afterClose : provides code to be run whenever a node with 
               this $tag is closed.  It is called with the $node 
               and the initiating digested object as arguments.

The autoOpen and autoClose properties help match the more  SGML-like LaTeX to XML.

=item C<< DocType($rootelement,$publicid,$systemid,%namespaces); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document.  The hash C<%namespaces> specifies
the namespace prefixes that are expected to be found in the DTD, along with
the associated namespace URI.  These prefixes may be different from
the prefixes used in implementation code (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined here.

=item C<< RegisterNamespace($prefix,$URL); >>

Declares the C<$prefix> to be associated with the given C<$URL>.
These prefixes may be used in code in ltxml files, particularly for
constructors, xpath expressions, etc.  They are not necessarily
the same as the prefixes that will be used in the generated document
(See DocType).

=back

=head2 Document Rewriting

=over 4

=item C<< DefRewrite(%specification); >>

=item C<< DefMathRewrite(%specification); >>

These two declarations define document rewrite rules that are applied to the
document tree after it has been constructed, but before math parsing, or
any other postprocessing, is done.  The C<%specification> consists of a 
seqeuence of key/value pairs with the initial specs successively narrowing the
selection of document nodes, and the remaining specs indicating how
to modify or replace the selected nodes.

The following select portions of the document:

   label =>$label   Selects the part of the document with label=$label
   scope =>$scope   The $scope could be "label:foo" or "section:1.2.3" or something
                    similar. These select a subtree labelled 'foo', or
                    a section with reference number "1.2.3"
   xpath =>$xpath   Select those nodes matching an explicit xpath expression.
   match =>$TeX     Selects nodes that look like what the processing of $TeX 
                    would produce.
   regexp=>$regexp  Selects text nodes that match the regular expression.

The following act upon the selected node:

   attributes => $hash Adds the attributes given in the hash reference 
                    to the node.
   replace =>$replacement Interprets the $replacement as TeX code to generate
                    nodes that will replace the selected nodes.

=back


=head2 Other useful operations

=over 4

=item C<< RequirePackage($package); >>

Finds an implementation (either TeX or LaTeXML) for the named C<$package>, and loads it
as appropriate.

=item C<< RawTeX('... tex code ...'); >>

RawTeX is a convenience function for including chunks of raw TeX (or LaTeX) code
in a Package implementation.  It is useful for copying portions of the normal
implementation that can be handled simply using macros and primitives.

=back


=head2 Convenience Functions

The following are exported as a convenience when writing definitions.

=over 4

=item C<< $value = LookupValue($name); >>

Lookup the current value associated with the the string C<$name>.

=item C<< AssignValue($name,$value,$scope); >>

Assign $value to be associated with the the string C<$name>, according
to the given scoping rule.

Values are also used to specify most configuration parameters (which can
therefor also be scoped).  The recognized configuration parameters are:

  VERBOSITY         : the level of verbosity for debugging output, with 0 being default.
  STRICT            : whether errors (such as undefined macros) are fatal.
  INCLUDE_COMMENTS  : whether to preserve comments in the source, and to add
                      occasional line-number comments.  Default does include them.
  PRESERVE_NEWLINES : whether newlines in the source should be preserved (not 100% TeX-like).
                      By default this is true.
  SEARCHPATHS       : a list of directories to search for sources, implementations, dtds, and such.

=item C<< PushValue($type,$name,$value); >>

This is like C<< ->assign >>, but pushes a value onto 
the value, which should be a LIST reference.
Scoping is not handled here (yet?), it simply pushes the value
onto the last binding of C<$name>.


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

=item C<< $boxes = Digest($tokens); >>

Processes and digestes the C<$tokens>.  Any arguments needed by
control sequences in C<$tokens> must be contained within the C<$tokens> itself.

=item C<< MergeFont(%style); >>

Set the current font by merging the font style attributes with the current font.
The attributes and likely values (the values aren't required to be in this set):

   family : serif, sansserif, typewriter, caligraphic, fraktur, script
   series : medium, bold
   shape  : upright, italic, slanted, smallcaps
   size   : tiny, footnote, small, normal, large, Large, LARGE, huge, Huge
   color  : any named color, default is black

Some families will only be used in math.
This function returns nothing so it can be easily used in beforeDigest, afterDigest.

=item C<< @tokens = roman($number); >>

Formats the C<$number> in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

Formats the C<$number> in (uppercase) roman numerals, returning a list of the tokens.

=item C<< SkipSpaces(); >>

Skips any spaces in the input.
This allows 'SkipSpaces' to be used in a parameter spec, without
contributing an argument.

=item C<< $tokens = ReadUntil($keyword,...); >>

Reads input until matching one of the C<$keyword>s.

=item C<< $tokens = Expand($tokens); >>

Expands the given C<$tokens> according to current definitions.

=item C<< @tokens = Invocation($cs,@args); >>

Constructs a sequence of tokens that would invoke the token C<$cs>
on the arguments.

=item C<< StartSemiVerbatim(); ... ; EndSemiVerbatim(); >>

Reads an argument delimted by braces, while disabling most TeX catcodes.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
