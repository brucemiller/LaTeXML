# /=====================================================================\ #
# |  LaTeXML::Intestine                                                 | #
# | Constructs the Document from digested material                      | #
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
use LaTeXML::Node;
our @ISA = qw(LaTeXML::Object);
#**********************************************************************

# [could conceivable make more sense to let the Stomach create the Intestine?]

sub new {
  my($class)=@_;
  bless {idstore=>{}, progress=>0},$class; }

#**********************************************************************
# Accessors

sub getRootNode { $_[0]->{root}; }
sub getNode     { $_[0]->{node}; }
sub setNode     { $_[0]->{node} = $_[1]; }

# Note: $node->getNodeNmme gets invoked so often, we're inlining => $$node{tag};

sub getNodePath {
  my($self)=@_;
  my $node = $$self{node};
  my $path = $$node{tag};
  while($node = $node->getParentNode){
    $path .= " < ".$$node{tag}; }
  $path; }

#**********************************************************************
# Record nodes by id
sub recordID {
  my($self,$id,$object)=@_;
  $$self{idstore}{$id}=$object; }

sub lookupID {
  my($self,$id)=@_;
  $$self{idstore}{$id}; }

#**********************************************************************
# Given a digested document, process it, constructing a DOM tree.
# Top-level API.
sub buildDOM {
  my($self,$doc)=@_;
  NoteProgress("\n(Building");
  my $font = $STOMACH->lookupValue('default@textfont');
  $$self{node} = $$self{root} = LaTeXML::Document->new(publicID=>$MODEL->getPublicID, 
						       systemID=>$MODEL->getSystemID,_font=>$font);
  $self->absorb($doc);
  NoteProgress(")");
  $$self{root}->toXML; }

# absorb a given object into the DOM.
sub absorb {
  my($self,$box)=@_;
  if(!defined $box){}
  elsif(ref $box){
    local $LaTeXML::BOX = $box;
    $box->beAbsorbed; }
  # The following handle inserting raw strings, presumably within the context of some constructor?
  elsif(!$LaTeXML::BOX->isMath){
    $self->openText_internal($box); }
  elsif($$self{node}{tag} eq 'XMTok'){ # Already in a XMTok, just insert the text
    $$self{node}->insert(LaTeXML::TextNode->new($box,_locator=>$box)); } # Should be safe...
  else {			# Shouldn't happen?  Should I distinguish space from `real' stuff?
# No, maybe this is `normal' after all...
#    Warn("Inserting raw text \"$box\" within math ".Stringify($$self{node})."; Converting to XMTok");
    $self->insertMathToken($box,font=>$LaTeXML::BOX->getFont); }}

#**********************************************************************
# Low level internal interface
sub openText_internal {
  my($self,$text)=@_;
  my $tag = $$self{node}{tag};
  if($tag eq '#PCDATA'){ # current node is a text node.
    $$self{node}->appendText($text); }
  elsif(($text =~/\S/) || $MODEL->canContain($tag,'#PCDATA')){  # Ignore stray whitespace
    my $node = LaTeXML::TextNode->new($text,_locator=>$LaTeXML::BOX);
    $self->openNode_internal($node); }}

# Insert a child node, return the child as the current node, assuming this one were.
sub openNode_internal {
  my($self,$child)=@_;
  Fatal("Expected Node; got ".Stringify($child)) unless defined $child && $child->isaNode;
  my $tag = $$self{node}{tag};
  my $ctag = $$child{tag};
  if($MODEL->canContain($tag,$ctag)){ # $child is allowed here, insert it!
    $$self{node} = $$self{node}->insert($child); }
  elsif(my $via=$MODEL->canContainIndirect($tag,$ctag)){ # Can be subchild if $via is between
    $self->openElement($via);				      # Open intermediary node.
    $self->openNode_internal($child); } # And retry insertion (should work now).
  else {			# Now we're getting more desparate...
    # Check if we can auto close some nodes, and _then_ insert the child.
    my($n,$t) = ($$self{node}, $$self{node}{tag});
    while(defined $n && $MODEL->canAutoClose($t)){
      if(defined(my $p = $n->getParentNode)){
	my $pt = $$p{tag};
	last if $MODEL->canContain($pt,$ctag) || $MODEL->canContainIndirect($pt,$ctag);
	$n = $p; $t = $pt; }
      else {
	$n = undef; }}

    if(defined $n && $MODEL->canAutoClose($t)){
      $self->closeNode_internal($n); # Close the auto closeable nodes.
      $self->openNode_internal($child); }	    # Then retry, possibly w/auto open's
    else {					    # Didn't find a legit place.
      $n = $$self{node};
      while(defined $n && ($$n{tag} eq '#PCDATA')){ # Get an element node!
	$n = $n->getParentNode; }
      Error(Stringify($child)." isn't allowed in ".Stringify($n));
      $n->insert($child);	# But we'll do it anyway, unless Error => Fatal.
      $$self{node} = $child; }}}

# No checking! Use this when you've already verified that the $tag can be closed.
sub closeNode_internal {
  my($self,$node)=@_;
  my $n = $$self{node};
  while(1){
    if(defined(my $post= $MODEL->getTagProperty($$n{tag},'afterClose'))){
      &$post($n,$LaTeXML::BOX); }
    last if $node eq $n;
    $n = $n->getParentNode; }
  $$self{node} = $node->getParentNode; }

sub floatToElement {
  my($self,$tag)=@_;
  my $savenode;
  for(my $n=$self->getNode; defined $n; $n = $n->getParentNode){
    if($MODEL->canContain($$n{tag},$tag)){
      $savenode = $self->getNode; $self->setNode($n); last; }}
  $savenode; }

sub floatToAttribute {
  my($self,$key)=@_;
  my $savenode;
  my $n = $$self{node};
  while(defined $n && ! $MODEL->canHaveAttribute($$n{tag},$key)){
    $n = $n->getParentNode; }
  if(defined $n){
    $savenode = $$self{node};
    $$self{node}=$n; }
  else {
    Error("No open node can accept attribute $key; in ".$self->getNodePath); }
  $savenode; }

#**********************************************************************
# Middle level, mostly public, API.
# Handlers for various construction operations.
# General naming: 'open' opens a node at current pos and sets it to current,
# 'close' closes current node(s), inserts opens & closes, ie. w/o moving current


# Tricky: Insert some text in a particular font.
# We need to find the current effective -- being the closest  _declared_ font,
# (ie. it will appear in the elements attributes).  We may also want
# to open/close some elements in such a way as to minimize the font switchiness.
# I guess we should only open/close "textstyle" elements, though.
# [Actually, we'd like the user to _declare_ what element to use....
#  I don't like having "textstyle" built in here!
#  AND, we've assumed that "font" names the relevant attribute!!!]

our $FONTTAG = "textstyle";	# Eventually declared somewhere???
sub openText {
  my($self,$text,$font)=@_;
  my $n = $$self{node};
  my ($bestdiff,$closeto)=(99999,$n);
  while(defined $n){
    my $d = $font->distance($n->getAttribute('_font'));
    if($d < $bestdiff){
      $bestdiff = $d;
      $closeto = $n;
      last if ($d == 0); }
    my $t=$$n{tag};
    last unless ($t eq $FONTTAG) || ($t eq '#PCDATA');
    $n = $n->getParentNode; }
  $$self{node} = $closeto;	# Move to best starting point for this text.
  $self->openElement($FONTTAG,font=>$font) if $bestdiff > 0; # Open if needed.
  # Finally, insert the darned text.
  $self->openText_internal($text); }

sub insertMathToken {
  my($self,$string,%attributes)=@_;
  my $node = $self->openElement('XMTok', %attributes);
  $node->insert(LaTeXML::TextNode->new($string,_locator=>$LaTeXML::BOX));
  $self->closeNode_internal($node); } # Should be safe.

sub openElement {
  my($self,$tag,%attributes)=@_;
  NoteProgress('.') if ($$self{progress}++ % 25)==0;
  $attributes{_namespace} = $MODEL->getDefaultNamespace unless $attributes{_namespace};
  $attributes{_locator}   = $LaTeXML::BOX unless $attributes{_locator};
  my $node = LaTeXML::Node->new($tag,%attributes);
  $self->openNode_internal($node);
  if(defined(my $post=$MODEL->getTagProperty($tag,'afterOpen'))){
    &$post($$self{node},$LaTeXML::BOX); }
  $$self{node}; }

sub closeElement {
  my($self,$tag)=@_;
  my $node = $$self{node};
  # First, check whether $tag is closeable.
  my ($t, @cant_close) = ();
  while(defined $node && (($t=$$node{tag}) ne $tag)){
    push(@cant_close,$node) unless $MODEL->canAutoClose($t);
    $node = $node->getParentNode; }
  if(!defined $node){		# Didn't find an open $tag at all!
    Error("Attempt to close $tag, which isn't open; in ".$self->getNodePath); }
  else {
    # Found node, but has intervening non-auto-closeable parents
    # Will go ahead and close them anyway, unless Error ends up a Fatal error.
    Error("Closing $tag whose open descendents (".
	  join(', ',map(Stringify($_),@cant_close)).") dont auto-close")
      if @cant_close;
    # So, now close up to the desired node.
    $self->closeNode_internal($node); }}

# Close $tag, if it is closeable.
sub maybeCloseElement {
  my($self,$tag)=@_;
  my($node,$t) = ($$self{node},undef);
  while(defined $node && (($t=$$node{tag}) ne $tag)){
    return unless $MODEL->canAutoClose($t);
    $node = $node->getParentNode; }
  $self->closeNode_internal($node) if $node; }

# Insert a new comment, or append to previous comment.
# Note: shouldn't this just move back to parent??
sub insertComment {
  my($self,$text)=@_;
  my $node = $$self{node};
  if($$node{tag} eq '_Comment_'){
    $node->appendComment($text); }
  else {
    while(defined $node && ($$node{tag} eq '#PCDATA')){ # Get an element node!
      $node = $node->getParentNode; }
    $$self{node} = $node->insert(LaTeXML::CommentNode->new($text,_locator=>$LaTeXML::BOX)); }}

sub insertPI {
  my($self,$op,%attrib)=@_;
  my $node = $$self{node};
  while(defined $node && ((ref $node) !~ /^(LaTeXML::Node|LaTeXML::Document)$/)){ # Get an element node!
    $node = $node->getParentNode; }
  $node->insert(LaTeXML::ProcessingInstruction->new($op,_locator=>$LaTeXML::BOX,%attrib));}

# Shorthand
sub insertElement {
  my($self,$tag,$content,%attrib)=@_;
  $self->openElement($tag,%attrib);
  if(ref $content eq 'ARRAY'){
    map($self->absorb($_), @$content); }
  elsif(defined $content){
    $self->absorb($content); }
  $self->closeElement($tag); }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Intestine

=head2 DESCRIPTION

C<LaTeXML::Intestine> carries out the construction of the document tree by traversing 
the digested L<LaTeXML::List> coming from the L<LaTeXML::Stomach>.  It is primarily
the L<LaTeXML::Constructor> patterns encoded in L<LaTeXML::Whatsit>s that generate the
interesting structure.  An intermediate representation of the document tree
using L<LaTeXML::Node> is first built, which is then converted
to an L<XML::LibXML::Document>.

=head2 Top-Level Method

=over 4

=item C<< $doc = $intestine->buildDOM($list); >>

Build and return an L<XML::LibXML::Document> from the digested C<$list>.
This is done by recursively "absorb"ing the digested objects.

=back

=head2 Accessing the Intestine's state

=over 4

=item C<< $doc = $intestine->getRootNode; >>

Returns the root node (L<LaTeXML::Document>) of the document being constructed.

=item C<< $node = $intestine->getNode; >>

Returns the node at the current insertion point during construction.  This node
is considered still to be `open'; any insertions will go into it (if possible).

=item C<< $intestine->setNode($node); >>

Sets C<$node> to be the current insertion point during construction.
This should be rarely used, if at all; The construction methods of intestine
generally maintain the notion of insertion point automatically.

=back

=head2 Methods useful for Document Construction

=over 4

=item C<< $intestine->absorb($digested); >>

Absorb the C<$digested> object into the document at the current insertion point
according to its type.  Various of the the other methods are invoked as needed,
and document nodes may be automatically opened or closed according to the document
model.

=item C<< $intestine->openText($text,$font); >>

Open a text node in font C<$font>, performing any required automatic opening
and closing of intermedate nodes (including those needed for font changes)
and inserting the string C<$text> into it.

=item C<< $intestine->insertMathToken($string,%attributes); >>

Insert a math token (XMTok) containing the string C<$string> with the given attributes.
Useful attributes would be name, role, font.

=item C<< $intestine->openElement($tag,%attributes); >>

Open an element, named C<$tag> and with the given attributes.
This will be inserted into the current node while  performing 
any required automatic opening and closing of intermedate nodes.
The new element becomes the current node.
An error (fatal if in C<Strict> mode) is signalled if there is no allowed way
to insert such an element into the current node.

=item C<< $intestine->closeElement($tag); >>

Close the closest open element named C<$tag> including any intermedate nodes that
may be automatically closed.  If that is not possible, signal an error.
The closed node's parent becomes the current node.

=item C<< $intestine->insertComment($text); >>

Insert a comment with the given C<$text> into the current node.

=item C<< $intestine->insertPI($op,%attributes); >>

Insert a ProcessingInstruction into the current node.

=item C<< $intestine->insertElement($tag,$content,%attributes); >>

This is a shorthand for creating an element C<$tag> (with given attributes),
absorbing C<$content> from within that new node, and then closing it.
The C<$content> must be digested material, either a single box, or
an array of boxes.

=cut

