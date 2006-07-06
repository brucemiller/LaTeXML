# /=====================================================================\ #
# |  LaTeXML::Document                                                 | #
# | Constructs the Document from digested material                      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Document;
use strict;
use LaTeXML::Global;
use LaTeXML::Object;
use XML::LibXML;
use Unicode::Normalize;

our @ISA = qw(LaTeXML::Object);

#**********************************************************************

# [could conceivable make more sense to let the Stomach create the Document?]

# Mystery attributes:
#    font :
#       Probably should keep font ONLY in extra properties, 
#        THEN once complete, compute the relative font at each node that accepts
#       a font attribute, and add the attribute.
#   locator : a box
#   namespace

sub new {
  my($class)=@_;
  my $doc = XML::LibXML::Document->new("1.0","UTF-8");
  # We'll set the DocType when the 1st Element gets added.
  bless { document=>$doc, node=>$doc,
	  idstore=>{}, node_fonts=>{}, node_boxes=>{}, node_properties=>{}, 
	  pending=>[], progress=>0},$class; }

#**********************************************************************
# Accessors

# This will be a node of type XML_DOCUMENT_NODE
sub getDocument { $_[0]->{document}; }

# Get the node representing the current insertion point.
# The node will have nodeType of
#   XML_DOCUMENT_NODE if the document is empty, so far.
#   XML_ELEMENT_NODE  for normal elements.
#   XML_TEXT_NODE     if the last insertion was text
# The other node types will not appear here.
sub getNode     { $_[0]->{node}; }
sub setNode     { $_[0]->{node} = $_[1]; }

# And some utilities
sub getNodePath {
  my($self)=@_;
  my $node = $$self{node};
  my $path = ($node->getType == XML_TEXT_NODE ? "_Text_" : $node->nodeName);
  while($node = $node->parentNode){
    $path .= " < ".($node->getType == XML_DOCUMENT_NODE ? "_Document_" : $node->nodeName); }
  $path; }

#**********************************************************************

# This should be called before returning the final XML::LibXML::Document to the
# outside world.  It resolves the fonts for each node relative to it's ancestors.
# It removes the `helper' attributes that store fonts, source box, etc.
sub finalize {
  my($self)=@_;

  my $root = $self->getDocument->documentElement;
  local $LaTeXML::FONT = $self->getNodeFont($root);
  $self->finalize_rec($root);
  $$self{document}; }

sub finalize_rec {
  my($self,$node)=@_;
  my $declared_font = $LaTeXML::FONT;
  if(my $font_attr = $node->getAttribute('_font')){
    if($MODEL->canHaveAttribute($node->nodeName,'font') && $node->hasChildNodes){
      my $font = $$self{node_fonts}{$font_attr};
      if(my $fontdecl = $font->relativeTo($LaTeXML::FONT)){
	$node->setAttribute(font=>$fontdecl);
	$declared_font = $font; }}}

  $node->removeAttribute('_font');
  $node->removeAttribute('_box');

##  # INSANE HACK for comparison! Sort the attributes!!!!
##  my %attr = map( ($_->nodeName => $_->getValue), grep($_->nodeType==XML_ATTRIBUTE_NODE,$node->attributes));
##  map($node->removeAttribute($_), keys %attr);
##  map($node->setAttribute($_,$attr{$_}), sort keys %attr);

  local $LaTeXML::FONT = $declared_font;
  foreach my $child ($node->childNodes){
    $self->finalize_rec($child)
      if $child->nodeType == XML_ELEMENT_NODE; }}

#**********************************************************************
# Record nodes by id
sub recordID {
  my($self,$id,$object)=@_;
  $$self{idstore}{$id}=$object; }

sub lookupID {
  my($self,$id)=@_;
  $$self{idstore}{$id}; }

#**********************************************************************

# Record the Box that created this node.
sub setNodeBox {
  my($self,$node,$box)=@_;
  return unless $box;
  my $boxid = "$box";
  $$self{node_boxes}{$boxid} = $box;
  $node->setAttribute(_box=>$boxid); }

sub getNodeBox {
  my($self,$node)=@_;
  return undef if $node->nodeType == XML_DOCUMENT_NODE;
  if(my $boxid = $node->getAttribute('_box')){
    $$self{node_boxes}{$boxid}; }}

sub setNodeFont {
  my($self,$node,$font)=@_;
#  my $fontid = "$font";
  my $fontid = $font->toString;
  $$self{node_fonts}{$fontid} = $font;
  $node->setAttribute(_font=>$fontid); }

sub getNodeFont {
  my($self,$node)=@_;
  ($node->nodeType == XML_DOCUMENT_NODE ? LaTeXML::Font->default()
   : $$self{node_fonts}{$node->getAttribute('_font')}); }

#**********************************************************************
# absorb a given object into the DOM.
sub absorb {
  my($self,$box)=@_;
  if(!defined $box){}
  elsif(ref $box){
    local $LaTeXML::BOX = $box;
    $box->beAbsorbed($self); }
  # The following handle inserting raw strings, presumably within the context of some constructor?
  elsif(!$LaTeXML::BOX->isMath){
    $self->openText_internal($box); }
  # Note that in math mode text nodes appear ONLY in <XMTok> or <text>!!!
  elsif($$self{node}->nodeName eq 'XMTok'){ # Already in a XMTok, just insert the text
    print STDERR "Appending text \"$box\" to XMTok ".Stringify($$self{node})."\n" if $LaTeXML::Document::DEBUG;
    $$self{node}->appendText(NFC($box)); }
  else {			# Shouldn't happen?  Should I distinguish space from `real' stuff?
    # Odd case: constructors that work in math & text can insert raw strings in Math mode.
    $self->insertMathToken($box,font=>$LaTeXML::BOX->getFont); }}

#**********************************************************************
# Low level internal interface
sub openText_internal {
  my($self,$text)=@_;
  if($$self{node}->nodeType == XML_TEXT_NODE){ # current node is a text node.
    print STDERR "Appending text \"$text\" to ".Stringify($$self{node})."\n"  if $LaTeXML::Document::DEBUG;
    $$self{node}->appendData(NFC($text)); }
  elsif(($text =~/\S/) || $MODEL->canContain($$self{node}->nodeName,'#PCDATA')){  # Ignore stray whitespace
    my $point = $self->find_insertion_point('#PCDATA');
    my $node = $$self{document}->createTextNode(NFC($text));
    print STDERR "Inserting text node ".Stringify($node)." for \"$text\" into ".Stringify($point)."\n"
       if $LaTeXML::Document::DEBUG;
###    $self->setNodeBox($node,$LaTeXML::BOX);
    $point->appendChild($node);
    $$self{node} = $node; }}

# Find the node where an element of $tag can be inserted.
# This will move up (closing auto-closable elements), or down (inserting 
# auto-openable elements), as needed.
sub find_insertion_point {
  my($self,$tag)=@_;
  if($$self{node}->nodeType == XML_TEXT_NODE){ # Up past current text node, if any
    $$self{node} = $$self{node}->parentNode; }
  my $curtag;
  my $type = $$self{node}->nodeType;
  if($type == XML_DOCUMENT_NODE){ $curtag = '_Document_'; }
  elsif($type == XML_ELEMENT_NODE){ $curtag = $$self{node}->nodeName; }
  else { Fatal("Insertion found node of unexpected type $type: ".Stringify($$self{node})); }

  if($MODEL->canContain($curtag,$tag)){ # $tag is allowed here, insert it!
    $$self{node}; }
  elsif(my $via=$MODEL->canContainIndirect($curtag,$tag)){ # $tag can be subchild if $via is between
    $self->openElement($via,font=> $self->getNodeFont($$self{node})); # Open intermediary node.
    $self->find_insertion_point($tag); } # And retry insertion (should work now).
  else {			# Now we're getting more desparate...
    # Check if we can auto close some nodes, and _then_ insert the $tag.
    my ($n,$closeto) = ($$self{node});
    while(($n->nodeType != XML_DOCUMENT_NODE) && $MODEL->canAutoClose($n->nodeName)){
      my $p = $n->parentNode;
      if($MODEL->canContainSomehow(($p->nodeType == XML_DOCUMENT_NODE ? '_Document_':$p->nodeName),$tag)){
	$closeto=$n; last; }
      $n = $p; }
    if($closeto){
      $self->closeNode_internal($closeto); # Close the auto closeable nodes.
      $self->find_insertion_point($tag); }	    # Then retry, possibly w/auto open's
    else {					    # Didn't find a legit place.
      Error("$tag isn't allowed in ".Stringify($$self{node}));
      $$self{node}; }}}	# But we'll do it anyway, unless Error => Fatal.

# No checking! Use this when you've already verified that the $tag can be closed.
sub closeNode_internal {
  my($self,$node)=@_;
  my $closeto = $node->parentNode; # Grab now in case afterClose screws the structure.
  my $n = $$self{node};
  $n = $n->parentNode if $n->nodeType == XML_TEXT_NODE;
  while($n->nodeType != XML_DOCUMENT_NODE){
    if(my $post= $MODEL->getTagProperty($n->nodeName,'afterClose')){
      &$post($n,$LaTeXML::BOX); }
    last if $$node eq $$n;	# NOTE: This equality test is questionable
    $n = $n->parentNode; }
  print STDERR "Closing ".Stringify($node)." => ".Stringify($closeto)."\n" if $LaTeXML::Document::DEBUG;
  $$self{node} = $closeto; }

# find an ancestor node that can contain an element $tag
# returns undef if no such place
sub floatToElement {
  my($self,$tag)=@_;
  my $n = $$self{node};
  $n = $n->parentNode if $n->nodeType == XML_TEXT_NODE;
  while(($n->nodeType != XML_DOCUMENT_NODE) && ! $MODEL->canContain($n->nodeName,$tag)){
    $n = $n->parentNode; }
  if($n->nodeType != XML_DOCUMENT_NODE){
    my $savenode = $$self{node};
    $$self{node}=$n;
    $savenode; }
  else { undef; }}

sub floatToAttribute {
  my($self,$key)=@_;
  my $n = $$self{node};
  $n = $n->parentNode if $n->nodeType == XML_TEXT_NODE;
  while(($n->nodeType != XML_DOCUMENT_NODE) && ! $MODEL->canHaveAttribute($n->nodeName,$key)){
    $n = $n->parentNode; }
  if($n->nodeType != XML_DOCUMENT_NODE){
    my $savenode = $$self{node};
    $$self{node}=$n;
    $savenode; }
  else { undef; }}

# Add the given attribute to the nearest node that is allowed to have it.
sub addAttribute {
  my($self,$key,$value)=@_;
  my $n = $$self{node};
  $n = $n->parentNode if $n->nodeType == XML_TEXT_NODE;
  while(($n->nodeType != XML_DOCUMENT_NODE) && ! $MODEL->canHaveAttribute($n->nodeName,$key)){
    $n = $n->parentNode; }
  if($n->nodeType != XML_DOCUMENT_NODE){
    $n->setAttribute($key=>$value); }
  else {
    Error("Attribute $key (=>$value) not allowed in ".Stringify($$self{node})." or ancestors"); }}

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
  return if $text=~/^\s+$/ && $$self{node}->nodeType == XML_DOCUMENT_NODE; # Ignore initial whitespace
  print STDERR "Insert text \"$text\" at ".Stringify($$self{node})."\n" if $LaTeXML::Document::DEBUG;
  my $startnode = $$self{node};
  $startnode = $startnode->parentNode if $startnode->nodeType == XML_TEXT_NODE;
  my ($bestdiff,$closeto)=(99999,$startnode);
  my $n = $startnode;
  while($n->nodeType != XML_DOCUMENT_NODE){
    my $d = $font->distance($self->getNodeFont($n));
    if($d < $bestdiff){
      $bestdiff = $d;
      $closeto = $n;
      last if ($d == 0); }
    last unless ($n->nodeName eq $FONTTAG);
    $n = $n->parentNode; }
  $$self{node} = $closeto if $closeto ne $startnode;	# Move to best starting point for this text.
  $self->openElement($FONTTAG,font=>$font) if $bestdiff > 0; # Open if needed.
  # Finally, insert the darned text.
  $self->openText_internal($text); }

sub insertMathToken {
  my($self,$string,%attributes)=@_;
  $attributes{role}='UNKNOWN' unless $attributes{role};
  my $node = $self->openElement('XMTok', %attributes);
  my $font = $attributes{font} || $LaTeXML::BOX->getFont;
  $self->setNodeFont($node,$font);
  $self->setNodeBox($node,$LaTeXML::BOX);
  $node->appendText(NFC($string));
  $self->closeNode_internal($node); } # Should be safe.

# Mystery:
#  How to deal with font declarations?
#  font vs _font; either must redirect to Font object until they are relativized, at end.
#  When relativizing, should it depend on font attribute on element and/or DTD allowed attribute?
sub openElement {
  my($self,$tag,%attributes)=@_;
  NoteProgress('.') if ($$self{progress}++ % 25)==0;
  print STDERR "Open element $tag at ".Stringify($$self{node})."\n" if $LaTeXML::Document::DEBUG;
  my $point = $self->find_insertion_point($tag);
  my $ns = $attributes{_namespace} || $MODEL->getDefaultNamespace;
  my $node;
  if($point->nodeType == XML_DOCUMENT_NODE){ # First node! (?)
    $$self{document}->createInternalSubset($tag,$MODEL->getPublicID,$MODEL->getSystemID);
    map( $$self{node}->appendChild($_), @{$$self{pending}});
    $node = ($ns ? $$self{document}->createElementNS($ns,$tag) : $$self{document}->createElement($tag));
    $$self{document}->setDocumentElement($node); 
    $node->setNamespace("http://www.w3.org/XML/1998/namespace",'xml',0);
}
  else {
    $node = ($ns ? $point->addNewChild($ns,$tag): $point->appendChild($$self{document}->createElement($tag))); }
#    $node = ($ns ? $$self{document}->createElementNS($ns,$tag) : $$self{document}->createElement($tag));
#    $point->appendChild($node); }

##  print STDERR "Open Element $tag : font attribute = ".ToString($attributes{font})." Box font = ".ToString($LaTeXML::BOX->getFont)."\n"; 
  foreach my $key (sort keys %attributes){
    next if $key =~ /^_/;
    next if $key eq 'font';	# !!!
    next if $key eq 'locator';	# !!!
    my $value = $attributes{$key};
    $value = ToString($value) if ref $value;
    next unless $value;
#    if($key=~/^xml:(.*)$/){
#      $node->setAttributeNS($MODEL->getNamespace('xml'),$key=>$value); }
#    els
    if(($key=~/^(.*):(.*)$/) && ($1 ne 'xml')){
      my($prefix,$name)=($1,$2);
      $node->setAttributeNS($MODEL->getNamespace($prefix),$name=>$value); }
    else {
      $node->setAttribute($key=>$value) if defined $value; }
}

  $self->setNodeFont($node, $attributes{font}||$LaTeXML::BOX->getFont);
  $self->setNodeBox($node, $LaTeXML::BOX);
  print STDERR "Inserting ".Stringify($node)." into ".Stringify($point)."\n" if $LaTeXML::Document::DEBUG;
  $$self{node} = $node;
  if(defined(my $post=$MODEL->getTagProperty($tag,'afterOpen'))){
    &$post($$self{node},$LaTeXML::BOX); }
  $$self{node}; }

sub closeElement {
  my($self,$tag)=@_;
  print STDERR "Close element $tag at ".Stringify($$self{node})."\n" if $LaTeXML::Document::DEBUG;
  my ($node, @cant_close) = ($$self{node});
  $node = $node->parentNode if $node->nodeType == XML_TEXT_NODE;
  while($node->nodeType != XML_DOCUMENT_NODE){
    my $t = $node->nodeName;
    last if $t eq $tag;
    push(@cant_close,$t) unless $MODEL->canAutoClose($t);
    $node = $node->parentNode; }
  if($node->nodeType == XML_DOCUMENT_NODE){ # Didn't find $tag at all!!
    Error("Attempt to close $tag, which isn't open; in ".$self->getNodePath); }
  else {			# Found node.
    # Intervening non-auto-closeable nodes!!
    Error("Closing $tag whose open descendents (".
	  join(', ',map(Stringify($_),@cant_close)).") dont auto-close")
      if @cant_close;
    # So, now close up to the desired node.
    $self->closeNode_internal($node); }}

# Check whether it is possible to close each element in @tags,
# any intervening nodes must be autocloseable.
# returning the last node that would be closed if it is possible,
# otherwise undef.
sub isCloseable {
  my($self,@tags)=@_;
  my($node,$t) = ($$self{node},undef);
  $node = $node->parentNode if $node->nodeType == XML_TEXT_NODE;
  while(my $tag = shift(@tags)){
    while(1){
      return if $node->nodeType == XML_DOCUMENT_NODE;
      last if ($t=$node->nodeName) eq $tag;
      return unless $MODEL->canAutoClose($t);
      $node = $node->parentNode; }
    $node = $node->parentNode if @tags; }
  $node; }

# Close $tag, if it is closeable.
sub maybeCloseElement {
  my($self,$tag)=@_;
  my $node = $self->isCloseable($tag);
  $self->closeNode_internal($node) if $node; }

# Shorthand
sub insertElement {
  my($self,$tag,$content,%attrib)=@_;
  $self->openElement($tag,%attrib);
  if(ref $content eq 'ARRAY'){
    map($self->absorb($_), @$content); }
  elsif(defined $content){
    $self->absorb($content); }
  $self->closeElement($tag); }

# Insert a new comment, or append to previous comment.
# Does NOT move the current insertion point to the Comment,
# but may move up past a text node.
sub insertComment {
  my($self,$text)=@_;
  chomp($text);
  $text =~ s/\-\-+/__/g;
  $text = NFC($text);
  if($$self{node}->nodeType == XML_TEXT_NODE){  # Get above plain text node!
    $$self{node} = $$self{node}->parentNode; }
  my $prev;
  if($$self{node}->nodeType == XML_DOCUMENT_NODE){
    push(@{$$self{pending}}, $$self{document}->createComment(' '.$text.' ')); }
  elsif(($prev = $$self{node}->lastChild) && ($prev->nodeType == XML_COMMENT_NODE)){
#    $prev->appendData("\n".$text); }  # DOES NOT WORK !?!?!?!
    $prev->setData($prev->data."\n     ".$text); }
  else {
    $$self{node}->appendChild($$self{document}->createComment(' '.$text.' ')); }}

# Insert a ProcessingInstruction of the form <?op attr=value ...?>
# Does NOT move the current insertion point to the PI,
# but may move up past a text node.
sub insertPI {
  my($self,$op,%attrib)=@_;
  # We'll just put these on the document itself.
  my $data = join(' ',map($_."=\"".ToString($attrib{$_})."\"",keys %attrib));
  my $pi = $$self{document}->createProcessingInstruction($op,$data);

  if($$self{node}->nodeType == XML_TEXT_NODE){  # Get above plain text node!
    $$self{node} = $$self{node}->parentNode; }
  if($$self{node}->nodeType == XML_DOCUMENT_NODE){
    push(@{$$self{pending}}, $pi); }
  else {
    $$self{node}->appendChild($pi); }
  $pi; }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Document

=head2 DESCRIPTION

C<LaTeXML::Document> carries out the construction of the document tree by traversing 
the digested L<LaTeXML::List> coming from the L<LaTeXML::Stomach>.  It is primarily
the L<LaTeXML::Constructor> patterns encoded in L<LaTeXML::Whatsit>s that generate the
interesting structure.  An intermediate representation of the document tree
using L<LaTeXML::Node> is first built, which is then converted
to an L<XML::LibXML::Document>.

=head2 Accessing the Document's state

=over 4

=item C<< $doc = $document->getDocument; >>

Returns the C<XML::LibXML::Document> currently being constructed.

=item C<< $node = $document->getNode; >>

Returns the node at the current insertion point during construction.  This node
is considered still to be `open'; any insertions will go into it (if possible).

=item C<< $document->setNode($node); >>

Sets C<$node> to be the current insertion point during construction.
This should be rarely used, if at all; The construction methods of document
generally maintain the notion of insertion point automatically.

=item C<< $node = $document->isCloseable($tag); >>

Check whether it is possible to close a C<$tag> element,
returning the node that would be closed if possible,
otherwise undef.

=back

=head2 Methods useful for Document Construction

=over 4

=item C<< $document->absorb($digested); >>

Absorb the C<$digested> object into the document at the current insertion point
according to its type.  Various of the the other methods are invoked as needed,
and document nodes may be automatically opened or closed according to the document
model.

=item C<< $document->openText($text,$font); >>

Open a text node in font C<$font>, performing any required automatic opening
and closing of intermedate nodes (including those needed for font changes)
and inserting the string C<$text> into it.

=item C<< $document->insertMathToken($string,%attributes); >>

Insert a math token (XMTok) containing the string C<$string> with the given attributes.
Useful attributes would be name, role, font.

=item C<< $document->openElement($tag,%attributes); >>

Open an element, named C<$tag> and with the given attributes.
This will be inserted into the current node while  performing 
any required automatic opening and closing of intermedate nodes.
The new element becomes the current node.
An error (fatal if in C<Strict> mode) is signalled if there is no allowed way
to insert such an element into the current node.

=item C<< $document->closeElement($tag); >>

Close the closest open element named C<$tag> including any intermedate nodes that
may be automatically closed.  If that is not possible, signal an error.
The closed node's parent becomes the current node.

=item C<< $document->insertComment($text); >>

Insert a comment with the given C<$text> into the current node.

=item C<< $document->insertPI($op,%attributes); >>

Insert a ProcessingInstruction into the current node.

=item C<< $document->insertElement($tag,$content,%attributes); >>

This is a shorthand for creating an element C<$tag> (with given attributes),
absorbing C<$content> from within that new node, and then closing it.
The C<$content> must be digested material, either a single box, or
an array of boxes.

=item C<< $document->addAttribute($key=>$value); >>

Add the given attribute to the nearest node that is allowed to have it.

-back

=cut

