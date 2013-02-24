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
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my($class,$string,$font,$locator,$tokens)=@_;
  return bless [$string,$font,$locator,$tokens],$class; }

# Accessors
sub isaBox {
  return 1; }

sub getString {
  my($self)=@_;
  return $$self[0]; }	# Return the string contents of the box

sub getFont {
  my($self)=@_;
  $$self[1]; }	# Return the font this box uses.

sub isMath {
  return 0; }		# Box is text mode.

sub getLocator {
  my($self)=@_;
  return $$self[2]; }

sub getSource {
  my($self)=@_;
  return $$self[2]; }

# So a Box can stand in for a List
sub unlist {
  my($self)=@_;
  return ($self); }	# Return list of the boxes

sub revert {
  my($self)=@_;
  return ($$self[3] ? $$self[3]->unlist : ()); }

sub toString {
  my($self)=@_;
  return $$self[0]; }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  return $type.'['.(defined $$self[0] ? $$self[0] : '').']'; }

# Should this compare fonts too?
sub equals {
  my($a,$b)=@_;
  return (defined $b) && ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]) && ($$a[1]->equals($$b[1])); }

sub beAbsorbed {
  my($self,$document)=@_;
  my $string = $$self[0];
  return ((defined $string) && ($string ne '')
	  ? $document->openText($$self[0],$$self[1]) : undef); }

sub getProperty { 
  my($self,$property)=@_;
  if($property eq 'isSpace'){
    my $tex = UnTeX($$self[3]);
    return (defined $tex) && ($tex =~ /^\s*$/); } # Check the TeX code, not (just) the string!
  else {
    return; }}

sub getProperties { return (); }
sub setProperty   { }
sub setProperties { }

#**********************************************************************
# LaTeXML::MathBox
#**********************************************************************
package LaTeXML::MathBox;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

sub new {
  my($class,$string,$font,$locator,$tokens,$attributes)=@_;
  return bless [$string,$font,$locator,$tokens,$attributes],$class; }

sub isMath {
  return 1; }		# MathBoxes are math mode.

sub beAbsorbed {
  my($self,$document)=@_;
  my $string = $$self[0];
  return ((defined $string) && ($string ne '')
	  ? $document->insertMathToken($$self[0],font=>$$self[1], ($$self[4]? %{$$self[4]} : ()))
	  : undef); }

#**********************************************************************
# LaTeXML::Comment
#**********************************************************************
package LaTeXML::Comment;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

sub revert   { return (); }
sub toString { return ''; }

sub beAbsorbed {
  my($self,$document)=@_;
  return $document->insertComment($$self[0]); }

#**********************************************************************
# LaTeXML::List
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::List;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

sub new {
  my($class,@boxes)=@_;
  my($b,$font,$locator);
  my @b=@boxes;
  while(defined ($b=shift(@b)) && (!defined $locator)){
    $locator = $b->getLocator unless defined $locator; }
  @b=@boxes;
  # Maybe the most representative font for a List is the font of the LAST box (that _has_ a font!) ???
  while(defined ($b=pop(@b)) && (!defined $font)){
    $font = $b->getFont unless defined $font; }
  return bless [[@boxes],$font,$locator||''],$class; }

sub isMath     {
  return 0; }			# List's are text mode

sub unlist {
  my($self)=@_;
  return @{$$self[0]}; }

sub revert {
  my($self)=@_;
  return map(Revert($_),$self->unlist); }

sub toString {
  my($self)=@_;
  return join('',grep(defined $_,map($_->toString,$self->unlist))); }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  return $type.'['.join(',',map(Stringify($_),$self->unlist)).']'; } # Not ideal, but....

sub equals {
  my($a,$b)=@_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  my @a = $a->unlist;
  my @b = $b->unlist;
  while(@a && @b && ($a[0]->equals($b[0]))){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub beAbsorbed {
  my($self,$document)=@_;
  return map($document->absorb($_), $self->unlist); }

#**********************************************************************
# LaTeXML::MathList
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::MathList;
use LaTeXML::Global;
use base qw(LaTeXML::List);

sub isMath {
  return 1; }		# MathList's are math mode.

#**********************************************************************
# What about Kern, Glue, Penalty ...

#**********************************************************************
# LaTeXML Whatsit.
#  Some arbitrary object, possibly with arguments.
# Particularly as an intermediate representation for invocations of control
# sequences that do NOT get expanded or processed, but are taken to represent 
# some semantic something or other.
# These get preserved in the expanded/processed token stream to be
# converted into XML objects in the document.
#**********************************************************************
package LaTeXML::Whatsit;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

# Specially recognized (some required?) properties:
#  font    : The font object
#  locator : a locator string, where in the source this whatsit was created
#  isMath  : whether this is a math object
#  id
#  body
#  trailer
sub new {
  my($class,$defn,$args,%properties)=@_;
  return bless {definition=>$defn, args=>$args||[], properties=>{%properties}},$class; }

sub getDefinition {
  my($self)=@_;
  return $$self{definition}; }

sub isMath {
  my($self)=@_;
  return $$self{properties}{isMath}; }

sub getFont {
  my($self)=@_;
  return $$self{properties}{font}; } # and if undef ????

sub setFont {
  my($self,$font)=@_;
  $$self{properties}{font} = $font;
  return; }

sub getLocator {
  my($self)=@_;
  return $$self{properties}{locator}; }

sub getProperty {
  my($self,$key)=@_;
  return $$self{properties}{$key}; }

sub getProperties {
  my($self)=@_;
  return %{$$self{properties}}; }

sub setProperty {
  my($self,$key,$value)=@_;
  $$self{properties}{$key}=$value;
  return; }

sub setProperties {
  my($self,%props) = @_;
  while (my ($key, $value) = each %props) { 
    $$self{properties}{$key} = $value if defined $value; }
  return; }

sub getArg {
  my($self,$n)=@_;
  return $$self{args}[$n-1]; }

sub getArgs {
  my($self)=@_;
  return @{$$self{args}}; }

sub setArgs { 
  my($self,@args)=@_;
  $$self{args} = [@args];
  return; }

sub getBody {
  my($self)=@_;
  return $$self{properties}{body}; }

sub setBody {
  my($self,@body)=@_;
  my $trailer = pop(@body);
  $$self{properties}{body} = ($self->isMath ? LaTeXML::MathList->new(@body) : LaTeXML::List->new(@body));
  $$self{properties}{trailer} = $trailer;
  # And copy any otherwise undefined properties from the trailer
  if($trailer){
    my %trailerhash = $trailer->getProperties;
    foreach my $prop (keys %trailerhash){
      $$self{properties}{$prop} = $trailer->getProperty($prop) unless defined $$self{properties}{$prop}; }}
  return; }

sub getTrailer {
  my($self)=@_;
  return $$self{properties}{trailer}; }

# So a Whatsit can stand in for a List
sub unlist {
  my($self)=@_;
  return ($self); }

sub revert {
  my($self)=@_;
  # WARNING: Forbidden knowledge?
  # But how else to cache this stuff (which is a big performance boost)
  if(my $saved = ($LaTeXML::DUAL_BRANCH
		  ? $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH}
		  : $$self{reversion})) {
    $saved->unlist; }
  else {
    my $defn = $self->getDefinition;
    my $spec = $defn->getReversionSpec;
    my @tokens = ();
    if((defined $spec) && (ref $spec eq 'CODE')){ # If handled by CODE, call it
      @tokens = &$spec($self,$self->getArgs); }
    else {
      if(defined $spec){
	@tokens=LaTeXML::Expandable::substituteTokens($spec,map(Tokens(Revert($_)),$self->getArgs))
	  if $spec ne ''; }
      else {
	my $alias = $defn->getAlias;
      if(defined $alias){
	push(@tokens, T_CS($alias)) if $alias ne ''; }
      else {
	push(@tokens,$defn->getCS); }
      if(my $parameters = $defn->getParameters){
	push(@tokens,$parameters->revertArguments($self->getArgs)); }}
    if(defined (my $body = $self->getBody)){
      push(@tokens, Revert($body));
      if(defined (my $trailer = $self->getTrailer)){
	push(@tokens, Revert($trailer)); }}}
    # Now cache it, in case it's needed again
    if($LaTeXML::DUAL_BRANCH){
      $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH}=Tokens(@tokens); }
    else {
      $$self{reversion}=Tokens(@tokens); }
    @tokens; }}

sub toString {
  my($self)=@_;
  return ToString(Tokens($self->revert)); } # What else??

sub getString {
  my($self)=@_;
  return $self->toString; }		  # Ditto?

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $hasbody = defined $$self{properties}{body};
  return "Whatsit[".join(',',$self->getDefinition->getCS->getCSName,
			 map(Stringify($_),
			     $self->getArgs,
			     (defined $$self{properties}{body}
			      ? ($$self{properties}{body},$$self{properties}{trailer})
			      : ())))
    ."]"; }

sub equals {
  my($a,$b)=@_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  return 0 unless $$a{definition} eq $$b{definition}; # I think we want IDENTITY here, not ->equals
  my @a = @{$$a{args}}; push(@a, $$a{properties}{body}) if  $$a{properties}{body};
  my @b = @{$$b{args}}; push(@b, $$b{properties}{body}) if  $$b{properties}{body};
  while(@a && @b && ($a[0]->equals($b[0]))){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub beAbsorbed {
  my($self,$document)=@_;
  return $self->getDefinition->doAbsorbtion($document,$self); }
####  &{$self->getDefinition->getConstructor}($document,@{$$self{args}},$$self{properties});}

#**********************************************************************
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::Box> - Representations of digested objects.

=head1 DESCRIPTION

These represent various kinds of digested objects

=over 4

=item C<LaTeXML::Box>

represents text in a particular font;

=item C<LaTeXML::MathBox>

=begin latex

\label{LaTeXML::MathBox}

=end latex

represents a math token in a particular font;

=item C<LaTeXML::List>

=begin latex

\label{LaTeXML::List}

=end latex

represents a sequence of digested things in text;

=item C<LaTeXML::MathList>

=begin latex

\label{LaTeXML::MathList}

=end latex

represents a sequence of digested things in math;

=item C<LaTeXML::Whatsit>

=begin latex

\label{LaTeXML::Whatsit}

=end latex

represents a digested object that can generate arbitrary elements in the XML Document.

=back

=head2 Common Methods

All these classes extend L<LaTeXML::Object> and so implement
the C<stringify> and C<equals> operations.

=over 4

=item C<< $font = $digested->getFont; >>

Returns the font used by C<$digested>.

=item C<< $boole = $digested->isMath; >>

Returns whether C<$digested> was created in math mode.

=item C<< @boxes = $digested->unlist; >>

Returns a list of the boxes contained in C<$digested>.
It is also defined for the Boxes and Whatsit (which just
return themselves) so they can stand-in for a List.

=item C<< $string = $digested->toString; >>

Returns a string representing this C<$digested>.

=item C<< $string = $digested->revert; >>

Reverts the box to the list of C<Token>s that created (or could have
created) it.

=item C<< $string = $digested->getLocator; >>

Get a string describing the location in the original source that gave rise
to C<$digested>.

=item C<< $digested->beAbsorbed($document); >>

C<$digested> should get itself absorbed into the C<$document> in whatever way
is apppropriate.

=back

=head2 Box Methods

The following methods are specific to C<LaTeXML::Box> and C<LaTeXML::MathBox>.

=over 4

=item C<< $string = $box->getString; >>

Returns the string part of the C<$box>.

=back

=head2 Whatsit Methods

Note that the font is stored in the data properties under 'font'.

=over 4

=item C<< $defn = $whatsit->getDefinition; >>

Returns the L<LaTeXML::Definition> responsible for creating C<$whatsit>.

=item C<< $value = $whatsit->getProperty($key); >>

Returns the value associated with C<$key> in the C<$whatsit>'s property list.

=item C<< $whatsit->setProperty($key,$value); >>

Sets the C<$value> associated with the C<$key> in the C<$whatsit>'s property list.

=item C<< $props = $whatsit->getProperties(); >>

Returns the hash of properties stored on this Whatsit.
(Note that this hash is modifiable).

=item C<< $props = $whatsit->setProperties(%keysvalues); >>

Sets several properties, like setProperty.

=item C<< $list = $whatsit->getArg($n); >>

Returns the C<$n>-th argument (starting from 1) for this C<$whatsit>.

=item C<< @args = $whatsit->getArgs; >>

Returns the list of arguments for this C<$whatsit>.

=item C<< $whatsit->setArgs(@args); >>

Sets the list of arguments for this C<$whatsit> to C<@args> (each arg should be
a C<LaTeXML::List> or C<LaTeXML::MathList>).

=item C<< $list = $whatsit->getBody; >>

Return the body for this C<$whatsit>. This is only defined for environments or
top-level math formula.  The body is stored in the properties under 'body'.

=item C<< $whatsit->setBody(@body); >>

Sets the body of the C<$whatsit> to the boxes in C<@body>.  The last C<$box> in C<@body>
is assumed to represent the `trailer', that is the result of the invocation
that closed the environment or math.  It is stored separately in the properties
under 'trailer'.

=item C<< $list = $whatsit->getTrailer; >>

Return the trailer for this C<$whatsit>. See C<setBody>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
