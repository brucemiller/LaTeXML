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
use LaTeXML::Error;
use LaTeXML::Definition;
use LaTeXML::Object;
use LaTeXML::DOM;
our @ISA = qw(LaTeXML::Object);
#**********************************************************************

sub new {
  my($class, $stomach)=@_;
  bless {model=>$stomach->getModel, initialFont=>$stomach->getFont, stomach=>$stomach},$class; }

#**********************************************************************
# Accessors
sub getModel { $_[0]->{model}; }

sub getRootNode { $_[0]->{root}; }
sub getNode     { $_[0]->{node}; }
sub setNode     { $_[0]->{node} = $_[1]; }

sub getContext { ($_[0]->{node} ? $_[0]->{node}->getContext($_[1]) : ''); }

#**********************************************************************
# Given a digested document, process it, constructing a DOM tree.
sub buildDOM {
  my($self,$doc)=@_;
  Message("Building DOM...") if Debugging();
  local $LaTeXML::INTESTINE = $self;
  local $LaTeXML::MODEL     = $self->getModel;
  $self->getModel->loadDocType([$$self{stomach}->getSearchPaths]);
  $$self{node} = $$self{root} = LaTeXML::DOM::Document->new($LaTeXML::MODEL);
  $$self{node}->setAttribute('font',$$self{initialFont});
  $doc->absorb($self);
  $$self{root}; }

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
  $$self{node} = $$self{node}->open($tag,%attributes); 
  # Probably here is the place we can set the `origin' of the node, 
  # or whatever that evolves into....
  if(defined(my $post=$self->getModel->getTagProperty($tag,'afterOpen'))){
    &$post($$self{node},$LaTeXML::BOX); }
  $$self{node}; }

sub closeElement {
  my($self,$tag)=@_;
  $$self{node} = $$self{node}->close($tag); 
  if(defined(my $post=$self->getModel->getTagProperty($tag,'afterClose'))){
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
  $content->absorb($self) if defined $content;
  $self->closeElement($tag); }

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

