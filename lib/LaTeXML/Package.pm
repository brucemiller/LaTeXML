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
our @ISA = qw(Exporter);
our @EXPORT = (qw(&DefExpandable &DefMacro
		  &DefPrimitive  &DefRegister &NewCounter
		  &DefConstructor &DefMath &dualize_arglist
		  &DefEnvironment
		  &DefTextFilter &DefMathFilter &DefKeyVal
		  &Let
		  &RequirePackage
		  &RawTeX
		  &Tag &DocType
		  &convertLaTeXArgs),
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
#**********************************************************************

sub parsePrototype {
  my($proto)=@_;
  my $oproto = $proto;
  $proto =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Fatal("Definition prototype doesn't have proper control sequence:"
	.($cs?$cs->toString:'')." then ".join('',map($_->untex,@junk))." in \"$oproto\" ") if @junk;
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

sub CheckOptions {
  my($operation,$allowed,%options)=@_;
  my @badops = grep(!$$allowed{$_}, keys %options);
  Error($operation." does not accept options:".join(', ',@badops)) if @badops;
}

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
our $expandable_options = {isConditional=>1,stash=>1};
sub DefExpandable {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefExpandable ($proto)",$expandable_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  $STOMACH->installDefinition(LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options),
			     stash=>$options{stash});
  return; }

# Define a Macro: Essentially an alias for DefExpandable
# For convenience, the $expansion can be a string which will be tokenized.
our $macro_options = {stash=>1};
sub DefMacro {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefMacro ($proto)",$macro_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  $expansion = TokenizeInternal($expansion) unless ref $expansion;
  $STOMACH->installDefinition(LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options),
			     stash=>$options{stash});
  return; }

#======================================================================
# Define a primitive control sequence. 
#======================================================================
# Primitives are executed in the Stomach.
# The $replacement should be a sub which returns nothing, or a list of Box's or Whatsit's.
# The options are:
#    isPrefix  : 1 for things like \global, \long, etc.
#    registerType : for parameters (but needs to be worked into DefParameter, below).

our $primitive_options = {isPrefix=>1,stash=>1};
sub DefPrimitive {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefPrimitive ($proto)",$primitive_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $replacement = sub { (); } unless defined $replacement;
  $STOMACH->installDefinition(LaTeXML::Primitive->new($cs,$paramlist,$replacement,%options),
			     stash=>$options{stash});
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
    || sub { my(@args)=@_;  
	     $STOMACH->lookupValue(join('',$name,map($_->toString,@args))) || $value; };
  my $setter = $options{setter} 
    || sub { my($value,@args)=@_; 
	     $STOMACH->assignValue(join('',$name,map($_->toString,@args)),$value); };
  # Not really right to set the value!
  $STOMACH->assignValue($cs->toString,$value) if defined $value;
  $STOMACH->assignMeaning($cs,LaTeXML::Register->new($cs,$paramlist, $type,$getter,$setter,
						 readonly=>$options{readonly}));
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
# It is the Whatsit that will be processed in the Intestine: It is responsible
# for constructing XML Nodes.  The $replacement should be a sub which inserts nodes, 
# or a string specifying a constructor pattern (See somewhere).
#
# Options are:
#   mode            : causes a switch into the given mode during the Whatsit building in the stomach.
#   untex           : a string representing the preferred TeX form of the invocation.
#   beforeDigest    : code to be executed (in the stomach) before parsing & constructing the Whatsit.
#                     Can be used for changing modes, beginning groups, etc.
#   afterDigest     : code to be executed (in the stomach) after parsing & constructing the Whatsit.
#                     useful for setting Whatsit properties,
#   properties      : a hashref listing default values of properties to assign to the Whatsit.
#                     These properties can be used in the constructor.
our $constructor_options = {mode=>1, untex=>1, properties=>1, alias=>1,
			    beforeDigest=>1, afterDigest=>1,
			    captureBody=>1,stash=>1};
sub DefConstructor {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefConstructor ($proto)",$constructor_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  my $mode = $options{mode};
  $STOMACH->installDefinition(LaTeXML::Constructor
			     ->new($cs,$paramlist,$replacement,
				   beforeDigest=> flatten(($mode ? (sub { $STOMACH->beginMode($mode); }):()),
							  $options{beforeDigest}),
				   afterDigest => flatten($options{afterDigest},
							  ($mode ? (sub { $STOMACH->endMode($mode) }):())),
				   alias       => $options{alias},
				   untex       => $options{untex},
				   captureBody => $options{captureBody},
				   properties  => $options{properties}||{}),
			     stash=>$options{stash});

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
our $math_options = {name=>1, omcd=>1, untex=>1, alias=>1, role=>1, operator_role=>1,
		     style=>1, size=>1, stackscripts=>1,
		     beforeDigest=>1, afterDigest=>1, stash=>1};
our $XMID=0;
sub next_id {
  "LXID".$XMID++; }

sub dualize_arglist {
  my(@args)=@_;
  my(@cargs,@pargs);
  foreach my $arg (@args){
    if(defined $arg){
      my $id = next_id();
      push(@cargs, T_CS('\@XMArg')->invocation(T_OTHER($id),$arg));
      push(@pargs, T_CS('\@XMRef')->invocation(T_OTHER($id))); }
    else {
      push(@cargs,undef);
      push(@pargs,undef); }}
  ( [@cargs],[@pargs] ); }

sub DefMath {
  my($proto,$presentation,%options)=@_;
  CheckOptions("DefMath ($proto)",$math_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);  
  my $nargs = scalar($paramlist->getParameters);
  my $name = $cs->getString;
  $name =~ s/^\\//;
  $name = $options{name} if defined $options{name};
  $name = undef if (defined $name) && (($name eq $presentation) || ($name eq ''));
  my $attr="name='#name' omcd='#omcd' style='#style' size='#size'"
    ." stackscripts='#stackscripts'";
  my %common =(alias=>$options{alias}||$cs->getString,
	       (defined $options{untex} ? (untex=>$options{untex}) : ()),
	       beforeDigest=> flatten(sub{ requireMath;},
				      $options{beforeDigest}),
	       afterDigest => flatten($options{afterDigest}),
	       properties => {name=>$name, omcd=>$options{omcd},
			      role => $options{role}, operator_role=>$options{operator_role},
			      style=>$options{style}, size=>$options{size},
			      stackscripts=>$options{stackscripts}},
	       stash=>$options{stash});

  if((ref $presentation) || ($presentation =~ /\#\d|\\./)){	      # Seems to have TeX! => XMDual
    my $cont_cs = $cs->getString."\@content";
    my $pres_cs = $cs->getString."\@presentation";
    DefExpandable($proto, sub {
      my($self,@args)=@_;
      my($cargs,$pargs)=dualize_arglist(@args);
      T_CS('\DUAL')->invocation(($options{role} ? T_OTHER($options{role}):undef),
				T_CS($cont_cs)->invocation(@$cargs),
				T_CS($pres_cs)->invocation(@$pargs) )->unlist;},
		 stash=>$options{stash});
    DefMacro($pres_cs . $paramlist->stringify, $presentation,
	     stash=>$options{stash});
    DefConstructor($cont_cs . $paramlist->stringify,
		   ($nargs == 0 
		    ? "<XMTok $attr role='#role'/>"
		    : "<XMApp role='#role'>"
		    .  "<XMTok $attr role='#operator_role'/>"
		    .   join('',map("#$_", 1..$nargs))
		    ."</XMApp>"),
		   %common); }
  else {
    my $end_tok = (defined $presentation ? ">$presentation</XMTok>" : "/>");
    $common{properties}{font} = sub { $STOMACH->getFont->specialize($presentation); };
    DefConstructor($proto,
		   ($nargs == 0 
		    ? "<XMTok role='#role' font='#font' $attr$end_tok"
		    : "<XMApp role='#role'>"
		    .  "<XMTok $attr font='#font' role='#operator_role'$end_tok"
		    .   join('',map("<XMArg>#$_</XMArg>", 1..$nargs))
		    ."</XMApp>"),
		   %common); }
}

#======================================================================
# Define a LaTeX environment
# Note that the body of the environment is treated is the 'body' parameter in the constructor.
our $environment_options = {mode=>1, properties=>1,
			    beforeDigest=>1, afterDigest=>1,
			    afterDigestBegin=>1, #beforeDigestEnd=>1
			    stash=>1};
sub DefEnvironment {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefEnvironment ($proto)",$environment_options,%options);
  $proto =~ s/^\{([^\}]+)\}//; # Pull off the environment name as {name}
  my $name = $1;
  my $paramlist=parseParameters($proto,"Environment $name");
  my $mode = $options{mode};
  # This is for the common case where the environment is opened by \begin{env}
  $STOMACH->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\begin{$name}"), $paramlist,$replacement,
				   beforeDigest=>flatten(($mode ? (sub { $STOMACH->beginMode($mode);})
							  : (sub { $STOMACH->bgroup; })),
							 sub { $STOMACH->beginEnvironment($name); },
							 $options{beforeDigest}),
				   afterDigest =>flatten($options{afterDigestBegin}),
				   captureBody=>1, 
				   properties=>$options{properties}||{}),
			     stash=>$options{stash});
  $STOMACH->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end{$name}"),"","",
				   afterDigest=>flatten($options{afterDigest},
							sub { $STOMACH->endEnvironment($name); },
							($mode ? (sub { $STOMACH->endMode($mode);})
							 :(sub { $STOMACH->egroup; })))),
			     stash=>$options{stash});
  # For the uncommon case opened by \csname env\endcsname
  $STOMACH->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\$name"), $paramlist,$replacement,
				   beforeDigest=>flatten(($mode ? (sub { $STOMACH->beginMode($mode);}):()),
							 $options{beforeDigest}),
				   captureBody=>1,
				   properties=>$options{properties}||{}),
			     stash=>$options{stash});
  $STOMACH->installDefinition(LaTeXML::Constructor
			     ->new(T_CS("\\end$name"),"","",
				   afterDigest=>flatten($options{afterDigest},
							($mode ? (sub { $STOMACH->endMode($mode);}):()))),
			     stash=>$options{stash});
  return; }

#======================================================================
# Specify the properties of a Node tag.
our $tag_options = {autoOpen=>1, autoClose=>1, afterOpen=>1, afterClose=>1};

sub Tag {
  my($tag,%properties)=@_;
  CheckOptions("Tag ($tag)",$tag_options,%properties);
  foreach my $key (keys %properties){
    $MODEL->setTagProperty($tag,$key,$properties{$key}); }
  return; }

sub DocType {
  my($rootelement,$pubid,$sysid,$namespace)=@_;
  $MODEL->setDocType($rootelement,$pubid,$sysid,$namespace); 
  return; }

our $require_options = {options=>1};
sub RequirePackage {
  my($package,%options)=@_;
  CheckOptions("RequirePackage ($package)",$require_options,%options);
  $STOMACH->input($package,%options); 
  return; }

sub Let {
  my($token1,$token2)=@_;
  ($token1)=Tokenize($token1)->unlist unless ref $token1;
  $STOMACH->assignMeaning($token1,$STOMACH->lookupMeaning($token2)); }

sub RawTeX {
  my($text)=@_;
  $STOMACH->digest(TokenizeInternal($text)); }
#======================================================================
# Additional support for counters (primarily LaTeX oriented)

sub NewCounter { 
  my($ctr,$within)=@_;
  $ctr=$ctr->toString if ref $ctr;
  $within=$within->toString if $within && ref $within;
  DefRegister("\\c\@$ctr",Number(0));
  $STOMACH->assignValue("\\c\@$ctr",Number(0),1);
  $STOMACH->assignValue("\\cl\@$ctr",Tokens(),1);
  $STOMACH->assignValue("\\cl\@$within",
			      Tokens(T_CS($ctr),$STOMACH->lookupValue("\\cl\@$within")->unlist),1) 
    if $within;
  DefMacro("\\the$ctr","\\arabic{$ctr}");
  }

#======================================================================
# Support for KeyVal type constructs.
# Note that LaTeXML can (surprisingly) read the keyval.sty package, so
# usages within LaTeX can just use that.
# Here we define perl-level declarations so that keyval args can be handled
sub DefKeyVal {
  my($keyset,$key,$type,$default)=@_;
  my $paramlist=parseParameters($type,"KeyVal $key in set $keyset");
  $STOMACH->assignValue('KEYVAL@'.$keyset.'@'.$key, $paramlist->[0]); 
  $STOMACH->assignValue('KEYVAL@'.$keyset.'@'.$key.'@default', Tokenize($default)) 
    if defined $default; }
#======================================================================
# Defining Filters
sub DefTextFilter {
  my(@args)=@_;
  Fatal("DefTextFilter only takes either 2 or 3 arguments") unless (scalar(@args)==2)||(scalar(@args)==3);
  @args = map( (ref $_ ? $_ : $STOMACH->digest(TokenizeInternal($_))), @args);
  my($init,$pattern,$replacement)=(scalar(@args)==2 ? ($args[0],@args) : @args);
  $STOMACH->addTextFilter($init->getInitial, 
			  $pattern,$replacement
#			 (ref $pattern eq 'CODE' ? $pattern : [$pattern->unlist]),
#			 (ref $replacement eq 'CODE' ? $replacement : [$replacement->unlist])
); }

sub DefMathFilter {
  my(@args)=@_;
  Fatal("DefMathFilter only takes either 2 or 3 arguments") unless (scalar(@args)==2)||(scalar(@args)==3);
  @args = map( (ref $_ ? $_ : $STOMACH->digest(TokenizeInternal('$'.$_.'$'))->getBody),
	       @args);
  my($init,$pattern,$replacement)=(scalar(@args)==2 ? ($args[0],@args) : @args);
  $STOMACH->addMathFilter($init->getInitial, 
			  $pattern,$replacement
#			 (ref $pattern eq 'CODE' ? $pattern : [$pattern->unlist]),
#			 (ref $replacement eq 'CODE' ? $replacement : [$replacement->unlist])
); }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Package

=head2 Description

You import (use) C<LaTeXML::Package> when implementing a `Package'; 
the LaTeXML implementation of a LaTeX package.
It exports various declarations and defining forms that allow you to specify what should 
be done with various control sequences, whether there is special treatment of document elements,
and so forth.  Using C<LaTeXML::Package> also imports the functions and variables
defined in L<LaTeXML::Global>, so see that documentation as well.

=head2 SYNOPSIS

To implement a LaTeXML version of a LaTeX package C<somepackage.sty>, 
such that C<\usepackage{somepackage}> would load your custom implementation,
you would need to create the file C<somepackage.ltxml> (It can be anywhere
perl searches for modules [ie the list of directories C<@INC>, which typically
includes the working directory] or in any of those directories with
C<"LaTeXML/Package"> appended).
It's contents would be something like the following code, which
contains random `illustrative' samples collected from the TeX
and LaTeX packages.

A relatively simple package might look something like this:

  use LaTeXML::Package;
  use strict;

  # Load "anotherpackage"
  RequirePackage('anotherpackage');

  # A simple macro, should act just like in TeX
  # For example, to change the style of section numbering
  DefMacro('\thesection', '\thechapter.\roman{section}');

  # A simple case: Define \thanks to add a thanks element
  # with the constructor's argument as content.
  DefConstructor('\thanks{}', "<thanks>#1</thanks>");

  # Define a new math relational symbol.
  # This will create a `dual' whose presentation is a bold 'x', 
  # but whose content form is the name 'myrel'.
  DefMath('\myrel', "\mathbf{x}", role=>'RELOP');

  # Define the negation of myrel.
  DefMath('\notmyrel',  "\mathbf{not x}", role=>'RELOP');
  # and define a Filter that combines \not and \in.
  DefMathFilter('\not\myrel','\notmyrel');

  # To define a symbol \Real to stand for the Reals, 
  # using double struck capital R for presentation
  # It plays a grammatical role as an ID (identifier).
  DefMath('\Real', "\x{211D}", role=>'ID');

  # To define a function \realpart,
  # using BLACK-LETTER CAPITAL R for presentation
  DefMath('\realpart{}', "\x{211C}");

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
  DocType("rootelement","-//Your Site//Your Document Type",'your.dtd');

  # Allow sometag elements to be automatically closed if needed
  Tag('sometag', autoClose=>1);

  # define a roman numeral conversion.
  DefExpandable('\romannumeral Number', sub { roman($_[1]); });

  # Make \pagestyle be ignored.
  DefPrimitive('\pagestyle{}',    undef);

  # These primitives implement LaTeX's \makeatletter and \makeatother.
  # They change the catcode but return nothing to the digested list.
  DefPrimitive('\makeatletter',sub {
     $STOMACH->assignCatcode(CC_LETTER,'@'); return; });
  DefPrimitive('\makeatother', sub {
      $STOMACH->assignCatcode(CC_OTHER,'@'); return; });

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
  	         afterDigest=>sub { $STOMACH->input($_[2]->toString); return;  });
  # If you prefer to be a little less perl-cryptic, you could write
  DefConstructor('\usepackage[]{}',"<?latexml package='#2' ?#1(options='#1')?>",
  	         afterDigest=>sub { my($whatsit,$options,$package)=@_;
                                    $STOMACH->input($package->toString); return;  });

  # Don't forget this; it tells perl the package loaded successfully.
  1;

=head2 Control Sequence Definitions

Many of the following defining forms define the behaviour of a control sequence (macro, 
primitive, register, etc). The general pattern is that the first argument is
a `prototype' of the control sequence and its arguments (described in detail in the
next section), and the second argument describes the replacement as a string, tokens or code.
The remaining arguments are generally optional keyword arguments providing further
control.

A common, but rarely used option is C<stash=>$stash> which causes the
definition to be stored in a global list named C<$stash>;  After the definitions
have gone out of scope, they can be reactivated by C<< $STOMACH->useStash($stash); >>.
This is an experimental feature to allow explicit control of the scope of a definition,
particularly useful for declarative information, when the scoping rules are different
from TeX's usual grouping.

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

  semiverb      : Like {} but with many catcodes and filtering disabled.
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
of Token's.  The only option is C<isConditional> which should be true, for conditional
control sequences (TeX uses these to keep track of conditional nesting when skipping
to \else or \fi).

=item C<< DefMacro($proto,$expansion); >>

Defines the macro expansion for C<$proto>.  C<$expansion> can be a string (which will be tokenized
at definition time) or a LaTeXML::Tokens; any macro arguments will be substituted for parameter
indicators (eg #1) and the result is used as the expansion of the control sequence.
If $expansion is a CODE ref, it will be called with the Gullet and any macro arguments, as arguments,
and it should return a list of Token's.

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
absorbtion by the Intestine, the Whatsit will generate the XML fragment according
to the replacement pattern, or code based on the stored data.

The replacement is a pattern representing the XML fragment to be inserted,
or code called with the Intestine, arguments and properties.
The pattern is simply a bit of XML as a string with certain substitutions made.
Generally, #1, #2 ... is replaced by the corresponding argument (turned into
a string when it appears as an attribute, or recursively processed when it appears as
content). #name stands for named properties stored in the Whatsit. 
The properties font, body and trailer are defined by default (the latter two
only when captureBody is true).  Other properties can be added to Whatsits (how?).
Additionally, the pattern can be conditionallized by surrounding portions of
the pattern by the IF construct ?#1(...) or IF-ELSE ?#1(...)(...) for inclusion 
only when the argument is defined.   Currently, conditionals can NOT be nested.
If the constuctor begins with '^', the XML fragment is allowed to `float up' to
a parent node that is allowed to contain it, according to the Document Type.

DefConstructor options are

  mode           : Changes to this mode (text, display_math 
                   or inline_math) during digestion.
  untex          : Specifies a pattern for untex'ing the 
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

=item C<< DefMath($proto,$tex,%options); >>

A common shorthand constructor; it defines a control sequence that creates a mathematical object,
such as a symbol, function or operator application.  It generates an XMDual using the replacement
$tex for the presentation.  The content information is drawn from the name and options
The untex option is the same as for DefConstructor; the remaining options clarify
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

=item C<< DocType($rootelement,$publicid,$systemid,$namespace); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document, and the default namespace URI.

=item C<< RequirePackage($package); >>

Finds an implementation (either TeX or LaTeXML) for the named C<$package>, and loads it
as appropriate.

=back

=head2 Other useful operations

=over 4

=item C<< Let($token1,$token2); >>

Gives C<$token1> the same `meaning' (definition) as C<$token2>; like TeX's \let.

=item C<< NewCounter($counter,$within); >>

Sets up a counter named $counter, and arranges for it to be reset whenever
the counter C<$within> is incremented. (like \newcounter).

=item C<< DefKeyVal($keyset,$key,$type); >>

Defines the type of value expected for the key $key when parsed in part
of a KeyVal using C<$keyset>.  C<$type> would be something like 'any' or 'Number', but
I'm still working on this.

=item C<< DefTextFilter($pattern,$replacement); >>

=item C<< DefMathFilter($pattern,$replacement); >>

These define filters to apply in text and math.  The C<$pattern> and C<$replacement>
are strings which will be digested to obtain the sequence of boxes.  
The C<$pattern> boxes will be matched against the boxes during digestion; if they
match they will be replaced by the boxes from $replacement.  The following 
two examples replace doubled quotes by the appropriate quotation marks:

  DefTextFilter("``","\N{LEFT DOUBLE QUOTATION MARK}");
  DefTextFilter("''","\N{RIGHT DOUBLE QUOTATION MARK}");

=item C<< DefTextFilter($init,$patterncode,$replacement); >>

=item C<< DefMathFilter($init,$patterncode,$replacement); >>

These forms define filters that use code to determine how many characters match.
The C<$patterncode> is called with the current list of digested things and should
return the number of matched items.  The C<$replacment> gets the list of matched
things and returns a list of things to relace it by.  For efficiency, these
filters are only invoked when the box in C<$init> is encountered.

=item C<< RawTeX('... tex code ...'); >>

RawTeX is a convenience function for including chunks of raw TeX (or LaTeX) code
in a Package implementation.  It is useful for copying portions of the normal
implementation that can be handled simply using macros and primitives.

=back

=cut
