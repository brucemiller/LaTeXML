# /=====================================================================\ #
# |  LaTeXML:Box, LaTeXML:List...                                       | #
# | Digested objects produced in the Stomack                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Box;
use strict;
use LaTeXML::Object;
use Exporter;
our @ISA = qw(LaTeXML::Object Exporter);
our @EXPORT = qw(Box List MathBox MathList Whatsit);
# Profiling hack so new doesn't get seen as BEGIN!
sub dummy {()} dummy();

# Concise exported constructors for various Digested objects.
sub Box { LaTeXML::Box->new(@_); }
sub List { LaTeXML::List->new(@_); }
sub MathBox { LaTeXML::MathBox->new(@_); }
sub MathList { LaTeXML::MathList->new(@_); }
sub Whatsit { LaTeXML::Whatsit->new(@_); }

sub new {
  my($class,$string,$font)=@_;
  my $self=[$string,$font];
  bless $self,$class; }

# Accessors
sub getString { $_[0][0]; }	# Return the string contents of the box
sub getFont   { $_[0][1]; }	# Return the font this box uses.
sub isMath    { 0; }		# Box is text mode.
sub getInitial { $_[0][0]; }	# Return the `initial', for indexing ops.

# So a Box can stand in for a List
sub unlist  { ($_[0]); }	# Return list of the boxes

sub untex { $_[0][0]; }
sub toString { $_[0][0]; }

sub absorb {
  my($self,$intestine)=@_;
  local $LaTeXML::BOX = $self;
  $intestine->openText($$self[0], $$self[1]); }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.$$self[0].']'; }

# Should this compare fonts too?
sub equals {
  my($a,$b)=@_;
  ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]); }

#**********************************************************************
# LaTeXML::MathBox
#**********************************************************************
package LaTeXML::MathBox;
use strict;
our @ISA = qw(LaTeXML::Box);

sub isMath { 1; }		# MathBoxes are math mode.

sub absorb {
  my($self,$intestine)=@_;
  local $LaTeXML::BOX = $self;
  $intestine->insertMathToken($$self[0],$$self[1]); }

#**********************************************************************
# LaTeXML::Comment
#**********************************************************************
package LaTeXML::Comment;
use strict;
our @ISA = qw(LaTeXML::Box);

sub untex { "%".$_[0][0]."\n"; }
sub toString { '';}

sub absorb {
  my($self,$intestine)=@_;
  local $LaTeXML::BOX = $self;
  $intestine->openComment($$self[0]); }
#**********************************************************************
# LaTeXML::List
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::List;
use strict;
use LaTeXML::Error;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

our %boxtypes=map(($_=>1), qw(LaTeXML::Box LaTeXML::MathBox LaTeXML::Comment LaTeXML::List 
			      LaTeXML::MathList LaTeXML::Whatsit));
sub new {
  my($class,@boxes)=@_;
  map( $boxtypes{ref $_} || TypeError($_,"Box|Comment|List|MathList|Whatsit"),@boxes);
  bless [@boxes],$class; }

sub typecheck {
  map( $boxtypes{ref $_} || TypeError($_,"Box|Comment|List|MathList|Whatsit"),@_); }

sub isMath     { 0; }			# List's are text mode
sub getFont    { $_[0]->[0]->getFont; }	# Return font of 1st box (?)
sub getInitial { ($_[0][0] ? $_[0][0]->getInitial : undef); }

sub unlist { @{$_[0]}; }

sub untex {
  my($self,@params)=@_;
  join('',map($_->untex(@params),@$self)); }

sub toString {
  my($self)=@_;
  join('',map($_->toString,@$self)); }

sub absorb {
  my($self,$intestine)=@_;
  local $LaTeXML::BOX = $self;
  map($_->absorb($intestine), @$self); }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.join('',map("$_",@$self)).']'; } # Not ideal, but....

sub equals {
  my($a,$b)=@_;
  return 0 unless (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while(@a && @b && ($a[0] eq $b[0])){
    shift(@a); shift(@b); }
  return !(@a || @b); }

#**********************************************************************
# LaTeXML::MathList
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::MathList;
our @ISA = qw(LaTeXML::List);

sub isMath { 1; }		# MathList's are math mode.

#**********************************************************************
# What about Kern, Glue, Penalty ...

#**********************************************************************
# LaTeXML Whatsit.
#  Some arbitrary object, possibly with arguments.
# Particularly as an intermediate representation for invocations of control
# sequences that do NOT get expanded or processed, but are taken to represent 
# some semantic something or other.
# These get preserved in the expanded/processed token stream to be
# converted into XML objects in the Intestines.
#**********************************************************************
package LaTeXML::Whatsit;
use strict;
use LaTeXML::Error;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,$defn,$stomach,$args,%data)=@_;
  my $ismath = $stomach->inMath;
  my $font = $data{font}
    || ($ismath ? $stomach->getFont->specialize($defn->getMathClass) : $stomach->getFont );
  my $self={definition=>$defn, isMath=>$ismath, args=>$args||[],
	    properties=>{font=>$font,%data}};
  bless $self,$class; }

sub isMath        { $_[0]{isMath}; }
sub getDefinition { $_[0]{definition}; }
sub getFont       { $_[0]{properties}->{font}; } # and if undef ????
sub getProperty   { $_[0]{properties}{$_[1]}; }
sub setProperty   { $_[0]{properties}{$_[1]}=$_[2]; return; }
sub getProperties { $_[0]{properties}; }
sub getArg        { $_[0]{args}->[$_[1]-1]; }
sub getArgs       { @{$_[0]{args}}; }
sub setArgs       { 
  my($self,@args)=@_;
  $$self{args} = [@args]; 
  return; }

sub getBody     { $_[0]{properties}->{body}; }
sub setBody {
  my($self,@body)=@_;
  my $trailer = pop(@body);
  $$self{properties}{body} = ($$self{isMath} ? LaTeXML::MathList->new(@body)
			      : LaTeXML::List->new(@body)); 
  $$self{properties}{trailer} = $trailer; 
  return; }

sub getTrailer  { $_[0]{properties}->{trailer}; }

# Return the `initial' of this object, for indexing.
sub getInitial { $_[0]->getDefinition->getCS; }

# So a Whatsit can stand in for a List
sub unlist  { ($_[0]); }

sub untex {
  my($self,@params)=@_;
  $$self{definition}->untex($self,@params); }

sub toString { $_[0]->untex;}

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $string = "Whatsit[".join(', ',$self->getDefinition->getCS,
			       map((defined $_ ? "$_" : 'undef'),$self->getArgs));
  if(defined $$self{properties}{body}){
    $string .= $$self{properties}{body}->stringify;
    $string .= $$self{properties}{trailer}->stringify; }
  $string."]"; }

sub equals {
  my($a,$b)=@_;
  return 0 unless (ref $a) eq (ref $b);
  return 0 unless $$a{definition} eq $$b{definition};
  my @a = @{$$a{args}};
  my @b = @{$$b{args}};
  while(@a && @b && ($a[0] eq $b[0])){
    shift(@a); shift(@b); }
  return !(@a || @b); }

#**********************************************************************
sub absorb {
  my($self,$intestine)=@_;
  local $LaTeXML::BOX = $self;
  my ($defn,$args,$props) = ($$self{definition},$$self{args},$$self{properties});
  my $constructor = $defn->getConstructor($$self{isMath});
  if(defined $constructor && !ref $constructor && $constructor){
    $constructor = conditionalize_constructor($constructor,$args,$props);
    my ($floats,$savenode) = ($defn->floats,undef);
    while($constructor){
      # Processing instruction pattern <?name a=v ...?>
      if($constructor =~ s|^\s*<\?([\w\-_]+)(.*?)\s*\?>||){
	my($target,$avpairs)=($1,$2);
	$intestine->insertPI($target,parse_avpairs($avpairs,$args,$props)); }
      # Open tag <name a=v ...> (possibly empty <name a=v/>)
      elsif($constructor =~ s|^\s*<([\w\-_]+)(.*?)\s*(/?)>||){
	my($tag,$avpairs,$empty)=($1,$2,$3);
	if($floats && !defined $savenode){
	  my $n = $intestine->getNode;
	  while(defined $n && !$n->canContain($tag)){
	    $n = $n->getParentNode; }
	  Error("No open node can accept a \"$tag\"") unless defined $n;
	  $savenode = $intestine->getNode;
	  $intestine->setNode($n); }
	$intestine->openElement($tag,parse_avpairs($avpairs,$args,$props));
	$intestine->closeElement($tag) if $empty; }
      # A Close tag </name>
      elsif($constructor =~ s|^\s*</([\w\-_]+)\s*>||){
	$intestine->closeElement($1); }
      # A bare argument #1 or property %prop
      elsif($constructor =~ s/^(\#(\d+)|\%([\w\-_]+))//){      # A positional argument or named property
	my $value = (defined $2 ? $$args[$2-1] : $$props{$3});
	$value->absorb($intestine) if defined $value; }
      # Could recognize a=v  to assign attribute to current node? May conflict with random text!?!
      elsif($constructor =~ s|^([\w\-_]+)=([\'\"])(.*?)\2||){
	my $key = $1;
	my $value = parse_attribute_value($3,$args,$props);
	my $n = $intestine->getNode;
	if($floats){
	  while(defined $n && ! $n->canHaveAttribute($key)){
	    $n = $n->getParentNode; }
	  Error("No open node can accept attribute $key") unless defined $n; }
	$n->setAttribute($key,$value) if defined $value; }
      # Else random text
      elsif($constructor =~ s/^([^\%\#<]+|.)//){	# Else, just some text.
	$intestine->openText($1,$$props{font}); }
    }
    $intestine->setNode($savenode) if defined $savenode; }
  elsif(ref $constructor eq 'CODE'){
    &$constructor($intestine,@$args,$props); }
}

# This evaluates conditionals in a constructor pattern, removing any that fail.
# Conditionals are of the form ?#1(...) or ?%foo(...) for Whatsit args or parameters.
# It does NOT handled nested conditionals!!!
sub conditionalize_constructor {
  my($constructor,$args,$props)=@_;
  $constructor =~ s/(\?|\!)(\#(\d+)|\%([\w\-_]+))\(((\\.|[^\)])*)\)/ {
    my $val = ($3 ? $$args[$3-1] : $$props{$4});
    (($1 eq '!' ? !$val : $val) ? $5 : ''); } /gex;
  $constructor; }

# Parse a set of attribute value pairs from a constructor pattern, 
# substituting argument and property values from the whatsit.
sub parse_avpairs {
  my($avpairs,$args,$props)=@_;
  my %attr=();		# Check substitutions for attributes.
  while($avpairs =~ s|^\s*([\w\-_]+)=([\'\"])(.*?)\2||){
    my $key = $1;
    my $value = parse_attribute_value($3,$args,$props);
    $attr{$key}=$value if defined $value; }
  Error("Couldn't recognize constructor attributes for $LaTeXML::BOX at \"$avpairs\"")
    if $avpairs;
  %attr; }

sub parse_attribute_value {
  my($value,$args,$props)=@_;
  if($value =~ /^\#(\d+)$/){ $value = $$args[$1-1]; }
  elsif($value =~ /^\%([\w\-_]+)$/){ $value = $$props{$1}; }
  else {
    $value =~ s/\#(\d+)/ my $x=$$args[$1-1]; (ref $x ? $x->untex : $x);/eg;
    $value =~ s/\%([\w\-_]+)/ my $x=$$props{$1}; (ref $x ? $x->untex : $x); /eg; }
  $value; }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Box, LaTeXML::MathBox, LaTeXML::Comment, LaTeXML::List, LaTeXML::MathList and LaTeXML::Whatsit.

=head2 DESCRIPTION

These represent various kinds of digested objects:
LaTeXML::Box represents a text character in a particular font;
LaTeXML::MathBox represents a math character in a particular font;
LaTeXML::List represents a sequence of digested things in text;
LaTeXML::MathList represents a sequence of digested things in math;
LaTeXML::Whatsit represents a digested object that can generate
arbitrary elements in the XML Document.

=head2 Exports

The following constructors are exported, for convenience.

=over 4

=item C<< $box = Box($string,$font); >>

Create a L<LaTeXML::Box> for the given $string, in the given $font.

=item C<< $mathbox = MathBox($string,$font); >>

Create a  L<LaTeXML::MathBox> for the given $string, in the given $font.

=item C<< $list = List(@boxes); >>

Create a L<LaTeXML::List> containing the given @boxes.

=item C<< $mathlist = MathList(@mathboxes); >>

Create a L<LaTeXML::MathList> containing the given @mathboxes.

=item C<< $whatsit = Whatsit($defn,$stomach,$args,%data); >>

Create a L<LaTeXML::Whatsit> according to $defn, with the given $args (an 
array reference containing the arguments) and any extra relevant %data.

=back

=head2 Common Methods for all digested objects.

All these classes extend L<LaTeXML::Object> and so implement
the C<stringify> and C<equals> operations.

=over 4

=item C<< $font = $digested->getFont; >>

Returns the font used by $digested.

=item C<< $boole = $digested->isMath; >>

Returns whether the $digested object was created in math mode.

=item C<< $string = $digested->getInitial; >>

Returns the `initial' of $digested;  This is used
to improve certain table lookups, such as finding
relevant Filters.

=item C<< @boxes = $digested->unlist; >>

Returns a list of the boxes contained in $digested.
It is also defined for the Boxes and Whatsit (which just
return themselves) so they can stand-in for a List.

=item C<< $string = $digested->toString; >>

Returns a string representing this $digested.

=item C<< $string = $digested->untex; >>

Returns the TeX string that corresponds to this $digested
in a form (hopefully) suitable for processing by TeX,
if needed.

=item C<< $digested->absorb($intestine); >>

Inserts the contents of $digested into the DOM that the
$intestine is building in a manner appropriate to the type
of $digested.

=back

=head2 Methods specific of LaTeXML::Box and LaTeXML::MathBox

=over 4

=item C<< $string = $box->getString; >>

Returns the string part of the $box.

=back

=head2 Methods specific to LaTeXML::Whatsit

LaTeXML::Whatsit extends LaTeXML::Object.
Note that the font is stored in the data properties under 'font'.

=over 4

=item C<< $defn = $whatsit->getDefinition; >>

Returns the LaTeXML::Definition responsible for creating this $whatsit.

=item C<< $value = $whatsit->getProperty($key); >>

Returns the value associated with the $key in the $whatsits property list.

=item C<< $whatsit->setProperty($key,$value); >>

Sets the $value associated with the $key in the $whatsits property list.

=item C<< $props = $whatsit->getProperties; >>

Returns the hash reference representing the property list of $whatsit.

=item C<< $list = $whatsit->getArg($n); >>

Returns the $n-th argument (starting from 1) for this $whatsit.

=item C<< @args = $whatsit->getArgs; >>

Returns the list of arguments for this $whatsit.

=item C<< $whatsit->setArgs(@args); >>

Sets the list of arguments for this $whatsit to @args (each arg should be a LaTeXML::List
or LaTeXML::MathList).

=item C<< $list = $whatsit->getBody; >>

Return the body for this $whatsit. This is only defined for environments or
top-level math formula.  The body is stored in the properties under 'body'.

=item C<< $whatsit->setBody(@body); >>

Sets the body of the $whatsit to the boxes in @body.  The last $box in @body
is assumed to represent the `trailer', that is the result of the invokation
that closed the environment or math.  It is stored separately in the properties
under 'trailer'.

=item C<< $list = $whatsit->getTrailer; >>

Return the trailer for this $whatsit. See setBody.

=item C<< $whatsit->absorb($intestine); >>

Inserts itself into the DOM being constructed by the $intestine.
The definition that created this $whatsit is a LaTeXML::Constructor,
it has a constructor which is either a procedure (CODE ref) or a string.
If a procedure, that procedure is called as
   &$constructor($intestine,@$args,$props)
Otherwise, the string is interpreted as a template representing the XML
fragment to be created.  See L<LaTeXML::Definition>

=back

=cut
