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
		  &DefConstructor &DefSymbol
		  &DefEnvironment
		  &DefTextFilter &DefMathFilter &DefKeyVal
		  &Let
		  &RequirePackage
		  &RawTeX
		  &Tag &DocType),
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
# Somebody must have bound $LaTeXML::STOMACH to the stomach that is
# receiving the definitions.

sub parsePrototype {
  my($proto)=@_;
  $proto =~ s/^(\\?[a-zA-Z@]+|\\?.)//; # Match a cs, env name,...
  my($cs,@junk) = TokenizeInternal($1)->unlist;
  Error("Definition prototype doesn't have proper control sequence: $proto") if @junk;
  $proto =~ s/^\s*//;
  ($cs, parseParameters($proto,$cs)); }

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
our $expandable_options = {isConditional=>1};
sub DefExpandable {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefExpandable ($proto)",$expandable_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  STOMACH->setMeaning($cs,LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options));
  return; }

# Define a Macro: Essentially an alias for DefExpandable
# For convenience, the $expansion can be a string which will be tokenized.
sub DefMacro {
  my($proto,$expansion,%options)=@_;
  CheckOptions("DefMacro ($proto)",{},%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $expansion = Tokens() unless defined $expansion;
  $expansion = TokenizeInternal($expansion) unless ref $expansion;
  STOMACH->setMeaning($cs,LaTeXML::Expandable->new($cs,$paramlist,$expansion,%options));
  return; }

#======================================================================
# Define a primitive control sequence. 
#======================================================================
# Primitives are executed in the Stomach.
# The $replacement should be a sub which returns nothing, or a list of Box's or Whatsit's.
# The options are:
#    isPrefix  : 1 for things like \global, \long, etc.
#    registerType : for parameters (but needs to be worked into DefParameter, below).

our $primitive_options = {isPrefix=>1};
sub DefPrimitive {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefPrimitive ($proto)",$primitive_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  $replacement = sub { (); } unless defined $replacement;
  STOMACH->setMeaning($cs,LaTeXML::Primitive->new($cs,$paramlist,$replacement,%options));
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
    || sub { my($stomach,@args)=@_;  
	     $stomach->getValue(join('',$name,map($_->toString,@args))) || $value; };
  my $setter = $options{setter} 
    || sub { my($stomach,$value,@args)=@_; 
	     $stomach->setValue(join('',$name,map($_->toString,@args)),$value); };
  # Not really right to set the value!
  STOMACH->setValue($cs->toString,$value) if defined $value;
  STOMACH->setMeaning($cs,LaTeXML::Register->new($cs,$paramlist, $type,$getter,$setter,
						 readonly=>$options{readonly}));
  return; }

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
#   mathConstructor : a constructor (analogous to replacement) preferred when in math mode.
#   beforeDigest    : code to be executed (in the stomach) before parsing & constructing the Whatsit.
#                     Can be used for changing modes, beginning groups, etc.
#   afterDigest     : code to be executed (in the stomach) after parsing & constructing the Whatsit.
#                     useful for setting Whatsit properties,

our $constructor_options = {mode=>1, 
			    untex=>1, mathConstructor=>1, floats=>1, mathclass=>1, 
			    beforeDigest=>1, afterDigest=>1,
			    captureBody=>1};
sub DefConstructor {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefConstructor ($proto)",$constructor_options,%options);
  my ($cs,$paramlist)=parsePrototype($proto);
  my $mode = $options{mode};
  my $def = LaTeXML::Constructor
    ->new($cs,$paramlist,$replacement,
	  beforeDigest=>[($mode ? (sub { $_[0]->beginMode($mode); }):()),
			 ($options{beforeDigest} ? ($options{beforeDigest}) : ())],
	  afterDigest=>[($options{afterDigest} ? ($options{afterDigest}) : ()),
			($mode ? (sub { $_[0]->endMode($mode) }):())],
	  (defined $options{untex} ? (untex => $options{untex}):()),
	  mathConstructor=> $options{mathConstructor},
	  floats=>$options{floats},
	  (defined $options{mathclass} ? (mathclass=>$options{mathclass}):()),
	  captureBody=>$options{captureBody});
  STOMACH->setMeaning($cs,$def);
  return; }

our $symbol_options = {style=>1, name=>1, mathclass=>1,untex=>1,partOfSpeech=>1};
sub DefSymbol {
  my($cs,$text,$name,%options)=@_;
  CheckOptions("DefSymbol ($cs)",$symbol_options,%options);
  my $mathattr = join('',($name ? " name='$name'" : ''),
		      ($options{partOfSpeech} ? " POS='$options{partOfSpeech}'" : ''),
		      ($options{style} ? " style='$options{style}'" : ''),
		      ' ?%font(font=\'%font\')');
  DefConstructor($cs,$text, mathConstructor=>"<XMTok$mathattr>$text</XMTok>", 
		 mathclass=>$options{mathclass}||'symbol',
		 ($options{untex} ? (untex=>$options{untex}) : ()));
}

#======================================================================
# Define a LaTeX environment
# Note that the body of the environment is treated is the 'body' parameter in the constructor.
our $environment_options = {mode=>1, beforeDigest=>1, afterDigest=>1,
			    afterDigestBegin=>1, #beforeDigestEnd=>1,
			    mathConstructor=>1};
sub DefEnvironment {
  my($proto,$replacement,%options)=@_;
  CheckOptions("DefEnvironment ($proto)",$environment_options,%options);
  $proto =~ s/^\{([^\}]+)\}//; # Pull off the environment name as {name}
  my $name = $1;
  my $paramlist=parseParameters($proto,"Environment $name");
  my $mode = $options{mode};
  # This is for the common case where the environment is opened by \begin{env}
  my $BEG=LaTeXML::Constructor->new("\\begin{$name}", $paramlist,$replacement,
				    mathConstructor  => $options{mathConstructor},
				    beforeDigest=>[($mode ? (sub { $_[0]->beginMode($mode);})
						    : (sub { $_[0]->bgroup; })),
						   sub { $_[0]->beginEnvironment($name); },
						   ($options{beforeDigest} ? ($options{beforeDigest}) : ())],
				    afterDigest =>[($options{afterDigestBegin} ?
						    ($options{afterDigestBegin}) : ())],
				    captureBody=>1);
  my $END=LaTeXML::Constructor->new("\\end{$name}","","",
				    afterDigest=>[($options{afterDigest} ? ($options{afterDigest}) : ()),
						  sub { $_[0]->endEnvironment($name); },
						  ($mode ? (sub { $_[0]->endMode($mode);})
						   :(sub { $_[0]->egroup; }))]);
  # For the uncommon case opened by \csname env\endcsname
  my $beg=LaTeXML::Constructor->new("\\$name", $paramlist,$replacement,
				    mathConstructor  => $options{mathConstructor},
				    beforeDigest=>[($mode ? (sub { $_[0]->beginMode($mode);}):()),
						   ($options{beforeDigest} ? ($options{beforeDigest}) : ())],
				    captureBody=>1);
  my $end=LaTeXML::Constructor->new("\\end$name","","",
				    afterDigest=>[($options{afterDigest} ? ($options{afterDigest}) : ()),
						  ($mode ? (sub { $_[0]->endMode($mode);}):())]),
  STOMACH->setMeaning(T_CS("\\begin{$name}"),$BEG);
  STOMACH->setMeaning(T_CS("\\end{$name}"),$END);
  STOMACH->setMeaning(T_CS("\\$name"),$beg);
  STOMACH->setMeaning(T_CS("\\end$name"),$end);
  return; }

#======================================================================
# Specify the properties of a Node tag.
our $tag_options = {autoOpen=>1, autoClose=>1, afterOpen=>1, afterClose=>1};

sub Tag {
  my($tag,%properties)=@_;
  CheckOptions("Tag ($tag)",$tag_options,%properties);
  foreach my $key (keys %properties){
    MODEL->setTagProperty($tag,$key,$properties{$key}); }
  return; }

sub DocType {
  my($rootelement,$pubid,$sysid,$namespace)=@_;
  MODEL->setDocType($rootelement,$pubid,$sysid,$namespace); 
  return; }

our $require_options = {options=>1};
sub RequirePackage {
  my($package,%options)=@_;
  CheckOptions("RequirePackage ($package)",$require_options,%options);
  STOMACH->input($package,%options); 
  return; }

sub Let {
  my($token1,$token2)=@_;
  ($token1)=Tokenize($token1)->unlist unless ref $token1;
  STOMACH->setMeaning($token1,STOMACH->getMeaning($token2)); }

sub RawTeX {
  my($text)=@_;
  STOMACH->digest(TokenizeInternal($text)); }
#======================================================================
# Additional support for counters (primarily LaTeX oriented)

sub NewCounter { 
  my($ctr,$within)=@_;
  $ctr=$ctr->untex if ref $ctr;
  $within=$within->untex if $within && ref $within;
  DefRegister("\\c\@$ctr",Number(0));
  STOMACH->setValue("\\c\@$ctr",Number(0),1);
  STOMACH->setValue("\\cl\@$ctr",Tokens(),1);
  STOMACH->setValue("\\cl\@$within",
			      Tokens(T_CS($ctr),STOMACH->getValue("\\cl\@$within")->unlist),1) 
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
  STOMACH->setValue('KEYVAL@'.$keyset.'@'.$key, $paramlist->[0]); 
  STOMACH->setValue('KEYVAL@'.$keyset.'@'.$key.'@default', Tokenize($default)) 
    if defined $default; }
#======================================================================
# Defining Filters
sub DefTextFilter {
  my(@args)=@_;
  Error("DefTextFilter only takes either 2 or 3 arguments") unless (scalar(@args)==2)||(scalar(@args)==3);
  my $stomach = STOMACH;
  @args = map( (ref $_ ? $_ : $stomach->digest(TokenizeInternal($_))), @args);
  my($init,$pattern,$replacement)=(scalar(@args)==2 ? ($args[0],@args) : @args);
  $stomach->addTextFilter($init->getInitial, 
			  (ref $pattern eq 'CODE' ? $pattern : [$pattern->unlist]),
			  (ref $replacement eq 'CODE' ? $replacement : [$replacement->unlist])); }

sub DefMathFilter {
  my(@args)=@_;
  Error("DefMathFilter only takes either 2 or 3 arguments") unless (scalar(@args)==2)||(scalar(@args)==3);
  my $stomach = STOMACH;
  @args = map( (ref $_ ? $_ : $stomach->digest(TokenizeInternal('$'.$_.'$'))->getBody),
	       @args);
  my($init,$pattern,$replacement)=(scalar(@args)==2 ? ($args[0],@args) : @args);
  $stomach->addMathFilter($init->getInitial, 
			  (ref $pattern eq 'CODE' ? $pattern : [$pattern->unlist]),
			  (ref $replacement eq 'CODE' ? $replacement : [$replacement->unlist])); }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Package

=head2 Description

LaTeXML::Package is used for defining Packages; LaTeXML implementations of LaTeX packages and so forth.
It exports various declarations and defining forms that allow you to specify what should 
be done with various control sequences, whether there is special treatment of document elements.

=head2 SYNOPSIS

To implement a LaTeXML version of a LaTeX package c<apackage.sty>, 
such that \usepackage{apackage} would load your custom implementation, 
you would need to create the file apackage.ltxml (It can be anywhere
perl searches for modules [ie the list of directories @INC, which typically
includes the working directory] or in any of those directories with
"LaTeXML/Package" appended).
It's contents would be something like the following code, which
contains random `illustrative' samples collected from the TeX
and LaTeX packages. Note that you wouldn't necessarily need to use the
Token package, unless you were using some of that packages exports.
Typically these are put in the package LaTeXML::Package::Pool, although
that only matters if you define subroutines or variables that need
(or need NOT) be shared amongst other Packages.

  package LaTeXML::Package::Pool;
  use strict;
  use LaTeXML::Package;
  use LaTeXML::Token;

  # Load "anotherpackage"
  RequirePackage('anotherpackage');
  DocType("some","-//NIST LaTeXML//LaTeXML SomeDTD",'some.dtd');
  Tag('sometag', autoClose=>1);

  # define a roman numeral conversion.
  DefExpandable('\romannumeral Number', sub { roman($_[1]); });

  # Make \pagestyle be ignored.
  DefPrimitive('\pagestyle{}',    undef);

  # These primitives implement LaTeX's \makeatletter and \makeatother.
  # They change the catcode but return nothing to the digested list.
  # Note that the 1st argument to the sub is a Stomach; 
  # Perl's infamous anonymous form of argument is used here
  DefPrimitive('\makeatletter',sub { $_[0]->setCatcode(CC_LETTER,'@'); return; });
  DefPrimitive('\makeatother', sub { $_[0]->setCatcode(CC_OTHER,'@'); return; });

  # Some frontmatter examples.

  # A simple case: Define \thanks to add a thanks element with the constructor's
  # argument as content.
  DefConstructor('\thanks{}', "<thanks>#1</thanks>");

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
  DefMacro('\maketitle', '\fmt@title{\@title}\fmt@author{\@author}\fmt@date{\@date}');
  # And a simple environment ...
  DefEnvironment('{abstract}','<abstract>%body</abstract>');

  # a different complication:  Have \usepackage generate a processing instruction,
  # but have it's after daemon do the actual input.
  # The constructor pattern uses a conditional clause ?#1(...) that includes the
  # attribute options only if the first (optional) argument is non-empty.
  DefConstructor('\usepackage[]{}',"<?latexml package='#2' ?#1(options='#1')?>",
  	         afterDigest=>sub { $_[0]->input($_[1]->getArg(2)->untex); return;  });
  # If you prefer to be a little less perl-cryptic, you could write
  DefConstructor('\usepackage[]{}',"<?latexml package='#2' ?#1(options='#1')?>",
  	         afterDigest=>sub { my($stomach,$whatsit)=@_;
                                    $stomach->input($whatsit->getArg(2)->untex); return;  });

  # And finally some basic symbols.
  # a text only ligature
  DefSymbol('\oe',"\N{LATIN SMALL LIGATURE OE}");
  # a greek letter that named 'alpha'; In math this gives 
  #  <XMTok name="alpha">unicode character for alpha</XMTok>
  # the mathclass is used to enable the correct font merging.
  DefSymbol('\alpha',     "\N{GREEK SMALL LETTER ALPHA}",'alpha', mathclass=>'lcgreek');
  # Similarly for the not in.
  DefSymbol('\notin',     "\N{NOT AN ELEMENT OF}",'NotIn');
  # and define a Filter that combines \not and \in.
  DefMathFilter('\not\in','\notin');
  # as it turns out, things like \sin are extremely simple; the font defaults to `normal'
  # for multicharacter content.
  DefSymbol('\sin',    "sin");

  # Don't forget this; it signals to perl that the package loaded successfully.
  1;

=head2 Control Sequence Definitions

=head3 Control Sequence Prototypes

Many of the following defining forms define the behaviour of a control sequence (macro, 
primitive, register, etc); they take a `Prototype' as the first argument indicating
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
  semiverb      : Like {} but catcodes are cut back, and filtering is disabled
  Token         : Read a single Token.
  XToken        : Read the next unexpandable Token after expandable ones have
                  been expanded.
  Number        : Read a Number object (according to a TeX's rules for integers)
  Dimension     : Read a Dimension object (according to a TeX's rules for dimensions)
  Glue          : Read a Glue object (according to a TeX's rules for glue)
  MuGlue        : Read a MuGlue object (according to a TeX's rules for muglue)
  Until:...     : Read all tokens (with balanced braces) until matching the seqence
                  given by "...".
  KeyVal:...    : Reads key-value pairs (like the keyval package), where "..." gives
                  the keyset to use.  It parses each value according to the keys
                  defined for keyset by DefKeyVal.
  Default:...   : For an optional argument, "..." specifies the default if no argument
                  is present.

In the following types, the part "..." following the colon are "|" separated
sequences of characters.  The input is expected to match one of the character sequences.
  Keyword:...   : Match one of the character sequences to the input.  The effective
                  argument is the Tokens corresonding to the matched sequence.
  Ignore:...    : Like Keyword, but allows the tokens to be missing, and doesn't 
                  contribute an item to the argument list.
  Flag:...      : Like Keyword, but allows the tokens to be missing (uses value undef).
  Literal:...   : Like Keyword, but doesn't contribute an item to the argument list.

Each item above, unless otherwise noted, contribute an item to the argument list.

=over 4

=item C<< DefExpandable($proto,$expansion,%options); >>

Defines an expandable control sequence. The $expansion should be a CODE ref that will take
the Gullet and any macro arguments as arguments.  It should return the result as a list
of Token's.  The only option is C<isConditional> which should be true, for conditional
control sequences (TeX uses these to keep track of conditional nesting when skipping
to \else or \fi).

=item C<< DefMacro($proto,$expansion); >>

Defines the macro expansion for $proto.  $expansion can be a string (which will be tokenized
at definition time) or a LaTeXML::Tokens; any macro arguments will be substituted for parameter
indicators (eg #1) and the result is used as the expansion of the control sequence.
If $expansion is a CODE ref, it will be called with the Gullet and any macro arguments, as arguments,
and it should return a list of Token's.

=item C<< DefPrimitive($proto,$replacement,%options); >>

Define a primitive control sequence.  The $replacement is a CODE ref that will be
called with the Stomach and any macro arguments as arguments.  Usually it should
return nothing (eg. end with return; ) since they are generally done for side-effect,
but otherwise should return a list of digested items.

The only option is for the special case: isPrefix=>1 is used for assignment  prefixes (like \global).

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
content). %name stands for named properties stored in the Whatsit. 
The properties font, body and trailer are defined by default (the latter two
only when captureBody is true).  Other properties can be added to Whatsits (how?).
Additionally, the pattern can be conditionallized by surrounding portions of
the pattern by ?#1(...), !#1(...) for inclusion only when the
argument is defined or not defined.  Similarly  ?%prop(...), !%prop(...) apply when
a given property is defined or not defined.  Currently, conditionals can NOT be nested.


DefConstructor options are
  mode           : Changes to this mode (text, display_math or inline_math)
                   during digestion.
  untex          : Specifies a pattern for untex'ing the contstructor, if the 
                   default is not appropriate. A string (that can include #1,#2...) 
                   or code called with the $whatsit as argument.
  mathConstructor: A replacement to be used in math mode instead of $replacement.
  floats         : The fragment will be inserted at the closest ancestor of the 
                   current point that it is allowed, and the current insertion 
                   point will not be moved.
  mathclass      : The mathclass used to determine how the current font should be
                   applied to characters in this object.
  beforeDigest   : supplies a Daemon to be executed during digestion just before the
                   Whatsit is created.  It is called with the Stomach as argument;
                   it should either return nothing (return;) or digested items.
  afterDigest    : supplies a Daemon to be executed during digestion just after the
                   Whatsit is created.  It is called with the Stomach and Whatit as
                   arguments; it should either return nothing (return;) or digested items.
  captureBody    : if true, arbitrary following material will be accumulated into 
                   a `body' until the current grouping level is reverted.
                   This is used by environments and math.

=item C<< DefSymbol($cs,$text,$name,%options); >>

A common shorthand constructor; it defines a control sequence that creates a `symbol'
the replacement is $text.  In math it creates a math token (XMTok) with the given name.

The untex option is the same as for DefConstructor; the remaining options are only
relevant for math symbols:
  style        : adds a style attribute to the XMTok.
  name         : gives a name attribute for the XMTok
  mathclass    : defines the mathclass used for determining how the current math 
                 font should apply to the content.
  partOfSpeech : adds a POS attribute to the XMTok.

The name and POS attributes contribute to the eventual parsing of mathematical content.

=item C<< DefEnvironment($proto,$replacement,%options); >>

Defines an Environment that generates a specific XML fragment.  The $replacement is
of the same form as that for DefConstructor, but will generally include reference to
the %body property. Upon encountering a \begin{env}:  the mode is switched, if needed,
else a new group is opened; then the environment name is noted; the beforeDigest daemon is run.
Then the Whatsit representing the begin command (but ultimately the whole environment) is created
and the afterDigestBegin daemon is run.
Next, the body will be digested and collected until the balancing \end{env}.   Then,
any afterDigest daemon is run, the environment is ended, finally the mode is ended or
the group is closed.  The body and \end{env} whatsit are added to the \begin{env}'s whatsit
as body and trailer, respectively.

Options are:
  mode             : changes to this mode to process the body in (eg. equation)
  beforeDigest     : code to execute before digesting the \begin{env}; See DefConstructor
  afterDigestBegin : code to execute after digesting the \begin{env}.
  afterDigest      : code to execute after digesting the  \end{env}.
  mathConstructor  : replacement pattern to be used in math mode.

=back

=head2 Document Declarations

=over 4

=item C<< Tag($tag,%properties); >>

Declares properties of elements with the name $tag.
The recognized properties are:
  autoOpen   :  whether this $tag can be automatically opened if needed to
               insert an element that can only be contained by $tag.
  autoClose  : whether this $tag can be automatically closed if needed to
               close an ancestor node, or insert an element into an ancestor.
  afterOpen  : provides code to be run whenever a node with this $tag 
               is opened.  It is called with the $node and the initiating 
               digested object as arguments.
  afterClose : provides code to be run whenever a node with this $tag 
               is closed.  It is called with the $node and the initiating 
               digested object as arguments.

The autoOpen and autoClose properties help match the more  SGML-like LaTeX to XML.

=item C<< DocType($rootelement,$publicid,$systemid,$namespace); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document, and the default namespace URI.

=item C<< RequirePackage($package); >>

Finds an implementation (either TeX or LaTeXML) for the named $package, and loads it
as appropriate.

=back

=head2 Other useful operations

=over 4

=item C<< Let($token1,$token2); >>

Gives $token1 the same definition as $token2; as TeX's \let.

=item C<< NewCounter($counter,$within); >>

Sets up a counter named $counter, and arranges for it to be reset whenever
the counter $within is incremented. (like \newcounter).

=item C<< DefKeyVal($keyset,$key,$type); >>

Defines the type of value expected for the key $key when parsed in part
of a KeyVal using $keyset.  $type would be something like 'any' or 'Number', but
I'm still working on this.

=item C<< DefTextFilter($pattern,$replacement); >>

=item C<< DefMathFilter($pattern,$replacement); >>

These define filters to apply in text and math.  The $pattern and $replacement
are strings which will be digested to obtain the sequence of boxes.  
The $pattern boxes will be matched against the boxes during digestion; if they
match they will be replaced by the boxes from $replacement.  The following 
two examples replace doubled quotes by the appropriate quotation marks:
  DefTextFilter("``","\N{LEFT DOUBLE QUOTATION MARK}");
  DefTextFilter("''","\N{RIGHT DOUBLE QUOTATION MARK}");

=item C<< DefTextFilter($init,$patterncode,$replacement); >>

=item C<< DefMathFilter($init,$patterncode,$replacement); >>

These forms define filters that use code to determine how many characters match.
The $patterncode is called with the current list of digested things and should
return the number of matched items.  The $replacment gets the list of matched
things and returns a list of things to relace it by.  For efficiency, these
filters are only invoked when the box in $init is encountered.

=item C<< RawTeX('... tex code ...'); >>

RawTeX is a convenience function for including chunks of raw TeX (or LaTeX) code
in a Package implementation.  It is useful for copying portions of the normal
implementation that can be handled simply using macros and primitives.

=back

=cut
