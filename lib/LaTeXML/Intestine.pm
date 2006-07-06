# /=====================================================================\ #
# |  LaTeXML::Intestine                                                 | #
# | Constructs the DOM from digested material                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Intestine;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
use LaTeXML::DOM;
our @ISA = qw(LaTeXML::Object);
#**********************************************************************

# [could conceivable make more sense to let the Stomach create the Intestine?]

sub new {
  my($class, $stomach)=@_;
  bless {model=>$stomach->getModel, 
#	 initialFont=>$stomach->getFont, 
	 initialFont=>$stomach->getValue('default@textfont'),
	 stomach=>$stomach,
	 progress=>0},$class; }

#**********************************************************************
# Accessors
sub getModel { $_[0]->{model}; }

sub getRootNode { $_[0]->{root}; }
sub getNode     { $_[0]->{node}; }
sub setNode     { $_[0]->{node} = $_[1]; }

sub getContext {
  my($self,$short)=@_;
  my $node = $$self{node};
  my $box = $LaTeXML::BOX;
  my $msg = "During DOM construction ";
  $msg .= "for ".$box->toString." from ".$box->getSourceLocator if $box;
  $msg .= "\n" unless $short;
  $node = undef if $short && $box; # ignore node if want short & have box
  $msg .= $node->getContext($short) if $node;
  $msg; }

#**********************************************************************
# Allow lookup of values from Stomach.
# Only will work for values globally set during digestion.

sub getValue { $_[0]->{stomach}->getValue($_[1]); }
sub setValue { $_[0]->{stomach}->setValue($_[1],$_[2],1); }

#**********************************************************************
# Given a digested document, process it, constructing a DOM tree.
sub buildDOM {
  my($self,$doc)=@_;
  NoteProgress("\n(Building");
  local $LaTeXML::INTESTINE = $self;
  local $LaTeXML::STOMACH   = $$self{stomach}; # Can still access FINAL state
  local $LaTeXML::MODEL     = $$self{model};
  $$self{model}->loadDocType([$$self{stomach}->getSearchPaths]);
  $$self{node} = $$self{root} = LaTeXML::DOM::Document->new();
  $$self{node}->setAttribute('font',$$self{initialFont});
  $self->absorb($doc);
  NoteProgress(")");
  $$self{root}; }

sub absorb {
  my($self,$box)=@_;
  local $LaTeXML::BOX = $box;
  $box->beAbsorbed($self); }

#**********************************************************************
# Handlers for various construction operations.
# General naming: 'open' opens a node at current pos and sets it to current,
# 'close' closes current node(s), inserts opens & closes, ie. w/o moving current

# Tricky: if there's a font switch, we may want to open or close nodes.
# We'll want to close nodes if we can minimize the number of font switches.
sub openText {
  my($self,$text,$font)=@_;
  my $n = $$self{node};
  my ($closeable,$bestdiff,$closeto,$lastcloseto,$f)=(1,99999,$n,$n);
  while(defined $n){
    $closeable &&= $n->canAutoClose;
    if(defined (my $f = $n->getAttribute('font'))){
      my $d = $font->distance($f);
      if($d < $bestdiff){
	$bestdiff = $d;
	$closeto = $lastcloseto; 
	last if ($d == 0); }
      last unless $closeable;
      $lastcloseto = $n->getParentNode; }
    $n = $n->getParentNode; }

  # Maybe close some nodes.
  while($$self{node} != $closeto){
    $$self{node} = $$self{node}->getParentNode; } # Hmm... this avoids the daemons!
  # Maybe open a new node.
  if($bestdiff > 0){
    # NOTE: We've embedded the element name here!!! Arghh!!!
    $self->openElement('textstyle',font=>$font); }
  # Finally, insert the darned text.
  $$self{node} = $$self{node}->insertText($text); }

sub insertMathToken {
  my($self,$string,$font)=@_;
  $self->openElement('XMTok', font=>$font);
  $self->getNode->insertText($string);
  $self->closeElement('XMTok'); }

sub openElement {
  my($self,$tag,%attributes)=@_;
  NoteProgress('.') if ($$self{progress}++ % 25)==0;
  $$self{node} = $$self{node}->open($tag,%attributes); 
  # Probably here is the place we can set the `origin' of the node, 
  # or whatever that evolves into....
  if(defined(my $post=$$self{model}->getTagProperty($tag,'afterOpen'))){
    &$post($$self{node},$LaTeXML::BOX); }
  $$self{node}; }

sub closeElement {
  my($self,$tag)=@_;
  $$self{node} = $$self{node}->close($tag); 
  if(defined(my $post=$$self{model}->getTagProperty($tag,'afterClose'))){
    # Hopefully, the node we want to process is now the last child of the
    # current node that has the correct type?
    my @nodes = grep($_->getNodeName eq $tag, $$self{node}->childNodes);
    my $node = $nodes[$#nodes];
    &$post($node,$LaTeXML::BOX); }
  $$self{node}; }

sub openComment {
  my($self,$text)=@_;
  $$self{node} = $$self{node}->insertComment($text); }

sub insertPI      { 
  my($self,$op,%attrib)=@_;
  $$self{node}->insert(LaTeXML::DOM::ProcessingInstruction->new($op,%attrib));}

# Shorthand
sub insertElement {
  my($self,$tag,$content,%attrib)=@_;
  $self->openElement($tag,%attrib);
  $self->absorb($content) if defined $content;
  $self->closeElement($tag); }

#**********************************************************************
# Higher level: Interpret a Constructor pattern.
# It looks like XML!
sub interpretConstructor {
  my($self,$constructor,$args,$props,$floats)=@_;
  $constructor = conditionalize_constructor($constructor,$args,$props);
  my $savenode = undef;
  while($constructor){
    # Processing instruction pattern <?name a=v ...?>
    if($constructor =~ s|^\s*<\?([\w\-_]+)(.*?)\s*\?>||){
      my($target,$avpairs)=($1,$2);
      $self->insertPI($target,parse_avpairs($avpairs,$args,$props)); }
    # Open tag <name a=v ...> (possibly empty <name a=v/>)
    elsif($constructor =~ s|^\s*<([\w\-_]+)(.*?)\s*(/?)>||){
      my($tag,$avpairs,$empty)=($1,$2,$3);
      if($floats && !defined $savenode){
	my $n = $self->getNode;
	while(defined $n && !$n->canContain($tag)){
	  $n = $n->getParentNode; }
	Error("No open node can accept a \"$tag\"") unless defined $n;
	$savenode = $self->getNode;
	$self->setNode($n); }
      $self->openElement($tag,parse_avpairs($avpairs,$args,$props));
      $self->closeElement($tag) if $empty; }
    # A Close tag </name>
    elsif($constructor =~ s|^\s*</([\w\-_]+)\s*>||){
      $self->closeElement($1); }
    # A bare argument #1 or property %prop
    elsif($constructor =~ s/^(\#(\d+)|\%([\w\-_]+))//){      # A positional argument or named property
      my $value = (defined $2 ? $$args[$2-1] : $$props{$3});
      $self->absorb($value) if defined $value; }
    # Attribute: a=v; assigns attribute in current node? May conflict with random text!?!
    elsif($constructor =~ s|^([\w\-_]+)=([\'\"])(.*?)\2||){
      my $key = $1;
      my $value = parse_attribute_value($3,$args,$props);
      my $n = $self->getNode;
      if($floats){
	while(defined $n && ! $n->canHaveAttribute($key)){
	  $n = $n->getParentNode; }
	Error("No open node can accept attribute $key") unless defined $n; }
      $n->setAttribute($key,$value) if defined $value; }
    # Else random text
    elsif($constructor =~ s/^([^\%\#<]+|.)//){	# Else, just some text.
      $self->openText($1,$$props{font}); }
  }
  $self->setNode($savenode) if defined $savenode; 
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
  Error("Couldn't recognize constructor attributes at \"$avpairs\"")
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

=head1 LaTeXML::Intestine

=head2 DESCRIPTION

LaTeXML::Intestine carries out the construction of the document tree (represented by
a LaTeXML::DOM::Document) by traversing the digested LaTeXML::List coming from the
LaTeXML::Stomach.  

=head2 Top-Level Method

=over 4

=item C<< $doc = $intestine->buildDOM($list); >>

Build and return a DOM from the digested $list.
This is done by invoking the absorb method of the digested objects, passing
the intestine as argument.

=back

=head2 Accessing the Intestine's state

=over 4

=item C<< $model = $intestine->getModel; >>

Returns the current LaTeXML::Model being used.

=item C<< $doc = $intestine->getRootNode; >>

Returns the root node (LaTeXML::DOM::Document) of the document being constructed.

=item C<< $node = $intestine->getNode; >>

Returns the node at the current insertion point during construction.  This node
is considered still to be `open'; any insertions will go into it (if possible).

=item C<< $string = $intestine->getContext; >>

Returns a string describing the current position in the constructed tree, for
error messages.

=back

=head2 Methods useful for Document Construction

=over 4

=item C<< $intestine->openText($text,$font); >>

Open a node for text in font $font, performing any required automatic opening
and closing of intermedate nodes (including those needed for font changes) 
and inserting the string $text into it.

=item C<< $intestine->insertMathToken($string,$font); >>

Insert a math token (XMTok) containing the string $string in the given font.

=item C<< $intestine->openElement($tag,%attributes); >>

Open an element, named $tag and with the given attributes.
This will be inserted into the current node while  performing 
any required automatic opening and closing of intermedate nodes.
The new element becomes the current node.
An error is signalled if there is no allowed way to insert such an element into
the current node.

=item C<< $intestine->closeElement($tag); >>

Close the closest open element named $tag including any intermedate nodes that
may be automatically closed.  If that is not possible, signal an error.
The closed node's parent becomes the current node.

=item C<< $intestine->openComment($text); >>

Insert a comment with the given $text into the current node.

=item C<< $intestine->insertPI($op,%attributes); >>

Insert a ProcessingInstruction into the current node.

=item C<< $intestine->insertElement($tag,$content,%attributes); >>

This is a shorthand for creating an element $tag (with given attributes),
absorbing $content from within that new node, and then closing it.

=cut

