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
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my($class,$string,$font,$locator,$tokens)=@_;
  bless [$string,$font,$locator,$tokens],$class; }

# Accessors
sub isaBox     { 1; }
sub getString  { $_[0][0]; }	# Return the string contents of the box
sub getFont    { $_[0][1]; }	# Return the font this box uses.
sub isMath     { 0; }		# Box is text mode.
sub getLocator { $_[0][2]; }
sub getSource  { $_[0][2]; }

# So a Box can stand in for a List
sub unlist     { ($_[0]); }	# Return list of the boxes
sub revert     { ($_[0][3] ? $_[0][3]->unlist : ()); }
sub toString   { $_[0][0]; }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.(defined $$self[0] ? $$self[0] : '').']'; }

# Should this compare fonts too?
sub equals {
  my($a,$b)=@_;
  (defined $b) && ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]) && ($$a[1]->equals($$b[1])); }

sub beAbsorbed {
  my $string = $_[0][0];
  ((defined $string) && ($string ne '') ? $_[1]->openText($_[0][0],$_[0][1]) : undef); }

sub getProperty { 
  my($self,$property)=@_;
  if($property eq 'isSpace'){
    my $tex = UnTeX($$self[3]);
    return (defined $tex) && ($tex =~ /^\s*$/); } # Check the TeX code, not (just) the string!
  else {
    undef; }}

sub getProperties { (); }

#**********************************************************************
# LaTeXML::MathBox
#**********************************************************************
package LaTeXML::MathBox;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

sub isMath { 1; }		# MathBoxes are math mode.

sub beAbsorbed {
  my $string = $_[0][0];
  ((defined $string) && ($string ne '') ? $_[1]->insertMathToken($_[0][0],font=>$_[0][1]) : undef); }

#**********************************************************************
# LaTeXML::Comment
#**********************************************************************
package LaTeXML::Comment;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Box);

sub revert   { (); }
sub toString { ''; }

sub beAbsorbed { $_[1]->insertComment($_[0][0]); }

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
  bless [[@boxes],$font,$locator||''],$class; }

sub isMath     { 0; }			# List's are text mode

sub unlist { @{$_[0][0]}; }

sub revert {
  my($self)=@_;
   map(Revert($_),$self->unlist); }

sub toString {
  my($self)=@_;
  join('',grep(defined $_,map($_->toString,$self->unlist))); }

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.join(',',map(Stringify($_),$self->unlist)).']'; } # Not ideal, but....
sub equals {
  my($a,$b)=@_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  my @a = $a->unlist;
  my @b = $b->unlist;
  while(@a && @b && ($a[0]->equals($b[0]))){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub beAbsorbed { map($_[1]->absorb($_), $_[0]->unlist); }

#**********************************************************************
# LaTeXML::MathList
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::MathList;
use LaTeXML::Global;
use base qw(LaTeXML::List);

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
  bless {definition=>$defn, args=>$args||[], properties=>{%properties}},$class; }

sub getDefinition { $_[0]{definition}; }
sub isMath        { $_[0]{properties}{isMath}; }
sub getFont       { $_[0]{properties}{font}; } # and if undef ????
sub setFont       { $_[0]{properties}{font} = $_[1]; }
sub getLocator    { $_[0]{properties}{locator}; }
sub getProperty   { $_[0]{properties}{$_[1]}; }
sub getProperties { %{$_[0]{properties}}; }
sub setProperty   { $_[0]{properties}{$_[1]}=$_[2]; return; }
sub setProperties {
    my ($self, %props) = @_;
    while (my ($key, $value) = each %props) { 
	$$self{properties}{$key} = $value if defined $value; }
    return; }

sub getArg        { $_[0]{args}->[$_[1]-1]; }
sub getArgs       { @{$_[0]{args}}; }
sub setArgs       { 
  my($self,@args)=@_;
  $$self{args} = [@args]; 
  return; }

sub getBody     { $_[0]{properties}{body}; }
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

sub getTrailer  { $_[0]{properties}{trailer}; }

# So a Whatsit can stand in for a List
sub unlist  { ($_[0]); }

sub revert {
  my($self)=@_;
  my $defn = $self->getDefinition;
  my $spec = $defn->getReversionSpec;
  if((defined $spec) && (ref $spec eq 'CODE')){
    return &$spec($self,$self->getArgs); }
  else {
    my @tokens = ();
    if(defined $spec){
      @tokens=LaTeXML::Expandable::substituteTokens($spec,map(Tokens(Revert($_)),$self->getArgs))
	if $spec ne '';
    }
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
	push(@tokens, Revert($trailer)); }}
    @tokens; }}

sub toString { ToString(Tokens($_[0]->revert)); } # What else??

# Methods for overloaded operators
sub stringify {
  my($self)=@_;
  my $string = "Whatsit[".join(',',$self->getDefinition->getCS->getCSName,
			       map(Stringify($_),$self->getArgs));
  if(defined $$self{properties}{body}){
    $string .= Stringify($$self{properties}{body});
    $string .= Stringify($$self{properties}{trailer}); }
  $string."]"; }

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
  $self->getDefinition->doAbsorbtion($document,$self); }
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
