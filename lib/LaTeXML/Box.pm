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
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,$string,$font)=@_;
  my $self=[$string,$font || Font()];
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

sub beAbsorbed {
  my($self,$intestine)=@_;
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

sub getSourceLocator { 'unknown'; }
  
#**********************************************************************
# LaTeXML::MathBox
#**********************************************************************
package LaTeXML::MathBox;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Box);

sub new {
  my($class,$string,$font)=@_;
  my $self=[$string,$font || MathFont()];
  bless $self,$class; }

sub isMath { 1; }		# MathBoxes are math mode.

sub beAbsorbed {
  my($self,$intestine)=@_;
  $intestine->insertMathToken($$self[0],$$self[1]); }

#**********************************************************************
# LaTeXML::Comment
#**********************************************************************
package LaTeXML::Comment;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Box);

sub untex    { ''; }
sub toString { ''; }

sub beAbsorbed {
  my($self,$intestine)=@_;
  $intestine->openComment($$self[0]); }

#**********************************************************************
# LaTeXML::List
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::List;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,@boxes)=@_;
  bless [@boxes],$class; }

sub isMath     { 0; }			# List's are text mode
sub getFont    { $_[0]->[0]->getFont; }	# Return font of 1st box (?)
sub getInitial { ($_[0][0] ? $_[0][0]->getInitial : undef); }

sub unlist { @{$_[0]}; }

sub untex {
  my($self)=@_;
  join('',map($_->untex,@$self)); }

sub toString {
  my($self)=@_;
  join('',map($_->toString,@$self)); }

sub beAbsorbed {
  my($self,$intestine)=@_;
  map($intestine->absorb($_), @$self); }

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
use LaTeXML::Global;
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
use LaTeXML::Global;
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,$defn,$stomach,$args,%data)=@_;
  my $ismath = $stomach->inMath;
  my $font = $data{font}
    || ($ismath ? $stomach->getFont->specialize($defn->getMathClass) : $stomach->getFont );
  my($file,$line)=$stomach->getSourceLocation;
  my $self={definition=>$defn, isMath=>$ismath, args=>$args||[],
	    properties=>{font=>$font,%data},
	    filename=>$file, line=>$line};
  bless $self,$class; }

sub isMath        { $_[0]{isMath}; }
sub getDefinition { $_[0]{definition}; }
sub getFont       { $_[0]{properties}->{font}; } # and if undef ????
sub setFont       { $_[0]{properties}->{font} = $_[1]; }
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
  my($self)=@_;
  $$self{definition}->untex($self); }

sub toString { $_[0]->untex;}

sub getSourceLocator { 
  my($self)=@_;
  "file $$self{filename}, line $$self{line}"; }

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

sub beAbsorbed {
  my($self,$intestine)=@_;
  my $defn = $$self{definition};
  my $constructor = $defn->getConstructor($$self{isMath});
  if(defined $constructor && !ref $constructor && $constructor){
    $intestine->interpretConstructor($constructor); }
  elsif(ref $constructor eq 'CODE'){
    &$constructor($intestine,@{$$self{args}},$$self{properties}); }
}

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

See L<LaTeXML::Global> for convenient constructors for these objects.

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

=item C<< $digested->beAbsorbed($intestine); >>

This method tells the $digested to insert it's content into the DOM
that the $intestine is building in whatever manner is appropriate for its type.

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

=item C<< $whatsit->beAbsorbed($intestine); >>

Inserts itself into the DOM being constructed by the $intestine.
The definition that created this $whatsit is a LaTeXML::Constructor,
it has a constructor which is either a procedure (CODE ref) or a string.
If a procedure, that procedure is called as
   &$constructor($intestine,@$args,$props)
Otherwise, the string is interpreted as a template representing the XML
fragment to be created.  See L<LaTeXML::Definition>

=back

=cut
